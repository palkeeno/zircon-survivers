extends Label
class_name DamageNumber

@export var lifetime_sec: float = 0.6
@export var float_pixels: float = 28.0
@export var drift_pixels: float = 10.0

func setup(amount: float) -> void:
	text = str(int(round(amount)))
	_show()

func _ready() -> void:
	# In case instantiated without calling setup().
	if text == "":
		text = "0"
	_show()

func _show() -> void:
	z_index = 100
	modulate = Color(1, 1, 1, 1)
	
	var start_pos := position
	var target_pos := start_pos + Vector2(randf_range(-drift_pixels, drift_pixels), -float_pixels)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, lifetime_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), lifetime_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
