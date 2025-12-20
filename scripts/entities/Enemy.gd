extends CharacterBody2D
class_name Enemy

@export var speed: float = 100.0
@export var damage: float = 10.0
@export var hp: float = 10.0 # Treated as Max HP
@export var damage_number_scene: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

var current_hp: float

var _target: Node2D = null

var _hp_bar: ProgressBar = null
var _damage_numbers: Node2D = null

func _ready():
	_ensure_overhead_ui()

func spawn(pos: Vector2):
	global_position = pos
	current_hp = hp
	_clear_damage_numbers()
	_update_hp_bar()
	
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
	if amount <= 0.0:
		return

	current_hp -= amount
	_show_damage_number(amount)
	_update_hp_bar()
	if current_hp <= 0.0:
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

func _ensure_overhead_ui() -> void:
	# Creates per-enemy UI (HP bar + damage numbers) if not present.
	var overhead_ui: Node2D = get_node_or_null("OverheadUI")
	if overhead_ui == null:
		overhead_ui = Node2D.new()
		overhead_ui.name = "OverheadUI"
		overhead_ui.position = Vector2(0, -38)
		add_child(overhead_ui)

	var hp_bar: ProgressBar = overhead_ui.get_node_or_null("HPBar")
	if hp_bar == null:
		hp_bar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.show_percentage = false
		hp_bar.custom_minimum_size = Vector2(46, 6)
		hp_bar.position = Vector2(-23, -3)
		overhead_ui.add_child(hp_bar)

	var damage_numbers: Node2D = overhead_ui.get_node_or_null("DamageNumbers")
	if damage_numbers == null:
		damage_numbers = Node2D.new()
		damage_numbers.name = "DamageNumbers"
		overhead_ui.add_child(damage_numbers)

	_hp_bar = hp_bar
	_damage_numbers = damage_numbers

func _update_hp_bar() -> void:
	if _hp_bar == null:
		_ensure_overhead_ui()
	if _hp_bar == null:
		return

	_hp_bar.max_value = max(1.0, hp)
	_hp_bar.value = clamp(current_hp, 0.0, hp)
	_hp_bar.visible = true

func _clear_damage_numbers() -> void:
	if _damage_numbers == null:
		_ensure_overhead_ui()
	if _damage_numbers == null:
		return

	for child in _damage_numbers.get_children():
		child.queue_free()

func _show_damage_number(amount: float) -> void:
	if damage_number_scene == null:
		return
	if _damage_numbers == null:
		_ensure_overhead_ui()
	if _damage_numbers == null:
		return

	var node := damage_number_scene.instantiate()
	if node == null:
		return

	# Randomize around enemy head a bit.
	if node is Control:
		(node as Control).position = Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 10.0))
	elif node is Node2D:
		(node as Node2D).position = Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 10.0))

	_damage_numbers.add_child(node)
	if node.has_method("setup"):
		node.call("setup", amount)
