extends "res://scripts/weapons/Weapon.gd"
class_name ShockwaveWeapon

@export var lightning_vfx_scene: PackedScene = preload("res://scenes/weapons/LightningVFX.tscn")
@export var start_range: float = 300.0
@export var chain_range: float = 220.0
@export var max_jumps: int = 4
@export var forks: int = 0
@export var damage_falloff: float = 0.9


func _try_shoot() -> bool:
	var enemies := _get_active_enemies()
	if enemies.is_empty():
		return false

	var first = _find_nearest_enemy(enemies, global_position, start_range, [])
	if not first:
		return false

	_do_chain(enemies, first, [])
	var fork_count := clampi(forks, 0, 2)
	for _i in range(fork_count):
		var alt = _find_nearest_enemy(enemies, global_position, start_range, [first])
		if alt:
			_do_chain(enemies, alt, [first])

	return true


func _do_chain(enemies: Array, first: Node2D, already_hit: Array) -> void:
	var hit: Array = []
	hit.append_array(already_hit)

	var current: Node2D = first
	var prev_pos: Vector2 = global_position
	var dmg := damage * owner_damage_mult
	var jumps: int = maxi(1, max_jumps)
	for _i in range(jumps):
		if not current or not is_instance_valid(current):
			break
		if current in hit:
			current = _find_nearest_enemy(enemies, current.global_position, chain_range, hit)
			continue
		if current.has_method("take_damage"):
			_spawn_lightning(prev_pos, current.global_position)
			current.take_damage(dmg)
			prev_pos = current.global_position
		hit.append(current)
		dmg *= clampf(damage_falloff, 0.25, 1.0)
		current = _find_nearest_enemy(enemies, current.global_position, chain_range, hit)


func _spawn_lightning(from_pos: Vector2, to_pos: Vector2) -> void:
	if not lightning_vfx_scene:
		return
	var fx = lightning_vfx_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx.has_method("spawn"):
		fx.spawn(from_pos, to_pos, 0.10)


func _find_nearest_enemy(enemies: Array, from_pos: Vector2, range_limit: float, exclude: Array) -> Node2D:
	var best: Node2D = null
	var min_dist_sq := INF
	var r2 := range_limit * range_limit
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e in exclude:
			continue
		if not (e is Node2D):
			continue
		var enemy := e as Node2D
		var d2 := from_pos.distance_squared_to(enemy.global_position)
		if d2 > r2:
			continue
		if d2 < min_dist_sq:
			min_dist_sq = d2
			best = enemy
	return best
