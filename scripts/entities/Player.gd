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

var _zirpower_manager: Node = null  # ZirPowerManager (C#)

var _is_phased: bool = false
var _phase_timer: float = 0.0

var shield_charges: int = 0

var _hp_ui_root: Control = null
var _hp_ui_bar: ProgressBar = null
var _hp_ui_label: Label = null
var _shield_ui_row: Control = null
var _shield_ui_count: Label = null

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

@export var auto_collision_from_alpha: bool = true
@export var alpha_collision_threshold: float = 0.2
@export var alpha_collision_cell_size: int = 8
@export var alpha_collision_max_rects: int = 24

func _compute_visual_radius_from_sprite(sprite: AnimatedSprite2D) -> float:
	if not sprite:
		return 30.0
	var frames: SpriteFrames = sprite.sprite_frames
	if not frames:
		return 30.0

	var anim: StringName = sprite.animation
	if anim == StringName():
		anim = &"default"
	if not frames.has_animation(anim):
		anim = &"default"
	if not frames.has_animation(anim):
		return 30.0

	var frame_count: int = frames.get_frame_count(anim)
	if frame_count <= 0:
		return 30.0

	var max_dim: float = 0.0
	for i in range(frame_count):
		var tex: Texture2D = frames.get_frame_texture(anim, i)
		if tex:
			var s: Vector2i = tex.get_size()
			max_dim = max(max_dim, float(max(s.x, s.y)))

	if max_dim <= 0.0:
		return 30.0

	var scale_mult: float = maxf(absf(sprite.scale.x), absf(sprite.scale.y))
	return (max_dim * 0.5) * scale_mult


func _get_frame1_texture(sprite: AnimatedSprite2D) -> Texture2D:
	if sprite == null:
		return null
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return null
	var anim: StringName = sprite.animation
	if anim == StringName():
		anim = &"default"
	if not frames.has_animation(anim):
		anim = &"default"
	if not frames.has_animation(anim):
		return null
	if frames.get_frame_count(anim) <= 0:
		return null
	return frames.get_frame_texture(anim, 0)


func _build_rects_from_alpha(img: Image, cell_size: int, threshold: float) -> Array[Rect2]:
	# Returns rectangles in pixel space (top-left origin) before centering.
	var rects: Array[Rect2] = []
	if img == null:
		return rects
	if cell_size <= 0:
		cell_size = 8

	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return rects

	var gw: int = int(ceil(float(w) / float(cell_size)))
	var gh: int = int(ceil(float(h) / float(cell_size)))

	# Build occupancy grid
	var occ: Array = []
	occ.resize(gh)
	for y in range(gh):
		var row: PackedByteArray = PackedByteArray()
		row.resize(gw)
		for x in range(gw):
			row[x] = 0
		occ[y] = row

	for gy in range(gh):
		var py0: int = gy * cell_size
		var py1: int = min(h, py0 + cell_size)
		for gx in range(gw):
			var px0: int = gx * cell_size
			var px1: int = min(w, px0 + cell_size)
			var filled: bool = false
			# Sample a few points for speed (corners + center-ish)
			var sx0: int = px0
			var sx1: int = px1 - 1
			var sy0: int = py0
			var sy1: int = py1 - 1
			var sxm: int = int((float(px0) + float(px1)) * 0.5)
			var sym: int = int((float(py0) + float(py1)) * 0.5)
			var samples: Array[Vector2i] = [
				Vector2i(sx0, sy0), Vector2i(sx1, sy0), Vector2i(sx0, sy1), Vector2i(sx1, sy1),
				Vector2i(sxm, sym),
			]
			for s in samples:
				var c: Color = img.get_pixelv(s)
				if c.a >= threshold:
					filled = true
					break
			if filled:
				(occ[gy] as PackedByteArray)[gx] = 1

	# Merge occupied cells into rectangles (run-length per row + vertical merge)
	var active: Dictionary = {} # key "x0:x1" -> Rect2 in grid coords
	for gy in range(gh):
		var row: PackedByteArray = occ[gy]
		var segments: Array = []
		var x: int = 0
		while x < gw:
			while x < gw and row[x] == 0:
				x += 1
			if x >= gw:
				break
			var x0: int = x
			while x < gw and row[x] == 1:
				x += 1
			var x1: int = x
			segments.append([x0, x1])

		var next_active: Dictionary = {}
		for seg in segments:
			var sx0i: int = seg[0]
			var sx1i: int = seg[1]
			var key: String = "%d:%d" % [sx0i, sx1i]
			if active.has(key):
				var r: Rect2 = active[key]
				r.size.y += 1.0
				next_active[key] = r
			else:
				next_active[key] = Rect2(Vector2(sx0i, gy), Vector2(sx1i - sx0i, 1))

		# Finalize rectangles that didn't continue
		for k in active.keys():
			if not next_active.has(k):
				rects.append(active[k])
		active = next_active

	# Finalize remaining
	for k in active.keys():
		rects.append(active[k])

	# Convert from grid coords to pixel coords
	var pixel_rects: Array[Rect2] = []
	for r in rects:
		var px: float = r.position.x * float(cell_size)
		var py: float = r.position.y * float(cell_size)
		var pw: float = r.size.x * float(cell_size)
		var ph: float = r.size.y * float(cell_size)
		pixel_rects.append(Rect2(px, py, pw, ph))
	return pixel_rects


func _apply_rect_colliders(parent_node: Node, rects: Array[Rect2], img_size: Vector2i, sprite_scale: Vector2, max_rects: int) -> int:
	# Adds RectangleShape2D CollisionShape2D nodes under `parent_node`.
	# Rects are in pixel coords (top-left origin). Converts to centered local coords.
	if parent_node == null:
		return 0
	var created: int = 0
	var half: Vector2 = Vector2(img_size) * 0.5
	var limit: int = max_rects
	if limit <= 0:
		limit = 24

	# Remove old auto-colliders
	for child in parent_node.get_children():
		if child is CollisionShape2D and (child as Node).name.begins_with("AutoCollision_"):
			child.queue_free()

	# Prefer larger rectangles first
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.size.x * a.size.y > b.size.x * b.size.y)

	for r in rects:
		if created >= limit:
			break
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var center_px: Vector2 = r.position + (r.size * 0.5)
		var local_center: Vector2 = (center_px - half) * sprite_scale
		var extents: Vector2 = (r.size * 0.5) * Vector2(absf(sprite_scale.x), absf(sprite_scale.y))
		if extents.x <= 0.5 or extents.y <= 0.5:
			continue

		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = extents * 2.0
		var cs: CollisionShape2D = CollisionShape2D.new()
		cs.name = "AutoCollision_%d" % created
		cs.position = local_center
		cs.shape = shape
		parent_node.add_child(cs)
		created += 1

	return created


func _build_player_collision_from_alpha(sprite: AnimatedSprite2D, player_collider: CollisionShape2D, hurtbox: Area2D, hurtbox_circle: CollisionShape2D) -> void:
	var tex: Texture2D = _get_frame1_texture(sprite)
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return

	var rects: Array[Rect2] = _build_rects_from_alpha(img, alpha_collision_cell_size, alpha_collision_threshold)
	if rects.is_empty():
		return

	var created_player: int = _apply_rect_colliders(self, rects, img.get_size(), sprite.scale, alpha_collision_max_rects)
	var created_hurt: int = 0
	if hurtbox != null:
		created_hurt = _apply_rect_colliders(hurtbox, rects, img.get_size(), sprite.scale, alpha_collision_max_rects)

	if created_player > 0 and player_collider != null:
		player_collider.disabled = true
	if created_hurt > 0 and hurtbox_circle != null:
		hurtbox_circle.disabled = true

func _ready():
	var sprite_node: Node = get_node_or_null("Sprite2D")
	if sprite_node and sprite_node is AnimatedSprite2D:
		(sprite_node as AnimatedSprite2D).play(&"default")

	_base_speed = speed
	_base_max_hp = max_hp
	_base_pickup_range = pickup_range
	_base_armor = armor

	current_hp = max_hp
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("xp_changed", experience, next_level_xp)
	emit_signal("shield_changed", shield_charges)

	_create_world_hp_ui()
	hp_changed.connect(_on_self_hp_changed_for_ui)
	_on_self_hp_changed_for_ui(current_hp, max_hp)
	shield_changed.connect(_on_self_shield_changed_for_ui)
	_on_self_shield_changed_for_ui(shield_charges)
	
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
	hurtbox.collision_layer = PhysicsLayers.NONE
	hurtbox.collision_mask = PhysicsLayers.ENEMY
	add_child(hurtbox)
	
	var hurt_shape = CollisionShape2D.new()
	hurt_shape.shape = CircleShape2D.new()
	# Radius will be synced to the player visual size below.
	hurt_shape.shape.radius = 30.0
	hurtbox.add_child(hurt_shape)
	
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.body_exited.connect(_on_hurtbox_body_exited)

	# 2. Magnet Area (XP Collection)
	_magnet_area = Area2D.new()
	_magnet_area.name = "MagnetArea"
	_magnet_area.collision_layer = PhysicsLayers.NONE
	_magnet_area.collision_mask = PhysicsLayers.LOOT
	add_child(_magnet_area)
	
	_magnet_shape = CollisionShape2D.new()
	_magnet_shape.shape = CircleShape2D.new()
	_magnet_shape.shape.radius = pickup_range
	_magnet_area.add_child(_magnet_shape)
	
	# XPGem is an Area2D, so we use area_entered, not body_entered
	_magnet_area.area_entered.connect(_on_magnet_area_entered)

	# Build a coarse rectangle-based collider from frame-1 alpha.
	# This is computed once and reused while the sprite keeps animating.
	if auto_collision_from_alpha and sprite_node and sprite_node is AnimatedSprite2D:
		var player_cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
		_build_player_collision_from_alpha(sprite_node as AnimatedSprite2D, player_cs, hurtbox, hurt_shape)
	else:
		# Sync circle colliders to the current player visual size.
		if sprite_node and sprite_node is AnimatedSprite2D:
			var r: float = _compute_visual_radius_from_sprite(sprite_node as AnimatedSprite2D)
			var player_cs2: CollisionShape2D = get_node_or_null("CollisionShape2D")
			if player_cs2 and player_cs2.shape is CircleShape2D:
				(player_cs2.shape as CircleShape2D).radius = r
			if hurt_shape.shape is CircleShape2D:
				(hurt_shape.shape as CircleShape2D).radius = r

	# Listen to Game Paused signal to check for sequential level ups
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").game_paused.connect(_on_game_paused)

	_bootstrap_existing_weapon_nodes()
	_initialize_zirpower_manager()


func _initialize_zirpower_manager() -> void:
	# ZirPowerManager (C#) を追加
	var zirpower_manager_script = load("res://csharp/Loadout/ZirPowerManager.cs")
	if zirpower_manager_script:
		_zirpower_manager = Node.new()
		_zirpower_manager.set_script(zirpower_manager_script)
		_zirpower_manager.name = "ZirPowerManager"
		add_child(_zirpower_manager)
		
		# キャラクターIDを取得して初期化
		var character_id := "izumi"  # デフォルト
		if has_node("/root/GameManager"):
			var gm = get_node("/root/GameManager")
			if "selected_character_id" in gm:
				character_id = gm.selected_character_id
		
		if _zirpower_manager.has_method("InitializeForCharacter"):
			_zirpower_manager.call("InitializeForCharacter", character_id)
			print("ZirPowerManager initialized for character: ", character_id)
	else:
		print("Error: Could not load ZirPowerManager.cs")


func _create_world_hp_ui() -> void:
	# Playerの子として生成すればキャラクターに追従する
	if _hp_ui_root != null and is_instance_valid(_hp_ui_root):
		return

	_hp_ui_root = Control.new()
	_hp_ui_root.name = "WorldHP"
	_hp_ui_root.z_index = 100
	_hp_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_ui_root.size = Vector2(90, 28)
	# HPバー(+盾スタック行)の高さ分だけ少し上げて、全体の位置感を維持
	_hp_ui_root.position = Vector2(-45, 30)
	add_child(_hp_ui_root)

	_hp_ui_bar = ProgressBar.new()
	_hp_ui_bar.name = "HPBar"
	_hp_ui_bar.show_percentage = false
	_hp_ui_bar.size_flags_horizontal = Control.SIZE_FILL
	_hp_ui_bar.size_flags_vertical = Control.SIZE_FILL
	_hp_ui_bar.custom_minimum_size = Vector2(_hp_ui_root.size.x, 14)
	_hp_ui_bar.size = Vector2(_hp_ui_root.size.x, 14)
	_hp_ui_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.25, 0.05, 0.05, 1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bg.content_margin_left = 2
	bg.content_margin_top = 2
	bg.content_margin_right = 2
	bg.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.15, 0.15, 1)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	_hp_ui_bar.add_theme_stylebox_override("background", bg)
	_hp_ui_bar.add_theme_stylebox_override("fill", fill)
	_hp_ui_root.add_child(_hp_ui_bar)

	_hp_ui_label = Label.new()
	_hp_ui_label.name = "HPText"
	_hp_ui_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_ui_label.offset_left = 0
	_hp_ui_label.offset_top = 0
	_hp_ui_label.offset_right = 0
	_hp_ui_label.offset_bottom = 0
	_hp_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_ui_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_ui_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_hp_ui_label.add_theme_font_size_override("font_size", 12)
	_hp_ui_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_ui_bar.add_child(_hp_ui_label)

	# シールドスタック表示（HPバーの下）
	_shield_ui_row = Control.new()
	_shield_ui_row.name = "ShieldRow"
	_shield_ui_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_ui_row.size = Vector2(_hp_ui_root.size.x, 12)
	_shield_ui_row.position = Vector2(0, 16)
	_hp_ui_root.add_child(_shield_ui_row)

	var icon := Label.new()
	icon.name = "ShieldIcon"
	icon.text = "🛡"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 12)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(0, -1)
	icon.size = Vector2(16, 12)
	_shield_ui_row.add_child(icon)

	_shield_ui_count = Label.new()
	_shield_ui_count.name = "ShieldCount"
	_shield_ui_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_shield_ui_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_ui_count.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_shield_ui_count.add_theme_font_size_override("font_size", 12)
	_shield_ui_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_ui_count.position = Vector2(16, -1)
	_shield_ui_count.size = Vector2(_hp_ui_root.size.x - 16, 12)
	_shield_ui_row.add_child(_shield_ui_count)

	_on_self_shield_changed_for_ui(shield_charges)


func _on_self_hp_changed_for_ui(current: float, max_val: float) -> void:
	if _hp_ui_bar == null or _hp_ui_label == null:
		return
	_hp_ui_bar.max_value = max_val
	_hp_ui_bar.value = current
	_hp_ui_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_self_shield_changed_for_ui(charges: int) -> void:
	if _shield_ui_row == null or _shield_ui_count == null:
		return
	var c := int(max(0, charges))
	_shield_ui_row.visible = c > 0
	_shield_ui_count.text = "x%d" % c

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
		elif child.name == "OrbitBoomerang":
			_register_weapon_node(child, "weapon_orbit_boomerang")


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
			w.aura_radius = base_radius * pow(1.12, stacks)
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
		# Prefer velocity-based knockback to avoid fighting physics.
		if enemy.has_method("apply_knockback"):
			enemy.call("apply_knockback", dir * (720.0 * power))
		else:
			# Fallback (older enemies)
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


## ジルパワーを発動（UIから呼ばれる）
func activate_zirpower(zirpower_id: String) -> void:
	if _zirpower_manager and _zirpower_manager.has_method("ActivateZirPower"):
		_zirpower_manager.call("ActivateZirPower", zirpower_id)
	else:
		print("Error: ZirPowerManager not initialized")


## ジルパワーが発動可能かチェック
func can_activate_zirpower(zirpower_id: String) -> bool:
	if _zirpower_manager and _zirpower_manager.has_method("CanActivateZirPower"):
		return _zirpower_manager.call("CanActivateZirPower", zirpower_id)
	return false


## ZirPowerManagerへの参照を取得
func get_zirpower_manager() -> Node:
	return _zirpower_manager
