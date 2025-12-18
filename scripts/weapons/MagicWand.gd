extends "res://scripts/weapons/Weapon.gd"
class_name MagicWand

@export var projectile_scene: PackedScene
@export var scan_interval: float = 0.1

var _nearest_enemy: Node2D = null

func _try_shoot() -> bool:
	if not projectile_scene:
		return false
	
	_find_nearest_enemy()
	
	if _nearest_enemy and is_instance_valid(_nearest_enemy):
		var direction = global_position.direction_to(_nearest_enemy.global_position)
		var count = max(1, shots_per_fire)
		for i in range(count):
			var dir_i = direction
			if count > 1:
				# Small random spread.
				var spread = deg_to_rad(8.0)
				dir_i = direction.rotated(randf_range(-spread, spread))
			_spawn_projectile(dir_i)
		return true
	
	return false

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
			
		# Simple distance check (squared for performance)
		var dist_sq = my_pos.distance_squared_to(enemy.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			nearest = enemy
	
	_nearest_enemy = nearest

func _spawn_projectile(direction: Vector2):
	var proj = null
	if has_node("/root/PoolManager"):
		proj = get_node("/root/PoolManager").get_instance(projectile_scene)
	
	if proj:
		# Add to tree if not already (PoolManager does it, but to PoolContainer)
		# We might want projectiles to be in a flat container for Ysort or just above everything
		# For now, relying on PoolManager's parent (PoolContainer) which is generic.
		# Ideally projectiles should be on a specific layer.
		
		# Initialize
		if proj.has_method("spawn"):
			proj.spawn(global_position, direction)
		else:
			proj.global_position = global_position

		# Apply common projectile modifiers if supported.
		if "damage" in proj:
			proj.damage = damage * owner_damage_mult
		if "scale" in proj and projectile_scale != 1.0:
			proj.scale = Vector2.ONE * projectile_scale
		if "pierce" in proj:
			proj.pierce = projectile_pierce
		if "explosion_radius" in proj:
			proj.explosion_radius = projectile_explosion_radius
