extends Area2D
class_name XPGem

@export var value: int = 1
@export var speed: float = 400.0

var _target: Node2D = null
var _is_collected: bool = false
var _velocity: Vector2 = Vector2.ZERO

var _base_collision_layer: int = 0
var _base_collision_mask: int = 0

func _ready():
	add_to_group("loot")
	add_to_group("xp")
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask

func spawn(pos: Vector2, xp_value: int):
	global_position = pos
	value = xp_value
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

func _physics_process(delta):
	if _target and is_instance_valid(_target):
		var direction = global_position.direction_to(_target.global_position)
		# Simple acceleration or constant speed? Constant speed is easier for magnet feel usually, or accelerating.
		# Let's accelerate
		_velocity = _velocity.move_toward(direction * speed * 2.0, speed * 5.0 * delta)
		global_position += _velocity * delta
		
		# Distance check for pickup collision (manual check can be lighter than physics sometimes, but Area2D is fine)
		if global_position.distance_squared_to(_target.global_position) < 400: # 20px radius squared
			_collect()

func collect(target_node: Node2D):
	_target = target_node
	_is_collected = true
	# Optional: Disable collision shape for pickup radius so it doesn't get picked up again?
	# Or just let physics process handle the movement until it hits "player center"

func _collect():
	if _target.has_method("add_experience"):
		_target.add_experience(value)
	
	_despawn()

func _despawn():
	# Prevent repeated collection while returning to pool.
	monitoring = false
	monitorable = false
	collision_layer = PhysicsLayers.NONE
	collision_mask = PhysicsLayers.NONE
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
