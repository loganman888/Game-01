# turret.gd - Working version with platform support
extends Node3D

# Export variables for turret configuration
@export var attack_range: float = 10.0
@export var attack_cooldown: float = .5
@export var damage: float = 50
@export var projectile_speed: float = 20.0
@export var rotation_speed: float = 5.0
@export var shop_type: String = "Basic Turret"
@export var shop_cost: int = 50

# Node references
@onready var rotation_base = $RotationBase
@onready var turret_model = $RotationBase/TurretModel
@onready var detection_area = $DetectionArea
@onready var pickup_area = $PickupDetectionArea
@onready var projectile_spawn = $RotationBase/ProjectileSpawn
@onready var shoot_sound = $ShootSound

# Preload the projectile scene
@onready var projectile_scene = preload("res://projectile.tscn")

# State variables
var current_target: Node3D = null
var can_attack: bool = true
var is_active: bool = true
var is_preview: bool = false
var original_materials: Dictionary = {}

# PLATFORM SUPPORT
var platform: Node = null

func _ready() -> void:
	add_to_group("turrets")
	
	# Setup combat detection area
	if detection_area:
		detection_area.collision_layer = 8   # Layer 4 (Turret)
		detection_area.collision_mask = 4    # Layer 3 (Enemy)
		
		var collision_shape = detection_area.get_node("CollisionShape3D")
		if collision_shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = attack_range
			collision_shape.shape = sphere_shape
	
	# Setup pickup detection area
	if pickup_area:
		pickup_area.collision_layer = 32  # Layer 6 (Pickup)
		pickup_area.collision_mask = 32   # Layer 6 (Pickup)
		pickup_area.monitoring = true
		pickup_area.monitorable = true
		
		var collision_shape = pickup_area.get_node("CollisionShape3D")
		if collision_shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = 2.0
			collision_shape.shape = sphere_shape
			collision_shape.disabled = false

func _process(delta: float) -> void:
	if !is_active or is_preview:
		return
	
	if !detection_area or !detection_area.monitoring:
		return
	
	if current_target and is_instance_valid(current_target):
		var distance = global_position.distance_to(current_target.global_position)
		if distance > attack_range:
			current_target = find_new_target()
	else:
		current_target = find_new_target()

	if current_target and is_instance_valid(current_target):
		var target_pos = current_target.global_position
		var direction = target_pos - global_position
		
		var target_rotation = Vector3.FORWARD.signed_angle_to(direction.normalized(), Vector3.UP)
		rotation_base.rotation.y = lerp_angle(rotation_base.rotation.y, target_rotation, delta * rotation_speed)
		
		if can_attack:
			shoot_at_target()

func set_preview(enable: bool) -> void:
	is_preview = enable
	if is_preview:
		# PLATFORM LOGIC: Free the platform spot if picking up the turret
		if platform:
			if platform.has_method("remove_turret"):
				platform.remove_turret()
			platform = null
		store_original_materials_recursive(self)
		set_active(false)
		visible = true
	else:
		restore_original_materials_recursive(self)
		clear_all_preview_materials()

func update_preview_material(material: StandardMaterial3D) -> void:
	if is_preview:
		apply_preview_material_recursive(self, material)
		visible = true

func apply_preview_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		if !original_materials.has(node):
			original_materials[node] = node.get_surface_override_material(0)
		node.material_override = material
		node.visible = true
	
	for child in node.get_children():
		apply_preview_material_recursive(child, material)

func store_original_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		original_materials[node] = node.get_surface_override_material(0)
		node.visible = true
	
	for child in node.get_children():
		store_original_materials_recursive(child)

func restore_original_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		if original_materials.has(node):
			node.material_override = original_materials[node]
		else:
			node.material_override = null
		node.visible = true
	
	for child in node.get_children():
		restore_original_materials_recursive(child)

func clear_all_preview_materials() -> void:
	original_materials.clear()

func set_active(active: bool) -> void:
	is_active = active
	visible = true
	set_process(active)
	set_physics_process(active)
	
	if !active:
		current_target = null
		can_attack = true
	
	if detection_area:
		detection_area.monitoring = active
		detection_area.monitorable = active
	
	if pickup_area:
		pickup_area.monitoring = true
		pickup_area.monitorable = true

func find_new_target() -> Node3D:
	if !is_active or !detection_area or !detection_area.monitoring:
		return null
	var bodies = detection_area.get_overlapping_bodies()
	return find_oldest_enemy(bodies)

# NEW FUNCTION: Find the oldest enemy (spawned first)
func find_oldest_enemy(bodies: Array) -> Node3D:
	var oldest_enemy: Node3D = null
	var oldest_spawn_time: float = INF
	
	for body in bodies:
		if is_instance_valid(body) and body.is_in_group("enemies") and body.is_inside_tree():
			# First try to use spawn_time if available
			if body.has_method("get_spawn_time") or body.get("spawn_time") != null:
				var spawn_time = body.get_spawn_time() if body.has_method("get_spawn_time") else body.spawn_time
				if spawn_time < oldest_spawn_time:
					oldest_spawn_time = spawn_time
					oldest_enemy = body
			# Fallback to using the object ID as a proxy for creation order
			elif oldest_enemy == null or body.get_instance_id() < oldest_enemy.get_instance_id():
				oldest_enemy = body
	
	# If no enemy found with the "oldest" method, fall back to closest
	if oldest_enemy == null:
		return find_closest_enemy(bodies)
				
	return oldest_enemy

# Keep the original function as a fallback
func find_closest_enemy(bodies: Array) -> Node3D:
	var closest_enemy: Node3D = null
	var closest_distance = attack_range

	for body in bodies:
		if is_instance_valid(body) and body.is_in_group("enemies") and body.is_inside_tree():
			var distance = global_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = body
				
	return closest_enemy

func shoot_at_target() -> void:
	if not current_target or !is_active or !projectile_spawn:
		return
	
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = projectile_spawn.global_position
	
	projectile.initialize(current_target, damage, projectile_speed, self)
	
	# Play shooting sound
	if shoot_sound:
		shoot_sound.play()
	
	can_attack = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _on_detection_area_body_entered(body: Node3D) -> void:
	if !is_active:
		return
	if body.is_in_group("enemies") and not current_target:
		current_target = find_oldest_enemy(detection_area.get_overlapping_bodies())

func _on_detection_area_body_exited(body: Node3D) -> void:
	if !is_active:
		return
	if body == current_target:
		current_target = find_oldest_enemy(detection_area.get_overlapping_bodies())
