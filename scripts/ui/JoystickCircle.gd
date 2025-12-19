extends Control
class_name JoystickCircle

@export var fill_color: Color = Color(0, 0, 0, 0.25)

func _ready() -> void:
	queue_redraw()
	resized.connect(queue_redraw)

func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	if r <= 0.0:
		return
	var c := size * 0.5
	draw_circle(c, r, fill_color)
