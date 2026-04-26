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

# --- RELIC EXPORTS ---
@export var loot_table: Array[Dictionary] = [] 
@export_range(0, 1.0) var drop_chance: float = 0.5 

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_component: Node = $HealthComponent
@onready var knight_model = $Knight
@onready var animation_player = $Knight/AnimationPlayer

var can_attack: bool = true
var base_speed: float
var current_speed: float
var slow_factor: float = 1.0
var is_dead = false
var spawn_time: float = 0.0
var red_flash_mat: StandardMaterial3D = StandardMaterial3D.new()

func _ready() -> void:
	base_speed = speed
	current_speed = base_speed
	spawn_time = Time.get_ticks_msec() / 1000.0
	add_to_group("enemies")
	red_flash_mat.albedo_color = Color.RED
	red_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	motion_mode = MOTION_MODE_GROUNDED
	
	if health_component:
		health_component.enemy_type = health_component.EnemyType.BASIC
	
	if animation_player:
		animation_player.play("Idle")
	
	await get_tree().process_frame
	if not target:
		target = get_tree().get_first_node_in_group("dummy")

func _physics_process(delta: float) -> void:
	if not target or is_dead:
		return
	update_movement(delta)
	check_attack()
	move_and_slide()

func update_movement(delta: float) -> void:
	if animation_player.current_animation == "2H_Melee_Attack_Chop":
		return
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target <= attack_reach:
		velocity = Vector3.ZERO
		return
	navigation_agent.target_position = target.global_position
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_direction: Vector3 = (next_path_position - global_position).normalized()
	var target_velocity: Vector3 = new_direction * current_speed
	var separation = calculate_separation()
	target_velocity += separation
	if not is_on_floor():
		target_velocity.y -= 9.8 * delta
	velocity = velocity.lerp(target_velocity, movement_smoothing)
	update_model_and_animation(target_velocity)

func calculate_separation() -> Vector3:
	var separation = Vector3.ZERO
	var nearby_count = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < separation_radius:
				var direction = (global_position - enemy.global_position).normalized()
				separation += direction * ((separation_radius - distance) / separation_radius)
				nearby_count += 1
	if nearby_count > 0:
		separation = separation.normalized() * separation_force
	separation.y = 0
	return separation

func check_attack() -> void:
	var distance = global_position.distance_to(target.global_position)
	if distance < attack_reach and can_attack and animation_player.current_animation != "2H_Melee_Attack_Chop":
		try_attack()

func try_attack() -> void:
	var health_comp = target.get_node("HealthComponent")
	if not health_comp: return
	current_speed = 0
	can_attack = false
	if animation_player:
		animation_player.play("2H_Melee_Attack_Chop", 0.2)
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(health_comp):
			health_comp.damage(Attack.new(10.0, self))
		await animation_player.animation_finished
		current_speed = base_speed * slow_factor
		start_attack_cooldown()

func start_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func die():
	if is_dead:
		return
	is_dead = true
	
	print("!!! [ENEMY] die() called. Running re-roll relic check.")
	apply_instant_relic()
	
	emit_signal("died")
	ScoreManager.add_score(SCORE_VALUE)
	queue_free()

func apply_instant_relic():
	# 1. Roll for the general drop chance
	if randf() > drop_chance or loot_table.is_empty():
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if !player: return

	# 2. Calculate Total Weight
	var total_weight = 0.0
	for entry in loot_table:
		total_weight += entry.get("weight", 1.0)

	# 3. Roll a random number between 0 and total_weight
	var roll = randf() * total_weight
	var current_sum = 0.0
	var chosen_scene: PackedScene = null

	# 4. Find which "weight bracket" the roll fell into
	for entry in loot_table:
		current_sum += entry.get("weight", 1.0)
		if roll <= current_sum:
			chosen_scene = entry.get("item")
			break

	# 5. Instantiate and apply (ONLY DO THIS ONCE!)
	if chosen_scene:
		var relic_instance = chosen_scene.instantiate()
		get_tree().root.add_child(relic_instance)
		
		# Give the buff to the player
		relic_instance.apply_relic_buff(player)
		print("!!! Enemy Dropped: ", relic_instance.relic_name)
		
		# Clean it up immediately
		relic_instance.queue_free()

# --- Helpers ---
func update_model_and_animation(movement_velocity: Vector3) -> void:
	if knight_model and animation_player:
		if movement_velocity.length() > 0.1:
			var target_rotation = atan2(movement_velocity.x, movement_velocity.z)
			knight_model.rotation.y = lerp_angle(knight_model.rotation.y, target_rotation, 0.1)
			if animation_player.current_animation != "Walking_A":
				animation_player.play("Walking_A")
		elif animation_player.current_animation != "Idle":
			animation_player.play("Idle")

func apply_flash_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
	for child in node.get_children():
		apply_flash_material(child, mat)

func on_death(): die()
