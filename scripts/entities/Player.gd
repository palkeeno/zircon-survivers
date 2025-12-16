extends CharacterBody2D
class_name Player

@export var speed : float = 200.0
@export var max_hp : float = 100.0
@export var pickup_range : float = 50.0 # Used by magnet logic later if needed

var current_hp : float
var experience : int = 0
var level : int = 1
var next_level_xp : int = 5

signal level_up(new_level)
signal hp_changed(current, max)
signal xp_changed(current, next)
signal player_died

# Reference to joystick can be assigned in editor or found dynamically
@export var joystick_path : NodePath

# Use loose typing 'Node' or 'Control' to avoid compile error if VirtualJoystick class isn't registered yet
var _joystick : Control

func _ready():
	current_hp = max_hp
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("xp_changed", experience, next_level_xp)
	
	if not joystick_path.is_empty():
		_joystick = get_node(joystick_path)
	
	# Register self to GameManager using usage-safe lookup
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").player_reference = self
	else:
		print("Error: GameManager singleton not found at /root/GameManager")

	# Add Hurtbox dynamically to avoid scene editing for now (or use what we have)
	var hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	# Collision Mask: Enemy is Layer 3 (Value 4)
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 4 # Detects Enemies
	add_child(hurtbox)
	
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 30.0 # Slightly smaller than body
	hurtbox.add_child(shape)
	
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.body_exited.connect(_on_hurtbox_body_exited)

# Damage Handling
var _touching_enemies = []
var _damage_timer = 0.0

func _process(delta):
	if _touching_enemies.size() > 0:
		_damage_timer -= delta
		if _damage_timer <= 0:
			take_damage(5.0 * _touching_enemies.size()) # 5 dmg per enemy roughly
			_damage_timer = 0.5 # 2 ticks per second

func _on_hurtbox_body_entered(body):
	if body.is_in_group("enemies"):
		_touching_enemies.append(body)
		# Immediate damage on touch? Or just start timer
		if _damage_timer <= 0:
			take_damage(5.0)
			_damage_timer = 0.5

func _on_hurtbox_body_exited(body):
	if body in _touching_enemies:
		_touching_enemies.erase(body)

func take_damage(amount: float):
	current_hp -= amount
	emit_signal("hp_changed", current_hp, max_hp)
	if current_hp <= 0:
		die()

func die():
	print("Player Died")
	emit_signal("player_died")
	# GameManager.trigger_game_over() # Implement later
	queue_free()

func add_experience(amount: int):
	experience += amount
	
	while experience >= next_level_xp:
		experience -= next_level_xp
		level += 1
		next_level_xp = int(next_level_xp * 1.2) + 5
		emit_signal("level_up", level)
		print("Level Up! New Level: ", level)
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").trigger_level_up_choice()
	
	emit_signal("xp_changed", experience, next_level_xp)


func _physics_process(_delta):
	var direction = Vector2.ZERO
	
	# Priority 1: Joystick
	# Duck-typing: check if it has the method get_output
	if _joystick and _joystick.has_method("get_output") and _joystick.get_output() != Vector2.ZERO:
		direction = _joystick.get_output()
		# print("Joystick Input: ", direction)
	else:
		# Priority 2: Keyboard (Debug/PC)
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		# if direction != Vector2.ZERO: print("Keyboard Input: ", direction)
	
	if not _joystick:
		print("Warning: Joystick node not found by Player")
	
	velocity = direction * speed
	move_and_slide()
