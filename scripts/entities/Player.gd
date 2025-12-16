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

	# 1. Hurtbox (Enemy Collision)
	var hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 4 # Enemy Layer (3, value 4)
	add_child(hurtbox)
	
	var hurt_shape = CollisionShape2D.new()
	hurt_shape.shape = CircleShape2D.new()
	hurt_shape.shape.radius = 61.0
	hurtbox.add_child(hurt_shape)
	
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.body_exited.connect(_on_hurtbox_body_exited)

	# 2. Magnet Area (XP Collection)
	var magnet = Area2D.new()
	magnet.name = "MagnetArea"
	magnet.collision_layer = 0
	magnet.collision_mask = 16 # Loot Layer (5, value 16)
	add_child(magnet)
	
	var magnet_shape = CollisionShape2D.new()
	magnet_shape.shape = CircleShape2D.new()
	magnet_shape.shape.radius = pickup_range
	magnet.add_child(magnet_shape)
	
	# XPGem is an Area2D, so we use area_entered, not body_entered
	magnet.area_entered.connect(_on_magnet_area_entered)

	# Listen to Game Paused signal to check for sequential level ups
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").game_paused.connect(_on_game_paused)

func _on_magnet_area_entered(area):
	# If area is XPGem (has 'collect' method)
	if area.has_method("collect"):
		area.collect(self)

# Damage Handling
@export var armor: float = 0.0

var _touching_enemies = []
var _damage_timer = 0.0

func _process(delta):
	# Validate touching enemies (remove dead/pooled ones)
	for i in range(_touching_enemies.size() - 1, -1, -1):
		var enemy = _touching_enemies[i]
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.process_mode == Node.PROCESS_MODE_DISABLED:
			_touching_enemies.remove_at(i)
			
	if _touching_enemies.size() > 0:
		_damage_timer -= delta
		if _damage_timer <= 0:
			# Calculate total damage from all touching enemies
			var total_damage = 0.0
			for enemy in _touching_enemies:
				# Assume Enemy has 'damage' property. If not, default to 5.0
				var dmg = enemy.damage if "damage" in enemy else 10.0
				total_damage += max(0.0, dmg - armor)
			
			if total_damage > 0:
				take_damage(total_damage)
			
			_damage_timer = 0.1 # 10 ticks per second (fast interval)

func _on_hurtbox_body_entered(body):
	if body.is_in_group("enemies"):
		if body not in _touching_enemies:
			_touching_enemies.append(body)
		
		# Immediate damage on touch
		if _damage_timer <= 0:
			var dmg = body.damage if "damage" in body else 10.0
			take_damage(max(0.0, dmg - armor))
			_damage_timer = 0.1

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
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").trigger_game_over()
	queue_free()

func _on_game_paused(is_paused: bool):
	if not is_paused:
		# Game Resumed. Check if we have enough XP for another level up.
		_check_level_up()

func add_experience(amount: int):
	experience += amount
	emit_signal("xp_changed", experience, next_level_xp)
	_check_level_up()

func _check_level_up():
	# If already leveling up (GameManager state), don't trigger again to avoid glitches
	# checking paused state might be enough if GM handles it correctly
	if experience >= next_level_xp:
		experience -= next_level_xp
		level += 1
		next_level_xp = int(next_level_xp * 1.2) + 5
		
		emit_signal("level_up", level)
		emit_signal("xp_changed", experience, next_level_xp)
		print("Level Up! New Level: ", level)
		
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").trigger_level_up_choice()


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
