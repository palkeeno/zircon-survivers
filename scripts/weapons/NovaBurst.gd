extends "res://scripts/weapons/Weapon.gd"
class_name NovaBurst

@export var zone_scene: PackedScene = preload("res://scenes/weapons/DamageZone.tscn")
@export var explosion_vfx_scene: PackedScene = preload("res://scenes/weapons/ExplosionVFX.tscn")
@export var nova_radius: float = 150.0
@export var bursts_per_fire: int = 1


func _try_shoot() -> bool:
	if not zone_scene:
		return false

	var bursts: int = maxi(1, bursts_per_fire)
	for _i in range(bursts):
		_spawn_explosion_vfx(global_position, nova_radius)
		_spawn_burst(global_position, nova_radius, damage * owner_damage_mult)

	return true


func _spawn_explosion_vfx(pos: Vector2, r: float) -> void:
	if not explosion_vfx_scene:
		return
	var fx = explosion_vfx_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx.has_method("spawn"):
		fx.spawn(pos, r, 0.20)


func _spawn_burst(pos: Vector2, r: float, dmg: float) -> void:
	var zone = zone_scene.instantiate()
	get_tree().current_scene.add_child(zone)
	if zone.has_method("spawn"):
		zone.spawn(pos, r, dmg)
	else:
		zone.global_position = pos
