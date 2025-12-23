extends CanvasLayer

@onready var resume_button: Button = $Control/Panel/MarginContainer/VBox/ResumeButton
@onready var inventory_panel: Control = $Control/Panel/MarginContainer/VBox/InventoryDetailsPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)

func open() -> void:
	visible = true
	if inventory_panel and inventory_panel.has_method("refresh"):
		inventory_panel.call("refresh")

func close() -> void:
	visible = false
	if inventory_panel and inventory_panel.has_method("hide_details"):
		inventory_panel.call("hide_details")

func _on_resume_pressed() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").resume_game()
	close()
