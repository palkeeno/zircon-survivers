extends Node2D
class_name DamageZone

@export var radius: float = 80.0
@export var damage: float = 10.0
@export var life_time: float = 0.15

var _instigator: Node = null
var _lifesteal_ratio: float = 0.0

@onready var _vfx: Node = get_node_or_null("ZoneVFX")

func spawn(pos: Vector2, r: float, dmg: float, instigator: Node = null, lifesteal_ratio: float = 0.0, show_vfx: bool = true):
	global_position = pos
	radius = r
	damage = dmg
	_instigator = instigator
	_lifesteal_ratio = maxf(0.0, lifesteal_ratio)
	if _vfx and is_instance_valid(_vfx):
		if "visible" in _vfx:
			_vfx.visible = show_vfx
		if show_vfx:
			if "radius" in _vfx:
				_vfx.radius = radius
			if "lifetime" in _vfx:
				_vfx.lifetime = life_time
			if _vfx.has_method("restart"):
				_vfx.restart(life_time)
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
	var heal_total: float = 0.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			var dist2 = global_position.distance_squared_to(enemy.global_position)
			if dist2 <= r2:
				enemy.take_damage(damage)
				if _lifesteal_ratio > 0.0 and _instigator and is_instance_valid(_instigator) and _instigator.has_method("heal"):
					heal_total += damage * _lifesteal_ratio

	if heal_total > 0.0 and _instigator and is_instance_valid(_instigator) and _instigator.has_method("heal"):
		_instigator.heal(heal_total)
