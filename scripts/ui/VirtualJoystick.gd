extends Control
class_name VirtualJoystick

enum JoystickMode {
	FIXED,
	DYNAMIC
}

enum VisibilityMode {
	ALWAYS,
	TOUCHSCREEN_ONLY
}

# Exposed properties
@export var deadzone_size : float = 10.0
@export var clampzone_size : float = 75.0
@export var joystick_mode : JoystickMode = JoystickMode.DYNAMIC
@export var visibility_mode : VisibilityMode = VisibilityMode.ALWAYS

# Internal references
@onready var _touch_zone = $TouchZone
@onready var _base = $Base
@onready var _tip = $Base/Tip

var _touch_index : int = -1
var _output : Vector2 = Vector2.ZERO

signal joystick_updated(output: Vector2)

func _ready():
	if visibility_mode == VisibilityMode.TOUCHSCREEN_ONLY and not DisplayServer.is_touchscreen_available():
		hide()

	_apply_visual_sizes()
	
	# Initial state: Base/Tip hidden, Zone visible
	_hide_joystick()

func _apply_visual_sizes() -> void:
	if _base == null or _tip == null:
		return

	# clampzone_size is treated as the movement radius (outer range circle).
	var range_radius: float = maxf(1.0, clampzone_size)
	var stick_radius: float = range_radius / 1.3

	_base.size = Vector2.ONE * (range_radius * 2.0)
	_tip.size = Vector2.ONE * (stick_radius * 2.0)
	_reset_tip_position()

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_point_inside_zone(event.position) and _touch_index == -1:
				_touch_index = event.index
				_show_joystick_at(event.position)
				_update_joystick(event.position)
		elif event.index == _touch_index:
			_reset_joystick()
			
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_joystick(event.position)

func _is_point_inside_zone(point: Vector2) -> bool:
	if _touch_zone:
		return _touch_zone.get_global_rect().has_point(point)
	return false

func _show_joystick_at(pos: Vector2):
	if _base:
		_base.visible = true
		_base.modulate.a = 1.0
		if joystick_mode == JoystickMode.DYNAMIC:
			_base.global_position = pos - _base.size / 2

func _hide_joystick():
	if _base:
		# Instead of hiding creating issues with layout, just Modulate alpha
		_base.modulate.a = 0.0
		# Checking 'visible' property might be safer for input pass-through but we handle input manually
	_reset_tip_position()

func _update_joystick(touch_position: Vector2):
	var center = _base.global_position + _base.size / 2
	var vector = touch_position - center
	
	if vector.length() > clampzone_size:
		vector = vector.normalized() * clampzone_size
	
	# Move Tip relative to Base center
	# Since Tip is child of Base, local position (size/2, size/2) is center.
	# We want Tip to move away from center by 'vector'
	
	_tip.global_position = center + vector - _tip.size / 2
	
	# Calculate output
	if vector.length() < deadzone_size:
		_output = Vector2.ZERO
	else:
		_output = vector.normalized() * ((vector.length() - deadzone_size) / (clampzone_size - deadzone_size))
	
	emit_signal("joystick_updated", _output)

func _reset_tip_position():
	if _base and _tip:
		_tip.position = _base.size / 2 - _tip.size / 2

func _reset_joystick():
	_touch_index = -1
	_output = Vector2.ZERO
	_hide_joystick()
	_reset_tip_position()
	emit_signal("joystick_updated", _output)

func get_output() -> Vector2:
	return _output
