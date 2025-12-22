extends Node2D
class_name DamageZoneVFX

@export var radius: float = 80.0
@export var lifetime: float = 0.15
@export var color: Color = Color(1.0, 0.95, 0.80, 0.55)
@export var fill_alpha: float = 0.12
@export var rim_width: float = 4.0

var _t := 0.0

func restart(new_lifetime: float) -> void:
	lifetime = maxf(0.01, new_lifetime)
	_t = 0.0
	queue_redraw()

func _ready() -> void:
	z_index = 5
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var lt := maxf(0.01, lifetime)
	var p := clampf(_t / lt, 0.0, 1.0)
	var a := (1.0 - p)
	if a <= 0.0:
		return

	var r := maxf(1.0, radius) * lerpf(0.85, 1.0, p)
	var c := color
	c.a *= a

	# Soft fill
	var fill := c
	fill.a *= fill_alpha
	draw_circle(Vector2.ZERO, r, fill)

	# Bright rim
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, c, rim_width, true)

	# Strike lines (suggests impact)
	var lcol := c
	lcol.a *= 0.75
	draw_line(Vector2(-r, 0), Vector2(r, 0), lcol, rim_width * 0.6, true)
	draw_line(Vector2(0, -r), Vector2(0, r), lcol, rim_width * 0.6, true)
