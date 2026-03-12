extends Control

var active_label = null
var hide_timer = null

func _ready():
	# Add to group to be easily findable
	add_to_group("wave_ui")
	
	# Make this control fill the screen
	anchor_right = 1.0
	anchor_bottom = 1.0

func show_wave_starting(wave_number: int, total_waves: int):
	show_message("Wave " + str(wave_number + 1) + " Starting!")

func show_wave_completed(wave_number: int):
	show_message("Wave " + str(wave_number + 1) + " Completed!")

func show_all_waves_completed():
	show_message("All Waves Completed!")

func show_message(text):
	# Remove previous label if exists
	if active_label:
		active_label.queue_free()
	
	# Cancel previous timer
	if hide_timer and hide_timer.timeout.is_connected(hide_message):
		hide_timer.timeout.disconnect(hide_message)
	
	# Create new centered label
	active_label = Label.new()
	active_label.text = text
	active_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	active_label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	active_label.anchor_right = 1.0
	active_label.anchor_bottom = 1.0
	active_label.add_theme_font_size_override("font_size", 32)
	
	# Optional: Add background panel
	var panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.25
	panel.anchor_bottom = 0.25
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -50
	panel.offset_bottom = 50
	panel.add_child(active_label)
	
	add_child(panel)
	active_label = panel  # For clean removal later
	
	# Auto-hide after delay
	hide_timer = get_tree().create_timer(3.0)
	hide_timer.timeout.connect(hide_message)

func hide_message():
	if active_label:
		active_label.queue_free()
		active_label = null
