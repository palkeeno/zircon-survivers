extends CanvasLayer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").game_over.connect(_on_game_over)

func _on_game_over():
	visible = true
	get_tree().paused = true

func _on_restart_pressed():
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").reset_game()

	get_tree().paused = false
	get_tree().reload_current_scene()
