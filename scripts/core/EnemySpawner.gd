extends Node

@export var enemy_scene: PackedScene
@export var container_path: NodePath
@export var spawn_interval: float = 1.0
@export var spawn_radius_min: float = 500.0 
@export var spawn_radius_max: float = 700.0

var _timer: Timer
var _container: Node

func _ready():
	if not container_path.is_empty():
		_container = get_node(container_path)
	
	_timer = Timer.new()
	add_child(_timer)
	
	# ... (reset timer)
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(_on_spawn_timer_timeout)
	_timer.start()
	
	if has_node("/root/PoolManager") and enemy_scene:
		get_node("/root/PoolManager").create_pool(enemy_scene, 50)

func _on_spawn_timer_timeout():
	if not enemy_scene:
		return
	
	var player_ref = null
	if has_node("/root/GameManager"):
		player_ref = get_node("/root/GameManager").player_reference
	
	if not player_ref:
		return
		
	var player_pos = player_ref.global_position
	var spawn_pos = _get_random_spawn_position(player_pos)
	
	var enemy = null
	if has_node("/root/PoolManager"):
		enemy = get_node("/root/PoolManager").get_instance(enemy_scene)
	
	if enemy:
		# Reparent to the game container (e.g. for Y-Sorting)
		if _container:
			if enemy.get_parent() != _container:
				enemy.reparent(_container)
		else:
			# Fallback: add to self if not in tree, but self is Node, not Node2D usually. 
			# Or if it's already in PoolManager, leave it there?
			# If PoolManager keeps it, Z-index might be wrong.
			pass

		if enemy.has_method("spawn"):
			enemy.spawn(spawn_pos)
		else:
			enemy.global_position = spawn_pos

func _get_random_spawn_position(center: Vector2) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(spawn_radius_min, spawn_radius_max)
	return center + Vector2(cos(angle), sin(angle)) * distance
