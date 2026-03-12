extends CharacterBody3D

signal died

const SCORE_VALUE: int = 100

@export var speed := 5.0
@export var target: Node3D
@export var attack_reach: float = 2.5
@export var attack_cooldown: float = .1
@export var separation_radius := 2.0
@export var separation_force := 3.0
@export var movement_smoothing := 0.2

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_component: Node = $HealthComponent
@onready var knight_model = $Knight
@onready var animation_player = $Knight/AnimationPlayer

@export var collision_safe_margin: float = 0.001

var can_attack: bool = true
var new_velocity: Vector3
var base_speed: float
var current_speed: float
var slow_factor: float = 1.0
var is_dead = false
var spawn_time: float = 0.0

func _ready() -> void:
	base_speed = speed
	current_speed = base_speed
	spawn_time = Time.get_ticks_msec() / 1000.0  # Current time in seconds
	add_to_group("enemies")
	
	motion_mode = MOTION_MODE_GROUNDED
	set_safe_margin(collision_safe_margin)
	
	# Set health type for basic enemy
	if health_component:
		health_component.enemy_type = health_component.EnemyType.BASIC
	
	# Initialize animation
	if animation_player:
		animation_player.play("Idle")
	
	await get_tree().process_frame
	if not target:
		target = get_tree().get_first_node_in_group("dummy")

func _physics_process(delta: float) -> void:
	if not target:
		return
		
	update_movement(delta)
	check_attack()
	move_and_slide()

func update_movement(delta: float) -> void:
	# Don't update movement if attacking
	if animation_player.current_animation == "2H_Melee_Attack_Chop":
		return
		
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# If in attack range, stop moving
	if distance_to_target <= attack_reach:
		velocity = Vector3.ZERO
		return
		
	navigation_agent.target_position = target.global_position
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var current_position: Vector3 = global_position
	var new_direction: Vector3 = (next_path_position - current_position).normalized()
	var target_velocity: Vector3 = new_direction * current_speed
	
	# Apply separation from other enemies
	var separation = calculate_separation()
	target_velocity += separation
	
	# Apply gravity
	if not is_on_floor():
		target_velocity.y -= 9.8 * delta
	
	# Smooth the velocity
	velocity = velocity.lerp(target_velocity, movement_smoothing)
	
	# Update animations and model rotation based on movement
	update_model_and_animation(target_velocity)

func update_model_and_animation(movement_velocity: Vector3) -> void:
	if knight_model and animation_player:
		# Check if in attack range
		var distance_to_target = global_position.distance_to(target.global_position)
		var in_attack_range = distance_to_target <= attack_reach
		
		# If in attack range, don't play walking animation
		if in_attack_range:
			# Face the target
			var direction_to_target = (target.global_position - global_position).normalized()
			var target_rotation = atan2(direction_to_target.x, direction_to_target.z)
			knight_model.rotation.y = lerp_angle(knight_model.rotation.y, target_rotation, 0.1)
			
			# Only play idle if not attacking
			if animation_player.current_animation != "2H_Melee_Attack_Chop" and animation_player.current_animation != "Idle":
				animation_player.play("Idle")
		
		# If not in attack range, handle walking animation
		else:
			if movement_velocity.length() > 0.1:
				var horizontal_velocity = Vector3(movement_velocity.x, 0, movement_velocity.z)
				if horizontal_velocity.length() > 0:
					var target_rotation = atan2(horizontal_velocity.x, horizontal_velocity.z)
					knight_model.rotation.y = lerp_angle(knight_model.rotation.y, target_rotation, 0.1)
					
					# Play walking animation
					if animation_player.current_animation != "Walking_A":
						animation_player.play("Walking_A")
			else:
				# Play idle when not moving
				if animation_player.current_animation != "Idle":
					animation_player.play("Idle")

func calculate_separation() -> Vector3:
	var separation = Vector3.ZERO
	var nearby_count = 0
	
	# Get all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy != self:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < separation_radius:
				var direction = global_position - enemy.global_position
				direction = direction.normalized()
				# The closer they are, the stronger the separation
				var force = (separation_radius - distance) / separation_radius
				separation += direction * force
				nearby_count += 1
	
	# Average the separation force if there are nearby enemies
	if nearby_count > 0:
		separation = separation / nearby_count
		separation = separation.normalized() * separation_force
	
	# Keep separation on the horizontal plane
	separation.y = 0
	
	return separation

func check_attack() -> void:
	var distance = global_position.distance_to(target.global_position)
	if distance < attack_reach and can_attack and animation_player.current_animation != "2H_Melee_Attack_Chop":
		try_attack()

func try_attack() -> void:
	var health_comp = target.get_node("HealthComponent")
	if not health_comp:
		return
		
	# Stop movement while attacking
	current_speed = 0
	can_attack = false
		
	if animation_player:
		animation_player.play("2H_Melee_Attack_Chop", 0.2)
		await get_tree().create_timer(0.8).timeout
		
		if is_instance_valid(health_comp):
			health_comp.damage(Attack.new(10.0, self))
			
		await animation_player.animation_finished
		
		# Resume movement after attack
		current_speed = base_speed * slow_factor
		start_attack_cooldown()

func start_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# Methods for slow turret compatibility
func get_speed() -> float:
	return current_speed

func set_speed(new_speed: float) -> void:
	current_speed = new_speed

func apply_slow(factor: float) -> void:
	slow_factor = factor
	current_speed = base_speed * slow_factor
	print("Enemy slowed to ", slow_factor * 100, "% speed")

func remove_slow() -> void:
	slow_factor = 1.0
	current_speed = base_speed
	print("Enemy speed restored")

func on_damage(attack: Attack) -> void:
	if has_node("EnemyModel"):
		var model = $EnemyModel
		model.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		model.modulate = Color.WHITE

func on_death() -> void:
	emit_signal("died")
	ScoreManager.add_score(SCORE_VALUE)
	queue_free()

func apply_damage(amount: float) -> void:
	if health_component:
		health_component.damage(Attack.new(amount, self))
		on_damage(Attack.new(amount, self))
		
		
func die():
	if is_dead:
		return
		
	is_dead = true
	emit_signal("died")
		
func get_spawn_time() -> float:
	return spawn_time
