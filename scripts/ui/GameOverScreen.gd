extends CanvasLayer

@onready var title_label: Label = $Control/VBoxContainer/Label
@onready var score_label: Label = $Control/VBoxContainer/ScoreLabel
@onready var back_to_start_button: Button = $Control/VBoxContainer/BackToStartButton

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_language_to_ui()
	if has_node("/root/Localization"):
		get_node("/root/Localization").language_changed.connect(_on_language_changed)
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("game_ended"):
			gm.game_ended.connect(_on_game_ended)
		else:
			gm.game_over.connect(_on_game_over)

func _apply_language_to_ui() -> void:
	var loc := get_node("/root/Localization") if has_node("/root/Localization") else null
	if back_to_start_button and loc:
		back_to_start_button.text = str(loc.t("ui.back_to_start", back_to_start_button.text))

func _on_language_changed(_lang_code: String) -> void:
	_apply_language_to_ui()

func _on_game_over():
	# Legacy fallback
	if title_label:
		title_label.text = "GAME OVER"
	_show_end_screen()

func _show_end_screen() -> void:
	visible = true
	if score_label and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm and ("score" in gm):
			score_label.text = "SCORE: %d" % int(gm.score)
	get_tree().paused = true

func _on_game_ended(is_clear: bool, _reason: String) -> void:
	if title_label:
		title_label.text = "CLEAR" if is_clear else "GAME OVER"
	_show_end_screen()

func _on_restart_pressed():
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").reset_game()

	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_back_to_start_pressed() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("return_to_menu"):
			gm.return_to_menu()
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/ui/StartScreen.tscn")
