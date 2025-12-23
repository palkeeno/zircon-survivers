extends CanvasLayer

@onready var hp_bar = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/HPBar
@onready var hp_label = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/HPLabel
@onready var shield_label = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/ShieldLabel
@onready var xp_bar = $Control/MarginContainer/VBoxContainer/XPBar
@onready var level_label = $Control/MarginContainer/VBoxContainer/XPBar/LevelLabel
@onready var loadout_label = $Control/MarginContainer/VBoxContainer/LoadoutLabel
@onready var weapons_icons = $Control/MarginContainer/VBoxContainer/WeaponsIcons
@onready var specials_icons = $Control/MarginContainer/VBoxContainer/SpecialsIcons
@onready var item_indicators_layer: Control = $Control/ItemIndicators

var _loadout_manager: Node = null

func _ready():
	# Connect to Player signals if available via GameManager
	# Or GameManager could broadcast them.
	# But strictly, Player emits them.
	
	# Wait for Player to register? Or check GameManager.
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.player_reference:
			_connect_player(gm.player_reference)
		
		# Also watch for future registrations (not implemented in GM yet, but we can poll or use a signal if we added one)
		# For now, let's assume Main creates HUD after Player, or we poll in process once.
		
	set_process(true)

var _player_connected = false
var _item_indicator_nodes: Dictionary = {} # instance_id -> Control

func _process(_delta):
	if not _player_connected and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.player_reference:
			_connect_player(gm.player_reference)
	_update_item_indicators()


func _update_item_indicators() -> void:
	if item_indicators_layer == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	# World -> screen conversion: use viewport's canvas transform (camera/zoom included).
	var canvas_xform: Transform2D = vp.get_canvas_transform()

	var rect: Rect2 = vp.get_visible_rect()
	var center: Vector2 = rect.size * 0.5
	var margin: float = 18.0
	var inner_rect := Rect2(Vector2(margin, margin), rect.size - Vector2(margin, margin) * 2.0)

	var live_ids: Dictionary = {}
	var items := get_tree().get_nodes_in_group("drop_items")
	for item in items:
		if item == null or not is_instance_valid(item) or not (item is Node2D):
			continue
		if not item.is_inside_tree() or item.process_mode == Node.PROCESS_MODE_DISABLED:
			continue

		var id := item.get_instance_id()
		live_ids[id] = true

		var ui: Control = _item_indicator_nodes.get(id, null)
		if ui == null:
			ui = _create_item_indicator()
			_item_indicator_nodes[id] = ui
			item_indicators_layer.add_child(ui)

		var screen_pos: Vector2 = canvas_xform * item.global_position
		var is_on_screen := inner_rect.has_point(screen_pos)
		ui.visible = not is_on_screen
		if is_on_screen:
			continue

		var dir := (screen_pos - center)
		if dir.length_squared() < 0.001:
			dir = Vector2.RIGHT
		dir = dir.normalized()

		var half := rect.size * 0.5 - Vector2(margin, margin)
		var sx := 1e9
		var sy := 1e9
		if absf(dir.x) > 0.0001:
			sx = half.x / absf(dir.x)
		if absf(dir.y) > 0.0001:
			sy = half.y / absf(dir.y)
		var s: float = minf(sx, sy)
		var edge_pos: Vector2 = center + dir * s

		ui.position = edge_pos - ui.size * 0.5

		var arrow: Label = ui.get_node("Arrow")
		arrow.rotation = atan2(dir.y, dir.x)

		var icon: Label = ui.get_node("Icon")
		if item.has_method("get_emoji"):
			icon.text = str(item.call("get_emoji"))
		elif "item_kind" in item:
			icon.text = str(item.item_kind)
		else:
			icon.text = "?"

	# Cleanup indicators for removed items
	for existing_id in _item_indicator_nodes.keys():
		if not live_ids.has(existing_id):
			var dead_ui: Control = _item_indicator_nodes[existing_id]
			if dead_ui and is_instance_valid(dead_ui):
				dead_ui.queue_free()
			_item_indicator_nodes.erase(existing_id)


func _create_item_indicator() -> Control:
	var root := Control.new()
	root.name = "ItemIndicator"
	root.custom_minimum_size = Vector2(54, 24)
	root.size = root.custom_minimum_size

	var arrow := Label.new()
	arrow.name = "Arrow"
	arrow.text = "▶"
	arrow.position = Vector2(0, 0)
	arrow.size = Vector2(24, 24)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 18)
	root.add_child(arrow)

	var icon := Label.new()
	icon.name = "Icon"
	icon.text = "?"
	icon.position = Vector2(26, 0)
	icon.size = Vector2(28, 24)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 18)
	root.add_child(icon)

	return root

func _connect_player(player):
	_player_connected = true
	player.hp_changed.connect(_on_hp_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.level_up.connect(_on_level_up)
	if player.has_signal("shield_changed"):
		player.shield_changed.connect(_on_shield_changed)
	
	if player.has_node("LoadoutManager"):
		_loadout_manager = player.get_node("LoadoutManager")
		if _loadout_manager and _loadout_manager.has_signal("LoadoutChanged"):
			# Avoid double-connect if HUD reconnects.
			if not _loadout_manager.is_connected("LoadoutChanged", Callable(self, "_on_loadout_changed")):
				_loadout_manager.connect("LoadoutChanged", Callable(self, "_on_loadout_changed"))
			_on_loadout_changed()
	
	# Initial update
	_on_hp_changed(player.current_hp, player.max_hp)
	_on_xp_changed(player.experience, player.next_level_xp)
	_on_level_up(player.level)
	if "shield_charges" in player:
		_on_shield_changed(int(player.shield_charges))

	# Constrain icon slots sizing to avoid oversized textures
	for node in weapons_icons.get_children():
		if node is TextureRect:
			node.custom_minimum_size = Vector2(24, 24)
			node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node.size_flags_horizontal = 0
			node.size_flags_vertical = 0
	for node in specials_icons.get_children():
		if node is TextureRect:
			node.custom_minimum_size = Vector2(24, 24)
			node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node.size_flags_horizontal = 0
			node.size_flags_vertical = 0

func _on_hp_changed(current, max_val):
	hp_bar.max_value = max_val
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_shield_changed(charges: int) -> void:
	if shield_label == null:
		return
	shield_label.text = "🛡 x%d" % int(max(0, charges))

func _on_xp_changed(current, next):
	xp_bar.max_value = next
	xp_bar.value = current

func _on_level_up(level):
	level_label.text = "LV %d" % level


func _on_loadout_changed():
	if not _loadout_manager:
		return
	var summary = _loadout_manager.call("GetLoadoutSummary")
	if summary == null or summary.size() < 2:
		return
	var weapons = summary[0]
	var specials = summary[1]

	var w_slots = []
	for i in range(4):
		w_slots.append("-")
	for i in range(min(weapons.size(), 4)):
		var w = weapons[i]
		w_slots[i] = "%s Lv%d" % [str(w.get("name", "")), int(w.get("level", 1))]

	var s_slots = []
	for i in range(4):
		s_slots.append("-")
	for i in range(min(specials.size(), 4)):
		var s = specials[i]
		s_slots[i] = "%s Lv%d" % [str(s.get("name", "")), int(s.get("level", 1))]

	loadout_label.text = "W: %s\nS: %s" % [" | ".join(w_slots), " | ".join(s_slots)]

	# マップタイル相当のサイズ（必要ならここだけ調整）
	var icon_size := Vector2(16, 16)

	# Set weapon icons
	for i in range(4):
		var texrect_w := weapons_icons.get_child(i)
		if texrect_w is TextureRect:
			texrect_w.custom_minimum_size = icon_size
			texrect_w.size = icon_size
			texrect_w.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texrect_w.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texrect_w.size_flags_horizontal = 0
			texrect_w.size_flags_vertical = 0

		if i < weapons.size():
			var w = weapons[i]
			var icon_path_w = str(w.get("icon_path", ""))
			if icon_path_w != "":
				var tex_w: Texture2D = load(icon_path_w)
				if tex_w:
					texrect_w.texture = tex_w
					continue
		texrect_w.texture = null

	# Set special icons
	for i in range(4):
		var texrect_s := specials_icons.get_child(i)
		if texrect_s is TextureRect:
			texrect_s.custom_minimum_size = icon_size
			texrect_s.size = icon_size
			texrect_s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texrect_s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texrect_s.size_flags_horizontal = 0
			texrect_s.size_flags_vertical = 0

		if i < specials.size():
			var s = specials[i]
			var icon_path_s = str(s.get("icon_path", ""))
			if icon_path_s != "":
				var tex_s: Texture2D = load(icon_path_s)
				if tex_s:
					texrect_s.texture = tex_s
					continue
		texrect_s.texture = null
