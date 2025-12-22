extends Node2D
class_name ImpactVFX

@export var lifetime: float = 0.10
@export var radius: float = 28.0
@export var width: float = 3.0
@export var color: Color = Color(1, 1, 1, 0.65)

var _t: float = 0.0


func spawn(pos: Vector2, r: float = 28.0, life: float = 0.10) -> void:
	global_position = pos
	radius = maxf(1.0, r)
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
	var r := radius * lerpf(0.7, 1.0, p)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, width, true)
	var fill := c
	fill.a *= 0.12
	draw_circle(Vector2.ZERO, r, fill)
