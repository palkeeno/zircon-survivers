extends Node2D
class_name Weapon

@export var cooldown: float = 1.0
@export var damage: float = 5.0

# Common upgrade-friendly parameters (not all weapons must use all of these).
@export var shots_per_fire: int = 1
@export var projectile_scale: float = 1.0
@export var projectile_pierce: int = 0
@export var projectile_explosion_radius: float = 0.0

# Multipliers set by Player/loadout (passives). Keep separate from per-weapon upgrades.
var owner_damage_mult: float = 1.0
var owner_cooldown_mult: float = 1.0

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


func _get_active_enemies() -> Array[Node2D]:
	# Enemies are pooled: pooled instances stay in the tree and in the group,
	# but have process_mode disabled and are invisible. Filter them out.
	var out: Array[Node2D] = []
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not e.is_inside_tree():
			continue
		if e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if not (e is Node2D):
			continue
		var n := e as Node2D
		# Pooled instances are hidden; avoid targeting them even if process_mode differs.
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		out.append(n)
	return out

func _try_shoot() -> bool:
	# Virtual method
	return false

func _start_cooldown():
	# Ensure latest cooldown is respected.
	_cooldown_timer.wait_time = cooldown * owner_cooldown_mult
	_cooldown_timer.start()

func _on_cooldown_ready():
	pass
