extends "res://scripts/weapons/Weapon.gd"
class_name PiercingBeam

@export var beam_vfx_scene: PackedScene = preload("res://scenes/weapons/BeamVFX.tscn")
@export var impact_vfx_scene: PackedScene = preload("res://scenes/weapons/ImpactVFX.tscn")

# Used only as fallback if we can't compute the visible rect.
@export var fallback_beam_length: float = 1200.0
@export var beam_width: float = 26.0
@export var beams_per_fire: int = 1
@export var spread_degrees: float = 10.0

@export var max_bounces: int = 0
@export var wall_collision_mask: int = 1


func _try_shoot() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return false

	var nearest: Node2D = _find_nearest_enemy(enemies)
	if not nearest:
		return false
	var dir := (nearest.global_position - global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	var world_rect := _get_visible_world_rect()

	var cnt: int = maxi(1, beams_per_fire)
	var dmg := damage * owner_damage_mult
	var half_width: float = maxf(1.0, beam_width) * 0.5
	var base_len: float = maxf(1.0, fallback_beam_length)

	for i in range(cnt):
		var angle_off := 0.0
		if cnt > 1:
			angle_off = deg_to_rad(spread_degrees) * (float(i) - float(cnt - 1) * 0.5)
		var bdir := dir.rotated(angle_off).normalized()
		_fire_beam(enemies, global_position, bdir, base_len, half_width, dmg, world_rect)

	return true


func _spawn_beam_vfx(origin: Vector2, direction: Vector2, length: float, width: float) -> void:
	if not beam_vfx_scene:
		return
	var fx = beam_vfx_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx.has_method("spawn"):
		fx.spawn(origin, direction, length, width, 0.08)


func _spawn_impact_vfx(pos: Vector2) -> void:
	if not impact_vfx_scene:
		return
	var fx = impact_vfx_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx.has_method("spawn"):
		fx.spawn(pos, 18.0, 0.08)


func _find_nearest_enemy(enemies: Array) -> Node2D:
	var best: Node2D = null
	var min_d2 := INF
	var origin := global_position
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not (e is Node2D):
			continue
		var n := e as Node2D
		var d2 := origin.distance_squared_to(n.global_position)
		if d2 < min_d2:
			min_d2 = d2
			best = n
	return best


func _get_visible_world_rect() -> Rect2:
	var vp := get_viewport()
	var vp_rect := vp.get_visible_rect()
	var size := vp_rect.size
	var cam := vp.get_camera_2d()
	if cam:
		var zoom := cam.zoom
		var world_size := Vector2(size.x / maxf(0.001, zoom.x), size.y / maxf(0.001, zoom.y))
		var center := cam.get_screen_center_position()
		return Rect2(center - world_size * 0.5, world_size)
	# Fallback: assume player is at center with 1:1 scale.
	return Rect2(global_position - size * 0.5, size)


func _length_to_rect_edge(origin: Vector2, dir: Vector2, rect: Rect2) -> float:
	var d := dir
	if d == Vector2.ZERO:
		return 0.0

	var t_min := INF
	# Left/right
	if absf(d.x) > 0.0001:
		var tx1 := (rect.position.x - origin.x) / d.x
		var tx2 := ((rect.position.x + rect.size.x) - origin.x) / d.x
		if tx1 > 0.0:
			var y1 := origin.y + d.y * tx1
			if y1 >= rect.position.y and y1 <= rect.position.y + rect.size.y:
				t_min = minf(t_min, tx1)
		if tx2 > 0.0:
			var y2 := origin.y + d.y * tx2
			if y2 >= rect.position.y and y2 <= rect.position.y + rect.size.y:
				t_min = minf(t_min, tx2)
	# Top/bottom
	if absf(d.y) > 0.0001:
		var ty1 := (rect.position.y - origin.y) / d.y
		var ty2 := ((rect.position.y + rect.size.y) - origin.y) / d.y
		if ty1 > 0.0:
			var x1 := origin.x + d.x * ty1
			if x1 >= rect.position.x and x1 <= rect.position.x + rect.size.x:
				t_min = minf(t_min, ty1)
		if ty2 > 0.0:
			var x2 := origin.x + d.x * ty2
			if x2 >= rect.position.x and x2 <= rect.position.x + rect.size.x:
				t_min = minf(t_min, ty2)

	if t_min == INF:
		return 0.0
	return maxf(1.0, t_min)


func _edge_intersection(origin: Vector2, dir: Vector2, rect: Rect2) -> Dictionary:
	var d := dir
	if d == Vector2.ZERO:
		return {}

	var best_t := INF
	var best_pos := Vector2.ZERO
	var best_n := Vector2.ZERO

	# Left edge (normal points right)
	if absf(d.x) > 0.0001:
		var txl := (rect.position.x - origin.x) / d.x
		if txl > 0.0:
			var yl := origin.y + d.y * txl
			if yl >= rect.position.y and yl <= rect.position.y + rect.size.y and txl < best_t:
				best_t = txl
				best_pos = Vector2(rect.position.x, yl)
				best_n = Vector2.RIGHT
		# Right edge (normal points left)
		var txr := ((rect.position.x + rect.size.x) - origin.x) / d.x
		if txr > 0.0:
			var yr := origin.y + d.y * txr
			if yr >= rect.position.y and yr <= rect.position.y + rect.size.y and txr < best_t:
				best_t = txr
				best_pos = Vector2(rect.position.x + rect.size.x, yr)
				best_n = Vector2.LEFT

	# Top edge (normal points down)
	if absf(d.y) > 0.0001:
		var tyt := (rect.position.y - origin.y) / d.y
		if tyt > 0.0:
			var xt := origin.x + d.x * tyt
			if xt >= rect.position.x and xt <= rect.position.x + rect.size.x and tyt < best_t:
				best_t = tyt
				best_pos = Vector2(xt, rect.position.y)
				best_n = Vector2.DOWN
		# Bottom edge (normal points up)
		var tyb := ((rect.position.y + rect.size.y) - origin.y) / d.y
		if tyb > 0.0:
			var xb := origin.x + d.x * tyb
			if xb >= rect.position.x and xb <= rect.position.x + rect.size.x and tyb < best_t:
				best_t = tyb
				best_pos = Vector2(xb, rect.position.y + rect.size.y)
				best_n = Vector2.UP

	if best_t == INF:
		return {}
	return {
		"length": maxf(1.0, best_t),
		"position": best_pos,
		"normal": best_n,
	}


func _fire_beam(enemies: Array, origin: Vector2, direction: Vector2, fallback_len: float, half_width: float, dmg: float, rect: Rect2) -> void:
	var o := origin
	var d := direction
	var bounces_left: int = maxi(0, max_bounces)

	while true:
		var edge := _edge_intersection(o, d, rect)
		var max_len := fallback_len
		var edge_pos := Vector2.ZERO
		var edge_n := Vector2.ZERO
		var has_edge := false
		if edge.size() > 0:
			max_len = float(edge["length"])
			edge_pos = edge["position"]
			edge_n = edge["normal"]
			has_edge = true

		var hit := _raycast_wall(o, d, max_len)
		var seg_len := max_len
		var hit_pos := Vector2.ZERO
		var hit_normal := Vector2.ZERO
		var did_hit := false

		if hit.size() > 0:
			hit_pos = hit["position"]
			hit_normal = hit["normal"]
			seg_len = o.distance_to(hit_pos)
			did_hit = true

		_spawn_beam_vfx(o, d, seg_len, beam_width)
		_apply_beam_damage(enemies, o, d, seg_len, half_width, dmg)

		if did_hit:
			if bounces_left <= 0:
				_spawn_impact_vfx(hit_pos)
				break
			_spawn_impact_vfx(hit_pos)
			o = hit_pos + hit_normal * 2.0
			d = d.bounce(hit_normal).normalized()
			bounces_left -= 1
			continue

		# No wall hit: optionally bounce off screen edge.
		if has_edge and bounces_left > 0:
			_spawn_impact_vfx(edge_pos)
			o = edge_pos + edge_n * 2.0
			d = d.bounce(edge_n).normalized()
			bounces_left -= 1
			continue

		break


func _raycast_wall(origin: Vector2, dir: Vector2, length: float) -> Dictionary:
	if wall_collision_mask <= 0:
		return {}
	var space = get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(origin, origin + dir * length)
	params.collision_mask = wall_collision_mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_parent()]
	return space.intersect_ray(params)


func _apply_beam_damage(enemies: Array, origin: Vector2, dir: Vector2, length: float, half_width: float, dmg: float) -> void:
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not e.has_method("take_damage"):
			continue
		var to_enemy: Vector2 = e.global_position - origin
		var along := to_enemy.dot(dir)
		if along < 0.0 or along > length:
			continue
		var perp := absf(to_enemy.cross(dir))
		if perp <= half_width:
			e.take_damage(dmg)
