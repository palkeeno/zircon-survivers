extends Node

@export var enemy_scene: PackedScene
@export var miniboss_scene: PackedScene
@export var boss_scene: PackedScene
@export var container_path: NodePath
@export var spawn_interval: float = 1.0
@export var spawn_radius_min: float = 500.0 
@export var spawn_radius_max: float = 700.0

@export var drop_item_scene: PackedScene = preload("res://scenes/objects/DropItem.tscn")
@export var field_item_spawn_chance: float = 0.003 # 0.3% per spawn tick

const _FIELD_ITEM_WEIGHT_HEART: int = 45
const _FIELD_ITEM_WEIGHT_SHIELD: int = 45
const _FIELD_ITEM_WEIGHT_MAGNET: int = 10

# Optional: time-driven wave table. If empty, uses spawn_interval/enemy_scene.
@export var waves: Array[Resource] = []

var _timer: Timer
var _container: Node

var _active_wave: Resource = null
var _active_enemy_scene: PackedScene = null
var _active_spawn_interval: float = 1.0
var _active_spawn_count: int = 1

var _pending_miniboss_minutes: Array[int] = []
var _pending_boss_indices: Array[int] = []

func _ready():
	if not container_path.is_empty():
		_container = get_node(container_path)
	
	_timer = Timer.new()
	add_child(_timer)
	
	# ... (reset timer)
	_active_spawn_interval = spawn_interval
	_timer.wait_time = _active_spawn_interval
	_timer.timeout.connect(_on_spawn_timer_timeout)
	_timer.start()
	
	# Prepare pools
	if has_node("/root/PoolManager"):
		var pm = get_node("/root/PoolManager")
		if enemy_scene:
			pm.create_pool(enemy_scene, 50)
		if miniboss_scene:
			pm.create_pool(miniboss_scene, 10)
		if boss_scene:
			pm.create_pool(boss_scene, 5)
		if drop_item_scene:
			pm.create_pool(drop_item_scene, 12)

	# Subscribe to time events
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("run_time_changed"):
			gm.run_time_changed.connect(_on_run_time_changed)
		if gm.has_signal("miniboss_requested"):
			gm.miniboss_requested.connect(_on_miniboss_requested)
		if gm.has_signal("boss_requested"):
			gm.boss_requested.connect(_on_boss_requested)

	# Initialize wave immediately if possible
	_update_wave(0.0)

func _on_run_time_changed(time_sec: float) -> void:
	_update_wave(time_sec)

func _on_miniboss_requested(minute: int) -> void:
	_pending_miniboss_minutes.append(minute)

func _on_boss_requested(boss_index: int) -> void:
	_pending_boss_indices.append(boss_index)

func _update_wave(time_sec: float) -> void:
	if waves.is_empty():
		_active_wave = null
		_active_enemy_scene = enemy_scene
		_active_spawn_interval = spawn_interval
		_active_spawn_count = 1
		_timer.wait_time = _active_spawn_interval
		return

	var selected: Resource = null
	for w in waves:
		if w == null:
			continue
		# Duck-typing: WaveConfig Resource
		if ("start_time_sec" in w) and ("end_time_sec" in w):
			if time_sec >= w.start_time_sec and time_sec < w.end_time_sec:
				selected = w
				break

	if selected == null:
		return
	if selected == _active_wave:
		return

	_active_wave = selected
	_active_enemy_scene = selected.enemy_scene if ("enemy_scene" in selected) else enemy_scene
	_active_spawn_interval = float(selected.spawn_interval) if ("spawn_interval" in selected) else spawn_interval
	_active_spawn_count = int(selected.spawn_count) if ("spawn_count" in selected) else 1
	_timer.wait_time = max(0.05, _active_spawn_interval)

	# Ensure pool warmup for this wave
	if has_node("/root/PoolManager") and _active_enemy_scene and ("pool_size" in selected):
		get_node("/root/PoolManager").create_pool(_active_enemy_scene, int(selected.pool_size))

func _on_spawn_timer_timeout():
	# Priority: scheduled bosses
	if _try_spawn_scheduled_bosses():
		return

	var scene_to_spawn: PackedScene = _active_enemy_scene if _active_enemy_scene else enemy_scene
	if not scene_to_spawn:
		return
	
	var player_ref = null
	if has_node("/root/GameManager"):
		player_ref = get_node("/root/GameManager").player_reference
	
	if not player_ref:
		return
		
	var player_pos = player_ref.global_position
	var spawn_pos = _get_random_spawn_position(player_pos)

	var count: int = max(1, _active_spawn_count)
	for _i in range(count):
		var pos_i: Vector2 = spawn_pos
		if _i != 0:
			pos_i = _get_random_spawn_position(player_pos)
		_spawn_instance(scene_to_spawn, pos_i)

	_maybe_spawn_field_item(player_pos)


func _maybe_spawn_field_item(player_pos: Vector2) -> void:
	if drop_item_scene == null:
		return
	if randf() > clampf(field_item_spawn_chance, 0.0, 1.0):
		return
	var pos := _get_random_spawn_position(player_pos)
	_spawn_drop_item(pos, _roll_field_item_kind())


func _spawn_drop_item(pos: Vector2, kind: String) -> void:
	var item = null
	if has_node("/root/PoolManager"):
		item = get_node("/root/PoolManager").get_instance(drop_item_scene)
	else:
		item = drop_item_scene.instantiate()
		if item:
			add_child(item)

	if not item:
		return
	# Reparent to game container so it's on the field.
	if _container and item.get_parent() != _container:
		item.reparent(_container)
	if item.has_method("spawn"):
		item.spawn(pos, kind)
	else:
		item.global_position = pos
		if "item_kind" in item:
			item.item_kind = kind


func _roll_field_item_kind() -> String:
	var total: int = _FIELD_ITEM_WEIGHT_HEART + _FIELD_ITEM_WEIGHT_SHIELD + _FIELD_ITEM_WEIGHT_MAGNET
	var r: int = randi() % maxi(1, total)
	if r < _FIELD_ITEM_WEIGHT_HEART:
		return "Heart"
	r -= _FIELD_ITEM_WEIGHT_HEART
	if r < _FIELD_ITEM_WEIGHT_SHIELD:
		return "Shield"
	return "Magnet"

func _try_spawn_scheduled_bosses() -> bool:
	# Boss has priority over miniboss if both are pending.
	if _pending_boss_indices.size() > 0 and boss_scene:
		_pending_boss_indices.pop_front()
		if _spawn_special(boss_scene) and has_node("/root/GameManager"):
			var gm = get_node("/root/GameManager")
			if gm.has_signal("boss_spawned"):
				gm.emit_signal("boss_spawned")
		return true

	if _pending_miniboss_minutes.size() > 0 and miniboss_scene:
		_pending_miniboss_minutes.pop_front()
		if _spawn_special(miniboss_scene) and has_node("/root/GameManager"):
			var gm2 = get_node("/root/GameManager")
			if gm2.has_signal("miniboss_spawned"):
				gm2.emit_signal("miniboss_spawned")
		return true

	return false

func _spawn_special(scene: PackedScene) -> bool:
	var player_ref = null
	if has_node("/root/GameManager"):
		player_ref = get_node("/root/GameManager").player_reference
	if not player_ref:
		return false
	var pos = _get_random_spawn_position(player_ref.global_position)
	return _spawn_instance(scene, pos)

func _spawn_instance(scene: PackedScene, pos: Vector2) -> bool:
	var instance = null
	if has_node("/root/PoolManager"):
		instance = get_node("/root/PoolManager").get_instance(scene)
	else:
		instance = scene.instantiate() if scene else null
		if instance:
			add_child(instance)

	if not instance:
		return false

	# Reparent to the game container (e.g. for Y-Sorting)
	if _container and instance.get_parent() != _container:
		instance.reparent(_container)

	if instance.has_method("spawn"):
		instance.spawn(pos)
	else:
		instance.global_position = pos
	return true

func _get_random_spawn_position(center: Vector2) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(spawn_radius_min, spawn_radius_max)
	return center + Vector2(cos(angle), sin(angle)) * distance
