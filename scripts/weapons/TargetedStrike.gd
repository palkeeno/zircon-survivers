extends "res://scripts/weapons/Weapon.gd"
class_name TargetedStrike

@export var zone_scene: PackedScene
@export var strike_radius: float = 80.0
@export var strikes_per_fire: int = 1

func _try_shoot() -> bool:
	if not zone_scene:
		return false

	var count: int = maxi(1, strikes_per_fire)
	var targets := _find_nearest_enemies(count)
	if targets.is_empty():
		return false

	for i in range(count):
		var t: Node2D = targets[i % targets.size()]
		if not is_instance_valid(t):
			continue
		var pos: Vector2 = t.global_position
		if count > 1:
			# Small random offset around each target so multi-strikes feel punchy.
			pos += Vector2(randf_range(-22, 22), randf_range(-22, 22))
		var zone = zone_scene.instantiate()
		get_tree().current_scene.add_child(zone)
		if zone.has_method("spawn"):
			zone.spawn(pos, strike_radius, damage * owner_damage_mult)
		else:
			zone.global_position = pos
	return true

func _find_nearest_enemies(count: int) -> Array[Node2D]:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return []

	var my_pos: Vector2 = global_position
	var scored: Array = []
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not (e is Node2D):
			continue
		var n := e as Node2D
		scored.append({"n": n, "d2": my_pos.distance_squared_to(n.global_position)})

	if scored.is_empty():
		return []

	scored.sort_custom(func(a, b):
		return a["d2"] < b["d2"]
	)

	var out: Array[Node2D] = []
	var take: int = mini(maxi(1, count), scored.size())
	for i in range(take):
		out.append(scored[i]["n"])
	return out
