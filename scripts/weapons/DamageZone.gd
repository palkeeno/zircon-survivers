extends Node2D
class_name DamageZone

@export var radius: float = 80.0
@export var damage: float = 10.0
@export var life_time: float = 0.15

func spawn(pos: Vector2, r: float, dmg: float):
	global_position = pos
	radius = r
	damage = dmg
	_apply_damage()
	# Small lifetime so it can be seen/debugged if you add visuals later.
	var t := Timer.new()
	t.wait_time = life_time
	t.one_shot = true
	add_child(t)
	t.timeout.connect(queue_free)
	t.start()

func _apply_damage():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var r2 = radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			var dist2 = global_position.distance_squared_to(enemy.global_position)
			if dist2 <= r2:
				enemy.take_damage(damage)
