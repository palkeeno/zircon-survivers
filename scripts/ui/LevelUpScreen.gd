extends CanvasLayer

@onready var buttons_container = $Control/VBoxContainer/ButtonsContainer
@onready var title_label = $Control/VBoxContainer/Title

var upgrades = [
	{ "id": "might", "name": "Might Up", "desc": "Increases Damage by 10%", "icon": "res://icon.svg", "color": Color(1, 0, 0) },
	{ "id": "speed", "name": "Speed Up", "desc": "Increases Move Speed by 10%", "icon": "res://icon.svg", "color": Color(0, 1, 0) },
	{ "id": "haste", "name": "Haste", "desc": "Reduces Global Cooldown by 10%", "icon": "res://icon.svg", "color": Color(1, 1, 0) },
	{ "id": "magnet", "name": "Magnet", "desc": "Increases Pickup Range by 20%", "icon": "res://icon.svg", "color": Color(0, 0, 1) },
	{ "id": "heal", "name": "Heal", "desc": "Heals 30% HP", "icon": "res://icon.svg", "color": Color(1, 0, 1) }
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Must run while paused
	visible = false
	
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").level_up_choice_requested.connect(_on_level_up_requested)

func _on_level_up_requested():
	visible = true
	_generate_choices()

func _generate_choices():
	# Clean up old buttons
	for child in buttons_container.get_children():
		child.queue_free()
	
	# Shuffle and pick 3
	var pool = upgrades.duplicate()
	pool.shuffle()
	var choices = pool.slice(0, 3) # Take top 3
	
	for choice in choices:
		var btn = Button.new()
		btn.text = choice["name"] + "\n" + choice["desc"]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.modulate = choice["color"]
		btn.pressed.connect(func(): _apply_upgrade(choice))
		buttons_container.add_child(btn)

func _apply_upgrade(choice):
	print("Selected Upgrade: ", choice["name"])
	
	# Apply logic via GameManager or Player directly
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var player = gm.player_reference
		if player:
			match choice["id"]:
				"might":
					# Iterate weapons and buff? Or just global stat?
					# For MVP, simpler to just hack it or have Player stats manager.
					# Let's say Player has stat modifiers (not implemented yet). 
					# Direct modification for now if accessible.
					pass # Player might not have 'damage_mult' yet.
					
				"speed":
					player.speed *= 1.1
				
				"haste":
					# Iterate children weapons?
					for child in player.get_children():
						if "cooldown" in child:
							child.cooldown *= 0.9
				
				"magnet":
					player.pickup_range *= 1.2
					
				"heal":
					player.current_hp = min(player.max_hp, player.current_hp + player.max_hp * 0.3)
					player.emit_signal("hp_changed", player.current_hp, player.max_hp)

	# Resume Game
	visible = false
	get_tree().paused = false
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").resume_game()
