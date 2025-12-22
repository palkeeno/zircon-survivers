extends Node2D
class_name BeamVFX

@export var length: float = 420.0
@export var width: float = 26.0
@export var lifetime: float = 0.08
@export var color: Color = Color(1, 1, 1, 0.65)

var _t: float = 0.0


func spawn(origin: Vector2, direction: Vector2, beam_length: float, beam_width: float, life: float = 0.08) -> void:
	global_position = origin
	var dir := direction
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	rotation = dir.angle()
	length = maxf(1.0, beam_length)
	width = maxf(1.0, beam_width)
	lifetime = maxf(0.01, life)
	_t = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / maxf(0.01, lifetime), 0.0, 1.0)
	var a := (1.0 - p)
	if a <= 0.0:
		return

	var c := color
	c.a *= a
	var w := width
	var rect := Rect2(Vector2(0.0, -w * 0.5), Vector2(length, w))

	# Soft core
	draw_rect(rect, c)
	# Thin bright center line
	var lc := c
	lc.a *= 0.9
	draw_line(Vector2(0.0, 0.0), Vector2(length, 0.0), lc, maxf(1.0, w * 0.18), true)
