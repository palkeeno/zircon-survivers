extends "res://scripts/weapons/Weapon.gd"
class_name HolyAura

@export var aura_radius: float = 90.0
@export var tick_interval: float = 0.5

var _tick_timer := 0.0

func _ready():
	# HolyAura is always active (no cooldown-based firing)
	set_process(true)

func _process(delta: float) -> void:
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
				enemy.take_damage(damage * _get_owner_damage_mult())

func _get_owner_damage_mult() -> float:
	# Fall back to 1.0 if the owning/parent node doesn't expose a multiplier.
	var source := get_parent()
	if source == null:
		source = get_owner() as Node

	if source != null:
		var mult = source.get("damage_mult")
		if mult == null:
			mult = source.get("owner_damage_mult")
		if mult == null:
			mult = source.get("damage_multiplier")

		if typeof(mult) == TYPE_INT or typeof(mult) == TYPE_FLOAT:
			return float(mult)

	return 1.0
