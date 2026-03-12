# WaveManager.gd
extends Node

signal wave_completed(wave_number)
signal all_waves_completed
signal wave_started(wave_number)

# Timing variables
var delay_between_waves: float = 6.0  # Longer delay between waves
var pre_wave_notification_time: float = 2.0  # Time between notification and actual spawning

class WaveEnemyData:
	var scene: PackedScene
	var count: int
	
	func _init(p_scene: PackedScene, p_count: int):
		scene = p_scene
		count = p_count

class Wave:
	var enemies: Array[WaveEnemyData] = []
	var spawn_delay: float = 0.5
	
	func add_enemy(scene: PackedScene, count: int):
		enemies.append(WaveEnemyData.new(scene, count))
	
	func get_total_enemies() -> int:
		var total = 0
		for enemy_data in enemies:
			total += enemy_data.count
		return total

# Wave definitions
var waves: Array[Wave] = []
var current_wave_index: int = -1
var current_wave: Wave
var enemies_remaining_in_wave: int = 0
var enemies_spawned_in_wave: Array[int] = []  # Tracks spawned count of each enemy type
var wave_transition_active = false  # Prevent multiple transitions
var total_enemies_spawned = 0  # Added: Track total enemies spawned in current wave
var completion_check_timer: Timer  # Added: Timer to periodically check wave completion

# Reference to spawner
var spawner: Node3D

func _on_enemy_died():
	# ENHANCEMENT: Prevent counter from going below zero
	if enemies_remaining_in_wave > 0:
		enemies_remaining_in_wave -= 1
		print("Enemy died. Remaining: ", enemies_remaining_in_wave)
	else:
		print("WARNING: Enemy died but counter already at 0!")
		
	# Check if wave is complete
	if enemies_remaining_in_wave <= 0 and not wave_transition_active:
		# ENHANCEMENT: Verify that all enemies are actually gone
		var enemies_in_scene = get_tree().get_nodes_in_group("enemies")
		if enemies_in_scene.size() > 0:
			print("WARNING: Counter is 0 but " + str(enemies_in_scene.size()) + " enemies still exist in scene!")
			
			# Reset counter to match reality
			enemies_remaining_in_wave = enemies_in_scene.size()
			print("Corrected enemy count to: ", enemies_remaining_in_wave)
			return
		
		print("All enemies defeated, completing wave " + str(current_wave_index + 1))
		complete_current_wave()

# ENHANCEMENT: New method to handle wave completion
func complete_current_wave():
	if wave_transition_active:
		return  # Prevent double completion
		
	wave_transition_active = true  # Prevent multiple transitions
	
	# Stop any completion check timer
	if completion_check_timer and completion_check_timer.is_inside_tree():
		completion_check_timer.stop()
		completion_check_timer.queue_free()
		completion_check_timer = null
	
	emit_signal("wave_completed", current_wave_index)
	
	# Move to next wave
	current_wave_index += 1
	if current_wave_index < waves.size():
		# Use a single timer instead of await
		var timer = Timer.new()
		add_child(timer)
		timer.one_shot = true
		timer.wait_time = delay_between_waves - pre_wave_notification_time
		timer.timeout.connect(func():
			emit_signal("wave_started", current_wave_index)
			
			# Create second timer for actual wave start
			var start_timer = Timer.new()
			add_child(start_timer)
			start_timer.one_shot = true
			start_timer.wait_time = pre_wave_notification_time
			start_timer.timeout.connect(func():
				start_wave(current_wave_index)
				start_wave_spawn(current_wave_index)
				wave_transition_active = false  # Reset flag
				start_timer.queue_free()
			)
			start_timer.start()
			
			timer.queue_free()
		)
		timer.start()
	else:
		emit_signal("all_waves_completed")
		wave_transition_active = false  # Reset flag

func define_waves(enemy_scenes: Dictionary):
	# Wave 1: 5 cubes
	var wave1 = Wave.new()
	wave1.add_enemy(enemy_scenes["knight"], 10)
	waves.append(wave1)
	
	# Wave 2: 10 knights, 5 healers
	var wave2 = Wave.new()
	wave2.add_enemy(enemy_scenes["knight"], 10)
	wave2.add_enemy(enemy_scenes["healer"], 5)
	waves.append(wave2)
	
	# Wave 3: Mixed enemies
	var wave3 = Wave.new()
	wave3.add_enemy(enemy_scenes["cube"], 8)
	wave3.add_enemy(enemy_scenes["knight"], 8)
	wave3.add_enemy(enemy_scenes["healer"], 7)
	waves.append(wave3)

func start_wave(wave_index: int):
	if wave_index >= waves.size():
		emit_signal("all_waves_completed")
		return
		
	current_wave_index = wave_index
	current_wave = waves[wave_index]
	
	# Reset tracking arrays
	enemies_remaining_in_wave = current_wave.get_total_enemies()
	enemies_spawned_in_wave.clear()
	for i in range(current_wave.enemies.size()):
		enemies_spawned_in_wave.append(0)
	
	# ENHANCEMENT: Reset total spawned counter
	total_enemies_spawned = 0
	
	print("Starting wave " + str(wave_index + 1) + " with " + str(enemies_remaining_in_wave) + " enemies")

func start_wave_spawn(wave_index: int):
	# Use the spawner to start spawning this wave
	if spawner:
		spawner.start_wave_spawn(self)
		
	# ENHANCEMENT: Start a periodic check to ensure wave completes
	start_completion_checking()

# ENHANCEMENT: Add a periodic check to ensure wave completes
func start_completion_checking():
	# Clean up existing timer if any
	if completion_check_timer and completion_check_timer.is_inside_tree():
		completion_check_timer.queue_free()
	
	# Create new timer
	completion_check_timer = Timer.new()
	add_child(completion_check_timer)
	completion_check_timer.wait_time = 0.5  # Check every 2 seconds
	completion_check_timer.one_shot = false
	completion_check_timer.timeout.connect(_check_wave_completion)
	completion_check_timer.start()
	
	print("Started wave completion checking timer")

# ENHANCEMENT: Periodically verify wave status
func _check_wave_completion():
	if wave_transition_active:
		return  # Wave is already transitioning
		
	# Get actual count of enemies in the scene
	var enemies_in_scene = get_tree().get_nodes_in_group("enemies")
	print("WAVE CHECK: " + str(enemies_in_scene.size()) + " enemies in scene, counter shows " + str(enemies_remaining_in_wave))
	
	# Check if spawning is complete
	var total_expected = current_wave.get_total_enemies()
	var all_spawned = total_enemies_spawned >= total_expected
	
	# If the counter doesn't match reality, fix it
	if enemies_in_scene.size() != enemies_remaining_in_wave:
		print("WAVE CHECK: Correcting enemy count mismatch!")
		enemies_remaining_in_wave = enemies_in_scene.size()
		
	# If spawning is complete and no enemies remain, but wave hasn't ended
	if all_spawned and enemies_remaining_in_wave <= 0 and enemies_in_scene.size() <= 0:
		print("WAVE CHECK: No enemies left and all spawned, ending wave")
		complete_current_wave()

func get_next_enemy_to_spawn() -> PackedScene:
	# This gives the spawner the next enemy to spawn based on the wave definition
	if !current_wave:
		return null
		
	# Find an enemy type that hasn't reached its count yet
	for i in range(current_wave.enemies.size()):
		var enemy_data = current_wave.enemies[i]
		if enemies_spawned_in_wave[i] < enemy_data.count:
			enemies_spawned_in_wave[i] += 1
			total_enemies_spawned += 1  # ENHANCEMENT: Track total spawned
			return enemy_data.scene
			
	return null

func start_waves(p_spawner: Node3D, enemy_scenes: Dictionary):
	spawner = p_spawner
	define_waves(enemy_scenes)
	
	# For the first wave, show notification then wait before starting
	emit_signal("wave_started", 0)
	await get_tree().create_timer(pre_wave_notification_time).timeout
	start_wave(0)
	start_wave_spawn(0)  # Start spawning for first wave
	
func get_total_waves() -> int:
	return waves.size()
