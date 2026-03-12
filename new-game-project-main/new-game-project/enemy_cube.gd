extends CharacterBody3D

signal died

const SCORE_VALUE: int = 100

@export var speed := 10.0
@export var target: Node3D
@export var attack_reach: float = 2.5
@export var attack_cooldown: float = 1.0
@export var separation_radius := 2.0
@export var separation_force := 3.0
@export var movement_smoothing := 0.2

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_component: Node = $HealthComponent

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
	
	# Look at target
	var look_at_position = Vector3(target.global_position.x, global_position.y, target.global_position.z)
	look_at(look_at_position)

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
	if distance < attack_reach and can_attack:
		try_attack()

func try_attack() -> void:
	var health_comp = target.get_node("HealthComponent")
	if not health_comp:
		return
	
	health_comp.damage(Attack.new(10.0, self))
	can_attack = false
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
	
