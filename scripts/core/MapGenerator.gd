extends Node2D
class_name MapGenerator

@export var tile_size: int = 64
@export var map_width: int = 30  # Number of tiles horizontally
@export var map_height: int = 20 # Number of tiles vertically
@export var tile_1_texture: Texture2D = preload("res://assets/map/map_1.png")
@export var tile_2_texture: Texture2D = preload("res://assets/map/map_2.png")

var _tiles: Node2D

func _ready():
	_tiles = Node2D.new()
	_tiles.name = "TileContainer"
	_tiles.z_index = -100  # Ensure tiles render below all game entities
	add_child(_tiles)
	_generate_map()

func _generate_map():
	randomize()
	
	var start_x = -(float(map_width * tile_size)) / 2.0
	var start_y = -(float(map_height * tile_size)) / 2.0
	
	for y in range(map_height):
		for x in range(map_width):
			var pos_x = start_x + x * tile_size
			var pos_y = start_y + y * tile_size
			
			# Randomly choose which tile (50/50)
			var tile_texture = tile_1_texture if randf() < 0.5 else tile_2_texture
			
			var sprite = Sprite2D.new()
			sprite.texture = tile_texture
			sprite.centered = true
			
			# Scale texture to fit tile_size
			if tile_texture:
				var texture_size = tile_texture.get_size()
				var scale_factor = float(tile_size) / texture_size.x  # Assuming square tiles
				sprite.scale = Vector2.ONE * scale_factor
			
			var half_tile := tile_size / 2.0
			sprite.position = Vector2(pos_x + half_tile, pos_y + half_tile)
			_tiles.add_child(sprite)

