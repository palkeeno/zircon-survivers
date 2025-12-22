extends Node2D
class_name ExplosionVFX

@export var lifetime: float = 0.18
@export var radius: float = 220.0
@export var rim_width: float = 6.0
@export var flash_alpha: float = 0.22
@export var spark_count: int = 18
@export var color: Color = Color(1.0, 0.85, 0.55, 0.85)

var _t: float = 0.0


func spawn(pos: Vector2, r: float, life: float = 0.18) -> void:
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
	var lt := maxf(0.01, lifetime)
	var p := clampf(_t / lt, 0.0, 1.0)
	# Ease-out: fast start, slow end
	var e := 1.0 - pow(1.0 - p, 2.2)
	
	var a := 1.0 - p
	if a <= 0.0:
		return

	var base_c := color
	base_c.a *= a

	var r_outer := radius * lerpf(0.25, 1.0, e)
	var r_inner := r_outer * 0.55

	# Flash fill (very short-lived)
	var fill_c := base_c
	fill_c.a *= flash_alpha * (1.0 - e)
	draw_circle(Vector2.ZERO, r_inner, fill_c)

	# Main rim
	var rim_c := base_c
	rim_c.a *= 0.85
	draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, 96, rim_c, rim_width, true)

	# Secondary inner rim
	var rim2 := base_c
	rim2.a *= 0.55
	draw_arc(Vector2.ZERO, r_inner, 0.0, TAU, 72, rim2, maxf(1.0, rim_width * 0.6), true)

	# Sparks / spikes
	var sc := maxi(6, spark_count)
	var noise_seed := int(global_position.x * 3.0 + global_position.y * 5.0)
	for i in range(sc):
		var ang := TAU * (float(i) / float(sc))
		# deterministic wobble
		var wob := sin(float(noise_seed + i) * 1.7) * 0.22
		ang += wob
		var spark_len := r_outer * lerpf(0.18, 0.42, 1.0 - p) * (1.0 + cos(float(noise_seed + i) * 2.3) * 0.12)
		var from := Vector2.RIGHT.rotated(ang) * (r_inner * lerpf(0.85, 1.0, e))
		var to := from + Vector2.RIGHT.rotated(ang) * spark_len
		var lc := base_c
		lc.a *= 0.6
		draw_line(from, to, lc, maxf(1.0, rim_width * 0.35), true)
