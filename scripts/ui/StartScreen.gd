extends Control

const GAME_SCENE_PATH := "res://scenes/game/Main.tscn"

@onready var _start_button: Button = %StartButton

func _ready() -> void:
	get_tree().paused = false
	if is_instance_valid(_start_button):
		_start_button.grab_focus()
		_start_button.pressed.connect(_on_start_pressed)

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
