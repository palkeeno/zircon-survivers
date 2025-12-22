extends Node2D
class_name BurningZone

@export var radius: float = 90.0
@export var damage_per_tick: float = 6.0
@export var duration: float = 2.8
@export var tick_interval: float = 0.35

@onready var _vfx: Node = get_node_or_null("ZoneVFX")

var _elapsed := 0.0
var _tick := 0.0


func spawn(pos: Vector2, r: float, dmg: float, dur: float, tick: float) -> void:
	global_position = pos
	radius = r
	damage_per_tick = dmg
	duration = max(0.05, dur)
	tick_interval = max(0.05, tick)

	_elapsed = 0.0
	_tick = 0.0

	if _vfx and is_instance_valid(_vfx):
		if "radius" in _vfx:
			_vfx.radius = radius
		if "lifetime" in _vfx:
			_vfx.lifetime = duration
		if _vfx.has_method("restart"):
			_vfx.restart(duration)

	set_process(true)
	_apply_damage()


func _process(delta: float) -> void:
	_elapsed += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		_apply_damage()
	if _elapsed >= duration:
		queue_free()


func _apply_damage() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var r2 = radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			var dist2 = global_position.distance_squared_to(enemy.global_position)
			if dist2 <= r2:
				enemy.take_damage(damage_per_tick)
