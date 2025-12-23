extends Node2D
class_name TwinClawVFX

@export var lifetime: float = 0.10
@export var base_radius: float = 70.0
@export var visual_scale_mult: float = 0.88
@export var end_scale_mult: float = 1.10
@export var start_alpha: float = 1.0
@export var end_alpha: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D

var _tween: Tween


func spawn(pos: Vector2, direction: Vector2, r: float, life: float = 0.10) -> void:
	global_position = pos

	var dir := direction
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	rotation = dir.angle()

	lifetime = maxf(0.01, life)
	var scale_mult := 1.0
	if _sprite and _sprite.texture:
		var tex_size: Vector2 = _sprite.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			# Make the sprite's on-screen diameter match the hit diameter (2*r),
			# regardless of the source image pixel size.
			var desired_diameter := maxf(1.0, 2.0 * r)
			scale_mult = desired_diameter / maxf(1.0, minf(tex_size.x, tex_size.y))
		else:
			scale_mult = maxf(0.01, r / maxf(1.0, base_radius))
	else:
		scale_mult = maxf(0.01, r / maxf(1.0, base_radius))

	scale_mult *= maxf(0.01, visual_scale_mult)

	if _tween:
		_tween.kill()
		_tween = null

	_sprite.scale = Vector2.ONE * scale_mult
	_sprite.modulate = Color(1, 1, 1, start_alpha)

	_tween = create_tween()
	_tween.tween_property(_sprite, "modulate", Color(1, 1, 1, end_alpha), lifetime)
	_tween.parallel().tween_property(_sprite, "scale", Vector2.ONE * scale_mult * end_scale_mult, lifetime)
	_tween.finished.connect(queue_free)
