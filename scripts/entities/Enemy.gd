extends CharacterBody2D
class_name Enemy

@export var auto_collision_from_alpha: bool = false
@export var alpha_collision_threshold: float = 0.2
@export var alpha_collision_simplify: float = 6.0

static var _alpha_hull_cache: Dictionary = {}

@export var speed: float = 100.0
@export var damage: float = 10.0
@export var hp: float = 10.0 # Treated as Max HP
@export var damage_number_scene: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

@export var is_miniboss: bool = false
@export var is_boss: bool = false

var current_hp: float

var _is_dead: bool = false

var _target: Node2D = null

var _hp_bar: ProgressBar = null
var _damage_numbers: Node2D = null

var _knockback_velocity: Vector2 = Vector2.ZERO
@export var knockback_drag: float = 900.0

func _ready():
	if auto_collision_from_alpha:
		_build_collision_from_sprite_alpha()
	_ensure_overhead_ui()


func _build_collision_from_sprite_alpha() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var tex: Texture2D = sprite.texture
	if tex == null:
		return

	var tex_path: String = ""
	if "resource_path" in tex:
		tex_path = str(tex.resource_path)
	var cache_key: String = "%s|thr=%.3f|simp=%.3f" % [tex_path, alpha_collision_threshold, alpha_collision_simplify]
	var centered_hull: PackedVector2Array
	if _alpha_hull_cache.has(cache_key):
		centered_hull = _alpha_hull_cache[cache_key]
	else:
		var img: Image = tex.get_image()
		if img == null:
			return

		var bitmap: BitMap = BitMap.new()
		bitmap.create_from_image_alpha(img, alpha_collision_threshold)

		var rect: Rect2i = Rect2i(Vector2i.ZERO, img.get_size())
		var polys: Array[PackedVector2Array] = bitmap.opaque_to_polygons(rect, alpha_collision_simplify)
		if polys.is_empty():
			return

		var half: Vector2 = Vector2(img.get_size()) * 0.5
		var all_points: PackedVector2Array = PackedVector2Array()
		for poly in polys:
			if poly.size() < 3:
				continue
			for p in poly:
				all_points.append(p - half)

		if all_points.size() < 3:
			return

		centered_hull = Geometry2D.convex_hull(all_points)
		if centered_hull.size() < 3:
			return
		_alpha_hull_cache[cache_key] = centered_hull

	# Remove old generated shapes (if any)
	for child in get_children():
		if child is CollisionShape2D and (child as Node).name.begins_with("AutoCollision_"):
			child.queue_free()

	# Create one convex collider from the hull (much lighter than many triangles).
	var scale_mult: Vector2 = sprite.scale
	var scaled_hull: PackedVector2Array = PackedVector2Array()
	scaled_hull.resize(centered_hull.size())
	for i in range(centered_hull.size()):
		scaled_hull[i] = centered_hull[i] * scale_mult

	var shape := ConvexPolygonShape2D.new()
	shape.points = scaled_hull
	var cs := CollisionShape2D.new()
	cs.name = "AutoCollision_0"
	cs.shape = shape
	add_child(cs)

	# Disable fallback collider if we successfully generated polygons.
	var fallback: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if fallback:
		fallback.disabled = true

func spawn(pos: Vector2):
	global_position = pos
	current_hp = hp
	_is_dead = false
	_knockback_velocity = Vector2.ZERO
	_clear_damage_numbers()
	_update_hp_bar()
	
	if has_node("/root/GameManager"):
		_target = get_node("/root/GameManager").player_reference
	
	# Reset stats if modified (e.g. hp)
	
func _physics_process(delta):
	# Simple tracking AI
	if _target and is_instance_valid(_target):
		var direction = global_position.direction_to(_target.global_position)
		if _knockback_velocity != Vector2.ZERO:
			_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_drag * max(0.0, delta))
		velocity = (direction * speed) + _knockback_velocity
		move_and_slide()
	
	# Despawn if too far (optional, for safety)
	# For now, we assume Spawner handles cleanup or Player kills them.

func take_damage(amount: float):
	if amount <= 0.0:
		return
	if _is_dead:
		return

	current_hp -= amount
	_show_damage_number(amount)
	_update_hp_bar()
	if current_hp <= 0.0:
		die()


func apply_knockback(impulse: Vector2) -> void:
	_knockback_velocity += impulse

@export var xp_value: int = 1
@export var xp_gem_scene: PackedScene

@export var coin_scene: PackedScene = preload("res://scenes/objects/Coin.tscn")
@export var coin_drop_chance: float = 0.05 # 5% per kill
@export var boss_coin_drop_count: int = 10

@export var drop_item_scene: PackedScene = preload("res://scenes/objects/DropItem.tscn")

@export var item_drop_chance: float = 0.005 # 0.5% per kill

const _ITEM_WEIGHT_HEART: int = 45
const _ITEM_WEIGHT_SHIELD: int = 45
const _ITEM_WEIGHT_MAGNET: int = 10 # extremely low

# ... existing code ...

func die():
	if _is_dead:
		return
	_is_dead = true

	# 撃破時に敵が即座にプールへ戻ると、敵配下のダメージ数字も消えてしまう。
	# 先にダメージ数字を親へ移して表示を継続する。
	var keep_parent: Node = get_parent()
	while keep_parent != null and is_instance_valid(keep_parent) and not (keep_parent is CanvasItem):
		keep_parent = keep_parent.get_parent()
	if keep_parent != null and is_instance_valid(keep_parent) and _damage_numbers != null and is_instance_valid(_damage_numbers):
		for child in _damage_numbers.get_children():
			if child != null and is_instance_valid(child):
				child.reparent(keep_parent, true)

	# Drop loot deferred to avoid physics callback errors (add_child)
	var drop_parent: Node = get_parent()
	var drop_pos: Vector2 = global_position
	call_deferred("_drop_xp_at", drop_parent, drop_pos)
	call_deferred("_drop_coins_at", drop_parent, drop_pos)
	call_deferred("_drop_items_at", drop_parent, drop_pos)

	# Return to pool instead of queue_free
	if has_node("/root/PoolManager"):
		get_node("/root/PoolManager").return_instance(self, scene_file_path)
	else:
		queue_free()

func _drop_xp_at(parent_node: Node, pos: Vector2) -> void:
	if parent_node == null or not is_instance_valid(parent_node):
		return
	if xp_gem_scene and has_node("/root/PoolManager"):
		var gem = get_node("/root/PoolManager").get_instance(xp_gem_scene)
		if gem:
			if gem.get_parent() != parent_node:
				gem.reparent(parent_node)
			if gem.has_method("spawn"):
				gem.spawn(pos, xp_value)
			else:
				gem.global_position = pos

func _drop_coins_at(parent_node: Node, pos: Vector2) -> void:
	if parent_node == null or not is_instance_valid(parent_node):
		return
	if coin_scene == null:
		return

	# Boss drops many coins.
	if is_boss:
		var count := maxi(1, boss_coin_drop_count)
		for _i in range(count):
			_spawn_coin(parent_node, pos)
		return

	# Normal / miniboss: chance-based single coin.
	if randf() <= clampf(coin_drop_chance, 0.0, 1.0):
		_spawn_coin(parent_node, pos)
		return

func _spawn_coin(parent_node: Node, pos: Vector2) -> void:
	var coin = null
	if has_node("/root/PoolManager"):
		coin = get_node("/root/PoolManager").get_instance(coin_scene)
	else:
		coin = coin_scene.instantiate()
		if coin:
			parent_node.add_child(coin)

	if coin == null:
		return
	if coin.get_parent() != parent_node:
		coin.reparent(parent_node)

	# Small scatter so stacks are visible.
	var ang := randf() * TAU
	var rad := randf_range(0.0, 26.0)
	var p := pos + Vector2.RIGHT.rotated(ang) * rad
	if coin.has_method("spawn"):
		coin.spawn(p, 1)
	else:
		coin.global_position = p

func _drop_items_at(parent_node: Node, pos: Vector2) -> void:
	if parent_node == null or not is_instance_valid(parent_node):
		return
	if drop_item_scene == null:
		return

	# Boss: Magnet guaranteed + (optional) one extra item at normal chance.
	if is_boss:
		_spawn_item(parent_node, pos, "Magnet")
		if randf() <= clampf(item_drop_chance, 0.0, 1.0):
			_spawn_item(parent_node, pos, _roll_non_magnet_kind())
		return

	# Miniboss: guaranteed exactly 1 item.
	if is_miniboss:
		_spawn_item(parent_node, pos, _roll_item_kind())
		return

	# Normal enemy: at most 1 item.
	if randf() <= clampf(item_drop_chance, 0.0, 1.0):
		_spawn_item(parent_node, pos, _roll_item_kind())
		return


func _spawn_item(parent_node: Node, pos: Vector2, kind: String) -> void:
	var item = null
	if has_node("/root/PoolManager"):
		item = get_node("/root/PoolManager").get_instance(drop_item_scene)
	else:
		item = drop_item_scene.instantiate()
		if item:
			parent_node.add_child(item)

	if item == null:
		return
	if item.get_parent() != parent_node:
		item.reparent(parent_node)
	if item.has_method("spawn"):
		item.spawn(pos, kind)
	else:
		item.global_position = pos
		if "item_kind" in item:
			item.item_kind = kind

func _roll_item_kind() -> String:
	var total: int = _ITEM_WEIGHT_HEART + _ITEM_WEIGHT_SHIELD + _ITEM_WEIGHT_MAGNET
	var r: int = randi() % maxi(1, total)
	if r < _ITEM_WEIGHT_HEART:
		return "Heart"
	r -= _ITEM_WEIGHT_HEART
	if r < _ITEM_WEIGHT_SHIELD:
		return "Shield"
	return "Magnet"

func _roll_non_magnet_kind() -> String:
	# Used for boss bonus drop (magnet already guaranteed).
	return "Heart" if (randi() % 2 == 0) else "Shield"

func _ensure_overhead_ui() -> void:
	# Creates per-enemy UI (HP bar + damage numbers) if not present.
	var overhead_ui: Node2D = get_node_or_null("OverheadUI")
	if overhead_ui == null:
		overhead_ui = Node2D.new()
		overhead_ui.name = "OverheadUI"
		overhead_ui.position = Vector2(0, -38)
		add_child(overhead_ui)

	var hp_bar: ProgressBar = overhead_ui.get_node_or_null("HPBar")
	if hp_bar == null:
		hp_bar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.show_percentage = false
		hp_bar.custom_minimum_size = Vector2(46, 6)
		hp_bar.position = Vector2(-23, -3)
		overhead_ui.add_child(hp_bar)

	var damage_numbers: Node2D = overhead_ui.get_node_or_null("DamageNumbers")
	if damage_numbers == null:
		damage_numbers = Node2D.new()
		damage_numbers.name = "DamageNumbers"
		overhead_ui.add_child(damage_numbers)

	_hp_bar = hp_bar
	_damage_numbers = damage_numbers

func _update_hp_bar() -> void:
	if _hp_bar == null:
		_ensure_overhead_ui()
	if _hp_bar == null:
		return

	_hp_bar.max_value = max(1.0, hp)
	_hp_bar.value = clamp(current_hp, 0.0, hp)
	_hp_bar.visible = true

func _clear_damage_numbers() -> void:
	if _damage_numbers == null:
		_ensure_overhead_ui()
	if _damage_numbers == null:
		return

	for child in _damage_numbers.get_children():
		child.queue_free()

func _show_damage_number(amount: float) -> void:
	if damage_number_scene == null:
		return
	if _damage_numbers == null:
		_ensure_overhead_ui()
	if _damage_numbers == null:
		return

	var node := damage_number_scene.instantiate()
	if node == null:
		return

	# Randomize around enemy head a bit.
	if node is Control:
		(node as Control).position = Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 10.0))
	elif node is Node2D:
		(node as Node2D).position = Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 10.0))

	_damage_numbers.add_child(node)
	if node.has_method("setup"):
		node.call("setup", amount)
