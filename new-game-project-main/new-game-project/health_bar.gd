extends Control

@onready var progress_bar = $ProgressBar

func _ready() -> void:
	# Set up progress bar appearance
	progress_bar.max_value = 100
	progress_bar.value = 100
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(50, 5)
	
	# Style the progress bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_bg.corner_radius_top_left = 2
	style_bg.corner_radius_top_right = 2
	style_bg.corner_radius_bottom_left = 2
	style_bg.corner_radius_bottom_right = 2
	progress_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(1, 0.2, 0.2, 0.8)  # Red health bar
	style_fill.corner_radius_top_left = 2
	style_fill.corner_radius_top_right = 2
	style_fill.corner_radius_bottom_left = 2
	style_fill.corner_radius_bottom_right = 2
	progress_bar.add_theme_stylebox_override("fill", style_fill)

func update_health(current_health: float, max_health: float) -> void:
	progress_bar.max_value = max_health
	progress_bar.value = current_health
