extends Area2D

# Simple goal object. Not part of item indicator targets.

@export var clear_reason: String = "stairs"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	# Player is a CharacterBody2D; we keep this flexible.
	if body.name != "Player" and not body.is_in_group("player"):
		return
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm and gm.has_method("trigger_game_clear"):
			gm.call("trigger_game_clear", clear_reason)
		elif gm and gm.has_method("trigger_game_over"):
			# Fallback (shouldn't happen after our GM update)
			gm.call("trigger_game_over")

func get_emoji() -> String:
	# Used by any potential UI in the future; currently NOT tracked by HUD indicators.
	return "⬇"
