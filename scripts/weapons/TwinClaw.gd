extends "res://scripts/weapons/Weapon.gd"
class_name TwinClaw

@export var zone_scene: PackedScene = preload("res://scenes/weapons/DamageZone.tscn")
@export var slash_vfx_scene: PackedScene = preload("res://scenes/weapons/SlashVFX.tscn")
@export var claw_radius: float = 70.0
@export var reach: float = 95.0
@export var slashes_per_fire: int = 1

@export var lifesteal_ratio: float = 0.05


func _try_shoot() -> bool:
	if not zone_scene:
		return false

	var player_node: Node = get_parent()
	var dir := _get_attack_direction(player_node)

	var count: int = maxi(1, slashes_per_fire)
	for _i in range(count):
		var fpos := global_position + dir * reach
		var bpos := global_position - dir * reach
		_spawn_slash_vfx(fpos, dir, claw_radius)
		_spawn_slash_vfx(bpos, -dir, claw_radius)
		_spawn_zone(fpos, claw_radius, damage * owner_damage_mult, player_node)
		_spawn_zone(bpos, claw_radius, damage * owner_damage_mult, player_node)
	return true


func _get_attack_direction(player_node: Node) -> Vector2:
	# Prefer the nearest enemy so the attack works even when the player isn't moving.
	var enemies := _get_active_enemies()
	var origin := global_position
	var best: Node2D = null
	var min_d2 := INF
	for e in enemies:
		var d2 := origin.distance_squared_to(e.global_position)
		if d2 < min_d2:
			min_d2 = d2
			best = e
	if best:
		var to_enemy := origin.direction_to(best.global_position)
		if to_enemy != Vector2.ZERO:
			return to_enemy.normalized()

	# Fallback: keep existing behavior (aim direction) when there are no enemies.
	var dir := Vector2.RIGHT
	if player_node and player_node.has_method("get_aim_direction"):
		dir = player_node.call("get_aim_direction")
	if dir == Vector2.ZERO:
		return Vector2.RIGHT
	return dir.normalized()


func _spawn_slash_vfx(pos: Vector2, direction: Vector2, r: float) -> void:
	if not slash_vfx_scene:
		return
	var fx = slash_vfx_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx.has_method("spawn"):
		fx.spawn(pos, direction, r, 0.10)


func _spawn_zone(pos: Vector2, r: float, dmg: float, instigator: Node) -> void:
	var zone = zone_scene.instantiate()
	get_tree().current_scene.add_child(zone)
	if zone.has_method("spawn"):
		zone.spawn(pos, r, dmg, instigator, lifesteal_ratio)
	else:
		zone.global_position = pos
