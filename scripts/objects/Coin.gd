extends Area2D
class_name Coin

@export var value: int = 1
@export var speed: float = 400.0

var _target: Node2D = null
var _is_collected: bool = false
var _velocity: Vector2 = Vector2.ZERO

var _base_collision_layer: int = 0
var _base_collision_mask: int = 0

func _ready() -> void:
	add_to_group("loot")
	add_to_group("coins")
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask

func spawn(pos: Vector2, coin_value: int = 1) -> void:
	global_position = pos
	value = maxi(1, int(coin_value))
	_is_collected = false
	_target = null
	_velocity = Vector2.ZERO
	monitoring = true
	monitorable = true
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs:
		cs.disabled = false

func _physics_process(delta: float) -> void:
	if not _is_collected:
		return
	if _target and is_instance_valid(_target):
		var direction = global_position.direction_to(_target.global_position)
		_velocity = _velocity.move_toward(direction * speed * 2.0, speed * 5.0 * delta)
		global_position += _velocity * delta
		if global_position.distance_squared_to(_target.global_position) < 400:
			_collect()

func collect(target_node: Node2D) -> void:
	_target = target_node
	_is_collected = true

func _collect() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm and gm.has_method("add_score"):
			gm.call("add_score", value)
	_despawn()

func _despawn() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs:
		cs.disabled = true
	_target = null
	_velocity = Vector2.ZERO
	_is_collected = false
	if has_node("/root/PoolManager"):
		get_node("/root/PoolManager").return_instance(self, scene_file_path)
	else:
		queue_free()
