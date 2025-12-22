extends "res://scripts/weapons/Weapon.gd"
class_name OrbitBoomerang

@export var boomerang_count: int = 1
@export var semi_major: float = 160.0
@export var eccentricity: float = 0.65
@export var angular_speed: float = 3.0
@export var orbit_rotation_speed: float = 1.2

# As boomerang_count increases, additional ellipse orbits are added at different angles.
@export var boomerangs_per_orbit: int = 1
@export var orbit_layer_angle_step_degrees: float = 25.0
@export var hit_radius: float = 28.0
@export var tick_interval: float = 0.25

@export var vfx_radius: float = 6.0
@export var vfx_tail_length: float = 16.0
@export var vfx_color: Color = Color(1, 1, 1, 0.75)

var _time := 0.0
var _tick := 0.0


func _ready():
	super._ready()
	# This weapon deals damage continuously; cooldown-based firing isn't used.
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_tick -= delta
	queue_redraw()
	if _tick <= 0.0:
		_tick = max(0.05, tick_interval)
		_apply_hits()


func _draw() -> void:
	var count: int = maxi(1, boomerang_count)
	var per_orbit: int = maxi(1, boomerangs_per_orbit)
	var layers: int = maxi(1, int(float(count + per_orbit - 1) / float(per_orbit)))
	var base_theta := _time * angular_speed
	var base_orbit_rot := _time * orbit_rotation_speed
	var layer_step := deg_to_rad(orbit_layer_angle_step_degrees)
	var c := vfx_color

	for i in range(count):
		var layer: int = int(float(i) / float(per_orbit))
		var layer_center := float(layer) - float(layers - 1) * 0.5
		var index_in_layer: int = i - layer * per_orbit
		var in_this_layer: int = mini(per_orbit, count - layer * per_orbit)
		var orbit_angle_offset := TAU * (float(index_in_layer) / float(maxi(1, in_this_layer)))
		# Small per-layer phase to avoid lining up perfectly.
		var theta := base_theta + orbit_angle_offset + layer_center * 0.55
		var orbit_rot := base_orbit_rot + layer_center * layer_step
		var offset := _compute_orbit_offset(theta, orbit_rot)
		# Tangent direction (approx) for a simple comet tail.
		var offset2 := _compute_orbit_offset(theta + 0.08, orbit_rot)
		var tangent := (offset2 - offset).normalized()
		var tail := -tangent * vfx_tail_length

		var p := offset
		draw_line(p, p + tail, c, maxf(1.0, vfx_radius * 0.65), true)
		draw_circle(p, maxf(1.0, vfx_radius), c)


func _compute_orbit_offset(theta: float, orbit_rot: float) -> Vector2:
	var a := maxf(10.0, semi_major)
	var e := clampf(eccentricity, 0.05, 0.92)
	var p := a * (1.0 - e * e)
	var denom := 1.0 + e * cos(theta)
	var r := p / maxf(0.1, denom)
	var local := Vector2(r * cos(theta), r * sin(theta))
	return local.rotated(orbit_rot)


func _apply_hits() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return

	var count: int = maxi(1, boomerang_count)
	var per_orbit: int = maxi(1, boomerangs_per_orbit)
	var layers: int = maxi(1, int(float(count + per_orbit - 1) / float(per_orbit)))
	var base_theta := _time * angular_speed
	var base_orbit_rot := _time * orbit_rotation_speed
	var layer_step := deg_to_rad(orbit_layer_angle_step_degrees)
	var r2 := hit_radius * hit_radius
	var dmg := damage * owner_damage_mult

	for i in range(count):
		var layer: int = int(float(i) / float(per_orbit))
		var layer_center := float(layer) - float(layers - 1) * 0.5
		var index_in_layer: int = i - layer * per_orbit
		var in_this_layer: int = mini(per_orbit, count - layer * per_orbit)
		var orbit_angle_offset := TAU * (float(index_in_layer) / float(maxi(1, in_this_layer)))
		var theta := base_theta + orbit_angle_offset + layer_center * 0.55
		var orbit_rot := base_orbit_rot + layer_center * layer_step
		var offset := _compute_orbit_offset(theta, orbit_rot)
		var pos := global_position + offset
		for e in enemies:
			if not is_instance_valid(e):
				continue
			if not e.has_method("take_damage"):
				continue
			if pos.distance_squared_to(e.global_position) <= r2:
				e.take_damage(dmg)
