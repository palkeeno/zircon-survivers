extends Control

const GAME_SCENE_PATH := "res://scenes/game/Main.tscn"

@onready var _start_button: Button = %StartButton
@onready var _zircoin_label: Label = %ZircoinLabel

func _ready() -> void:
	get_tree().paused = false
	if is_instance_valid(_start_button):
		_start_button.grab_focus()
		_start_button.pressed.connect(_on_start_pressed)
	
	# 所持ジルコイン表示を更新
	_update_zircoin_display()
	
	# SaveDataManagerのシグナルに接続
	if has_node("/root/SaveDataManager"):
		var save_mgr = get_node("/root/SaveDataManager")
		if save_mgr.has_signal("zircoin_changed"):
			save_mgr.zircoin_changed.connect(_on_zircoin_changed)


func _update_zircoin_display() -> void:
	if not is_instance_valid(_zircoin_label):
		return
	
	var total: int = 0
	if has_node("/root/SaveDataManager"):
		var save_mgr = get_node("/root/SaveDataManager")
		if save_mgr.has_method("get_total_zircoin"):
			total = save_mgr.get_total_zircoin()
	
	_zircoin_label.text = "所持ジルコイン: %d" % total


func _on_zircoin_changed(total: int) -> void:
	if is_instance_valid(_zircoin_label):
		_zircoin_label.text = "所持ジルコイン: %d" % total

func _on_start_pressed() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("reset_game"):
			gm.reset_game()
		if gm.has_method("start_game"):
			gm.start_game()

	var err := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if err != OK:
		push_error("Failed to change scene to %s (err=%s)" % [GAME_SCENE_PATH, str(err)])
