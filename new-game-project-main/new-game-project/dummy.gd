extends CharacterBody3D

const GRAVITY = 9.8  # You can adjust this value as needed

@onready var health_component = $HealthComponent
@onready var healthbar = $CanvasLayer/ProgressBar
@onready var timer = $Timer

func _ready() -> void:
	print("Dummy ready, health component: ", health_component)
	
	# Initialize the health bar
	healthbar.max_value = health_component.MaxHealth
	healthbar.value = health_component.health
	
	# Connect to health component's signal
	health_component.health_changed.connect(_on_health_changed)

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Move the character
	move_and_slide()

func _on_health_changed(current_health, max_health):
	healthbar.value = current_health
	print("Health updated: ", current_health, "/", max_health)

func on_death() -> void:
	print("Dummy died!")
	queue_free()
	
	
