extends Area2D
class_name Projectile

@export var speed: float = 400.0
@export var damage: float = 5.0
@export var life_time: float = 3.0

var _direction: Vector2 = Vector2.RIGHT
var _life_timer: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)

func spawn(pos: Vector2, direction: Vector2):
	global_position = pos
	_direction = direction.normalized()
	rotation = _direction.angle()
	_life_timer = life_time

func _physics_process(delta):
	global_position += _direction * speed * delta
	
	_life_timer -= delta
	if _life_timer <= 0:
		_despawn()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
		_despawn()

func _despawn():
	if has_node("/root/PoolManager"):
		get_node("/root/PoolManager").return_instance(self, scene_file_path)
	else:
		queue_free()
