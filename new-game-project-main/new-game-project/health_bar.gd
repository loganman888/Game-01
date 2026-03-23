extends Control

@onready var progress_bar = $ProgressBar

# Make this a class variable so update_health can access it!
var style_fill: StyleBoxFlat

func _ready() -> void:
	# Set up progress bar appearance
	progress_bar.max_value = 100
	progress_bar.value = 100
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(50, 5)
	
	# Style the progress bar background
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_bg.corner_radius_top_left = 2
	style_bg.corner_radius_top_right = 2
	style_bg.corner_radius_bottom_left = 2
	style_bg.corner_radius_bottom_right = 2
	progress_bar.add_theme_stylebox_override("background", style_bg)
	
	# Style the fill
	style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(1.0, 0.2, 0.2, 0.8)  # Default Red
	style_fill.corner_radius_top_left = 2
	style_fill.corner_radius_top_right = 2
	style_fill.corner_radius_bottom_left = 2
	style_fill.corner_radius_bottom_right = 2
	progress_bar.add_theme_stylebox_override("fill", style_fill)

func update_health(current_health: float, max_health: float) -> void:
	progress_bar.max_value = max_health
	progress_bar.value = current_health
	
	# --- NEW OVERHEAL VISUAL LOGIC ---
	if current_health > max_health:
		# Change to a Gold/Yellow color if they have a shield buffer
		style_fill.bg_color = Color(1.0, 0.84, 0.0, 0.8) 
	else:
		# Return to normal Red once the shield is broken
		style_fill.bg_color = Color(1.0, 0.2, 0.2, 0.8)
