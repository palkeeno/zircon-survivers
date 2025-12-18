extends Resource
class_name WaveConfig

@export var start_time_sec: float = 0.0
@export var end_time_sec: float = 999999.0

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var spawn_count: int = 1
@export var pool_size: int = 50
