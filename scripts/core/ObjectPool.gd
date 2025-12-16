extends Node
class_name ObjectPool

# Dictionary to store pools: { "scene_path": [available_nodes] }
var pools: Dictionary = {}

# Parent node to organize pooled objects in the scene tree
var pool_container: Node

func _ready():
	pool_container = Node.new()
	pool_container.name = "PoolContainer"
	add_child(pool_container)

## Pre-instantiates a number of objects for a given scene
func create_pool(scene: PackedScene, initial_size: int):
	var scene_path = scene.resource_path
	if not pools.has(scene_path):
		pools[scene_path] = []
	
	for i in range(initial_size):
		var instance = scene.instantiate()
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		instance.visible = false
		pool_container.add_child(instance)
		pools[scene_path].append(instance)

## Gets an instance from the pool
func get_instance(scene: PackedScene) -> Node:
	var scene_path = scene.resource_path
	if not pools.has(scene_path):
		pools[scene_path] = []
	
	var instance: Node
	if pools[scene_path].is_empty():
		# Pool empty, create new one (expand pool)
		instance = scene.instantiate()
		pool_container.add_child(instance)
	else:
		instance = pools[scene_path].pop_back()
	
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.visible = true
	return instance

## Returns an instance to the pool
func return_instance(instance: Node, scene_path: String):
	if not instance:
		return
		
	# Defer the disabling logic to avoid physics callback errors
	call_deferred("_disable_instance", instance, scene_path)

func _disable_instance(instance: Node, scene_path: String):
	if not instance:
		return
		
	# Reset state
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.visible = false
	
	# Reparent to pool container if it was moved elsewhere
	if instance.get_parent() != pool_container:
		instance.get_parent().remove_child(instance)
		pool_container.add_child(instance)
	
	if not pools.has(scene_path):
		pools[scene_path] = []
	
	pools[scene_path].append(instance)
