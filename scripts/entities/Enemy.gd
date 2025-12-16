extends CharacterBody2D
class_name Enemy

@export var speed: float = 100.0
@export var damage: float = 10.0
@export var hp: float = 10.0

var _target: Node2D = null

func _ready():
	# Initial setup if needed
	pass

func spawn(pos: Vector2):
	global_position = pos
	
	if has_node("/root/GameManager"):
		_target = get_node("/root/GameManager").player_reference
	
	# Reset stats if modified (e.g. hp)
	
func _physics_process(_delta):
	# Simple tracking AI
	if _target and is_instance_valid(_target):
		var direction = global_position.direction_to(_target.global_position)
		velocity = direction * speed
		move_and_slide()
	
	# Despawn if too far (optional, for safety)
	# For now, we assume Spawner handles cleanup or Player kills them.

func take_damage(amount: float):
	hp -= amount
	if hp <= 0:
		die()

@export var xp_value: int = 1
@export var xp_gem_scene: PackedScene

# ... existing code ...

func die():
	# Drop XP deferred to avoid physics callback errors (add_child)
	call_deferred("_drop_xp")

	# Return to pool instead of queue_free
	if has_node("/root/PoolManager"):
		get_node("/root/PoolManager").return_instance(self, scene_file_path)
	else:
		queue_free()

func _drop_xp():
	if xp_gem_scene and has_node("/root/PoolManager"):
		var gem = get_node("/root/PoolManager").get_instance(xp_gem_scene)
		if gem:
			if gem.has_method("spawn"):
				gem.spawn(global_position, xp_value)
			else:
				gem.global_position = global_position
