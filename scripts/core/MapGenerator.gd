extends Node2D
class_name MapGenerator

@export var tile_size: int = 64
@export var map_width: int = 30  # Legacy (unused for finite generation)
@export var map_height: int = 20 # Legacy (unused for finite generation)
@export var tile_1_texture: Texture2D = preload("res://assets/map/map_1.png")
@export var tile_2_texture: Texture2D = preload("res://assets/map/map_2.png")

@export var stairs_scene: PackedScene = preload("res://scenes/objects/Stairs.tscn")

## プレイヤーシーン（これを使ってマップ生成後にスポーン）
@export var player_scene: PackedScene = preload("res://scenes/entities/Player.tscn")

## ジョイスティックへのパス（プレイヤーに設定する）
@export var joystick_path: NodePath = NodePath("../CanvasLayer/VirtualJoystick")

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
var _player: Node2D = null
var _player_spawn_pos: Vector2 = Vector2.ZERO  # マップ生成後に決定されるスポーン位置
var _tile_nodes_by_cell: Dictionary = {} # Vector2i -> Node
var _field_cells: Dictionary = {} # Vector2i -> true
var _blocked_cells: Dictionary = {} # Vector2i -> true (unwalkable inside field)
var _spawn_cell: Vector2i = Vector2i(999999, 999999)  # 無効値で初期化
var _stairs_cell: Vector2i = Vector2i(999999, 999999)  # 無効値で初期化
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

	# マップ生成（プレイヤーはまだスポーンしない）
	_generate_field_once()
	set_process(false)
	
	# マップ生成完了後、プレイヤーをスポーン
	call_deferred("_spawn_player_at_valid_position")

func _generate_field_once() -> void:
	_clear_generated_nodes()

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

		# バウンディングボックスを少し大きめに（余裕を持たせる）
		var bb_w := maxi(10, int(round(sqrt(float(target_field_tiles) * screen_aspect) * 1.15)))
		var bb_h := maxi(10, int(ceil(float(target_field_tiles) / maxf(1.0, float(bb_w)) * 1.15)))
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

		# Success - マップ構築（プレイヤーはまだスポーンしない）
		_build_visuals_and_collisions()
		_spawn_stairs()
		_log_map_info()
		return

	# Fallback: build whatever we last generated
	push_error("MapGenerator: All %d generation attempts failed! Using fallback." % [attempts])
	
	# 無効なセル値の場合はフォールバックセルを設定
	if _spawn_cell == Vector2i(999999, 999999):
		# フィールドセルから最初の1つを選択
		if not _field_cells.is_empty():
			_spawn_cell = _field_cells.keys()[0]
		else:
			_spawn_cell = Vector2i.ZERO
	
	# 階段セルも確認
	if _stairs_cell == Vector2i(999999, 999999):
		# spawn_cellと異なるセルを探す
		for k in _field_cells.keys():
			if k != _spawn_cell and not _blocked_cells.has(k):
				_stairs_cell = k
				break
		# それでも見つからない場合
		if _stairs_cell == Vector2i(999999, 999999):
			push_error("MapGenerator: Cannot find valid stairs cell even in fallback!")
			# 少なくともspawn_cellから1セル離れた位置
			_stairs_cell = _spawn_cell + Vector2i(1, 0)
	
	_build_visuals_and_collisions()
	_spawn_stairs()
	_log_map_info()


func _log_map_info() -> void:
	var offset := -_spawn_cell
	# マップの4隅を計算
	var min_x := 999999
	var max_x := -999999
	var min_y := 999999
	var max_y := -999999
	for k in _field_cells.keys():
		var local_cell: Vector2i = k
		var world_cell := local_cell + offset
		min_x = mini(min_x, world_cell.x)
		max_x = maxi(max_x, world_cell.x)
		min_y = mini(min_y, world_cell.y)
		max_y = maxi(max_y, world_cell.y)
	
	var corner_tl := _cell_to_local_center(Vector2i(min_x, min_y))
	var corner_tr := _cell_to_local_center(Vector2i(max_x, min_y))
	var corner_bl := _cell_to_local_center(Vector2i(min_x, max_y))
	var corner_br := _cell_to_local_center(Vector2i(max_x, max_y))
	
	var stairs_world_cell := _stairs_cell + offset
	var stairs_pos := _cell_to_local_center(stairs_world_cell)
	
	print("MapGenerator: Map generated")
	print("  - _spawn_cell (local)=", _spawn_cell, ", offset=", offset)
	print("  - Map corners: TL=", corner_tl, ", TR=", corner_tr, ", BL=", corner_bl, ", BR=", corner_br)
	print("  - Stairs cell (local)=", _stairs_cell, ", world_cell=", stairs_world_cell, ", pos=", stairs_pos)

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
	var max_possible := bb_w * bb_h
	if target_count > max_possible:
		# ターゲットがBBサイズを超える場合、90%を目標にする
		target_count = int(float(max_possible) * 0.9)
	var center := Vector2i(int(floor(float(bb_w) * 0.5)), int(floor(float(bb_h) * 0.5)))
	print("[MapGenerator] _generate_connected_blob: target=%d, bb_w=%d, bb_h=%d, center=%s, max_possible=%d" % [target_count, bb_w, bb_h, center, max_possible])
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

	# 80%以上達成で成功とする
	var success := cells.size() >= int(float(target_count) * 0.8)
	if not success:
		print("[MapGenerator] _generate_connected_blob: FAILED - only generated %d/%d cells" % [cells.size(), target_count])
	return success

func _pick_spawn_cell_near_center(bb_w: int, bb_h: int) -> Vector2i:
	var center := Vector2i(int(floor(float(bb_w) * 0.5)), int(floor(float(bb_h) * 0.5)))
	print("[MapGenerator] _pick_spawn_cell_near_center: bb_w=%d, bb_h=%d, center=%s, has_center=%s" % [bb_w, bb_h, center, _field_cells.has(center)])
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
	print("[MapGenerator] _pick_spawn_cell_near_center: fallback best=%s" % [best])
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
	print("[MapGenerator] _pick_stairs_cell: spawn_cell=%s, stairs_min_distance_tiles=%d, min_d2=%s" % [spawn_cell, stairs_min_distance_tiles, min_d2])
	print("[MapGenerator] _pick_stairs_cell: _field_cells.size()=%d, _blocked_cells.size()=%d" % [_field_cells.size(), _blocked_cells.size()])
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
	print("[MapGenerator] _pick_stairs_cell: candidates with min_distance=%d" % [candidates.size()])
	if candidates.is_empty():
		# 最低距離の条件を緩和して再試行（ただしspawn_cellは除外）
		push_warning("MapGenerator: No stairs candidates with min distance, relaxing constraint")
		for k in _field_cells.keys():
			var c: Vector2i = k
			if c == spawn_cell:
				continue
			if _blocked_cells.has(c):
				continue
			candidates.append(c)
		print("[MapGenerator] _pick_stairs_cell: candidates relaxed=%d" % [candidates.size()])
	if candidates.is_empty():
		push_error("MapGenerator: No valid stairs cell found!")
		return Vector2i(999999, 999999)
	var chosen := candidates[_rng.randi_range(0, candidates.size() - 1)]
	print("[MapGenerator] _pick_stairs_cell: chosen=%s" % [chosen])
	return chosen

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


## マップ生成完了後、通行可能なマスを選んでプレイヤーをスポーン
func _spawn_player_at_valid_position() -> void:
	if player_scene == null:
		push_error("MapGenerator: player_scene is not set!")
		return
	
	# プレイヤーは原点(0,0)付近にスポーン（元の_spawn_cellの位置）
	# 階段から十分離れた位置であることを確認
	var spawn_pos := _pick_safe_player_spawn_position()
	
	# プレイヤーをインスタンス化
	_player = player_scene.instantiate()
	if _player == null:
		push_error("MapGenerator: Failed to instantiate player!")
		return
	
	# ジョイスティックパスを設定
	if joystick_path != NodePath("") and "joystick_path" in _player:
		_player.joystick_path = joystick_path
	
	# 位置を先に設定してからシーンに追加（add_child前に位置を設定しないと衝突判定が誤動作する）
	_player.position = spawn_pos
	_player_spawn_pos = spawn_pos
	
	# 親ノードに追加（Mainノードの直下）
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = self
	parent_node.add_child(_player)
	
	# GameManagerに登録
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").player_reference = _player
	
	print("MapGenerator: Player spawned at ", spawn_pos)


## プレイヤーの安全なスポーン位置を選択（原点付近で階段から離れた位置）
func _pick_safe_player_spawn_position() -> Vector2:
	# 原点(0,0)が理想的なスポーン位置（_spawn_cellがオフセットされて原点になる設計）
	var origin := Vector2.ZERO
	
	# 階段の位置を計算
	var offset := -_spawn_cell
	var stairs_world_cell := _stairs_cell + offset
	var stairs_pos := _cell_to_local_center(stairs_world_cell)
	
	print("[MapGenerator] _pick_safe_player_spawn: _spawn_cell=%s, _stairs_cell=%s, offset=%s" % [_spawn_cell, _stairs_cell, offset])
	print("[MapGenerator] _pick_safe_player_spawn: stairs_world_cell=%s, stairs_pos=%s" % [stairs_world_cell, stairs_pos])
	
	# 階段から最低限離れるべき距離（タイル数 × タイルサイズ）
	var min_distance_from_stairs := float(stairs_min_distance_tiles) * float(tile_size) * 0.5
	print("[MapGenerator] _pick_safe_player_spawn: min_distance_from_stairs=%s" % [min_distance_from_stairs])
	
	# 原点が階段から十分離れているか確認
	var dist_origin_to_stairs := origin.distance_to(stairs_pos)
	print("[MapGenerator] _pick_safe_player_spawn: origin=%s, dist_to_stairs=%s" % [origin, dist_origin_to_stairs])
	
	if dist_origin_to_stairs >= min_distance_from_stairs:
		# 原点が通行可能か確認
		if is_world_point_walkable(origin):
			print("[MapGenerator] _pick_safe_player_spawn: using origin (safe)")
			return origin
	
	# 原点が使えない場合、原点に近くて階段から離れた通行可能な位置を探す
	var best_pos := origin
	var best_dist_from_origin := INF
	
	for k in _field_cells.keys():
		var local_cell: Vector2i = k
		if _blocked_cells.has(local_cell):
			continue
		var world_cell := local_cell + offset
		var cell_center := _cell_to_local_center(world_cell)
		
		# 階段から十分離れているか
		var dist_from_stairs := cell_center.distance_to(stairs_pos)
		if dist_from_stairs < min_distance_from_stairs:
			continue
		
		# 原点からの距離
		var dist_from_origin := cell_center.distance_to(origin)
		if dist_from_origin < best_dist_from_origin:
			best_dist_from_origin = dist_from_origin
			best_pos = cell_center
	
	# それでも見つからない場合は原点を返す（フォールバック）
	if best_dist_from_origin == INF:
		push_warning("MapGenerator: Could not find safe spawn position, using origin")
		return origin
	
	return best_pos


## 通行可能なマスからランダムに位置を選択（使わなくなったが互換性のため残す）
func _pick_random_walkable_position() -> Vector2:
	var offset := -_spawn_cell
	var walkable_positions: Array[Vector2] = []
	
	for k in _field_cells.keys():
		var local_cell: Vector2i = k
		if _blocked_cells.has(local_cell):
			continue
		var world_cell := local_cell + offset
		var cell_center := _cell_to_local_center(world_cell)
		walkable_positions.append(cell_center)
	
	if walkable_positions.is_empty():
		push_warning("MapGenerator: No walkable positions found, using origin")
		return Vector2.ZERO
	
	# ランダムに選択
	var idx := _rng.randi_range(0, walkable_positions.size() - 1)
	return walkable_positions[idx]


## 指定位置から最も近い通行可能な位置を探す
func _find_nearest_walkable_position(world_pos: Vector2) -> Vector2:
	var offset := -_spawn_cell
	var best_pos := world_pos
	var best_dist_sq := INF
	
	for k in _field_cells.keys():
		var local_cell: Vector2i = k
		if _blocked_cells.has(local_cell):
			continue
		var world_cell := local_cell + offset
		var cell_center := _cell_to_local_center(world_cell)
		var dist_sq := cell_center.distance_squared_to(world_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_pos = cell_center
	
	return best_pos

func _spawn_stairs() -> void:
	if stairs_scene == null:
		return
	# 無効な階段セルの場合はスキップ
	if _stairs_cell == Vector2i(999999, 999999):
		push_error("MapGenerator: Cannot spawn stairs - invalid stairs cell!")
		return
	# 階段がスポーンセルと同じ場合は警告
	if _stairs_cell == _spawn_cell:
		push_error("MapGenerator: Stairs cell is same as spawn cell! This will cause instant game clear!")
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
	
	# 位置を先に設定してからシーンに追加（add_child前に位置を設定しないと衝突判定が誤動作する）
	var stairs_pos := _cell_to_local_center(stairs_world_cell)
	if inst is Node2D:
		(inst as Node2D).position = stairs_pos
	
	var parent_node: Node = get_parent() if get_parent() != null else self
	parent_node.add_child(inst)
	
	print("[MapGenerator] Stairs spawned at world_cell=%s, pos=%s" % [stairs_world_cell, stairs_pos])

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
