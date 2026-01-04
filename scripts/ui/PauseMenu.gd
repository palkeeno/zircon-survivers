extends CanvasLayer

@onready var resume_button: Button = $Control/Panel/MarginContainer/VBox/ResumeButton
@onready var inventory_panel: Control = $Control/Panel/MarginContainer/VBox/InventoryDetailsPanel
@onready var lang_label: Label = $Control/Panel/MarginContainer/VBox/LangRow/LangLabel
@onready var lang_option: OptionButton = $Control/Panel/MarginContainer/VBox/LangRow/LangOption

var _setting_lang_option := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	_setup_language_ui()
	_apply_language_to_ui()
	if has_node("/root/Localization"):
		get_node("/root/Localization").language_changed.connect(_on_language_changed)


func _setup_language_ui() -> void:
	if lang_option == null:
		return
	_setting_lang_option = true
	lang_option.clear()
	lang_option.add_item("日本語")
	lang_option.add_item("English")
	var current := "ja"
	if has_node("/root/Localization"):
		current = str(get_node("/root/Localization").get_language())
	lang_option.select(0 if current == "ja" else 1)
	_setting_lang_option = false
	lang_option.item_selected.connect(_on_lang_selected)


func _apply_language_to_ui() -> void:
	var loc := get_node("/root/Localization") if has_node("/root/Localization") else null
	if resume_button and loc:
		resume_button.text = str(loc.t("ui.resume", resume_button.text))
	if lang_label and loc:
		lang_label.text = str(loc.t("ui.language", lang_label.text))


func _on_language_changed(_lang_code: String) -> void:
	_setup_language_ui()
	_apply_language_to_ui()
	if inventory_panel and inventory_panel.has_method("refresh"):
		inventory_panel.call("refresh")

func open() -> void:
	visible = true
	_apply_language_to_ui()
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


func _on_lang_selected(index: int) -> void:
	if _setting_lang_option:
		return
	if not has_node("/root/Localization"):
		return
	var lang_code := "ja" if index == 0 else "en"
	get_node("/root/Localization").set_language(lang_code)
