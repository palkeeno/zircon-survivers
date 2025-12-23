extends Area2D
class_name DropItem

@export_enum("Heart", "Magnet", "Shield") var item_kind: String = "Heart"

@onready var _icon_label: Label = $Icon

var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _is_despawning: bool = false

func _ready() -> void:
	add_to_group("loot")
	add_to_group("drop_items")
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
	_update_visuals()

func spawn(pos: Vector2, kind: String) -> void:
	global_position = pos
	item_kind = kind
	_is_despawning = false
	monitoring = true
	monitorable = true
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs:
		cs.disabled = false
	_update_visuals()

func get_emoji() -> String:
	match item_kind:
		"Heart":
			return "❤"
		"Magnet":
			return "🧲"
		"Shield":
			return "🛡"
		_:
			return "?"

func collect(target_node: Node2D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		_despawn()
		return

	match item_kind:
		"Heart":
			var max_hp := 0.0
			if "max_hp" in target_node:
				max_hp = float(target_node.max_hp)
			var heal_amount := max_hp * 0.30
			if target_node.has_method("heal"):
				target_node.call("heal", heal_amount)
		"Magnet":
			# Collect all XP gems currently on the field.
			var gems := get_tree().get_nodes_in_group("xp")
			for g in gems:
				if g == null or not is_instance_valid(g):
					continue
				if g.has_method("collect"):
					g.call("collect", target_node)
		"Shield":
			if target_node.has_method("add_shield_charges"):
				target_node.call("add_shield_charges", 1)
			elif "shield_charges" in target_node:
				target_node.shield_charges = int(target_node.shield_charges) + 1
			else:
				# If Player doesn't support shields, do nothing.
				pass

	_despawn()

func _update_visuals() -> void:
	if _icon_label == null:
		return
	_icon_label.text = get_emoji()

func _despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = true

	# Prevent repeat pickup while returning to pool.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs:
		cs.set_deferred("disabled", true)
	call_deferred("_finish_despawn")


func _finish_despawn() -> void:
	if has_node("/root/PoolManager"):
		get_node("/root/PoolManager").return_instance(self, scene_file_path)
	else:
		queue_free()
