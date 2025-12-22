extends "res://scripts/weapons/Weapon.gd"
class_name FireBottle

@export var burning_zone_scene: PackedScene = preload("res://scenes/weapons/BurningZone.tscn")
@export var impact_vfx_scene: PackedScene = preload("res://scenes/weapons/ImpactVFX.tscn")

@export var throw_distance: float = 150.0
@export var throw_spread: float = 55.0

@export var burn_radius: float = 90.0
@export var burn_duration: float = 2.8
@export var burn_tick_interval: float = 0.35
@export var bottles_per_fire: int = 1


func _try_shoot() -> bool:
	if not burning_zone_scene:
		return false

	var count: int = maxi(1, bottles_per_fire)
	var dirs := _choose_directions(count)
	for dir in dirs:
		var pos := global_position + dir * throw_distance
		pos += Vector2(randf_range(-throw_spread, throw_spread), randf_range(-throw_spread, throw_spread))
		_spawn_impact_vfx(pos)
		var zone = burning_zone_scene.instantiate()
		get_tree().current_scene.add_child(zone)
		if zone.has_method("spawn"):
			zone.spawn(pos, burn_radius, damage * owner_damage_mult, burn_duration, burn_tick_interval)
		else:
			zone.global_position = pos

	return true


func _choose_directions(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var slots := 12
	var idxs: Array[int] = []
	idxs.resize(slots)
	for i in range(slots):
		idxs[i] = i
	idxs.shuffle()

	var take := mini(count, slots)
	for i in range(take):
		var a := TAU * (float(idxs[i]) / float(slots))
		out.append(Vector2.RIGHT.rotated(a).normalized())

	# If we exceed 12, allow repeats but try not to repeat the last direction.
	while out.size() < count:
		var next_i := randi_range(0, slots - 1)
		if out.size() > 0 and slots > 1:
			var last_dir := out[out.size() - 1]
			var last_idx := int(roundi((wrapf(last_dir.angle(), 0.0, TAU) / TAU) * float(slots))) % slots
			var guard := 0
			while next_i == last_idx and guard < 6:
				next_i = randi_range(0, slots - 1)
				guard += 1
		var aa := TAU * (float(next_i) / float(slots))
		out.append(Vector2.RIGHT.rotated(aa).normalized())

	return out


func _spawn_impact_vfx(pos: Vector2) -> void:
	if not impact_vfx_scene:
		return
	var fx = impact_vfx_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if "color" in fx:
		fx.color = Color(1.0, 0.55, 0.20, 0.75)
	if fx.has_method("spawn"):
		fx.spawn(pos, 24.0, 0.10)
