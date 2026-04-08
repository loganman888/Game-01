extends CharacterBody3D

const INTERACTION_DISTANCE: float = 5.0
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005
const BOB_FREQ = 2.8
const BOB_AMP = 0.02
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

var speed: float
var t_bob: float = 0.0
var is_in_targeting_mode: bool = false
var camera_original_parent: Node
var camera_original_transform: Transform3D
var gravity: float = 9.8

var turret_cost_multiplier: float = 1.0 
var turret_fire_rate_multiplier: float = 1.0 

# --- REPAIR SYSTEM STATS ---
var max_repair_energy: float = 100.0
var current_repair_energy: float = 100.0
var base_repair_rate: float = 25.0         # Heals 25 HP per second
var repair_speed_multiplier: float = 1.0   # 1.0 = normal, 2.0 = double speed
var repair_energy_regen: float = 10.0      # How much comes back per round

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var health_lbl: Label = $HealthLbl
@onready var health_component: Node = $HealthComponent
@onready var pickup_system = $PickupSystem
@onready var unlock_prompt_label = $UnlockPromptLabel
@onready var energy_bar: ProgressBar = $HUD/EnergyBar


func debug_setup():
	for platform in get_tree().get_nodes_in_group("turret_platforms"):
		platform.is_locked = true

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	debug_setup()
	setup_crosshair()
	
	
	if energy_bar:
		energy_bar.max_value = max_repair_energy
		energy_bar.value = current_repair_energy

func _input(event):
	if is_in_targeting_mode: return
		
	# Mouse Look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(60))
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if Input.is_action_just_pressed("open_turret_menu"):
		var menu = get_tree().get_first_node_in_group("turret_menu")
		if menu: menu.toggle_menu()

	# --- UNIFIED INTERACTION INPUTS ---
	if Input.is_action_just_pressed("use") or Input.is_action_just_pressed("interact"):
		handle_interaction()

func _process(delta: float) -> void:
	if health_component:
		health_lbl.text = str(health_component.health)
	update_ui_prompt()
	
	handle_continuous_repair(delta)
	
	# --- ADD THIS LINE ---
	if energy_bar:
		energy_bar.value = current_repair_energy

func get_interactable_in_crosshair() -> Node:
	var space_state = get_world_3d().direct_space_state
	var start_pos = camera.global_position
	var end_pos = start_pos + (-camera.global_transform.basis.z * INTERACTION_DISTANCE)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	
	# --- THE DYNAMIC MASK FIX ---
	if pickup_system and pickup_system.current_turret:
		query.collision_mask = 1  # Hands full? ONLY look at Platforms (Layer 1).
	else:
		query.collision_mask = 33 # Hands empty? Look at Platforms (1) AND Turrets (32).
	# ----------------------------
	
	query.exclude = [self]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true 
	
	var result = space_state.intersect_ray(query)
	if result:
		var current = result.collider
		while current:
			if current.is_in_group("turret_platforms") or current.is_in_group("turrets"):
				return current
			current = current.get_parent()
	return null

# 2. Update the UI based on what we see
func update_ui_prompt() -> void:
	var target = get_interactable_in_crosshair()
	
	# 1. Check what we are looking at FIRST
	if target:
		if target.is_in_group("turret_platforms") and target.get("is_locked"):
			unlock_prompt_label.text = "Press 'F' to unlock platform (%d points)" % target.unlock_cost
			unlock_prompt_label.visible = true
			return
		elif target.is_in_group("turrets"):
			# Get HP safely (defaults to 100 if the turret doesn't have the durability variables yet)
			var hp = int(target.current_durability) if "current_durability" in target else 100
			var max_hp = int(target.max_durability) if "max_durability" in target else 100
			var my_energy = int(current_repair_energy)
			
			if target.get("is_broken") == true:
				unlock_prompt_label.text = "[BROKEN] HP: %d/%d | Your Energy: %d\nHold 'R' to Repair | 'F' to Pick Up" % [hp, max_hp, my_energy]
				unlock_prompt_label.modulate = Color(1, 0.2, 0.2) # Make text red
			else:
				unlock_prompt_label.text = "HP: %d/%d | Your Energy: %d\nHold 'R' to Repair | 'F' to Pick Up | 'E' to Use" % [hp, max_hp, my_energy]
				unlock_prompt_label.modulate = Color(1, 1, 1) # Normal white text
			
			unlock_prompt_label.visible = true
			return
			
	# 2. If we aren't looking at anything interactable, but we ARE holding a turret
	if pickup_system and pickup_system.current_turret:
		unlock_prompt_label.text = "Left Click to Place | 'Sell' to Cancel" 
		unlock_prompt_label.visible = true
		return
		
	# 3. Otherwise, hide the prompt
	unlock_prompt_label.visible = false

# 3. Fire the action based on the button pressed
func handle_interaction() -> void:
	var target = get_interactable_in_crosshair()
	if !target: return
	
	# F Key -> Unlock Platform
	if Input.is_action_just_pressed("use") and target.is_in_group("turret_platforms"):
		if target.get("is_locked"):
			if ScoreManager.has_enough_points(target.unlock_cost):
				ScoreManager.add_score(-target.unlock_cost)
				target.unlock_platform()
				unlock_prompt_label.visible = false
			else:
				unlock_prompt_label.text = "Not enough points!"
				await get_tree().create_timer(1.5).timeout
	
	# F Key -> Pickup Turret
	if Input.is_action_just_pressed("use") and target.is_in_group("turrets"):
		if "shop_type" in target:
			pickup_system.pickup_turret(target, target.shop_type, target.shop_cost)
			
	# E Key -> Use Turret (Manual Control)
	if Input.is_action_just_pressed("interact") and target.is_in_group("turrets"):
		if target.has_method("start_manual_control"):
			target.start_manual_control()

# 4. Continuous Actions (Holding a button)
func handle_continuous_repair(delta: float) -> void:
	# Use is_action_pressed (not just_pressed) because we are HOLDING the key
	if not Input.is_action_pressed("repair"):
		return
		
	var target = get_interactable_in_crosshair()
	
	if target and target.is_in_group("turrets") and target.has_method("repair_step"):
		var current_hp = target.get("current_durability")
		var max_hp = target.get("max_durability")
		
		# If the turret is hurt AND we have energy to spend...
		if current_hp < max_hp and current_repair_energy > 0:
			
			# Calculate how much we can heal in this exact frame
			var heal_amount = base_repair_rate * repair_speed_multiplier * delta
			
			# Prevent spending more energy than the turret actually needs to reach 100%
			var missing_hp = max_hp - current_hp
			
			# Using min() ensures we never heal more than we need OR more than we have energy for
			heal_amount = min(heal_amount, min(missing_hp, current_repair_energy))
			
			if heal_amount > 0:
				current_repair_energy -= heal_amount
				target.repair_step(heal_amount)

# 5. Replenish Energy (Call this from your WaveManager when a round ends!)
func replenish_repair_energy() -> void:
	current_repair_energy += repair_energy_regen
	if current_repair_energy > max_repair_energy:
		current_repair_energy = max_repair_energy

# --- MOVEMENT AND HELPERS (Unchanged) ---

func _physics_process(delta: float) -> void:
	if is_in_targeting_mode:
		handle_targeting_camera_movement(delta)
		return
		
	if not is_on_floor(): velocity += calculate_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = JUMP_VELOCITY
	speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction: Vector3 = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		velocity.x = direction.x * speed if direction else lerp(velocity.x, 0.0, delta * 7.0)
		velocity.z = direction.z * speed if direction else lerp(velocity.z, 0.0, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)

	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	camera.fov = lerp(camera.fov, BASE_FOV + FOV_CHANGE * clamp(velocity.length(), 0.5, SPRINT_SPEED * 2), delta * 8.0)
	move_and_slide()

func handle_targeting_camera_movement(delta: float) -> void:
	var move_speed = 20.0
	var movement = Vector3.ZERO
	if Input.is_action_pressed("forward"): movement.z -= 1
	if Input.is_action_pressed("back"): movement.z += 1
	if Input.is_action_pressed("left"): movement.x -= 1
	if Input.is_action_pressed("right"): movement.x += 1
	if movement != Vector3.ZERO:
		camera.global_position += movement.normalized() * move_speed * delta

func enter_targeting_mode(height: float, tilt: float, pos: Vector3) -> void:
	is_in_targeting_mode = true
	camera_original_parent = camera.get_parent()
	camera_original_transform = camera.global_transform
	camera_original_parent.remove_child(camera)
	get_tree().get_root().add_child(camera)
	camera.global_position = pos
	camera.global_rotation = Vector3.ZERO
	camera.rotation_degrees.x = tilt
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit_targeting_mode() -> void:
	is_in_targeting_mode = false
	if camera and camera_original_parent:
		if camera.get_parent(): camera.get_parent().remove_child(camera)
		camera_original_parent.add_child(camera)
		camera.global_transform = camera_original_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _headbob(time) -> Vector3:
	return Vector3(cos(time * BOB_FREQ / 2) * BOB_AMP, sin(time * BOB_FREQ) * BOB_AMP, 0)

func setup_crosshair():
	if get_node_or_null("CrosshairContainer"): return
	var c = CenterContainer.new()
	c.name = "CrosshairContainer"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cross = Control.new()
	cross.custom_minimum_size = Vector2(20, 20)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cross)
	add_child(c)
	cross.connect("draw", func(): 
		cross.draw_line(Vector2(10,0), Vector2(10,20), Color.WHITE, 2)
		cross.draw_line(Vector2(0,10), Vector2(20,10), Color.WHITE, 2))

func calculate_gravity() -> Vector3: return Vector3(0, -gravity, 0)
func on_death() -> void: get_tree().quit()
