extends Node3D

# Export variables
@export var attack_range: float = 10.0
@export var attack_cooldown: float = 0.5
@export var damage: float = 50
@export var projectile_speed: float = 20.0
@export var rotation_speed: float = 5.0
@export var shop_type: String = "Basic Turret"
@export var shop_cost: int = 50

# --- NEW: DURABILITY VARIABLES ---
@export var max_durability: float = 100.0
@export var durability_loss_per_shot: float = 25.0  # Loses 5 HP per shot (20 shots = broken)
var current_durability: float
var is_broken: bool = false
# ---------------------------------

@onready var rotation_base = $RotationBase
@onready var turret_model = $RotationBase/TurretModel
@onready var detection_area = $DetectionArea
@onready var pickup_area = $PickupDetectionArea
@onready var projectile_spawn = $RotationBase/ProjectileSpawn
@onready var shoot_sound = $ShootSound
@onready var rate_label = $Label3D

@onready var projectile_scene = preload("res://projectile.tscn")

var current_target: Node3D = null
var can_attack: bool = true
var is_active: bool = true
var is_preview: bool = false
var original_materials: Dictionary = {}
var platform: Node = null

func _ready() -> void:
	add_to_group("turrets")
	current_durability = max_durability # Start at full health!
	
	if detection_area:
		detection_area.collision_layer = 8
		detection_area.collision_mask = 4
		var collision_shape = detection_area.get_node("CollisionShape3D")
		if collision_shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = attack_range
			collision_shape.shape = sphere_shape
	
	if pickup_area:
		pickup_area.collision_layer = 32
		pickup_area.collision_mask = 32
		pickup_area.monitoring = true
		pickup_area.monitorable = true

func _process(delta: float) -> void:
	update_rate_label()

	# NEW: Stop aiming and shooting if broken!
	if !is_active or is_preview or is_broken:
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

# --- NEW: DECAY AND REPAIR LOGIC ---
func apply_decay() -> void:
	if is_preview or is_broken: return
	
	current_durability -= durability_loss_per_shot
	if current_durability <= 0:
		current_durability = 0
		break_turret()

func break_turret() -> void:
	is_broken = true
	current_target = null
	if detection_area:
		detection_area.monitoring = false # Stop looking for enemies
		
# --- THE NEW MANUAL REPAIR ---
func repair_step(amount: float) -> void:
	if current_durability >= max_durability: 
		return
		
	current_durability += amount
	
	# If we heal it above 0, it turns back on immediately!
	if is_broken and current_durability > 0:
		is_broken = false
		if detection_area and is_active:
			detection_area.monitoring = true
			detection_area.monitorable = true
			
	# Cap it so we don't overheal past max
	if current_durability > max_durability:
		current_durability = max_durability
# -----------------------------------

func shoot_at_target() -> void:
	if not current_target or !is_active or !projectile_spawn: return
	
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = projectile_spawn.global_position
	projectile.initialize(current_target, damage, projectile_speed, self)
	
	if shoot_sound: shoot_sound.play()
	
	# NEW: Apply decay every time we shoot!
	apply_decay()
	
	can_attack = false
	var player = get_tree().get_first_node_in_group("player")
	var fire_rate_buff = 1.0
	if player and "turret_fire_rate_multiplier" in player:
		fire_rate_buff = player.turret_fire_rate_multiplier
	
	var final_wait_time = attack_cooldown / fire_rate_buff
	await get_tree().create_timer(final_wait_time).timeout
	can_attack = true

func find_new_target() -> Node3D:
	if !is_active or !detection_area or !detection_area.monitoring or is_broken:
		return null
	var bodies = detection_area.get_overlapping_bodies()
	return find_oldest_enemy(bodies)

func find_oldest_enemy(bodies: Array) -> Node3D:
	var oldest_enemy: Node3D = null
	var oldest_spawn_time: float = INF
	for body in bodies:
		if is_instance_valid(body) and body.is_in_group("enemies") and body.is_inside_tree():
			if body.has_method("get_spawn_time") or body.get("spawn_time") != null:
				var spawn_time = body.get_spawn_time() if body.has_method("get_spawn_time") else body.spawn_time
				if spawn_time < oldest_spawn_time:
					oldest_spawn_time = spawn_time
					oldest_enemy = body
			elif oldest_enemy == null or body.get_instance_id() < oldest_enemy.get_instance_id():
				oldest_enemy = body
	if oldest_enemy == null:
		return find_closest_enemy(bodies)
	return oldest_enemy

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

func _on_detection_area_body_entered(body: Node3D) -> void:
	if !is_active or is_broken: return
	if body.is_in_group("enemies") and not current_target:
		current_target = find_oldest_enemy(detection_area.get_overlapping_bodies())

func _on_detection_area_body_exited(body: Node3D) -> void:
	if !is_active or is_broken: return
	if body == current_target:
		current_target = find_oldest_enemy(detection_area.get_overlapping_bodies())

func update_rate_label():
	if !rate_label: return
	
	var player = get_tree().get_first_node_in_group("player")
	var current_buff = 1.0
	if player and "turret_fire_rate_multiplier" in player:
		current_buff = player.turret_fire_rate_multiplier
	
	# NEW: Update the label to turn RED when broken, and show HP normally.
	if is_broken:
		rate_label.text = "BROKEN!"
		rate_label.modulate = Color(1, 0, 0) # Red color
	else:
		rate_label.text = str(current_buff).pad_decimals(1) + "x\nHP: " + str(round(current_durability))
		rate_label.modulate = Color(1, 1, 1) # White color

# --- PLATFORM LOGIC (UNCHANGED) ---
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
		# Don't turn the detection back on if it's broken!
		detection_area.monitoring = active and not is_broken 
		detection_area.monitorable = active and not is_broken
	if pickup_area:
		pickup_area.monitoring = active
		pickup_area.monitorable = active
