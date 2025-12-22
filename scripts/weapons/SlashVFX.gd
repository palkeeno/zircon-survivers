extends Node2D
class_name SlashVFX

@export var lifetime: float = 0.10
@export var radius: float = 70.0
@export var arc_degrees: float = 120.0
@export var width: float = 5.0
@export var color: Color = Color(1, 1, 1, 0.75)

@export var inner_radius_ratio: float = 0.82
@export var inner_offset_ratio: float = 0.16
@export var inner_alpha: float = 0.22

@export var fill_alpha: float = 0.22
@export var arc_points: int = 40

var _t: float = 0.0


func spawn(pos: Vector2, direction: Vector2, r: float, life: float = 0.10) -> void:
	global_position = pos
	var dir := direction
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	rotation = dir.angle()
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

	var arc := deg_to_rad(arc_degrees)
	var start := -arc * 0.5
	var end := arc * 0.5

	var r := maxf(1.0, radius) * lerpf(0.92, 1.05, p)
	var w := maxf(1.0, width) * lerpf(1.15, 0.75, p)

	# Build a filled crescent (polygon between outer arc and an offset inner arc)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = clampi(arc_points, 12, 96)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := lerpf(start, end, t)
		pts.append(Vector2.RIGHT.rotated(ang) * r)

	var ir := r * clampf(inner_radius_ratio, 0.1, 0.98)
	# Clamp offset so the inner arc stays inside the outer arc (avoids self-intersection)
	var desired_off := r * clampf(inner_offset_ratio, 0.0, 0.6)
	var max_off := maxf(0.0, (r - ir) * 0.9)
	var off := Vector2(minf(desired_off, max_off), 0.0)
	for i in range(steps, -1, -1):
		var t2 := float(i) / float(steps)
		var ang2 := lerpf(start, end, t2)
		pts.append(off + Vector2.RIGHT.rotated(ang2) * ir)

	var fill := c
	fill.a *= fill_alpha
	var indices := Geometry2D.triangulate_polygon(pts)
	if indices.is_empty():
		# Fallback: draw rims only if polygon cannot be triangulated.
		pass
	else:
		# Godot 4's draw_polygon() doesn't accept indices; draw triangles explicitly.
		for tri in range(0, indices.size(), 3):
			var tri_pts := PackedVector2Array([
				pts[indices[tri + 0]],
				pts[indices[tri + 1]],
				pts[indices[tri + 2]],
			])
			draw_colored_polygon(tri_pts, fill)

	# Rim for crispness (outer + inner)
	var rim := c
	rim.a *= 0.9
	draw_arc(Vector2.ZERO, r, start, end, steps, rim, w, true)
	var inner_rim := c
	inner_rim.a *= inner_alpha
	draw_arc(off, ir, start, end, steps, inner_rim, maxf(1.0, w * 0.65), true)
