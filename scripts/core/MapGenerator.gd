extends Node2D
class_name MapGenerator

@export var tile_size: int = 64
@export var map_width: int = 30  # Initial generation width (tiles)
@export var map_height: int = 20 # Initial generation height (tiles)
@export var tile_1_texture: Texture2D = preload("res://assets/map/map_1.png")
@export var tile_2_texture: Texture2D = preload("res://assets/map/map_2.png")

@export var player_path: NodePath = NodePath("../Player")
@export var generate_radius_tiles: int = 20
@export var update_interval_sec: float = 0.1

var _tiles: Node2D
var _player: Node2D
var _tiles_by_cell: Dictionary = {}
var _update_accum: float = 0.0

func _ready():
	_tiles = Node2D.new()
	_tiles.name = "TileContainer"
	_tiles.z_index = -100  # Ensure tiles render below all game entities
	add_child(_tiles)
	set_process(true)
	_player = _resolve_player()
	_generate_initial_area()
	_ensure_tiles_around_player(true)

func _process(delta: float) -> void:
	_update_accum += delta
	if _update_accum < update_interval_sec:
		return
	_update_accum = 0.0
	_ensure_tiles_around_player(false)

func _ensure_tiles_around_player(force_resolve_player: bool) -> void:
	if _player == null or force_resolve_player:
		_player = _resolve_player()
	if _player == null:
		return

	var center_cell := _world_to_cell(_player.global_position)
	var r: int = maxi(0, generate_radius_tiles)
	for y in range(center_cell.y - r, center_cell.y + r + 1):
		for x in range(center_cell.x - r, center_cell.x + r + 1):
			var cell := Vector2i(x, y)
			if _tiles_by_cell.has(cell):
				continue
			_spawn_tile(cell)

func _resolve_player() -> Node2D:
	if player_path != NodePath(""):
		var n := get_node_or_null(player_path)
		if n is Node2D:
			return n

	# Fallback: find first node in group "player"
	var candidates := get_tree().get_nodes_in_group("player")
	if candidates.size() > 0 and candidates[0] is Node2D:
		return candidates[0]

	return null

func _generate_initial_area() -> void:
	# Keep the previous behavior (initial rectangle), but centered at the generator origin.
	var w: int = maxi(0, map_width)
	var h: int = maxi(0, map_height)
	if w == 0 or h == 0:
		return

	var start_x := -int(floor(float(w) / 2.0))
	var start_y := -int(floor(float(h) / 2.0))
	for y in range(start_y, start_y + h):
		for x in range(start_x, start_x + w):
			var cell := Vector2i(x, y)
			if _tiles_by_cell.has(cell):
				continue
			_spawn_tile(cell)

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
	_tiles_by_cell[cell] = sprite

func _pick_texture_for_cell(cell: Vector2i) -> Texture2D:
	# Stable 50/50 choice per cell (prevents the pattern from changing based on spawn order).
	var h := int(cell.x * 73856093) ^ int(cell.y * 19349663)
	return tile_1_texture if (h & 1) == 0 else tile_2_texture

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos := to_local(world_pos)
	return Vector2i(int(floor(local_pos.x / float(tile_size))), int(floor(local_pos.y / float(tile_size))))

func _cell_to_local_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * float(tile_size), (float(cell.y) + 0.5) * float(tile_size))
