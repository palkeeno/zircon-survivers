extends Node2D
class_name LightningVFX

@export var lifetime: float = 0.10
@export var width: float = 3.0
@export var color: Color = Color(1, 1, 1, 0.85)
@export var segments: int = 8
@export var jitter: float = 10.0

var _t: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _points: PackedVector2Array = PackedVector2Array()


func spawn(from_pos: Vector2, to_pos: Vector2, life: float = 0.10) -> void:
	global_position = Vector2.ZERO
	_from = from_pos
	_to = to_pos
	lifetime = maxf(0.01, life)
	_t = 0.0
	_rebuild_points()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()


func _rebuild_points() -> void:
	var segs: int = maxi(2, segments)
	_points = PackedVector2Array()
	_points.resize(segs + 1)

	var dir := (_to - _from)
	var n := dir.orthogonal().normalized()
	var dist := dir.length()
	var j := minf(jitter, maxf(2.0, dist * 0.08))

	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var p := _from.lerp(_to, t)
		if i != 0 and i != segs:
			p += n * randf_range(-j, j)
		_points[i] = p


func _draw() -> void:
	var p := clampf(_t / maxf(0.01, lifetime), 0.0, 1.0)
	var a := (1.0 - p)
	if a <= 0.0:
		return

	var c := color
	c.a *= a
	for i in range(_points.size() - 1):
		draw_line(to_local(_points[i]), to_local(_points[i + 1]), c, width, true)
