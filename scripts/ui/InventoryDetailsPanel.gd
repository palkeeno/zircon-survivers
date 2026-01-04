extends Control

@export var icon_size: Vector2 = Vector2(48, 48)
@export var columns: int = 4

@onready var items_grid: GridContainer = $VBoxContainer/ItemsGrid
@onready var details_popup: PanelContainer = $DetailsPopup
@onready var details_name: Label = $DetailsPopup/MarginContainer/VBox/Name
@onready var details_level: Label = $DetailsPopup/MarginContainer/VBox/Level
@onready var details_stats: RichTextLabel = $DetailsPopup/MarginContainer/VBox/Stats
@onready var close_button: Button = $DetailsPopup/Close

var _loadout_manager: Node = null
var _player: Node = null

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(func(): hide_details())
	if has_node("/root/Localization"):
		get_node("/root/Localization").language_changed.connect(func(_lang):
			refresh()
			hide_details()
		)
	rebuild()

func rebuild() -> void:
	items_grid.columns = max(1, columns)
	refresh()

func refresh() -> void:
	_loadout_manager = _get_loadout_manager()
	_player = _get_player()

	for c in items_grid.get_children():
		c.queue_free()

	var items: Array = _get_loadout_items()
	for item in items:
		_add_item_button(item)

	hide_details()

func hide_details() -> void:
	if details_popup:
		details_popup.visible = false
	if details_stats:
		details_stats.text = ""


func show_offer_details(offer: Dictionary) -> void:
	# Public API for LevelUpScreen: show details for an offer without applying it.
	if details_popup == null or details_name == null or details_level == null or details_stats == null:
		return

	var offer_name := str(offer.get("name", ""))
	var ability_id := str(offer.get("target_id", offer.get("id", "")))
	var loc := get_node("/root/Localization") if has_node("/root/Localization") else null
	if loc and ability_id != "":
		details_name.text = str(loc.ability_name(ability_id, offer_name))
	else:
		details_name.text = offer_name

	var slot_kind := str(offer.get("slot_kind", ""))
	var action := str(offer.get("action", ""))
	var header := ""
	if slot_kind != "" and action != "":
		header = "%s / %s" % [slot_kind, action]
	elif slot_kind != "":
		header = slot_kind
	elif action != "":
		header = action
	details_level.text = header

	var desc := str(offer.get("desc_full", ""))
	if desc == "":
		desc = str(offer.get("desc", ""))
	if loc and ability_id != "":
		desc = str(loc.ability_desc_full(ability_id, desc))

	var lines: Array[String] = []
	if desc != "":
		var label_desc := str(loc.t("ui.description", "説明")) if loc else "説明"
		lines.append("[b]%s[/b]\n%s" % [label_desc, desc])

	# Meta info (weapon stats, cooldown, etc.)
	if slot_kind == "Weapon":
		var scene_path := str(offer.get("weapon_scene_path", ""))
		var stats_text := _get_weapon_scene_stats_text(scene_path)
		if stats_text != "":
			var label_stats := str(loc.t("ui.stats", "能力値")) if loc else "能力値"
			lines.append("[b]%s[/b]\n%s" % [label_stats, stats_text])
	else:
		var base_cd := float(offer.get("base_cooldown_sec", 0.0))
		if base_cd > 0.0:
			var label_cd := str(loc.t("ui.cooldown", "クールダウン")) if loc else "クールダウン"
			lines.append("%s: %.2fs" % [label_cd, base_cd])

	details_stats.text = "\n\n".join(lines)
	details_popup.visible = true
	call_deferred("_update_details_popup_layout")


func _get_weapon_scene_stats_text(scene_path: String) -> String:
	if scene_path == "":
		return ""
	var ps: PackedScene = load(scene_path)
	if ps == null:
		return ""
	var w: Node = ps.instantiate()
	if w == null:
		return ""

	var out: Array[String] = []
	out.append(_fmt_if_has(w, "damage", "威力"))
	if "cooldown" in w:
		out.append("攻撃間隔: %.2fs" % float(w.cooldown))
	out.append(_fmt_if_has(w, "shots_per_fire", "発射数"))
	out.append(_fmt_if_has(w, "projectile_scale", "弾サイズ"))
	out.append(_fmt_if_has(w, "projectile_pierce", "貫通"))
	out.append(_fmt_if_has(w, "projectile_explosion_radius", "爆発半径"))
	# Some weapons have their own motion params
	out.append(_fmt_if_has(w, "angular_speed", "回転速度"))
	out.append(_fmt_if_has(w, "orbit_rotation_speed", "軌道回転"))
	out.append(_fmt_if_has(w, "width", "幅"))
	out.append(_fmt_if_has(w, "reach", "射程"))
	out.append(_fmt_if_has(w, "aura_radius", "半径"))
	out.append(_fmt_if_has(w, "strike_radius", "半径"))
	out.append(_fmt_if_has(w, "strikes_per_fire", "対象数"))
	out.append(_fmt_if_has(w, "nova_radius", "半径"))
	out.append(_fmt_if_has(w, "chain_range", "連鎖距離"))
	out.append(_fmt_if_has(w, "max_jumps", "連鎖回数"))
	out.append(_fmt_if_has(w, "boomerang_count", "数"))
	out.append(_fmt_if_has(w, "tick_interval", "ヒット間隔"))
	out.append(_fmt_if_has(w, "burn_radius", "半径"))
	out.append(_fmt_if_has(w, "burn_duration", "持続"))
	out.append(_fmt_if_has(w, "slashes_per_fire", "斬撃数"))
	out.append(_fmt_if_has(w, "claw_radius", "半径"))

	# Projectile meta (e.g., bullet speed)
	if "projectile_scene" in w:
		var proj_scene = w.get("projectile_scene")
		if proj_scene is PackedScene:
			var p: Node = (proj_scene as PackedScene).instantiate()
			if p != null:
				out.append(_fmt_if_has(p, "speed", "弾速"))
				out.append(_fmt_if_has(p, "life_time", "射程(秒)"))
				p.free()

	# remove empties
	var filtered: Array[String] = []
	for s in out:
		if s != "":
			filtered.append(s)

	w.free()
	return "\n".join(filtered)

func _add_item_button(item: Dictionary) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = icon_size
	btn.focus_mode = Control.FOCUS_NONE

	var texrect := TextureRect.new()
	texrect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texrect.offset_left = 0
	texrect.offset_top = 0
	texrect.offset_right = 0
	texrect.offset_bottom = 0
	texrect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texrect.custom_minimum_size = icon_size
	texrect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texrect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texrect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var icon_path := str(item.get("icon_path", ""))
	if icon_path != "":
		var tex: Texture2D = load(icon_path)
		if tex:
			texrect.texture = tex

	btn.add_child(texrect)

	var lvl := int(item.get("level", 1))
	var level_badge := Label.new()
	level_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_badge.offset_left = 0
	level_badge.offset_top = 0
	level_badge.offset_right = 0
	level_badge.offset_bottom = 0
	level_badge.text = "Lv%d" % lvl
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	level_badge.add_theme_font_size_override("font_size", 14)
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(level_badge)

	btn.pressed.connect(func(): _show_details(item))
	items_grid.add_child(btn)

func _show_details(item: Dictionary) -> void:
	if not details_popup:
		return
	var ability_id := str(item.get("id", ""))
	var loc := get_node("/root/Localization") if has_node("/root/Localization") else null
	var fallback_name := str(item.get("name", ""))
	if loc and ability_id != "":
		details_name.text = str(loc.ability_name(ability_id, fallback_name))
	else:
		details_name.text = fallback_name
	details_level.text = "Lv%d" % int(item.get("level", 1))

	var lines: Array[String] = []
	var desc := str(item.get("description", ""))
	if loc and ability_id != "":
		desc = str(loc.ability_desc_full(ability_id, desc))
	if desc != "":
		var label_desc := str(loc.t("ui.description", "説明")) if loc else "説明"
		lines.append("[b]%s[/b]\n%s" % [label_desc, desc])

	var slot_kind := str(item.get("slot_kind", ""))
	if slot_kind == "Weapon":
		var label_stats := str(loc.t("ui.stats", "能力値")) if loc else "能力値"
		lines.append("[b]%s[/b]\n%s" % [label_stats, _get_weapon_stats_text(str(item.get("id", "")))])
	else:
		var base_cd := float(item.get("base_cooldown_sec", 0.0))
		if base_cd > 0.0:
			var label_cd := str(loc.t("ui.cooldown", "クールダウン")) if loc else "クールダウン"
			lines.append("%s: %.2fs" % [label_cd, base_cd])

	var upgrades: Array = item.get("upgrades", [])
	var up_lines: Array[String] = []
	for u in upgrades:
		var stacks := int(u.get("stacks", 0))
		if stacks <= 0:
			continue
		var uname := str(u.get("name", u.get("id", "")))
		up_lines.append("%s x%d" % [uname, stacks])
	if not up_lines.is_empty():
		var label_up := str(loc.t("ui.upgrades", "強化")) if loc else "強化"
		lines.append("[b]%s[/b]\n%s" % [label_up, "\n".join(up_lines)])

	details_stats.text = "\n\n".join(lines)
	details_popup.visible = true
	call_deferred("_update_details_popup_layout")


func _update_details_popup_layout() -> void:
	if details_popup == null or not details_popup.visible:
		return
	if details_name == null or details_level == null or details_stats == null:
		return

	# Let Godot measure text first
	await get_tree().process_frame

	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size if vp else Vector2(1280, 720)

	var header_h := details_name.get_combined_minimum_size().y + details_level.get_combined_minimum_size().y
	var content_h := details_stats.get_content_height()
	var padding := 24.0 + 16.0 # panel margins + a little air
	var desired_h := header_h + content_h + padding

	var max_h := maxf(160.0, vp_size.y - 40.0)
	var use_scroll := desired_h > max_h

	if use_scroll:
		details_stats.fit_content = false
		details_stats.scroll_active = true
		var stats_h := maxf(60.0, max_h - header_h - padding)
		details_stats.custom_minimum_size = Vector2(details_stats.custom_minimum_size.x, stats_h)
		details_popup.custom_minimum_size = Vector2(details_popup.custom_minimum_size.x, max_h)
		details_popup.size = Vector2(details_popup.size.x, max_h)
	else:
		details_stats.scroll_active = false
		details_stats.fit_content = true
		details_stats.custom_minimum_size = Vector2(details_stats.custom_minimum_size.x, 0)
		details_popup.custom_minimum_size = Vector2(details_popup.custom_minimum_size.x, desired_h)
		details_popup.size = Vector2(details_popup.size.x, desired_h)

	# Keep it within screen vertically
	var top_margin := 20.0
	var bottom_margin := 20.0
	var min_y := top_margin
	var max_y := vp_size.y - bottom_margin - details_popup.size.y
	if max_y < min_y:
		max_y = min_y
	var pos := details_popup.position
	pos.y = clampf(pos.y, min_y, max_y)
	details_popup.position = pos

func _get_weapon_stats_text(ability_id: String) -> String:
	var w := _find_weapon_node(ability_id)
	if w == null:
		return "(武器ノードが見つかりません)"

	var out: Array[String] = []
	out.append(_fmt_if_has(w, "damage", "攻撃力"))
	out.append(_fmt_if_has(w, "shots_per_fire", "発射数"))
	# cooldownは短いほど速い
	if "cooldown" in w:
		out.append("攻撃間隔: %.2fs" % float(w.cooldown))
	out.append(_fmt_if_has(w, "projectile_scale", "弾サイズ"))
	out.append(_fmt_if_has(w, "projectile_pierce", "貫通"))
	out.append(_fmt_if_has(w, "projectile_explosion_radius", "爆発半径"))
	out.append(_fmt_if_has(w, "aura_radius", "半径"))
	out.append(_fmt_if_has(w, "strike_radius", "半径"))
	out.append(_fmt_if_has(w, "strikes_per_fire", "対象数"))
	out.append(_fmt_if_has(w, "nova_radius", "半径"))
	out.append(_fmt_if_has(w, "chain_range", "連鎖距離"))
	out.append(_fmt_if_has(w, "max_jumps", "連鎖回数"))
	out.append(_fmt_if_has(w, "boomerang_count", "数"))
	out.append(_fmt_if_has(w, "tick_interval", "ヒット間隔"))
	out.append(_fmt_if_has(w, "width", "幅"))
	out.append(_fmt_if_has(w, "burn_radius", "半径"))
	out.append(_fmt_if_has(w, "burn_duration", "持続"))
	out.append(_fmt_if_has(w, "slashes_per_fire", "斬撃数"))
	out.append(_fmt_if_has(w, "claw_radius", "半径"))
	out.append(_fmt_if_has(w, "reach", "射程"))

	# remove empties
	var filtered: Array[String] = []
	for s in out:
		if s != "":
			filtered.append(s)

	return "\n".join(filtered)

func _fmt_if_has(obj: Object, prop: String, label: String) -> String:
	if obj == null:
		return ""
	if not (prop in obj):
		return ""
	var v = obj.get(prop)
	match typeof(v):
		TYPE_FLOAT:
			return "%s: %.2f" % [label, float(v)]
		TYPE_INT:
			return "%s: %d" % [label, int(v)]
		_:
			return "%s: %s" % [label, str(v)]

func _find_weapon_node(ability_id: String) -> Node:
	if _player == null:
		return null
	for child in _player.get_children():
		if child and child.has_meta("ability_id") and str(child.get_meta("ability_id")) == ability_id:
			return child
	return null

func _get_player() -> Node:
	if not has_node("/root/GameManager"):
		return null
	var gm = get_node("/root/GameManager")
	return gm.player_reference

func _get_loadout_manager() -> Node:
	var p := _get_player()
	if p == null:
		return null
	if p.has_node("LoadoutManager"):
		return p.get_node("LoadoutManager")
	return null

func _get_loadout_items() -> Array:
	var items: Array = []
	if _loadout_manager == null:
		return items

	if _loadout_manager.has_method("GetLoadoutDetailsForUI"):
		var arr = _loadout_manager.call("GetLoadoutDetailsForUI")
		if arr is Array:
			for d in arr:
				if d is Dictionary:
					items.append(d)
			return items

	# Fallback: GetLoadoutSummary
	if _loadout_manager.has_method("GetLoadoutSummary"):
		var summary = _loadout_manager.call("GetLoadoutSummary")
		if summary and summary.size() >= 2:
			for w in summary[0]:
				var d := Dictionary(w)
				d["slot_kind"] = "Weapon"
				items.append(d)
			for s in summary[1]:
				var d2 := Dictionary(s)
				d2["slot_kind"] = "Special"
				items.append(d2)

	return items
