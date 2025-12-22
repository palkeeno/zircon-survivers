extends Node2D
class_name HolyAuraVFX

@export var radius: float = 90.0
@export var fill_color: Color = Color(1.0, 0.97, 0.90, 0.06)
@export var rim_color: Color = Color(1.0, 0.97, 0.90, 0.35)
@export var rim_width: float = 4.0
@export var pulse_speed: float = 2.2
@export var pulse_amount: float = 0.06

var _t := 0.0

func _ready() -> void:
	z_index = -1
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var r := maxf(1.0, radius)
	var pulse := 1.0 + sin(_t * pulse_speed) * pulse_amount
	var outer := r * pulse
	var inner := outer * 0.55

	# Soft fill (multiple circles for a cheap radial falloff)
	var steps := 7
	for i in range(steps):
		var t := float(i) / float(max(1, steps - 1))
		var rr := lerpf(inner, outer, t)
		var c := fill_color
		c.a *= lerpf(1.0, 0.05, t)
		draw_circle(Vector2.ZERO, rr, c)

	# Bright rim
	var arc_points := 96
	draw_arc(Vector2.ZERO, outer, 0.0, TAU, arc_points, rim_color, rim_width, true)

	# Subtle shimmering highlights
	var shimmer := rim_color
	shimmer.a *= 0.35
	var a0 := fmod(_t * 0.8, TAU)
	draw_arc(Vector2.ZERO, outer, a0, a0 + 0.55, 24, shimmer, rim_width * 0.75, true)
	var a1 := fmod(_t * 0.8 + 2.4, TAU)
	draw_arc(Vector2.ZERO, outer, a1, a1 + 0.35, 18, shimmer, rim_width * 0.6, true)
