extends CanvasLayer

@onready var hp_bar = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/HPBar
@onready var hp_label = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/HPLabel
@onready var shield_label = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/ShieldLabel
@onready var xp_bar = $Control/MarginContainer/VBoxContainer/XPBar
@onready var level_label = $Control/MarginContainer/VBoxContainer/XPBar/LevelLabel
@onready var loadout_label = $Control/MarginContainer/VBoxContainer/LoadoutLabel
@onready var time_label: Label = $Control/MarginContainer/VBoxContainer/SecondRow/TimeLabel
@onready var score_label: Label = $Control/MarginContainer/VBoxContainer/SecondRow/ScoreLabel
@onready var weapons_icons = $Control/MarginContainer/VBoxContainer/SecondRow/InventoryBox/WeaponsIcons
@onready var specials_icons = $Control/MarginContainer/VBoxContainer/SecondRow/InventoryBox/SpecialsIcons
@onready var pause_button: Button = $Control/MarginContainer/VBoxContainer/SecondRow/PauseButton
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var item_indicators_layer: Control = $Control/ItemIndicators
@onready var zirpower_container: VBoxContainer = $Control/ZirPowerContainer

var _loadout_manager: Node = null
var _zirpower_buttons_initialized: bool = false

var _timer_fx_tween: Tween = null
var _timer_default_modulate: Color = Color(1, 1, 1, 1)
var _timer_default_scale: Vector2 = Vector2.ONE

func _ready():
	# Connect to Player signals if available via GameManager
	# Or GameManager could broadcast them.
	# But strictly, Player emits them.
	
	# Wait for Player to register? Or check GameManager.
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		# Score label defaults
		if score_label:
			score_label.text = "SCORE: %d" % int(gm.score) if ("score" in gm) else "SCORE: 0"
			if gm.has_signal("score_changed"):
				var c_score := Callable(self, "_on_score_changed")
				if not gm.is_connected("score_changed", c_score):
					gm.score_changed.connect(c_score)
		if gm.player_reference:
			_connect_player(gm.player_reference)

		# Timer label defaults
		if time_label:
			_timer_default_modulate = time_label.modulate
			_timer_default_scale = time_label.scale
			# Countdown display (prefer GM time_left; fall back to elapsed)
			var initial_time: float = 0.0
			if "max_run_time_sec" in gm and "run_time_sec" in gm:
				initial_time = maxf(0.0, float(gm.max_run_time_sec) - float(gm.run_time_sec))
			time_label.text = _format_time(initial_time)

		# Subscribe to GM time and boss/miniboss events
		# Prefer countdown if available.
		if gm.has_signal("time_left_changed"):
			var c_left := Callable(self, "_on_time_left_changed")
			if not gm.is_connected("time_left_changed", c_left):
				gm.time_left_changed.connect(c_left)
		elif gm.has_signal("run_time_changed"):
			var c := Callable(self, "_on_run_time_changed")
			if not gm.is_connected("run_time_changed", c):
				gm.run_time_changed.connect(c)

		# Prefer actual spawn signals if available; fall back to requested signals.
		if gm.has_signal("miniboss_spawned"):
			var c_minispawn := Callable(self, "_on_miniboss_spawned")
			if not gm.is_connected("miniboss_spawned", c_minispawn):
				gm.miniboss_spawned.connect(c_minispawn)
		elif gm.has_signal("miniboss_requested"):
			var c_minireq := Callable(self, "_on_miniboss_requested")
			if not gm.is_connected("miniboss_requested", c_minireq):
				gm.miniboss_requested.connect(c_minireq)

		if gm.has_signal("boss_spawned"):
			var c_bosspawn := Callable(self, "_on_boss_spawned")
			if not gm.is_connected("boss_spawned", c_bosspawn):
				gm.boss_spawned.connect(c_bosspawn)
		elif gm.has_signal("boss_requested"):
			var c_bosreq := Callable(self, "_on_boss_requested")
			if not gm.is_connected("boss_requested", c_bosreq):
				gm.boss_requested.connect(c_bosreq)

		# Pause button
		if pause_button:
			pause_button.pressed.connect(_on_pause_pressed)
			pause_button.disabled = (gm.current_state != gm.GameState.PLAYING) if "GameState" in gm else false

		# Close pause menu when game resumes
		if gm.has_signal("game_paused"):
			var c_pause := Callable(self, "_on_game_paused")
			if not gm.is_connected("game_paused", c_pause):
				gm.game_paused.connect(c_pause)
		
		# Also watch for future registrations (not implemented in GM yet, but we can poll or use a signal if we added one)
		# For now, let's assume Main creates HUD after Player, or we poll in process once.
		
	set_process(true)
	if loadout_label:
		loadout_label.visible = false
	if score_label:
		score_label.visible = true


func _on_score_changed(total_score: int) -> void:
	if score_label == null:
		return
	score_label.text = "SCORE: %d" % int(maxi(0, total_score))

var _player_connected = false
var _item_indicator_nodes: Dictionary = {} # instance_id -> Control

func _process(_delta):
	if not _player_connected and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.player_reference:
			_connect_player(gm.player_reference)
	_update_item_indicators()
	_update_pause_button_state()


func _update_pause_button_state() -> void:
	if pause_button == null:
		return
	if not has_node("/root/GameManager"):
		pause_button.disabled = false
		return
	var gm = get_node("/root/GameManager")
	# PLAYING中のみ押せる
	if "current_state" in gm and "GameState" in gm:
		pause_button.disabled = (gm.current_state != gm.GameState.PLAYING)
	else:
		pause_button.disabled = false


func _on_pause_pressed() -> void:
	if not has_node("/root/GameManager"):
		return
	var gm = get_node("/root/GameManager")
	if "current_state" in gm and "GameState" in gm:
		if gm.current_state != gm.GameState.PLAYING:
			return
	gm.pause_game()
	if pause_menu and pause_menu.has_method("open"):
		pause_menu.call("open")
	else:
		pause_menu.visible = true


func _on_game_paused(is_paused: bool) -> void:
	# 外部から再開された場合もメニューを閉じる
	if not is_paused:
		if pause_menu and pause_menu.has_method("close"):
			pause_menu.call("close")
		elif pause_menu:
			pause_menu.visible = false


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
	
	# ジルパワーボタンの初期化
	if not _zirpower_buttons_initialized:
		_initialize_zirpower_buttons(player)
	
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

	# HUD上のインベントリはアイコン表示のみ（文字表示なし）
	if loadout_label:
		loadout_label.visible = false

	# アイコンを倍サイズへ
	var icon_size := Vector2(48, 48)

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


func _format_time(time_sec: float) -> String:
	var total := maxi(0, int(floor(time_sec)))
	var minutes := int(total / 60.0)
	var seconds := total % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_run_time_changed(time_sec: float) -> void:
	if time_label == null:
		return
	# Legacy: show elapsed.
	time_label.text = _format_time(time_sec)

func _on_time_left_changed(time_left_sec: float) -> void:
	if time_label == null:
		return
	time_label.text = _format_time(time_left_sec)


func _on_miniboss_spawned() -> void:
	_play_timer_alert(false)


func _on_boss_spawned() -> void:
	_play_timer_alert(true)


func _on_miniboss_requested(_minute: int) -> void:
	# Fallback when only "requested" signal exists.
	_play_timer_alert(false)


func _on_boss_requested(_boss_index: int) -> void:
	# Fallback when only "requested" signal exists.
	_play_timer_alert(true)


func _play_timer_alert(is_boss: bool) -> void:
	if time_label == null:
		return
	if _timer_fx_tween and _timer_fx_tween.is_running():
		_timer_fx_tween.kill()

	# Ensure pivot is centered for scale pop.
	time_label.pivot_offset = time_label.size * 0.5

	var flash_color := Color(1, 0.35, 0.35, 1) if is_boss else Color(0.35, 0.65, 1, 1)
	time_label.modulate = flash_color
	time_label.scale = _timer_default_scale * 1.25

	_timer_fx_tween = create_tween()
	_timer_fx_tween.set_parallel(true)
	_timer_fx_tween.tween_property(time_label, "scale", _timer_default_scale, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_timer_fx_tween.tween_property(time_label, "modulate", _timer_default_modulate, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## ジルパワーボタンを初期化
func _initialize_zirpower_buttons(player: CharacterBody2D) -> void:
	if _zirpower_buttons_initialized or zirpower_container == null:
		return
	
	print("Initializing ZirPower buttons...")
	
	# PlayerのZirPowerManagerから直接取得
	var zirpower_manager = player.get_zirpower_manager()
	if not zirpower_manager:
		print("Error: ZirPowerManager not found on player")
		return
	
	# すべてのジルパワーを取得（GDScript互換メソッド使用）
	if not zirpower_manager.has_method("GetAllZirPowersForGDScript"):
		print("Error: GetAllZirPowersForGDScript method not found. Make sure C# project is built.")
		return
	
	var all_zirpowers = zirpower_manager.GetAllZirPowersForGDScript()
	if all_zirpowers.is_empty():
		print("No zirpowers found for this character")
		return
	
	print("Found ", all_zirpowers.size(), " zirpowers")
	
	# ZirPowerButtonシーンをロード
	var button_scene = load("res://scenes/ui/ZirPowerButton.tscn")
	if not button_scene:
		print("Error: ZirPowerButton.tscn not found")
		return
	
	# アルティメットを先に（上に）、アクティブを後に（下に）追加
	# まずアルティメット（type == 1）を追加
	for zirpower_data in all_zirpowers:
		if zirpower_data["type"] == 1:  # Ultimate
			var button_instance = button_scene.instantiate()
			button_instance.zirpower_id = zirpower_data["id"]
			button_instance.set_player(player)
			zirpower_container.add_child(button_instance)
			print("Added Ultimate button for: ", zirpower_data["name"], " (", zirpower_data["id"], ")")
	
	# 次にアクティブ（type == 0）を追加
	for zirpower_data in all_zirpowers:
		if zirpower_data["type"] == 0:  # Active
			var button_instance = button_scene.instantiate()
			button_instance.zirpower_id = zirpower_data["id"]
			button_instance.set_player(player)
			zirpower_container.add_child(button_instance)
			print("Added Active button for: ", zirpower_data["name"], " (", zirpower_data["id"], ")")
	
	_zirpower_buttons_initialized = true
	print("ZirPower buttons initialization complete")
