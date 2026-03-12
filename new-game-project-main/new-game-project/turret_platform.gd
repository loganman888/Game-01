# TurretPlatform.gd
extends Area3D

@export var snap_point: Vector3 = Vector3.ZERO
@export var unlock_cost: int = 100

var placed_turret: Node3D = null
var is_locked: bool = true

func _ready():
	add_to_group("turret_platforms")
	
	# Set up collision layers and masks
	collision_layer = 1  # Set to layer 1 (or whatever layer you want)
	collision_mask = 1   # Set to mask 1 (or whatever mask you want)
	
	
	
	# Verify collision shape
	var shape = get_node_or_null("CollisionShape3D")
	if shape:
		print("CollisionShape3D found on platform: ", name)
		# Debug visualization
		if Engine.is_editor_hint():
			shape.debug_shape_custom_color = Color(1, 0, 0, 0.5)
			shape.debug_shape_enabled = true
	else:
		print("WARNING: No CollisionShape3D found on platform: ", name)

func can_place() -> bool:
	return placed_turret == null and not is_locked

func place_turret(turret: Node3D) -> void:
	placed_turret = turret

func remove_turret() -> void:
	placed_turret = null

func unlock_platform() -> void:
	is_locked = false
	print("Platform unlocked: ", name)
