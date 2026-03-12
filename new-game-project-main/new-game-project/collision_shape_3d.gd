# TurretPlatform.gd
extends StaticBody3D # or Area3D, but StaticBody3D is typical for a solid platform

@export var snap_point: Vector3 = Vector3.ZERO # Adjust this in the editor as needed

var placed_turret: Node3D = null

func can_place() -> bool:
	return placed_turret == null

func place_turret(turret: Node3D) -> void:
	placed_turret = turret

func remove_turret() -> void:
	placed_turret = null

func _ready():
	add_to_group("turret_platforms")
