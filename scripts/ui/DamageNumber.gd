extends Label
class_name DamageNumber

@export var hold_sec: float = 0.25
@export var fade_sec: float = 0.35
@export var float_pixels: float = 10.0
@export var drift_pixels: float = 0.0

@export var font_size: int = 28
@export var outline_size: int = 6

func setup(amount: float) -> void:
	text = str(int(round(amount)))
	_show()

func _ready() -> void:
	# In case instantiated without calling setup().
	if text == "":
		text = "0"
	_show()

func _show() -> void:
	# 親が無効化/移動しても、表示した座標に留まるようにする
	var start_global := global_position
	top_level = true
	global_position = start_global

	z_index = 100
	modulate = Color(1, 0.2, 0.2, 1)
	add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	add_theme_font_size_override("font_size", font_size)

	# 太字（プロジェクト内の既存フォント資産を使用）
	var bold_font := load("res://addons/gut/fonts/AnonymousPro-Bold.ttf")
	if bold_font:
		add_theme_font_override("font", bold_font)

	# 太めの黒縁取りで視認性アップ
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_theme_constant_override("outline_size", outline_size)
	
	var start_pos := position
	var target_pos := start_pos + Vector2(randf_range(-drift_pixels, drift_pixels), -float_pixels)
	
	var tween := create_tween()
	# まずその場に少し留めてから、フェード＋軽く上へ
	if hold_sec > 0.0:
		tween.tween_interval(hold_sec)
	var t := maxf(0.05, fade_sec)
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 0.2, 0.2, 0), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
