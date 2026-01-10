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
@export var hit_radius: float = 20.0
@export var tick_interval: float = 0.25

@export var vfx_radius: float = 20.0
@export var vfx_tail_length: float = 16.0
@export var vfx_color: Color = Color(1, 1, 1, 0.75)

var _time := 0.0
var _tick := 0.0

var _hitboxes: Array[Area2D] = []
var _hitbox_shapes: Array[CollisionShape2D] = []


func _ready():
	super._ready()
	# This weapon deals damage continuously; cooldown-based firing isn't used.
	set_process(true)
	_sync_hitboxes()


func _process(delta: float) -> void:
	_time += delta
	_tick -= delta
	_sync_hitboxes()
	_update_hitbox_radii()
	_update_hitbox_positions()
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
		# Keep visuals exactly matched to collision radius.
		var rr := maxf(1.0, hit_radius)
		draw_line(p, p + tail, c, maxf(1.0, rr * 0.45), true)
		draw_circle(p, rr, c)


func _compute_orbit_offset(theta: float, orbit_rot: float) -> Vector2:
	var a := maxf(10.0, semi_major)
	var e := clampf(eccentricity, 0.05, 0.92)
	var p := a * (1.0 - e * e)
	var denom := 1.0 + e * cos(theta)
	var r := p / maxf(0.1, denom)
	var local := Vector2(r * cos(theta), r * sin(theta))
	return local.rotated(orbit_rot)


func _sync_hitboxes() -> void:
	var desired: int = maxi(1, boomerang_count)
	# Grow
	while _hitboxes.size() < desired:
		var idx := _hitboxes.size()
		var a := Area2D.new()
		a.name = "BoomerangHitbox_%d" % idx
		a.monitoring = true
		a.monitorable = true
		# Weapons don't need a layer; only a mask to detect enemies.
		a.collision_layer = PhysicsLayers.NONE
		a.collision_mask = PhysicsLayers.ENEMY
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = maxf(1.0, hit_radius)
		cs.shape = shape
		a.add_child(cs)
		add_child(a)
		_hitboxes.append(a)
		_hitbox_shapes.append(cs)
	# Shrink
	while _hitboxes.size() > desired:
		var a: Area2D = _hitboxes.pop_back() as Area2D
		_hitbox_shapes.pop_back()
		if a and is_instance_valid(a):
			a.queue_free()


func _update_hitbox_radii() -> void:
	var r := maxf(1.0, hit_radius)
	for cs in _hitbox_shapes:
		if not cs or not is_instance_valid(cs):
			continue
		var s := cs.shape
		if s is CircleShape2D:
			(s as CircleShape2D).radius = r


func _update_hitbox_positions() -> void:
	var count: int = maxi(1, boomerang_count)
	var per_orbit: int = maxi(1, boomerangs_per_orbit)
	var layers: int = maxi(1, int(float(count + per_orbit - 1) / float(per_orbit)))
	var base_theta := _time * angular_speed
	var base_orbit_rot := _time * orbit_rotation_speed
	var layer_step := deg_to_rad(orbit_layer_angle_step_degrees)

	for i in range(mini(count, _hitboxes.size())):
		var layer: int = int(float(i) / float(per_orbit))
		var layer_center := float(layer) - float(layers - 1) * 0.5
		var index_in_layer: int = i - layer * per_orbit
		var in_this_layer: int = mini(per_orbit, count - layer * per_orbit)
		var orbit_angle_offset := TAU * (float(index_in_layer) / float(maxi(1, in_this_layer)))
		var theta := base_theta + orbit_angle_offset + layer_center * 0.55
		var orbit_rot := base_orbit_rot + layer_center * layer_step
		var offset := _compute_orbit_offset(theta, orbit_rot)
		var hb := _hitboxes[i]
		if hb and is_instance_valid(hb):
			hb.global_position = global_position + offset


func _is_active_enemy(n: Node) -> bool:
	if not is_instance_valid(n):
		return false
	if not (n is Node2D):
		return false
	if not n.is_inside_tree():
		return false
	if n.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if n is CanvasItem and not (n as CanvasItem).visible:
		return false
	return n.is_in_group("enemies") and n.has_method("take_damage")


func _apply_hits() -> void:
	var dmg := damage * owner_damage_mult
	for hb in _hitboxes:
		if not hb or not is_instance_valid(hb):
			continue
		for body in hb.get_overlapping_bodies():
			if _is_active_enemy(body):
				(body as Node).call("take_damage", dmg)
