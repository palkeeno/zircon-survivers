extends CanvasLayer

@onready var hp_bar = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/HPBar
@onready var hp_label = $Control/MarginContainer/VBoxContainer/TopRow/HPContainer/HPLabel
@onready var xp_bar = $Control/MarginContainer/VBoxContainer/XPBar
@onready var level_label = $Control/MarginContainer/VBoxContainer/XPBar/LevelLabel
@onready var loadout_label = $Control/MarginContainer/VBoxContainer/LoadoutLabel

var _loadout_manager: Node = null

func _ready():
	# Connect to Player signals if available via GameManager
	# Or GameManager could broadcast them.
	# But strictly, Player emits them.
	
	# Wait for Player to register? Or check GameManager.
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.player_reference:
			_connect_player(gm.player_reference)
		
		# Also watch for future registrations (not implemented in GM yet, but we can poll or use a signal if we added one)
		# For now, let's assume Main creates HUD after Player, or we poll in process once.
		
	set_process(true)

var _player_connected = false
func _process(_delta):
	if not _player_connected and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.player_reference:
			_connect_player(gm.player_reference)
			set_process(false)

func _connect_player(player):
	_player_connected = true
	player.hp_changed.connect(_on_hp_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.level_up.connect(_on_level_up)
	
	if player.has_node("LoadoutManager"):
		_loadout_manager = player.get_node("LoadoutManager")
		if _loadout_manager and _loadout_manager.has_signal("LoadoutChanged"):
			# Avoid double-connect if HUD reconnects.
			if not _loadout_manager.is_connected("LoadoutChanged", Callable(self, "_on_loadout_changed")):
				_loadout_manager.connect("LoadoutChanged", Callable(self, "_on_loadout_changed"))
			_on_loadout_changed()
	
	# Initial update
	_on_hp_changed(player.current_hp, player.max_hp)
	_on_xp_changed(player.experience, player.next_level_xp)
	_on_level_up(player.level)

func _on_hp_changed(current, max_val):
	hp_bar.max_value = max_val
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_xp_changed(current, next):
	xp_bar.max_value = next
	xp_bar.value = current

func _on_level_up(level):
	level_label.text = "LV %d" % level


func _on_loadout_changed():
	if not _loadout_manager:
		return
	var summary = _loadout_manager.call("GetLoadoutSummary")
	if summary == null or summary.size() < 2:
		return
	var weapons = summary[0]
	var specials = summary[1]

	var w_slots = []
	for i in range(4):
		w_slots.append("-")
	for i in range(min(weapons.size(), 4)):
		var w = weapons[i]
		w_slots[i] = "%s Lv%d" % [str(w.get("name", "")), int(w.get("level", 1))]

	var s_slots = []
	for i in range(4):
		s_slots.append("-")
	for i in range(min(specials.size(), 4)):
		var s = specials[i]
		s_slots[i] = "%s Lv%d" % [str(s.get("name", "")), int(s.get("level", 1))]

	loadout_label.text = "W: %s\nS: %s" % [" | ".join(w_slots), " | ".join(s_slots)]
