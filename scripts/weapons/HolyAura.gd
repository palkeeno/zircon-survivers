extends "res://scripts/weapons/Weapon.gd"
class_name HolyAura

@export var aura_radius: float = 90.0
@export var tick_interval: float = 0.5

var _tick_timer := 0.0
@onready var _vfx: Node = get_node_or_null("AuraVFX")

func _ready():
	# HolyAura is always active (no cooldown-based firing)
	set_process(true)

func _process(delta: float) -> void:
	# Keep visuals in sync even when not ticking damage.
	if _vfx and is_instance_valid(_vfx) and ("radius" in _vfx):
		_vfx.radius = aura_radius

	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = max(0.05, tick_interval)
	_damage_enemies_in_radius()

func _damage_enemies_in_radius():
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return
	var r2 = aura_radius * aura_radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			var dist2 = global_position.distance_squared_to(enemy.global_position)
			if dist2 <= r2:
				enemy.take_damage(damage * owner_damage_mult)
