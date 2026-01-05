extends Node2D
class_name MapGenerator

@export var tile_size: int = 64
@export var map_width: int = 30  # Legacy (unused for finite generation)
@export var map_height: int = 20 # Legacy (unused for finite generation)
@export var tile_1_texture: Texture2D = preload("res://assets/map/map_1.png")
@export var tile_2_texture: Texture2D = preload("res://assets/map/map_2.png")

@export var stairs_scene: PackedScene = preload("res://scenes/objects/Stairs.tscn")

@export var player_path: NodePath = NodePath("../Player")

# Field generation tuning
@export var field_area_multiplier: float = 9.0
@export var field_aspect_min: float = 0.55
@export var field_aspect_max: float = 1.80
@export var obstacle_ratio_min: float = 0.03
@export var obstacle_ratio_max: float = 0.07
@export var stairs_min_distance_tiles: int = 12

var _tiles: Node2D
var _obstacles: Node2D
var _walls: Node2D
var _player: Node2D
var _tile_nodes_by_cell: Dictionary = {} # Vector2i -> Node
var _field_cells: Dictionary = {} # Vector2i -> true
var _blocked_cells: Dictionary = {} # Vector2i -> true (unwalkable inside field)
var _spawn_cell: Vector2i = Vector2i.ZERO
var _stairs_cell: Vector2i = Vector2i.ZERO
var _rng := RandomNumberGenerator.new()

func _ready():
	add_to_group("field")
	_rng.randomize()
	_tiles = Node2D.new()
	_tiles.name = "TileContainer"
	_tiles.z_index = -100  # Ensure tiles render below all game entities
	add_child(_tiles)

	_obstacles = Node2D.new()
	_obstacles.name = "ObstacleContainer"
	_obstacles.z_index = -50
	add_child(_obstacles)

	_walls = Node2D.new()
	_walls.name = "WallContainer"
	_walls.z_index = -10
	add_child(_walls)

	_player = _resolve_player()
	_generate_field_once()
	set_process(false)

func _generate_field_once() -> void:
	_clear_generated_nodes()
	_player = _resolve_player()

	var vp := get_viewport()
	var screen_size := Vector2(1280, 720)
	if vp:
		screen_size = vp.get_visible_rect().size

	var screen_w_tiles := maxi(5, int(floor(screen_size.x / float(tile_size))))
	var screen_h_tiles := maxi(5, int(floor(screen_size.y / float(tile_size))))
	var screen_area_tiles: int = maxi(1, screen_w_tiles * screen_h_tiles)
	var target_field_tiles: int = maxi(40, int(round(float(screen_area_tiles) * maxf(1.0, field_area_multiplier))))
	var screen_aspect := float(screen_w_tiles) / maxf(1.0, float(screen_h_tiles))

	# Generate a connected blob within a moderate bounding box.
	var attempts := 0
	while attempts < 12:
		attempts += 1
		_field_cells.clear()
		_blocked_cells.clear()

		var bb_w := maxi(10, int(round(sqrt(float(target_field_tiles) * screen_aspect))))
		var bb_h := maxi(10, int(ceil(float(target_field_tiles) / maxf(1.0, float(bb_w)))))
		# Clamp extreme aspect
		var ratio := float(bb_w) / maxf(1.0, float(bb_h))
		if ratio < field_aspect_min:
			bb_w = int(round(float(bb_h) * field_aspect_min))
		elif ratio > field_aspect_max:
			bb_h = int(round(float(bb_w) / field_aspect_max))

		var ok := _generate_connected_blob(target_field_tiles, bb_w, bb_h)
		if not ok:
			continue

		_spawn_cell = _pick_spawn_cell_near_center(bb_w, bb_h)
		if _spawn_cell == Vector2i(999999, 999999):
			continue

		# Obstacles (keep walkable area connected)
		_generate_obstacles_preserving_connectivity(_spawn_cell)
		# Stairs placement
		_stairs_cell = _pick_stairs_cell(_spawn_cell)
		if _stairs_cell == Vector2i(999999, 999999):
			continue

		# Success
		_build_visuals_and_collisions()
		_position_player_at_spawn()
		_spawn_stairs()
		return

	# Fallback: build whatever we last generated
	_build_visuals_and_collisions()
	_position_player_at_spawn()
	_spawn_stairs()

func _clear_generated_nodes() -> void:
	for c in _tiles.get_children():
		c.queue_free()
	for c in _obstacles.get_children():
		c.queue_free()
	for c in _walls.get_children():
		c.queue_free()
	_tile_nodes_by_cell.clear()

func _generate_connected_blob(target_count: int, bb_w: int, bb_h: int) -> bool:
	# Cells are generated in local grid coords [0..bb_w-1, 0..bb_h-1]
	if target_count > bb_w * bb_h:
		return false
	var center := Vector2i(int(floor(float(bb_w) * 0.5)), int(floor(float(bb_h) * 0.5)))
	_field_cells[center] = true
	var cells: Array[Vector2i] = [center]
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var guard := 0
	while cells.size() < target_count and guard < target_count * 50:
		guard += 1
		var base: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		# Slightly bias to expand outward from center but stay compact.
		var dir: Vector2i = dirs[_rng.randi_range(0, dirs.size() - 1)]
		var n := base + dir
		if n.x < 0 or n.y < 0 or n.x >= bb_w or n.y >= bb_h:
			continue
		if _field_cells.has(n):
			continue
		# Avoid snake-like thin shapes: require adjacency to at least 1 existing cell (always true) and
		# prefer adding cells with >=2 neighbors once the blob is big enough.
		var neighbors := 0
		for d in dirs:
			if _field_cells.has(n + d):
				neighbors += 1
		if cells.size() > 80 and neighbors < 2 and _rng.randf() < 0.65:
			continue
		_field_cells[n] = true
		cells.append(n)

	return cells.size() >= target_count

func _pick_spawn_cell_near_center(bb_w: int, bb_h: int) -> Vector2i:
	var center := Vector2i(int(floor(float(bb_w) * 0.5)), int(floor(float(bb_h) * 0.5)))
	if _field_cells.has(center):
		return center
	# Find closest field cell to center
	var best := Vector2i(999999, 999999)
	var best_d := 1e18
	for k in _field_cells.keys():
		var c: Vector2i = k
		var d := float((c - center).length_squared())
		if d < best_d:
			best_d = d
			best = c
	return best

func _generate_obstacles_preserving_connectivity(spawn_cell: Vector2i) -> void:
	var field_count := _field_cells.size()
	if field_count <= 0:
		return
	var ratio := clampf(_rng.randf_range(obstacle_ratio_min, obstacle_ratio_max), 0.0, 0.25)
	var target := int(round(float(field_count) * ratio))
	if target <= 0:
		return

	var candidates: Array[Vector2i] = []
	for k in _field_cells.keys():
		var c: Vector2i = k
		if c == spawn_cell:
			continue
		candidates.append(c)
	# Shuffle
	for i in range(candidates.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var added := 0
	for c in candidates:
		if added >= target:
			break
		# Try adding obstacle without disconnecting walkable region
		_blocked_cells[c] = true
		if _is_walkable_connected(spawn_cell):
			added += 1
		else:
			_blocked_cells.erase(c)

func _is_walkable_connected(from_cell: Vector2i) -> bool:
	if not _field_cells.has(from_cell):
		return false
	if _blocked_cells.has(from_cell):
		return false
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var q: Array[Vector2i] = [from_cell]
	var visited: Dictionary = {from_cell: true}
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			if visited.has(n):
				continue
			if not _field_cells.has(n):
				continue
			if _blocked_cells.has(n):
				continue
			visited[n] = true
			q.append(n)

	# All walkable cells should be reachable
	var total_walkable := 0
	for k in _field_cells.keys():
		if not _blocked_cells.has(k):
			total_walkable += 1
	return visited.size() == total_walkable

func _pick_stairs_cell(spawn_cell: Vector2i) -> Vector2i:
	var min_d2 := float(maxi(0, stairs_min_distance_tiles))
	min_d2 = min_d2 * min_d2
	var candidates: Array[Vector2i] = []
	for k in _field_cells.keys():
		var c: Vector2i = k
		if c == spawn_cell:
			continue
		if _blocked_cells.has(c):
			continue
		var d2 := float((c - spawn_cell).length_squared())
		if d2 < min_d2:
			continue
		candidates.append(c)
	if candidates.is_empty():
		return Vector2i(999999, 999999)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _build_visuals_and_collisions() -> void:
	# Place tiles centered around (0,0) by shifting local grid coords.
	# Compute grid offset so that spawn is at world origin.
	var offset := -_spawn_cell
	for k in _field_cells.keys():
		var c: Vector2i = k
		var world_cell := c + offset
		_spawn_tile(world_cell)
		if _blocked_cells.has(c):
			_spawn_obstacle(world_cell)
	_spawn_boundary_walls(offset)

func _spawn_boundary_walls(offset: Vector2i) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for k in _field_cells.keys():
		var c: Vector2i = k
		var world_cell: Vector2i = c + offset
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			if _field_cells.has(n):
				continue
			# Edge wall along side facing d
			_spawn_edge_wall(world_cell, d)

func _spawn_edge_wall(world_cell: Vector2i, dir: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = _cell_to_local_center(world_cell)
	_walls.add_child(body)

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Thin rectangle along the cell edge
	var thickness := 10.0
	var size := Vector2(float(tile_size), thickness)
	if dir.x != 0:
		size = Vector2(thickness, float(tile_size))
	rect.size = size
	cs.shape = rect
	# Offset from center to edge
	var half := float(tile_size) * 0.5
	if dir == Vector2i(0, -1):
		cs.position = Vector2(0, -half)
	elif dir == Vector2i(0, 1):
		cs.position = Vector2(0, half)
	elif dir == Vector2i(-1, 0):
		cs.position = Vector2(-half, 0)
	elif dir == Vector2i(1, 0):
		cs.position = Vector2(half, 0)
	body.add_child(cs)

func _spawn_obstacle(world_cell: Vector2i) -> void:
	# Visible + collidable blocked tile.
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = _cell_to_local_center(world_cell)
	_obstacles.add_child(body)

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(tile_size), float(tile_size))
	cs.shape = rect
	body.add_child(cs)

	var sprite := Sprite2D.new()
	sprite.texture = tile_2_texture if tile_2_texture else tile_1_texture
	sprite.centered = true
	if sprite.texture:
		var texture_size := sprite.texture.get_size()
		var denom: float = maxf(1.0, float(texture_size.x))
		var scale_factor: float = float(tile_size) / denom
		sprite.scale = Vector2.ONE * scale_factor
	# Darken to indicate impassable
	sprite.modulate = Color(0.25, 0.25, 0.25, 1)
	body.add_child(sprite)

func _position_player_at_spawn() -> void:
	if _player == null:
		return
	# Background is at (0,0); spawn is world origin in our coordinate system.
	_player.global_position = Vector2.ZERO
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").player_reference = _player

func _spawn_stairs() -> void:
	if stairs_scene == null:
		return
	# Convert stairs cell from generation coords into world cell (spawn-centered).
	var offset := -_spawn_cell
	var stairs_world_cell := _stairs_cell + offset
	# Parent may still be constructing children during _ready; defer the add.
	call_deferred("_deferred_spawn_stairs", stairs_world_cell)

func _deferred_spawn_stairs(stairs_world_cell: Vector2i) -> void:
	if stairs_scene == null:
		return
	var inst := stairs_scene.instantiate()
	if inst == null:
		return
	var parent_node: Node = get_parent() if get_parent() != null else self
	parent_node.add_child(inst)
	if inst is Node2D:
		(inst as Node2D).global_position = _cell_to_local_center(stairs_world_cell)

func is_world_point_walkable(world_pos: Vector2) -> bool:
	var cell := _world_to_cell(world_pos)
	return is_cell_walkable(cell)

func is_cell_walkable(world_cell: Vector2i) -> bool:
	# Reverse offset: spawn is at world origin
	var local_cell := world_cell - (-_spawn_cell)
	if not _field_cells.has(local_cell):
		return false
	if _blocked_cells.has(local_cell):
		return false
	return true

func get_random_walkable_world_position_near(center_world_pos: Vector2, min_radius: float, max_radius: float) -> Vector2:
	# Used by spawners to keep spawns inside the field.
	var center_cell := _world_to_cell(center_world_pos)
	var min_r := maxi(0, int(floor(min_radius / float(tile_size))))
	var max_r := maxi(min_r + 1, int(ceil(max_radius / float(tile_size))))
	var tries := 80
	while tries > 0:
		tries -= 1
		var dx := _rng.randi_range(-max_r, max_r)
		var dy := _rng.randi_range(-max_r, max_r)
		var d2 := dx * dx + dy * dy
		if d2 < min_r * min_r or d2 > max_r * max_r:
			continue
		var c := center_cell + Vector2i(dx, dy)
		if is_cell_walkable(c):
			return global_transform * _cell_to_local_center(c)
	# Fallback: center
	return center_world_pos

func _resolve_player() -> Node2D:
	if player_path != NodePath(""):
		var n := get_node_or_null(player_path)
		if n is Node2D:
			return n

	# Fallback: find first node in group "player" (optional)
	var candidates := get_tree().get_nodes_in_group("player")
	if candidates.size() > 0 and candidates[0] is Node2D:
		return candidates[0]

	return null

func _generate_initial_area() -> void:
	# Legacy method kept for compatibility; finite generation does not call this.
	pass

func _spawn_tile(cell: Vector2i) -> void:
	var tile_texture := _pick_texture_for_cell(cell)
	var sprite := Sprite2D.new()
	sprite.texture = tile_texture
	sprite.centered = true

	# Scale texture to fit tile_size
	if tile_texture:
		var texture_size := tile_texture.get_size()
		var denom: float = maxf(1.0, float(texture_size.x))  # assuming square tiles
		var scale_factor: float = float(tile_size) / denom
		sprite.scale = Vector2.ONE * scale_factor

	sprite.position = _cell_to_local_center(cell)
	_tiles.add_child(sprite)
	_tile_nodes_by_cell[cell] = sprite

func _pick_texture_for_cell(cell: Vector2i) -> Texture2D:
	# Stable 50/50 choice per cell (prevents the pattern from changing based on spawn order).
	var h := int(cell.x * 73856093) ^ int(cell.y * 19349663)
	return tile_1_texture if (h & 1) == 0 else tile_2_texture

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos := to_local(world_pos)
	return Vector2i(int(floor(local_pos.x / float(tile_size))), int(floor(local_pos.y / float(tile_size))))

func _cell_to_local_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * float(tile_size), (float(cell.y) + 0.5) * float(tile_size))
