extends Node2D
class_name Weapon

@export var cooldown: float = 1.0
@export var damage: float = 5.0

var _cooldown_timer: Timer

func _ready():
	_cooldown_timer = Timer.new()
	add_child(_cooldown_timer)
	_cooldown_timer.wait_time = cooldown
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_ready)
	_start_cooldown() # Start initial delay if needed, or start ready? Let's start ready for first shot.
	_cooldown_timer.stop() # Ensure it's ready immediately

func _process(_delta):
	if _cooldown_timer.is_stopped():
		if _try_shoot():
			_start_cooldown()

func _try_shoot() -> bool:
	# Virtual method
	return false

func _start_cooldown():
	_cooldown_timer.start()

func _on_cooldown_ready():
	pass
