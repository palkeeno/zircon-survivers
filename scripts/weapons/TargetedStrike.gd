extends "res://scripts/weapons/Weapon.gd"
class_name TargetedStrike

@export var zone_scene: PackedScene
@export var strike_radius: float = 80.0
@export var strikes_per_fire: int = 1

# Multiplier applied to damage (can be overridden/set by the weapon/owner setup).
var owner_damage_mult: float = 1.0

var _nearest_enemy: Node2D = null

func _try_shoot() -> bool:
	_find_nearest_enemy()
	if not _nearest_enemy or not is_instance_valid(_nearest_enemy):
		return false
	if not zone_scene:
		return false

	var count = max(1, strikes_per_fire)
	for i in range(count):
		var pos = _nearest_enemy.global_position
		if count > 1:
			# Random offset around target
			pos += Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var zone = zone_scene.instantiate()
		get_tree().current_scene.add_child(zone)
		if zone.has_method("spawn"):
			zone.spawn(pos, strike_radius, damage * owner_damage_mult)
		else:
			zone.global_position = pos
	return true

func _find_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		_nearest_enemy = null
		return

	var min_dist_sq = INF
	var nearest = null
	var my_pos = global_position

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist_sq = my_pos.distance_squared_to(enemy.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			nearest = enemy

	_nearest_enemy = nearest
