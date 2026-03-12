extends Node3D

@export var enemy_scenes: Dictionary = {
	"cube": preload("res://enemy_cube.tscn"),
	"healer": preload("res://healer.tscn"),
	"knight": preload("res://enemy.tscn")
}
@export var spawn_interval: float = .5
@export var target: Node3D
@export var spawn_radius: float = 5.0
@export var initial_spawn_delay: float = 3.0
@export var wave_ui_scene: PackedScene = preload("res://Wave_UI.tscn")

var spawn_timer: Timer
var delay_timer: Timer
var wave_manager: Node
var wave_spawn_active: bool = false
var wave_ui: Control
var total_spawned_this_wave: int = 0  # ENHANCEMENT: Track spawned count

func _ready() -> void:
	print("\n=== Spawner Initialization ===")
	print("Spawner position: ", global_position)
	
	# Try to find target if not assigned
	if !target:
		target = get_tree().get_first_node_in_group("dummy")
		if !target:
			push_error("No target assigned to spawner!")
			return
	
	# Setup UI - find existing or create new
	setup_wave_ui()
	
	# Create wave manager
	wave_manager = preload("res://wavemanager.gd").new()
	add_child(wave_manager)
	
	# Connect to wave manager signals
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	wave_manager.wave_started.connect(_on_wave_started)
	
	# Create and setup spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Start the wave system after a delay
	await get_tree().create_timer(initial_spawn_delay).timeout
	wave_manager.start_waves(self, enemy_scenes)

func setup_wave_ui() -> void:
	# First check if UI already exists in the scene
	wave_ui = get_tree().get_first_node_in_group("wave_ui")
	
	# If not found, create and add it
	if wave_ui == null:
		# Check if we have a valid scene reference
		if wave_ui_scene == null:
			push_error("Wave UI scene not assigned!")
			return
			
		# Instance the UI
		wave_ui = wave_ui_scene.instantiate()
		
		# Create a CanvasLayer to ensure UI is always on top
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 10  # Higher layer to be on top of other UI
		canvas_layer.add_child(wave_ui)
		
		# Add to scene tree
		get_tree().current_scene.add_child(canvas_layer)
		
		print("Wave UI created and added to scene")
	else:
		print("Found existing Wave UI")

func start_wave_spawn(wave_mgr) -> void:
	wave_spawn_active = true
	total_spawned_this_wave = 0  # ENHANCEMENT: Reset counter
	spawn_timer.start()
	_try_spawn_enemy()

func _on_spawn_timer_timeout() -> void:
	if wave_spawn_active:
		_try_spawn_enemy()

func _try_spawn_enemy() -> void:
	if !target or !wave_spawn_active:
		return
		
	var enemy_scene = wave_manager.get_next_enemy_to_spawn()
	if enemy_scene == null:
		# No more enemies to spawn in this wave
		wave_spawn_active = false
		spawn_timer.stop()
		
		# ENHANCEMENT: Log when all enemies are spawned
		print("SPAWN COMPLETE: Finished spawning " + str(total_spawned_this_wave) + 
			  " enemies for wave " + str(wave_manager.current_wave_index + 1))
		return
	
	var enemy = enemy_scene.instantiate()
	if !enemy:
		push_error("Failed to instantiate enemy!")
		return
	
	# Calculate spawn position
	var spawn_angle = randf() * TAU
	var spawn_distance = spawn_radius
	var spawn_offset = Vector3(
		cos(spawn_angle) * spawn_distance,
		0.0,
		sin(spawn_angle) * spawn_distance
	)
	
	# ENHANCEMENT: Ensure enemy is in the enemies group
	if !enemy.is_in_group("enemies"):
		enemy.add_to_group("enemies")
	
	# Connect died signal
	if enemy.has_signal("died"):
		enemy.died.connect(wave_manager._on_enemy_died)
		print("Connected died signal for enemy " + str(total_spawned_this_wave + 1))
	else:
		push_warning("Enemy doesn't have a died signal! Wave tracking may fail.")
	
	# Add enemy to scene
	get_tree().current_scene.add_child(enemy)
	
	# Set position and target
	enemy.global_position = global_position + spawn_offset
	enemy.target = target
	
	# ENHANCEMENT: Increment counter
	total_spawned_this_wave += 1

func _on_wave_started(wave_number: int) -> void:
	print("Wave ", wave_number + 1, " started!")
	
	# Show wave start UI
	if wave_ui:
		wave_ui.show_wave_starting(wave_number, wave_manager.get_total_waves())
	else:
		# Try to find the UI again in case it was added after this spawner
		wave_ui = get_tree().get_first_node_in_group("wave_ui")
		if wave_ui:
			wave_ui.show_wave_starting(wave_number, wave_manager.get_total_waves())
		else:
			push_warning("Wave UI not found, can't show wave start notification")

func _on_wave_completed(wave_number: int) -> void:
	print("Wave ", wave_number + 1, " completed!")
	
	# Show wave completion UI
	if wave_ui:
		wave_ui.show_wave_completed(wave_number)
	else:
		# Try to find the UI again
		wave_ui = get_tree().get_first_node_in_group("wave_ui")
		if wave_ui:
			wave_ui.show_wave_completed(wave_number)
		else:
			push_warning("Wave UI not found, can't show wave completion notification")

func _on_all_waves_completed() -> void:
	print("All waves completed! Level finished!")
	
	# Show all waves completed UI
	if wave_ui:
		wave_ui.show_all_waves_completed()
	else:
		# Try to find the UI again
		wave_ui = get_tree().get_first_node_in_group("wave_ui")
		if wave_ui:
			wave_ui.show_all_waves_completed()
		else:
			push_warning("Wave UI not found, can't show all waves completed notification")
