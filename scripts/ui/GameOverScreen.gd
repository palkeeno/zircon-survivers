extends CanvasLayer

## リザルト画面 - RunResultを表示

# UI要素（unique_name_in_owner で参照）
@onready var background_rect: ColorRect = %BackgroundRect
@onready var title_label: Label = %TitleLabel
@onready var survival_time_value: Label = %SurvivalTimeValue
@onready var level_value: Label = %LevelValue
@onready var kills_value: Label = %KillsValue
@onready var zircoin_value: Label = %ZircoinValue
@onready var weapons_row: HBoxContainer = %WeaponsRow
@onready var specials_row: HBoxContainer = %SpecialsRow
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton

# カウントアップ演出用
var _countup_tween: Tween = null
var _current_zircoin_display: int = 0
var _target_zircoin: int = 0

# アイコンサイズ
const ICON_SIZE := Vector2(48, 48)

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("game_ended"):
			gm.game_ended.connect(_on_game_ended)
		else:
			gm.game_over.connect(_on_game_over)


func _on_game_over():
	# Legacy fallback - RunResult が無い場合
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.last_run_result:
			_show_result(gm.last_run_result)
			return
	
	# フォールバック表示
	if title_label:
		title_label.text = "GAME OVER"
	visible = true
	get_tree().paused = true


func _on_game_ended(_is_clear: bool, _reason: String) -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.last_run_result:
			_show_result(gm.last_run_result)
			return
	
	# フォールバック
	_on_game_over()


func _show_result(result) -> void:
	if result == null:
		return
	
	visible = true
	get_tree().paused = true
	
	# 背景色を end_type に応じて変更
	if background_rect:
		background_rect.color = result.get_theme_color()
	
	# タイトル
	if title_label:
		title_label.text = "[ %s ]" % result.get_end_type_name()
	
	# 統計情報
	if survival_time_value:
		survival_time_value.text = result.format_survival_time()
	
	if level_value:
		level_value.text = str(result.final_level)
	
	if kills_value:
		kills_value.text = str(result.enemies_killed)
	
	# ジルコインのカウントアップ演出
	_target_zircoin = result.carry_over_resources.get("zircoin", 0)
	_current_zircoin_display = 0
	if zircoin_value:
		zircoin_value.text = "+ 0"
	_start_countup_animation()
	
	# ファイナルビルド表示
	_display_final_build(result.final_build)


func _start_countup_animation() -> void:
	if _countup_tween:
		_countup_tween.kill()
	
	if _target_zircoin <= 0:
		if zircoin_value:
			zircoin_value.text = "+ 0"
		return
	
	# カウントアップ時間を調整（多いほど長く、最大2秒）
	var duration := clampf(float(_target_zircoin) / 100.0, 0.5, 2.0)
	
	_countup_tween = create_tween()
	_countup_tween.set_ease(Tween.EASE_OUT)
	_countup_tween.set_trans(Tween.TRANS_QUAD)
	_countup_tween.tween_method(_update_zircoin_display, 0, _target_zircoin, duration)


func _update_zircoin_display(value: int) -> void:
	_current_zircoin_display = value
	if zircoin_value:
		zircoin_value.text = "+ %d" % value


func _display_final_build(final_build: Array) -> void:
	# final_build = [[weapons], [specials]]
	if weapons_row:
		_clear_children(weapons_row)
	if specials_row:
		_clear_children(specials_row)
	
	if final_build.size() < 2:
		return
	
	var weapons: Array = final_build[0] if final_build[0] is Array else []
	var specials: Array = final_build[1] if final_build[1] is Array else []
	
	# 武器アイコン
	for weapon in weapons:
		if weapon is Dictionary:
			var icon := _create_ability_icon(weapon)
			if weapons_row and icon:
				weapons_row.add_child(icon)
	
	# スペシャルアイコン
	for special in specials:
		if special is Dictionary:
			var icon := _create_ability_icon(special)
			if specials_row and icon:
				specials_row.add_child(icon)


func _create_ability_icon(ability_data: Dictionary) -> Control:
	var icon_path: String = ability_data.get("icon_path", "")
	var ability_name: String = ability_data.get("name", "?")
	var level: int = ability_data.get("level", 1)
	
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(60, 70)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = ICON_SIZE
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex_rect.texture = load(icon_path)
	else:
		# プレースホルダー
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = ICON_SIZE
		tex_rect.texture = placeholder
	
	container.add_child(tex_rect)
	
	# レベル表示
	var level_label := Label.new()
	level_label.text = "Lv%d" % level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	container.add_child(level_label)
	
	# ツールチップ
	container.tooltip_text = ability_name
	
	return container


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _on_restart_pressed():
	if _countup_tween:
		_countup_tween.kill()
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.reset_game()
		if gm.has_method("start_game"):
			gm.start_game()

	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_back_to_start_pressed() -> void:
	if _countup_tween:
		_countup_tween.kill()
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("return_to_menu"):
			gm.return_to_menu()
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/ui/StartScreen.tscn")
