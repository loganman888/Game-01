extends Node3D

# Export variables for turret configuration
@export var effect_range: float = 10.0
@export var slow_factor: float = 0.5  # How much to slow enemies (0.5 = 50% slower)
@export var range_indicator_color: Color = Color(0.0, 0.7, 1.0, 0.3)  # Blue, semi-transparent
@export var shop_type: String = "Slow Turret"
@export var shop_cost: int = 100

# Node references
@onready var activation_sound = $ActivationSound
@onready var effect_sound = $EffectSound
@onready var wind_down_sound = $WindDownSound
@onready var rotation_base = $RotationBase
@onready var turret_model = $RotationBase/TurretModel
@onready var detection_area = $DetectionArea
@onready var pickup_area = $PickupDetectionArea

# State variables
var is_active: bool = true
var is_preview: bool = false
var original_materials: Dictionary = {}
var affected_enemies: Dictionary = {}  # Keep track of affected enemies and their original speeds
var range_indicator: MeshInstance3D
var enemies_in_range: int = 0
var effect_sound_playing: bool = false
var is_winding_down: bool = false

# Visual effect variables
var pulse_time: float = 0.0
var pulse_speed: float = 3.0
var pulse_strength: float = 0.2

# --- PLATFORM SUPPORT ---
var platform: Node = null # Reference to the TurretPlatform the turret is placed on

func _ready() -> void:
	add_to_group("turrets")
	
	# Setup effect detection area
	if detection_area:
		detection_area.collision_layer = 8   # Layer 4 (Turret)
		detection_area.collision_mask = 4    # Layer 3 (Enemy)
		
		var collision_shape = detection_area.get_node("CollisionShape3D")
		if collision_shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = effect_range
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
	
	# Create range indicator
	create_range_indicator()

func create_range_indicator() -> void:
	range_indicator = MeshInstance3D.new()
	add_child(range_indicator)
	range_indicator.name = "RangeIndicator"
	setup_range_indicator()
	range_indicator.visible = false

func setup_range_indicator() -> void:
	# Create a sphere mesh for the range indicator
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = effect_range
	sphere_mesh.height = effect_range * 2  # Sphere height should be double the radius
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16
	range_indicator.mesh = sphere_mesh
	
	# Create and set up the material
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = range_indicator_color
	material.emission_enabled = true
	material.emission = range_indicator_color
	material.emission_energy_multiplier = 1.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	range_indicator.material_override = material
	
	# Center the range indicator on the turret
	range_indicator.position = Vector3.ZERO

func _process(delta: float) -> void:
	if !is_active or is_preview:
		# Stop sounds if they're playing and we're not active
		if effect_sound_playing:
			effect_sound.stop()
			effect_sound_playing = false
		if wind_down_sound and wind_down_sound.playing:
			wind_down_sound.stop()
			is_winding_down = false
		
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
	
	# Handle effect sound
	if enemies_in_range > 0 and !effect_sound_playing and effect_sound:
		if is_winding_down:
			# If we're winding down, wait for it to finish
			await wind_down_sound.finished
			is_winding_down = false
		effect_sound.play()
		effect_sound_playing = true
	
	# Update affected enemies
	update_affected_enemies()

func update_affected_enemies() -> void:
	if !detection_area or !detection_area.monitoring:
		return
		
	var bodies = detection_area.get_overlapping_bodies()
	
	# Remove slow effect from enemies that are no longer in range or have been freed
	var enemies_to_remove = []
	for enemy in affected_enemies.keys():
		if !is_instance_valid(enemy) or !bodies.has(enemy):
			enemies_to_remove.append(enemy)
	
	# Remove the enemies outside the loop to avoid modification during iteration
	for enemy in enemies_to_remove:
		if is_instance_valid(enemy):
			remove_slow_effect(enemy)
		affected_enemies.erase(enemy)
	
	# Apply slow effect to enemies in range
	for body in bodies:
		if is_instance_valid(body) and body.is_in_group("enemies") and !affected_enemies.has(body):
			apply_slow_effect(body)

func apply_slow_effect(enemy: Node) -> void:
	if is_instance_valid(enemy) and enemy.has_method("get_speed"):
		var original_speed = enemy.get_speed()
		affected_enemies[enemy] = original_speed
		enemy.set_speed(original_speed * (1.0 - slow_factor))

func remove_slow_effect(enemy: Node) -> void:
	if is_instance_valid(enemy) and affected_enemies.has(enemy):
		if enemy.has_method("set_speed"):
			enemy.set_speed(affected_enemies[enemy])  # Restore original speed
		affected_enemies.erase(enemy)

func _on_detection_area_body_entered(body: Node3D) -> void:
	if !is_active or !body.is_in_group("enemies"):
		return
	
	enemies_in_range += 1
	
	# Play activation sound when first enemy enters range
	if enemies_in_range == 1 and activation_sound:
		activation_sound.play()

func _on_detection_area_body_exited(body: Node3D) -> void:
	if !is_active or !body.is_in_group("enemies"):
		return
	
	enemies_in_range = max(0, enemies_in_range - 1)
	
	# When the last enemy exits, play wind down sound
	if enemies_in_range == 0:
		if effect_sound:
			effect_sound.stop()
			effect_sound_playing = false
		
		if wind_down_sound and !is_winding_down:
			is_winding_down = true
			wind_down_sound.play()
			# Wait for wind down sound to finish
			await wind_down_sound.finished
			is_winding_down = false

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
	
	if !active:
		# Stop all sounds when turret becomes inactive
		if effect_sound_playing and effect_sound:
			effect_sound.stop()
			effect_sound_playing = false
		if wind_down_sound and wind_down_sound.playing:
			wind_down_sound.stop()
		is_winding_down = false
		enemies_in_range = 0
		
		# Remove slow effect from all affected enemies when deactivated
		var enemies_to_remove = affected_enemies.keys()
		for enemy in enemies_to_remove:
			if is_instance_valid(enemy):
				remove_slow_effect(enemy)
		affected_enemies.clear()
	
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
