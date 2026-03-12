extends Sprite3D

@onready var health_component = get_parent().get_node("HealthComponent")
@onready var viewport = $SubViewport
@onready var health_bar = $SubViewport/HealthBar

func _ready() -> void:
	# Set up the viewport
	viewport.size = Vector2(50, 10)  # Smaller viewport size
	
	# Set up the sprite (self)
	texture = viewport.get_texture()
	pixel_size = 0.005  # Smaller pixel size
	billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Corrected this line
	no_depth_test = true
	
	# Position above enemy
	position.y = 1.5  # Lower position above enemy
	
	# Connect to health component
	if health_component:
		print("Health component found")
		health_component.health_changed.connect(_on_health_changed)
		# Set initial health
		_on_health_changed(health_component.health, health_component.MaxHealth)
	else:
		print("Health component not found!")
		# Print the parent node name to help debug
		print("Parent node: ", get_parent().name)

func _on_health_changed(current_health: float, max_health: float) -> void:
	if health_bar:
		health_bar.update_health(current_health, max_health)
		print("Health updated: ", current_health, "/", max_health)
