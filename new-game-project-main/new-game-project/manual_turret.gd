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

# --- NEW: DURABILITY VARIABLES ---
@export var max_durability: float = 100.0
@export var durability_loss_per_shot: float = 10.0  # 10 massive strikes before it breaks
var current_durability: float
var is_broken: bool = false
# ---------------------------------

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
	current_durability = max_durability # Start at full health
	
	if detection_area:
		detection_area.collision_layer = 8
		detection_area.collision_mask = 4
		var collision_shape = detection_area.get_node("CollisionShape3D")
		if collision_shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = effect_range
			collision_shape.shape = sphere_shape
	
	if pickup_area:
		pickup_area.collision_layer = 32
		pickup_area.collision_mask = 32
		pickup_area.monitoring = true
		pickup_area.monitorable = true
	
	create_range_indicator()

# --- THE NEW BRIDGE FROM THE PLAYER SCRIPT ---
func start_manual_control() -> void:
	# Prevent entry if the turret is broken!
	if is_active and not is_preview and can_interact and not is_targeting_mode and not is_broken:
		enter_targeting_mode()

func _input(event: InputEvent) -> void:
	if not is_active or is_preview or not can_interact:
		return
		
	# ONLY handle inputs if we are already in targeting mode
	if is_targeting_mode:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				apply_damage_at_preview()
				exit_targeting_mode()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				exit_targeting_mode()
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
		if range_indicator and range_indicator.visible:
			pulse_time += delta * pulse_speed
			var pulse = (sin(pulse_time) * pulse_strength) + 1.0
			range_indicator.scale = Vector3.ONE * pulse
			
			var material = range_indicator.material_override as StandardMaterial3D
			if material:
				var alpha = range_indicator_color.a * (0.8 + (sin(pulse_time) * 0.2))
				material.albedo_color.a = alpha
		return
	
	if is_targeting_mode:
		update_targeting_position()

func update_targeting_position() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera: return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_length = 1000
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# --- THE AIM FIX ---
	query.collision_mask = 1 # ONLY hit Layer 1 (The ground/environment)
	# -------------------
	
	var result = space_state.intersect_ray(query)
	if result:
		targeting_indicator.global_position = result.position
		targeting_indicator.global_position.y += 0.05

func enter_targeting_mode() -> void:
	ensure_targeting_indicator()
	is_targeting_mode = true
	targeting_indicator.visible = true
	
	if player and player.has_method("enter_targeting_mode"):
		var camera_position = global_position + Vector3(0, targeting_camera_height, 0)
		player.enter_targeting_mode(targeting_camera_height, targeting_camera_tilt, camera_position)

func exit_targeting_mode() -> void:
	is_targeting_mode = false
	if targeting_indicator: targeting_indicator.visible = false
	if player and player.has_method("exit_targeting_mode"):
		player.exit_targeting_mode()

func play_fire_sound() -> void:
	if fire_sound: fire_sound.play()

func play_impact_sound_at_location(position: Vector3) -> void:
	var temp_audio = AudioStreamPlayer3D.new()
	get_tree().get_root().add_child(temp_audio)
	
	if impact_sound:
		temp_audio.stream = impact_sound.stream
		temp_audio.volume_db = impact_sound.volume_db
		temp_audio.max_distance = impact_sound.max_distance
		temp_audio.attenuation_model = impact_sound.attenuation_model
	
	temp_audio.global_position = position
	temp_audio.play()
	await temp_audio.finished
	temp_audio.queue_free()

func apply_damage_at_preview() -> void:
	can_interact = false 
	
	var damage_position = targeting_indicator.global_position
	
	play_fire_sound()
	
	# --- NEW: Apply decay upon firing ---
	apply_decay()
	
	await get_tree().create_timer(damage_delay).timeout
	
	play_impact_sound_at_location(damage_position)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var flat_damage_pos = Vector2(damage_position.x, damage_position.z)
		var flat_enemy_pos = Vector2(enemy.global_position.x, enemy.global_position.z)
		var distance = flat_damage_pos.distance_to(flat_enemy_pos)
		
		if distance <= effect_range:
			if enemy.has_node("HealthComponent"):
				var hc = enemy.get_node("HealthComponent")
				if hc.has_method("damage"):
					var new_attack = Attack.new(damage_amount, self)
					hc.damage(new_attack)
			
			elif enemy.has_method("apply_damage"):
				enemy.apply_damage(damage_amount)
	
	start_cooldown()

# --- DECAY AND REPAIR LOGIC ---
func apply_decay() -> void:
	if is_preview or is_broken: return
	
	current_durability -= durability_loss_per_shot
	if current_durability <= 0:
		current_durability = 0
		break_turret()

func break_turret() -> void:
	is_broken = true
	# Kick the player out of the camera if it breaks!
	if is_targeting_mode:
		exit_targeting_mode()
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
		if range_indicator: range_indicator.visible = true
	else:
		restore_original_materials_recursive(self)
		clear_all_preview_materials()
		if range_indicator: range_indicator.visible = false

func set_active(active: bool) -> void:
	is_active = active
	visible = true
	set_process(active)
	set_physics_process(active)
	
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
