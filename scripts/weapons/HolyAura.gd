extends "res://scripts/weapons/Weapon.gd"
class_name HolyAura

@export var aura_radius: float = 90.0
@export var tick_interval: float = 0.2

var _tick_timer := 0.0
@onready var _vfx: Node = get_node_or_null("AuraVFX")
@onready var _area: Area2D = get_node_or_null("AuraArea")
@onready var _shape: CollisionShape2D = null

var _touching: Dictionary = {} # instance_id -> Node

func _ready():
	# HolyAura is always active (no cooldown-based firing)
	set_process(true)
	_ensure_area()
	_sync_radius()

func _process(delta: float) -> void:
	_sync_radius()

	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = max(0.05, tick_interval)
	_damage_touching_enemies()


func _ensure_area() -> void:
	if _area and is_instance_valid(_area):
		return
	_area = Area2D.new()
	_area.name = "AuraArea"
	_area.monitoring = true
	_area.monitorable = true
	_area.collision_layer = 0
	_area.collision_mask = 4 # Enemy layer (value 4)
	add_child(_area)

	_shape = CollisionShape2D.new()
	var s := CircleShape2D.new()
	s.radius = maxf(1.0, aura_radius)
	_shape.shape = s
	_area.add_child(_shape)

	_area.body_entered.connect(_on_aura_body_entered)
	_area.body_exited.connect(_on_aura_body_exited)


func _sync_radius() -> void:
	# VFX
	if _vfx and is_instance_valid(_vfx) and ("radius" in _vfx):
		_vfx.radius = aura_radius
	# Collision
	if not (_area and is_instance_valid(_area)):
		return
	if _shape == null or not is_instance_valid(_shape):
		_shape = _area.get_node_or_null("CollisionShape2D")
	var cs := _shape
	if cs and is_instance_valid(cs) and cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = maxf(1.0, aura_radius)


func _is_active_enemy(n: Node) -> bool:
	if not is_instance_valid(n):
		return false
	if not (n is Node2D):
		return false
	if not n.is_inside_tree():
		return false
	if n.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if n is CanvasItem and not (n as CanvasItem).visible:
		return false
	return n.is_in_group("enemies") and n.has_method("take_damage")


func _on_aura_body_entered(body: Node) -> void:
	if not _is_active_enemy(body):
		return
	_touching[int(body.get_instance_id())] = body
	# Apply damage once on touch, but respect tick pacing.
	body.call("take_damage", damage * owner_damage_mult)
	_tick_timer = max(0.05, tick_interval)


func _on_aura_body_exited(body: Node) -> void:
	_touching.erase(int(body.get_instance_id()))


func _damage_touching_enemies() -> void:
	var dmg := damage * owner_damage_mult
	# Copy keys to avoid dictionary mutation issues if enemies despawn.
	for k in _touching.keys():
		var enemy: Node = _touching.get(k)
		if not _is_active_enemy(enemy):
			_touching.erase(k)
			continue
		enemy.call("take_damage", dmg)
