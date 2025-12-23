extends CharacterBody2D
class_name Player

@export var speed : float = 200.0
@export var max_hp : float = 100.0
@export var pickup_range : float = 50.0 # Used by magnet logic later if needed

var _base_speed: float
var _base_max_hp: float
var _base_pickup_range: float
var _base_armor: float

var _regen_per_sec: float = 0.0
var _stat_damage_mult: float = 1.0
var _stat_cooldown_mult: float = 1.0

var _magnet_area: Area2D
var _magnet_shape: CollisionShape2D

var _weapon_nodes := {} # ability_id -> Node

var _is_phased: bool = false
var _phase_timer: float = 0.0

var shield_charges: int = 0

@export var damage_zone_scene: PackedScene = preload("res://scenes/weapons/DamageZone.tscn")

var current_hp : float
var experience : int = 0
var level : int = 1
var next_level_xp : int = 5

signal level_up(new_level)
signal hp_changed(current, max)
signal xp_changed(current, next)
signal player_died
signal shield_changed(charges)

# Reference to joystick can be assigned in editor or found dynamically
@export var joystick_path : NodePath

# Use loose typing 'Node' or 'Control' to avoid compile error if VirtualJoystick class isn't registered yet
var _joystick : Control

var _aim_dir: Vector2 = Vector2.RIGHT

func _ready():
	_base_speed = speed
	_base_max_hp = max_hp
	_base_pickup_range = pickup_range
	_base_armor = armor

	current_hp = max_hp
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("xp_changed", experience, next_level_xp)
	emit_signal("shield_changed", shield_charges)
	
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
	_magnet_area = Area2D.new()
	_magnet_area.name = "MagnetArea"
	_magnet_area.collision_layer = 0
	_magnet_area.collision_mask = 16 # Loot Layer (5, value 16)
	add_child(_magnet_area)
	
	_magnet_shape = CollisionShape2D.new()
	_magnet_shape.shape = CircleShape2D.new()
	_magnet_shape.shape.radius = pickup_range
	_magnet_area.add_child(_magnet_shape)
	
	# XPGem is an Area2D, so we use area_entered, not body_entered
	_magnet_area.area_entered.connect(_on_magnet_area_entered)

	# Listen to Game Paused signal to check for sequential level ups
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").game_paused.connect(_on_game_paused)

	_bootstrap_existing_weapon_nodes()

func _on_magnet_area_entered(area):
	# If area is XPGem (has 'collect' method)
	if area.has_method("collect"):
		area.collect(self)

# Damage Handling
@export var armor: float = 0.0

var _touching_enemies = []
var _damage_timer = 0.0

func _process(delta):
	# Phase timer
	if _is_phased:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_is_phased = false

	# Passive regen
	if _regen_per_sec > 0.0 and current_hp > 0.0 and current_hp < max_hp:
		current_hp = min(max_hp, current_hp + _regen_per_sec * delta)
		emit_signal("hp_changed", current_hp, max_hp)

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
	if _is_phased:
		return
	if shield_charges > 0:
		shield_charges -= 1
		emit_signal("shield_changed", shield_charges)
		return
	current_hp -= amount
	emit_signal("hp_changed", current_hp, max_hp)
	if current_hp <= 0:
		die()


func add_shield_charges(count: int) -> void:
	if count <= 0:
		return
	shield_charges += count
	emit_signal("shield_changed", shield_charges)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if current_hp <= 0.0:
		return
	current_hp = clamp(current_hp + amount, 0.0, max_hp)
	emit_signal("hp_changed", current_hp, max_hp)

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
	
	if direction != Vector2.ZERO:
		_aim_dir = direction.normalized()

	velocity = direction * speed
	move_and_slide()


func get_aim_direction() -> Vector2:
	return _aim_dir


func _bootstrap_existing_weapon_nodes():
	# Player.tscn may already include the starting weapon. Tag it so C# can find it.
	for child in get_children():
		if child == null:
			continue
		# Prefer meta tag if already set.
		if child.has_meta("ability_id"):
			_weapon_nodes[child.get_meta("ability_id")] = child
			_register_weapon_base_stats(child)
			continue
		# Best-effort mapping by node name (keeps this minimal & backwards compatible).
		if child.name == "MagicWand":
			_register_weapon_node(child, "weapon_magic_wand")
		elif child.name == "HolyAura":
			_register_weapon_node(child, "weapon_holy_aura")
		elif child.name == "TargetedStrike":
			_register_weapon_node(child, "weapon_targeted_strike")


func _register_weapon_node(node: Node, ability_id: String):
	if not node:
		return
	node.set_meta("ability_id", ability_id)
	_weapon_nodes[ability_id] = node
	_register_weapon_base_stats(node)
	_apply_owner_modifiers_to_weapon(node)


func _register_weapon_base_stats(node: Node):
	# Store base values so upgrades can be applied deterministically by stack count.
	if not ("cooldown" in node):
		return
	if not node.has_meta("base_damage") and ("damage" in node):
		node.set_meta("base_damage", float(node.damage))
	if not node.has_meta("base_cooldown"):
		node.set_meta("base_cooldown", float(node.cooldown))
	if "shots_per_fire" in node and not node.has_meta("base_shots_per_fire"):
		node.set_meta("base_shots_per_fire", int(node.shots_per_fire))
	if "projectile_scale" in node and not node.has_meta("base_projectile_scale"):
		node.set_meta("base_projectile_scale", float(node.projectile_scale))
	if "projectile_pierce" in node and not node.has_meta("base_projectile_pierce"):
		node.set_meta("base_projectile_pierce", int(node.projectile_pierce))
	if "projectile_explosion_radius" in node and not node.has_meta("base_projectile_explosion_radius"):
		node.set_meta("base_projectile_explosion_radius", float(node.projectile_explosion_radius))
	if "aura_radius" in node and not node.has_meta("base_aura_radius"):
		node.set_meta("base_aura_radius", float(node.aura_radius))
	if "tick_interval" in node and not node.has_meta("base_tick_interval"):
		node.set_meta("base_tick_interval", float(node.tick_interval))
	if "strike_radius" in node and not node.has_meta("base_strike_radius"):
		node.set_meta("base_strike_radius", float(node.strike_radius))
	if "strikes_per_fire" in node and not node.has_meta("base_strikes_per_fire"):
		node.set_meta("base_strikes_per_fire", int(node.strikes_per_fire))
	if "nova_radius" in node and not node.has_meta("base_nova_radius"):
		node.set_meta("base_nova_radius", float(node.nova_radius))
	if "bursts_per_fire" in node and not node.has_meta("base_bursts_per_fire"):
		node.set_meta("base_bursts_per_fire", int(node.bursts_per_fire))
	if "start_range" in node and not node.has_meta("base_start_range"):
		node.set_meta("base_start_range", float(node.start_range))
	if "chain_range" in node and not node.has_meta("base_chain_range"):
		node.set_meta("base_chain_range", float(node.chain_range))
	if "max_jumps" in node and not node.has_meta("base_max_jumps"):
		node.set_meta("base_max_jumps", int(node.max_jumps))
	if "forks" in node and not node.has_meta("base_forks"):
		node.set_meta("base_forks", int(node.forks))
	if "boomerang_count" in node and not node.has_meta("base_boomerang_count"):
		node.set_meta("base_boomerang_count", int(node.boomerang_count))
	if "semi_major" in node and not node.has_meta("base_semi_major"):
		node.set_meta("base_semi_major", float(node.semi_major))
	if "eccentricity" in node and not node.has_meta("base_eccentricity"):
		node.set_meta("base_eccentricity", float(node.eccentricity))
	if "orbit_rotation_speed" in node and not node.has_meta("base_orbit_rotation_speed"):
		node.set_meta("base_orbit_rotation_speed", float(node.orbit_rotation_speed))
	if "angular_speed" in node and not node.has_meta("base_angular_speed"):
		node.set_meta("base_angular_speed", float(node.angular_speed))
	if "tick_interval" in node and not node.has_meta("base_tick_interval"):
		node.set_meta("base_tick_interval", float(node.tick_interval))
	if "fallback_beam_length" in node and not node.has_meta("base_fallback_beam_length"):
		node.set_meta("base_fallback_beam_length", float(node.fallback_beam_length))
	if "beam_width" in node and not node.has_meta("base_beam_width"):
		node.set_meta("base_beam_width", float(node.beam_width))
	if "beams_per_fire" in node and not node.has_meta("base_beams_per_fire"):
		node.set_meta("base_beams_per_fire", int(node.beams_per_fire))
	if "max_bounces" in node and not node.has_meta("base_max_bounces"):
		node.set_meta("base_max_bounces", int(node.max_bounces))
	if "throw_distance" in node and not node.has_meta("base_throw_distance"):
		node.set_meta("base_throw_distance", float(node.throw_distance))
	if "burn_radius" in node and not node.has_meta("base_burn_radius"):
		node.set_meta("base_burn_radius", float(node.burn_radius))
	if "burn_duration" in node and not node.has_meta("base_burn_duration"):
		node.set_meta("base_burn_duration", float(node.burn_duration))
	if "burn_tick_interval" in node and not node.has_meta("base_burn_tick_interval"):
		node.set_meta("base_burn_tick_interval", float(node.burn_tick_interval))
	if "bottles_per_fire" in node and not node.has_meta("base_bottles_per_fire"):
		node.set_meta("base_bottles_per_fire", int(node.bottles_per_fire))
	if "claw_radius" in node and not node.has_meta("base_claw_radius"):
		node.set_meta("base_claw_radius", float(node.claw_radius))
	if "reach" in node and not node.has_meta("base_reach"):
		node.set_meta("base_reach", float(node.reach))
	if "slashes_per_fire" in node and not node.has_meta("base_slashes_per_fire"):
		node.set_meta("base_slashes_per_fire", int(node.slashes_per_fire))


func _apply_owner_modifiers_to_weapon(node: Node):
	if not node:
		return
	if "owner_damage_mult" in node:
		node.owner_damage_mult = _stat_damage_mult
	if "owner_cooldown_mult" in node:
		node.owner_cooldown_mult = _stat_cooldown_mult


func _get_weapon_node(ability_id: String) -> Node:
	if _weapon_nodes.has(ability_id):
		var n = _weapon_nodes[ability_id]
		if is_instance_valid(n):
			return n
		_weapon_nodes.erase(ability_id)
	# Fallback: scan children
	for child in get_children():
		if child and child.has_meta("ability_id") and str(child.get_meta("ability_id")) == ability_id:
			_weapon_nodes[ability_id] = child
			return child
	return null


# Called from C# (LoadoutManager)
func ensure_weapon_scene(scene_path: String, ability_id: String):
	var existing = _get_weapon_node(ability_id)
	if existing:
		return
	var ps: PackedScene = load(scene_path)
	if not ps:
		return
	var node = ps.instantiate()
	add_child(node)
	_register_weapon_node(node, ability_id)


# Called from C# (LoadoutManager)
func add_weapon_scene(scene_path: String, ability_id: String):
	# For now, acquire behaves like ensure + attach.
	ensure_weapon_scene(scene_path, ability_id)


# Called from C# (LoadoutManager)
func apply_weapon_upgrade(ability_id: String, upgrade_id: String, stacks: int):
	var w = _get_weapon_node(ability_id)
	if not w:
		return
	_register_weapon_base_stats(w)

	# Apply only the changed aspect based on current stack count.
	match ability_id:
		"weapon_magic_wand":
			_apply_magic_wand_upgrade(w, upgrade_id, stacks)
		"weapon_holy_aura":
			_apply_holy_aura_upgrade(w, upgrade_id, stacks)
		"weapon_targeted_strike":
			_apply_targeted_strike_upgrade(w, upgrade_id, stacks)
		"weapon_nova_burst":
			_apply_nova_burst_upgrade(w, upgrade_id, stacks)
		"weapon_shockwave":
			_apply_shockwave_upgrade(w, upgrade_id, stacks)
		"weapon_orbit_boomerang":
			_apply_orbit_boomerang_upgrade(w, upgrade_id, stacks)
		"weapon_piercing_beam":
			_apply_piercing_beam_upgrade(w, upgrade_id, stacks)
		"weapon_fire_bottle":
			_apply_fire_bottle_upgrade(w, upgrade_id, stacks)
		"weapon_twin_claw":
			_apply_twin_claw_upgrade(w, upgrade_id, stacks)


func _apply_magic_wand_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_cd = float(w.get_meta("base_cooldown"))
	var base_shots = int(w.get_meta("base_shots_per_fire")) if w.has_meta("base_shots_per_fire") else 1
	var base_scale = float(w.get_meta("base_projectile_scale")) if w.has_meta("base_projectile_scale") else 1.0
	var base_pierce = int(w.get_meta("base_projectile_pierce")) if w.has_meta("base_projectile_pierce") else 0

	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.1, stacks)
		"cd_down":
			w.cooldown = max(0.05, base_cd * pow(0.92, stacks))
		"count_up":
			w.shots_per_fire = base_shots + stacks
		"size_up":
			w.projectile_scale = base_scale * pow(1.08, stacks)
		"pierce_up":
			w.projectile_pierce = base_pierce + stacks
		"explosion":
			w.projectile_explosion_radius = 70.0 if stacks > 0 else 0.0


func _apply_holy_aura_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_radius = float(w.get_meta("base_aura_radius")) if w.has_meta("base_aura_radius") else 90.0

	match upgrade_id:
		"radius_up":
			w.aura_radius = base_radius * pow(1.08, stacks)
		_:
			pass


func _apply_targeted_strike_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_cd = float(w.get_meta("base_cooldown"))
	var base_radius = float(w.get_meta("base_strike_radius")) if w.has_meta("base_strike_radius") else 80.0
	var base_count = int(w.get_meta("base_strikes_per_fire")) if w.has_meta("base_strikes_per_fire") else 1

	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.1, stacks)
		"cd_down":
			w.cooldown = max(0.05, base_cd * pow(0.92, stacks))
		"radius_up":
			w.strike_radius = base_radius * pow(1.08, stacks)
		"count_up":
			w.strikes_per_fire = base_count + stacks


func _apply_nova_burst_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_cd = float(w.get_meta("base_cooldown"))
	var base_radius = float(w.get_meta("base_nova_radius")) if w.has_meta("base_nova_radius") else 140.0
	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.13, stacks)
		"cd_down":
			w.cooldown = max(0.25, base_cd * pow(0.92, stacks))
		"radius_up":
			w.nova_radius = base_radius * pow(1.08, stacks)


func _apply_shockwave_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_cd = float(w.get_meta("base_cooldown"))
	var base_start = float(w.get_meta("base_start_range")) if w.has_meta("base_start_range") else 280.0
	var base_chain = float(w.get_meta("base_chain_range")) if w.has_meta("base_chain_range") else 200.0
	var base_jumps = int(w.get_meta("base_max_jumps")) if w.has_meta("base_max_jumps") else 4
	var base_forks = int(w.get_meta("base_forks")) if w.has_meta("base_forks") else 0

	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.1, stacks)
		"cd_down":
			w.cooldown = max(0.05, base_cd * pow(0.92, stacks))
		"range_up":
			w.start_range = base_start * pow(1.08, stacks)
			w.chain_range = base_chain * pow(1.08, stacks)
		"jumps_up":
			w.max_jumps = base_jumps + stacks
		"fork":
			w.forks = clampi(base_forks + stacks, 0, 2)


func _apply_orbit_boomerang_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_count = int(w.get_meta("base_boomerang_count")) if w.has_meta("base_boomerang_count") else 1
	var base_a = float(w.get_meta("base_semi_major")) if w.has_meta("base_semi_major") else 160.0
	var base_rot = float(w.get_meta("base_orbit_rotation_speed")) if w.has_meta("base_orbit_rotation_speed") else 1.2
	var base_speed = float(w.get_meta("base_angular_speed")) if w.has_meta("base_angular_speed") else 3.0
	var base_tick = float(w.get_meta("base_tick_interval")) if w.has_meta("base_tick_interval") else 0.25

	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.1, stacks)
		"count_up":
			w.boomerang_count = base_count + stacks
		"radius_up":
			w.semi_major = base_a * pow(1.08, stacks)
		"speed_up":
			w.angular_speed = base_speed * pow(1.10, stacks)
			w.orbit_rotation_speed = base_rot * pow(1.08, stacks)
		"tick_up":
			w.tick_interval = max(0.05, base_tick * pow(0.90, stacks))


func _apply_piercing_beam_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_cd = float(w.get_meta("base_cooldown"))
	var base_w = float(w.get_meta("base_beam_width")) if w.has_meta("base_beam_width") else 26.0
	var base_cnt = int(w.get_meta("base_beams_per_fire")) if w.has_meta("base_beams_per_fire") else 1
	var base_bounces = int(w.get_meta("base_max_bounces")) if w.has_meta("base_max_bounces") else 0

	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.1, stacks)
		"cd_down":
			w.cooldown = max(0.05, base_cd * pow(0.92, stacks))
		"width_up":
			w.beam_width = base_w * pow(1.08, stacks)
		"bounce_up":
			w.max_bounces = base_bounces + stacks
		"count_up":
			w.beams_per_fire = base_cnt + stacks


func _apply_fire_bottle_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_cd = float(w.get_meta("base_cooldown"))
	var base_radius = float(w.get_meta("base_burn_radius")) if w.has_meta("base_burn_radius") else 90.0
	var base_dur = float(w.get_meta("base_burn_duration")) if w.has_meta("base_burn_duration") else 2.8
	var base_tick = float(w.get_meta("base_burn_tick_interval")) if w.has_meta("base_burn_tick_interval") else 0.35
	var base_cnt = int(w.get_meta("base_bottles_per_fire")) if w.has_meta("base_bottles_per_fire") else 1

	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.1, stacks)
		"cd_down":
			w.cooldown = max(0.05, base_cd * pow(0.92, stacks))
		"radius_up":
			w.burn_radius = base_radius * pow(1.08, stacks)
		"duration_up":
			w.burn_duration = base_dur * pow(1.10, stacks)
		"tick_up":
			w.burn_tick_interval = max(0.05, base_tick * pow(0.90, stacks))
		"count_up":
			w.bottles_per_fire = base_cnt + stacks


func _apply_twin_claw_upgrade(w: Node, upgrade_id: String, stacks: int):
	var base_damage = float(w.get_meta("base_damage"))
	var base_cd = float(w.get_meta("base_cooldown"))
	var base_radius = float(w.get_meta("base_claw_radius")) if w.has_meta("base_claw_radius") else 70.0
	var base_cnt = int(w.get_meta("base_slashes_per_fire")) if w.has_meta("base_slashes_per_fire") else 1

	match upgrade_id:
		"dmg_up":
			w.damage = base_damage * pow(1.1, stacks)
		"cd_down":
			w.cooldown = max(0.05, base_cd * pow(0.92, stacks))
		"radius_up":
			w.claw_radius = base_radius * pow(1.08, stacks)
		"count_up":
			w.slashes_per_fire = base_cnt + stacks


# Called from C# (LoadoutManager)
func set_stat_modifiers(mods: Dictionary):
	_stat_damage_mult = float(mods.get("damage_mult", 1.0))
	_stat_cooldown_mult = float(mods.get("cooldown_mult", 1.0))
	var armor_bonus = float(mods.get("armor_bonus", 0.0))
	var max_hp_bonus = float(mods.get("max_hp_bonus", 0.0))
	_regen_per_sec = float(mods.get("regen_per_sec", 0.0))
	var magnet_mult = float(mods.get("magnet_mult", 1.0))

	# Apply player stats
	speed = _base_speed
	armor = _base_armor + armor_bonus
	var new_max_hp = _base_max_hp + max_hp_bonus
	if new_max_hp != max_hp:
		var delta = new_max_hp - max_hp
		max_hp = new_max_hp
		current_hp = clamp(current_hp + delta, 0.0, max_hp)
		emit_signal("hp_changed", current_hp, max_hp)

	pickup_range = _base_pickup_range * magnet_mult
	if _magnet_shape and _magnet_shape.shape and _magnet_shape.shape is CircleShape2D:
		_magnet_shape.shape.radius = pickup_range

	# Apply to weapons
	for ability_id in _weapon_nodes.keys():
		var w = _weapon_nodes[ability_id]
		if is_instance_valid(w):
			_apply_owner_modifiers_to_weapon(w)
	# Also apply to any stray weapon children (backward compatible)
	for child in get_children():
		if child and ("owner_damage_mult" in child or "owner_cooldown_mult" in child):
			_apply_owner_modifiers_to_weapon(child)


# Auto-active abilities (called from C#)
func do_knockback_pulse(radius: float, power: float):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var r2 = radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist2 = global_position.distance_squared_to(enemy.global_position)
		if dist2 > r2:
			continue
		var dir = (enemy.global_position - global_position).normalized()
		# Simple push-back. Enemy AI overwrites velocity, so we shift position directly.
		enemy.global_position += dir * (12.0 * power)


func do_nova(radius: float, dmg: float):
	if not damage_zone_scene:
		return
	var zone = damage_zone_scene.instantiate()
	get_tree().current_scene.add_child(zone)
	if zone.has_method("spawn"):
		zone.spawn(global_position, radius, dmg * _stat_damage_mult)


func do_phase(duration: float):
	_is_phased = true
	_phase_timer = max(0.1, duration)


func do_vacuum(radius: float):
	# Pull loot by forcing it to collect toward player.
	# (XPGem will home-in once collect() is called)
	var areas = get_tree().get_nodes_in_group("loot")
	if areas.size() == 0:
		return
	var r2 = radius * radius
	for a in areas:
		if not is_instance_valid(a):
			continue
		if a.has_method("collect"):
			var dist2 = global_position.distance_squared_to(a.global_position)
			if dist2 <= r2:
				a.collect(self)


func do_slow_zone(radius: float, slow_strength: float, duration: float):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var r2 = radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist2 = global_position.distance_squared_to(enemy.global_position)
		if dist2 > r2:
			continue
		if "speed" in enemy:
			if not enemy.has_meta("base_speed"):
				enemy.set_meta("base_speed", float(enemy.speed))
			enemy.speed = float(enemy.get_meta("base_speed")) * (1.0 - clamp(slow_strength, 0.0, 0.9))

	var t := Timer.new()
	t.wait_time = max(0.1, duration)
	t.one_shot = true
	add_child(t)
	t.timeout.connect(func():
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_meta("base_speed") and "speed" in enemy:
				enemy.speed = float(enemy.get_meta("base_speed"))
	)
	t.start()
