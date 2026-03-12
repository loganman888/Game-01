extends Node3D

# Export variables for turret configuration
@export var effect_range: float = 5.0  # Radius of damage area
@export var damage_amount: float = 50.0  # Single instance damage
@export var range_indicator_color: Color = Color(0.2, 0.8, 1.0, 0.3)  # Bluish, semi-transparent
@export var shop_type: String = "ManualTurret"
@export var display_name: String = "Manual Turret"
@export var shop_cost: int = 150
@export var interaction_distance: float = 3.0
@export var targeting_camera_height: float = 30.0
@export var targeting_camera_tilt: float = -90.0  # Straight down view
@export var damage_delay: float = 0.5  # Time in seconds before damage is applied

# Node references
@onready var rotation_base = $RotationBase
@onready var turret_model = $RotationBase/TurretModel
@onready var detection_area = $DetectionArea
@onready var pickup_area = $PickupDetectionArea
@onready var fire_sound: AudioStreamPlayer3D = $FireSound      # Sound at turret location
@onready var impact_sound: AudioStreamPlayer3D = $ImpactSound  # Sound to be played at target

# PLATFORM SUPPORT
var platform: Node = null

# State variables
var is_active: bool = true
var is_preview: bool = false
var is_targeting_mode: bool = false
var can_interact: bool = true
var original_materials: Dictionary = {}
var range_indicator: MeshInstance3D
var targeting_indicator: MeshInstance3D
var _targeting_indicator_created := false
var player: Node

# Visual effect variables
var pulse_time: float = 0.0
var pulse_speed: float = 3.0
var pulse_strength: float = 0.2

func _ready() -> void:
	add_to_group("turrets")
	player = get_tree().get_first_node_in_group("player")
	
	# Setup detection area (for interaction range)
	if detection_area:
		detection_area.collision_layer = 8
		detection_area.collision_mask = 4
		var collision_shape = detection_area.get_node("CollisionShape3D")
		if collision_shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = effect_range
			collision_shape.shape = sphere_shape
	
	# Setup pickup detection area
	if pickup_area:
		pickup_area.collision_layer = 32
		pickup_area.collision_mask = 32
		pickup_area.monitoring = true
		pickup_area.monitorable = true
		var collision_shape = pickup_area.get_node("CollisionShape3D")
		if collision_shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = 2.0
			collision_shape.shape = sphere_shape
			collision_shape.disabled = false
	
	# Create range indicator only
	create_range_indicator()

func _input(event: InputEvent) -> void:
	if not is_active or is_preview or not can_interact:
		return
		
	if event.is_action_pressed("use"):
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
			
		# Get the camera and check if player is looking at the turret
		var camera = player.get_node_or_null("Head/Camera3D")
		if not camera:
			print("Camera not found")
			return
			
		# Setup raycast from camera
		var space_state = get_world_3d().direct_space_state
		var start_pos = camera.global_position
		var end_pos = start_pos - camera.global_transform.basis.z * interaction_distance
		
		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		query.exclude = [player]
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		
		if result:
			# Check if we hit this turret or its collision area
			var hit_node = result.collider
			while hit_node:
				if hit_node == self or hit_node == detection_area:
					if not is_targeting_mode and global_position.distance_to(player.global_position) <= interaction_distance:
						enter_targeting_mode()
					break
				hit_node = hit_node.get_parent()
	
	# Only handle mouse clicks when in targeting mode
	elif is_targeting_mode:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				# Confirm target location and apply damage
				apply_damage_at_preview()
				exit_targeting_mode()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				# Cancel targeting mode
				exit_targeting_mode()
		# Keep escape as an additional way to cancel
		elif event.is_action_pressed("ui_cancel"):
			exit_targeting_mode()

func create_range_indicator() -> void:
	range_indicator = MeshInstance3D.new()
	add_child(range_indicator)
	range_indicator.name = "RangeIndicator"
	setup_range_indicator()
	range_indicator.visible = false

func setup_range_indicator() -> void:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = effect_range
	sphere_mesh.height = effect_range * 2
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16
	range_indicator.mesh = sphere_mesh
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = range_indicator_color
	material.emission_enabled = true
	material.emission = range_indicator_color
	material.emission_energy_multiplier = 1.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	range_indicator.material_override = material
	range_indicator.position = Vector3.ZERO

func ensure_targeting_indicator() -> void:
	if not _targeting_indicator_created:
		create_targeting_indicator()
		_targeting_indicator_created = true

func create_targeting_indicator() -> void:
	targeting_indicator = MeshInstance3D.new()
	add_child(targeting_indicator)
	targeting_indicator.name = "TargetingIndicator"
	
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = effect_range
	cylinder.bottom_radius = effect_range
	cylinder.height = 0.1
	targeting_indicator.mesh = cylinder
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.0, 0.0, 0.5)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.0, 0.0)
	targeting_indicator.material_override = material
	targeting_indicator.visible = false

func _process(delta: float) -> void:
	if !is_active or is_preview:
		# Pulse effect for range indicator during preview
		if range_indicator and range_indicator.visible:
			pulse_time += delta * pulse_speed
			var pulse = (sin(pulse_time) * pulse_strength) + 1.0
			range_indicator.scale = Vector3.ONE * pulse
			
			# Update transparency based on pulse
			var material = range_indicator.material_override as StandardMaterial3D
			if material:
				var alpha = range_indicator_color.a * (0.8 + (sin(pulse_time) * 0.2))
				material.albedo_color.a = alpha
		return
	
	if is_targeting_mode:
		update_targeting_position()

func update_targeting_position() -> void:
	# Get the camera directly from the scene tree since it's temporarily parented to root
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_length = 1000
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		targeting_indicator.global_position = result.position
		targeting_indicator.global_position.y += 0.05

func enter_targeting_mode() -> void:
	ensure_targeting_indicator()
	is_targeting_mode = true
	targeting_indicator.visible = true
	
	# Use player's camera system with turret position
	if player and player.has_method("enter_targeting_mode"):
		var camera_position = global_position + Vector3(0, targeting_camera_height, 0)
		player.enter_targeting_mode(targeting_camera_height, targeting_camera_tilt, camera_position)

func exit_targeting_mode() -> void:
	is_targeting_mode = false
	if targeting_indicator:
		targeting_indicator.visible = false
	
	# Return player's camera to normal
	if player and player.has_method("exit_targeting_mode"):
		player.exit_targeting_mode()

func play_fire_sound() -> void:
	if fire_sound:
		fire_sound.play()

func play_impact_sound_at_location(position: Vector3) -> void:
	# Create temporary audio player at target location
	var temp_audio = AudioStreamPlayer3D.new()
	get_tree().get_root().add_child(temp_audio)
	
	# Copy properties from the impact audio player
	if impact_sound:
		temp_audio.stream = impact_sound.stream
		temp_audio.volume_db = impact_sound.volume_db
		temp_audio.max_distance = impact_sound.max_distance
		temp_audio.attenuation_model = impact_sound.attenuation_model
	
	# Position the audio player
	temp_audio.global_position = position
	
	# Play the sound
	temp_audio.play()
	
	# Wait for sound to finish and then remove
	await temp_audio.finished
	temp_audio.queue_free()

func apply_damage_at_preview() -> void:
	var damage_position = targeting_indicator.global_position
	
	# Play fire sound from turret location
	play_fire_sound()
	
	# Wait for the delay before impact
	await get_tree().create_timer(damage_delay).timeout
	
	# Play impact sound at target location
	play_impact_sound_at_location(damage_position)
	
	# Get all enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		# Create positions that ignore Y axis for distance calculation
		var flat_damage_pos = Vector2(damage_position.x, damage_position.z)
		var flat_enemy_pos = Vector2(enemy.global_position.x, enemy.global_position.z)
		
		# Calculate distance ignoring height (y-axis)
		var distance = flat_damage_pos.distance_to(flat_enemy_pos)
		
		if distance <= effect_range:
			if enemy.has_method("apply_damage"):
				enemy.apply_damage(damage_amount)
	
	# Start cooldown
	start_cooldown()

func start_cooldown() -> void:
	can_interact = false
	await get_tree().create_timer(2.0).timeout
	can_interact = true

# PLATFORM LOGIC
func set_preview(enable: bool) -> void:
	is_preview = enable
	if is_preview:
		if platform:
			if platform.has_method("remove_turret"):
				platform.remove_turret()
			platform = null
		store_original_materials_recursive(self)
		set_active(false)
		visible = true
		if range_indicator:
			range_indicator.visible = true
	else:
		restore_original_materials_recursive(self)
		clear_all_preview_materials()
		if range_indicator:
			range_indicator.visible = false

func set_active(active: bool) -> void:
	is_active = active
	visible = true
	set_process(active)
	set_physics_process(active)
	
	if detection_area:
		detection_area.monitoring = active
		detection_area.monitorable = active
	
	if pickup_area:
		pickup_area.monitoring = true
		pickup_area.monitorable = true

func update_preview_material(material: StandardMaterial3D) -> void:
	if is_preview:
		apply_preview_material_recursive(self, material)
		visible = true

func apply_preview_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D and node != range_indicator:
		if !original_materials.has(node):
			original_materials[node] = node.get_surface_override_material(0)
		node.material_override = material
		node.visible = true
	
	for child in node.get_children():
		apply_preview_material_recursive(child, material)

func store_original_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D and node != range_indicator:
		original_materials[node] = node.get_surface_override_material(0)
		node.visible = true
	
	for child in node.get_children():
		store_original_materials_recursive(child)

func restore_original_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D and node != range_indicator:
		if original_materials.has(node):
			node.material_override = original_materials[node]
		else:
			node.material_override = null
		node.visible = true
	
	for child in node.get_children():
		restore_original_materials_recursive(child)

func clear_all_preview_materials() -> void:
	original_materials.clear()
