extends CharacterBody3D

const PLATFORM_INTERACTION_DISTANCE: float = 5.0
const TURRET_INTERACTION_DISTANCE: float = 5.0
var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005
const BOB_FREQ = 2.8
const BOB_AMP = 0.02
var t_bob = 0.0
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var health_lbl: Label = $HealthLbl
@onready var health_component: Node = $HealthComponent
@onready var pickup_system = $PickupSystem
@onready var unlock_prompt_label = $UnlockPromptLabel

var is_in_targeting_mode: bool = false
var camera_original_parent: Node
var camera_original_transform: Transform3D
var gravity = 9.8

func debug_setup():
	var platforms = get_tree().get_nodes_in_group("turret_platforms")
	for platform in platforms:
		platform.is_locked = true

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	debug_setup()
	setup_crosshair()

func setup_crosshair():
	var existing_container = get_node_or_null("CrosshairContainer")
	if existing_container:
		return
	
	var container = CenterContainer.new()
	container.name = "CrosshairContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var crosshair = Control.new()
	crosshair.custom_minimum_size = Vector2(20, 20)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	container.add_child(crosshair)
	add_child(container)
	
	crosshair.connect("draw", _draw_crosshair.bind(crosshair))
	crosshair.queue_redraw()

func _draw_crosshair(crosshair: Control):
	var center = crosshair.size / 2
	var color = Color.WHITE
	var thickness = 2.0
	var size = 10.0
	
	crosshair.draw_line(
		center + Vector2(0, -size),
		center + Vector2(0, size),
		color,
		thickness
	)
	
	crosshair.draw_line(
		center + Vector2(-size, 0),
		center + Vector2(size, 0),
		color,
		thickness
	)

func _input(event):
	if is_in_targeting_mode:
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(60))
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.is_action_just_pressed("open_turret_menu"):
		var menu = get_tree().get_first_node_in_group("turret_menu")
		if menu:
			menu.toggle_menu()

func _process(_delta: float) -> void:
	health_lbl.text = str(health_component.health)
	check_turret_interaction()
	check_platform_interaction()

func check_platform_interaction() -> void:
	var space_state = get_world_3d().direct_space_state
	
	var start_pos = camera.global_position
	var forward_direction = -camera.global_transform.basis.z
	var end_pos = start_pos + (forward_direction * PLATFORM_INTERACTION_DISTANCE)
	

	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [self]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 4294967295
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider.is_in_group("turret_platforms"):
			handle_platform_interaction(result.collider)
		else:
			var current = result.collider
			while current:
				if current.is_in_group("turret_platforms"):
					handle_platform_interaction(current)
					break
				current = current.get_parent()
	else:
		if unlock_prompt_label:
			unlock_prompt_label.visible = false

func handle_platform_interaction(platform: Node) -> void:
	if platform.is_locked:
		if unlock_prompt_label:
			unlock_prompt_label.text = "Press 'F' to unlock platform (%d points)" % platform.unlock_cost
			unlock_prompt_label.visible = true
			
		if Input.is_action_just_pressed("use"):
			if ScoreManager.has_enough_points(platform.unlock_cost):
				ScoreManager.add_score(-platform.unlock_cost)
				platform.unlock_platform()
				unlock_prompt_label.visible = false
			else:
				unlock_prompt_label.text = "Not enough points!"
				await get_tree().create_timer(1.5).timeout
				unlock_prompt_label.visible = false
	else:
		if unlock_prompt_label:
			unlock_prompt_label.visible = false

func check_turret_interaction() -> void:
	if Input.is_action_just_pressed("interact"):
		var space_state = get_world_3d().direct_space_state
		var start_pos = camera.global_position
		var end_pos = camera.global_position - camera.global_transform.basis.z * TURRET_INTERACTION_DISTANCE
		
		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		query.collision_mask = 32  # Only hit Layer 6 (Pickup)
		query.exclude = [self]
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.hit_from_inside = true
		
		var result = space_state.intersect_ray(query)
		if result:
			if result.collider.get_parent().is_in_group("turrets"):
				var turret = result.collider.get_parent()
				pickup_system.pickup_turret(turret, turret.shop_type, turret.shop_cost)

func _physics_process(delta: float) -> void:
	if is_in_targeting_mode:
		handle_targeting_camera_movement(delta)
		return
		
	if not is_on_floor():
		velocity += calculate_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction: Vector3 = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)

	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()

func handle_targeting_camera_movement(delta: float) -> void:
	var move_speed = 20.0
	var movement = Vector3.ZERO
	
	if Input.is_action_pressed("forward"):
		movement.z -= 1
	if Input.is_action_pressed("back"):
		movement.z += 1
	if Input.is_action_pressed("left"):
		movement.x -= 1
	if Input.is_action_pressed("right"):
		movement.x += 1
	
	if movement != Vector3.ZERO:
		movement = movement.normalized() * move_speed * delta
		camera.global_position += movement

func enter_targeting_mode(height: float, tilt: float, position: Vector3) -> void:
	is_in_targeting_mode = true
	
	camera_original_parent = camera.get_parent()
	camera_original_transform = camera.global_transform
	
	camera_original_parent.remove_child(camera)
	get_tree().get_root().add_child(camera)
	
	camera.global_position = position
	camera.global_rotation = Vector3.ZERO
	camera.rotation_degrees.x = tilt
	camera.rotation_degrees.y = 0
	camera.rotation_degrees.z = 0
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit_targeting_mode() -> void:
	is_in_targeting_mode = false
	
	if camera and camera_original_parent:
		if camera.get_parent():
			camera.get_parent().remove_child(camera)
		
		camera_original_parent.add_child(camera)
		camera.global_transform = camera_original_transform
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func on_death() -> void:
	get_tree().quit()

func calculate_gravity() -> Vector3:
	return Vector3(0, -gravity, 0)
