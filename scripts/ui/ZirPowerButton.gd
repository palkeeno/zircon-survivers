extends Button
class_name ZirPowerButton

## ジルパワーボタンのUI
## クールダウン表示、ウルティメットの場合は意志ゲージも表示

@export var zirpower_id: String = ""  ## 発動するジルパワーのID
@export var button_icon: Texture2D  ## ボタンのアイコン画像

var _zirpower_def = null
var _player: CharacterBody2D = null
var _cooldown_remaining: float = 0.0

@onready var _icon_rect: TextureRect = $MarginContainer/VBoxContainer/IconRect
@onready var _name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var _cooldown_overlay: ColorRect = $CooldownOverlay
@onready var _cooldown_label: Label = $CooldownOverlay/CooldownLabel
@onready var _gauge_container: Panel = $GaugeContainer
@onready var _gauge_fill: ColorRect = $GaugeContainer/Fill
@onready var _gauge_label: Label = $GaugeContainer/Label


func _ready() -> void:
	pressed.connect(_on_button_pressed)
	
	# アイコンを設定
	if button_icon and _icon_rect:
		_icon_rect.texture = button_icon
	
	# GameManagerのシグナルに接続
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_signal("will_changed"):
			gm.will_changed.connect(_on_will_changed)
		if gm.has_signal("will_full"):
			gm.will_full.connect(_on_will_full)
	
	# _load_zirpower_def()はset_player()で呼ばれるので削除
	_update_display()


func _load_zirpower_def() -> void:
	# Playerがセットされるまで待つ
	if not _player:
		return
	
	if zirpower_id.is_empty():
		return
	
	# PlayerのZirPowerManagerから取得
	var zirpower_manager = null
	if _player.has_method("get_zirpower_manager"):
		zirpower_manager = _player.call("get_zirpower_manager")
	
	if not zirpower_manager:
		print("Error: ZirPowerManager not found on player")
		return
	
	# GDScript互換メソッドを使用
	if zirpower_manager.has_method("GetZirPowerDefForGDScript"):
		_zirpower_def = zirpower_manager.GetZirPowerDefForGDScript(zirpower_id)
		if _zirpower_def:
			print("Loaded ZirPower def: ", zirpower_id)
		else:
			print("Error: ZirPower def not found: ", zirpower_id)
	else:
		print("Error: GetZirPowerDefForGDScript method not found on ZirPowerManager")


func set_player(player: CharacterBody2D) -> void:
	_player = player
	# Playerがセットされたら定義をロード
	_load_zirpower_def()
	_update_display()


func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		_update_display()


func _on_button_pressed() -> void:
	if not _player:
		print("Error: Player not set for ZirPowerButton")
		return
	
	if not _player.has_method("can_activate_zirpower"):
		print("Error: Player does not have can_activate_zirpower method")
		return
	
	if _player.call("can_activate_zirpower", zirpower_id):
		_player.call("activate_zirpower", zirpower_id)
		_start_cooldown()


func _start_cooldown() -> void:
	# 小文字のキーを使用（GDScript互換Dictionary）
	if _zirpower_def and _zirpower_def.has("cooldown"):
		_cooldown_remaining = _zirpower_def["cooldown"]


func _update_display() -> void:
	if not _zirpower_def:
		return
	
	var is_ultimate: bool = false
	# 小文字のキーを使用。ZirPowerType.Ultimate は値が1
	if _zirpower_def.has("type"):
		is_ultimate = (_zirpower_def["type"] == 1)
	
	# 名前ラベルを設定
	if _name_label and _zirpower_def.has("name"):
		_name_label.text = _zirpower_def["name"]
	
	# クールダウン表示
	if _cooldown_remaining > 0.0:
		disabled = true
		if _cooldown_overlay:
			_cooldown_overlay.visible = true
		if _cooldown_label:
			_cooldown_label.text = "%.1f" % _cooldown_remaining
	else:
		if _cooldown_overlay:
			_cooldown_overlay.visible = false
		
		# Ultimateの場合は意志ゲージをチェック
		if is_ultimate:
			# シーンツリーに追加されていない場合はスキップ
			if not is_inside_tree():
				disabled = true
			else:
				var gm = get_node_or_null("/root/GameManager")
				if gm and gm.has_method("is_will_full"):
					disabled = not gm.call("is_will_full")
				else:
					disabled = true
		else:
			disabled = false
	
	# Ultimateの場合はゲージを表示
	if _gauge_container:
		_gauge_container.visible = is_ultimate
		if is_ultimate:
			_update_gauge()


func _update_gauge() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.has_method("get_will_percent"):
		return
	
	var percent: int = gm.call("get_will_percent")
	
	if _gauge_fill:
		# ゲージの幅を％に応じて変更
		var max_width = _gauge_container.size.x - 4  # パディング考慮
		_gauge_fill.size.x = max_width * (percent / 100.0)
	
	if _gauge_label:
		_gauge_label.text = "%d%%" % percent


func _on_will_changed(_current_percent: int) -> void:
	# 小文字のキーを使用
	if _zirpower_def and _zirpower_def.has("type") and _zirpower_def["type"] == 1:  # Ultimate
		_update_gauge()
		_update_display()


func _on_will_full() -> void:
	# 小文字のキーを使用
	if _zirpower_def and _zirpower_def.has("type") and _zirpower_def["type"] == 1:  # Ultimate
		# 100%到達時のアニメーション
		_play_full_animation()


func _play_full_animation() -> void:
	# スケールのトゥイーンアニメーション
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	# 発光エフェクト（modulate）
	var glow_tween = create_tween()
	glow_tween.set_loops(3)
	glow_tween.tween_property(self, "modulate", Color(2.0, 2.0, 1.0, 1.0), 0.2)
	glow_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
