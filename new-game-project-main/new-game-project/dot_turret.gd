extends Node3D

# Export variables for turret configuration
@export var effect_range: float = 10.0
@export var damage_per_second: float = 20.0  # Amount of damage per second to apply
@export var range_indicator_color: Color = Color(1.0, 0.2, 0.0, 0.3)  # Reddish, semi-transparent
@export var shop_type: String = "DOT Turret"
@export var shop_cost: int = 120

# --- NEW: DURABILITY VARIABLES ---
@export var max_durability: float = 100.0
@export var durability_loss_per_sec: float = 5.0  # Loses 5 HP per second while actively cooking enemies
var current_durability: float
var is_broken: bool = false
# ---------------------------------

# Node references
@onready var activation_sound = $ActivationSound
@onready var effect_sound = $EffectSound
@onready var wind_down_sound = $WindDownSound
@onready var rotation_base = $RotationBase
@onready var turret_model = $RotationBase/TurretModel
@onready var detection_area = $DetectionArea
@onready var pickup_area = $PickupDetectionArea

# PLATFORM SUPPORT
var platform: Node = null

# State variables
var is_active: bool = true
var is_preview: bool = false
var original_materials: Dictionary = {}
var range_indicator: MeshInstance3D
var enemies_in_range: int = 0
var effect_sound_playing: bool = false
var is_winding_down: bool = false

# Visual effect variables
var pulse_time: float = 0.0
var pulse_speed: float = 3.0
var pulse_strength: float = 0.2

func _ready() -> void:
	add_to_group("turrets")
	current_durability = max_durability # Start at full health
	
	# Setup detection area
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
	
	# Create range indicator
	create_range_indicator()

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

func _process(delta: float) -> void:
	if !is_active or is_preview or is_broken:
		# Stop sounds if they're playing and we're not active or broken
		if effect_sound_playing:
			if effect_sound: effect_sound.stop()
			effect_sound_playing = false
		if wind_down_sound and wind_down_sound.playing:
			wind_down_sound.stop()
			is_winding_down = false
		
		# Pulse effect for range indicator during preview
		if range_indicator and range_indicator.visible:
			pulse_time += delta * pulse_speed
			var pulse = (sin(pulse_time) * pulse_strength) + 1.0
			range_indicator.scale = Vector3.ONE * pulse
			
			var material = range_indicator.material_override as StandardMaterial3D
			if material:
				var alpha = range_indicator_color.a * (0.8 + (sin(pulse_time) * 0.2))
				material.albedo_color.a = alpha
		return
	
	# --- NEW: Drain health slowly while actively doing work ---
	if enemies_in_range > 0:
		apply_decay(durability_loss_per_sec * delta)
	
	# Handle effect sound based on enemies in range
	if enemies_in_range > 0:
		if !effect_sound_playing and effect_sound:
			if is_winding_down:
				await wind_down_sound.finished
				is_winding_down = false
			effect_sound.play()
			effect_sound_playing = true
	else:
		if effect_sound_playing and effect_sound:
			effect_sound.stop()
			effect_sound_playing = false
	
	# Deal DoT to enemies in detection area
	apply_damage_to_enemies(delta)

# --- DECAY AND REPAIR LOGIC ---
func apply_decay(amount: float) -> void:
	if is_preview or is_broken: return
	
	current_durability -= amount
	if current_durability <= 0:
		current_durability = 0
		break_turret()

func break_turret() -> void:
	is_broken = true
	enemies_in_range = 0
	if detection_area:
		detection_area.monitoring = false 
		
func repair_step(amount: float) -> void:
	if current_durability >= max_durability: 
		return
		
	current_durability += amount
	
	if is_broken and current_durability > 0:
		is_broken = false
		if detection_area and is_active:
			detection_area.monitoring = true
			detection_area.monitorable = true
			
	if current_durability > max_durability:
		current_durability = max_durability
# -----------------------------------

func apply_damage_to_enemies(delta: float) -> void:
	if !detection_area or !detection_area.monitoring:
		return
		
	var bodies = detection_area.get_overlapping_bodies()
	for body in bodies:
		if is_instance_valid(body) and body.is_in_group("enemies"):
			var step_damage = damage_per_second * delta
			
			if body.has_node("HealthComponent"):
				var hc = body.get_node("HealthComponent")
				if hc.has_method("damage"):
					var dot_attack = Attack.new(step_damage, self)
					hc.damage(dot_attack)
			elif body.has_method("apply_damage"):
				body.apply_damage(step_damage)

func _on_detection_area_body_entered(body: Node3D) -> void:
	if !is_active or is_broken or !body.is_in_group("enemies"):
		return
	
	enemies_in_range += 1
	
	if enemies_in_range == 1 and activation_sound:
		activation_sound.play()

func _on_detection_area_body_exited(body: Node3D) -> void:
	if !is_active or is_broken or !body.is_in_group("enemies"):
		return
	
	enemies_in_range = max(0, enemies_in_range - 1)
	
	if enemies_in_range == 0:
		if effect_sound:
			effect_sound.stop()
			effect_sound_playing = false
		
		if wind_down_sound and !is_winding_down:
			is_winding_down = true
			wind_down_sound.play()

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
		if effect_sound_playing and effect_sound:
			effect_sound.stop()
			effect_sound_playing = false
		if wind_down_sound and wind_down_sound.playing:
			wind_down_sound.stop()
		is_winding_down = false
		enemies_in_range = 0
	
	if detection_area:
		detection_area.monitoring = active and not is_broken
		detection_area.monitorable = active and not is_broken
	
	if pickup_area:
		pickup_area.monitoring = active
		pickup_area.monitorable = active

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
