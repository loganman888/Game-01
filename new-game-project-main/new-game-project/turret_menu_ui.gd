extends Control

@onready var grid_container = $Panel/GridContainer
var pickup_system: Node

const OFFSET_X = -75
const OFFSET_Y = -100

var TURRET_INFO = {
	"Basic Turret": {
		"scene": preload("res://turret.tscn"),
		"type": "turret",
		"get_stats": func():
			var instance = preload("res://turret.tscn").instantiate()
			var stats = {
				"Damage": str(instance.damage),
				"Attack Speed": str(instance.attack_cooldown) + "s",
				"Attack Range": str(instance.attack_range) + "m"
			}
			instance.queue_free()
			return stats
			},
	"Rapid Turret": {
		"scene": preload("res://rapid_turret.tscn"),
		"type": "turret",
		"get_stats": func():
			var instance = preload("res://rapid_turret.tscn").instantiate()
			var stats = {
				"Damage": str(instance.damage),
				"Attack Speed": str(instance.attack_cooldown) + "s",
				"Attack Range": str(instance.attack_range) + "m"
			}
			instance.queue_free()
			return stats
			},
	"Slow Turret": {
		"scene": preload("res://slow_turret.tscn"),
		"type": "turret",
		"get_stats": func():
			var instance = preload("res://slow_turret.tscn").instantiate()
			var stats = {
				"Slow Effect": str(instance.slow_factor * 100) + "%",
				"Effect Range": str(instance.effect_range) + "m"
			}
			instance.queue_free()
			return stats
			},
	"DOT Turret": {
		"scene": preload("res://dot_turret.tscn"),
		"type": "turret",
		"get_stats": func():
			var instance = preload("res://dot_turret.tscn").instantiate()
			var stats = {
				"Damage per Second": str(instance.damage_per_second),
				"Effect Range": str(instance.effect_range) + "m"
			}
			instance.queue_free()
			return stats
			},
	"Manual Turret": {
		"scene": preload("res://manual_turret.tscn"),
		"type": "turret",
		"get_stats": func():
			var instance = preload("res://manual_turret.tscn").instantiate()
			var stats = {
				"Damage": str(instance.damage_amount),
				"Effect Range": str(instance.effect_range) + "m",
				"Control": "User Controlled"
			}
			instance.queue_free()
			return stats
			}
}

func _ready():
	add_to_group("turret_menu")
	visible = false
	pickup_system = get_tree().get_first_node_in_group("pickup_system")
	notify_pickup_system_menu_state()
	
	var screen_size = get_viewport().get_visible_rect().size
	var panel = $Panel
	
	panel.position = Vector2(
		(screen_size.x / 2) - (panel.size.x / 2) + OFFSET_X,
		(screen_size.y / 2) - (panel.size.y / 2) + OFFSET_Y
	)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", style)
	
	grid_container.custom_minimum_size = Vector2(150, 300)
	grid_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_container.add_theme_constant_override("h_separation", 5)
	grid_container.add_theme_constant_override("v_separation", 5)
	
	setup_turret_buttons()

func notify_pickup_system_menu_state():
	if pickup_system:
		pickup_system.set_turret_menu_open(visible)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		notify_pickup_system_menu_state()

func setup_turret_buttons():
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()

	for turret_name in TURRET_INFO:
		var data = TURRET_INFO[turret_name]
		var button = Button.new()
		
		var stats = data.get_stats.call()
		
		var tooltip = turret_name + "\n"
		for stat_name in stats:
			tooltip += stat_name + ": " + stats[stat_name] + "\n"
		button.tooltip_text = tooltip
		
		var vbox = VBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = turret_name
		name_label.add_theme_font_size_override("font_size", 14)
		
		var instance = data.scene.instantiate()
		var cost = instance.shop_cost
		instance.queue_free()
		
		var cost_label = Label.new()
		cost_label.text = str(cost) + " pts"
		cost_label.add_theme_color_override("font_color", Color(1, 1, 0))
		cost_label.add_theme_font_size_override("font_size", 12)
		
		vbox.add_child(name_label)
		vbox.add_child(cost_label)
		
		button.custom_minimum_size = Vector2(120, 40)
		button.add_child(vbox)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.4, 0.4, 0.4)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		
		button.add_theme_stylebox_override("normal", style)
		
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.3, 0.3, 0.3)
		button.add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style = style.duplicate()
		pressed_style.bg_color = Color(0.15, 0.15, 0.15)
		button.add_theme_stylebox_override("pressed", pressed_style)
		
		button.pressed.connect(_on_item_button_pressed.bind(turret_name))
		grid_container.add_child(button)

func _on_item_button_pressed(item_name: String):
	var data = TURRET_INFO[item_name]
	if pickup_system.current_turret or pickup_system.current_platform:
		print("Already holding an item!")
		return

	var instance = data.scene.instantiate()
	var cost = instance.shop_cost
	instance.queue_free()

	if ScoreManager.purchase_turret(cost):
		if pickup_system:
			var new_item = data.scene.instantiate()
			get_tree().get_root().add_child(new_item)
			if data.type == "turret":
				pickup_system.pickup_turret(new_item, data.type, cost)
			toggle_menu()

# In your turret menu script, replace the _input function with this:
func _unhandled_input(event):
	if event.is_action_pressed("open_turret_menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mouse_right") and visible:
		# Stop the event from propagating
		get_viewport().set_input_as_handled()
		accept_event()
		# Close the menu
		toggle_menu()
		# Prevent further processing
		return

func toggle_menu():
	visible = !visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		setup_turret_buttons()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	notify_pickup_system_menu_state()
	
	
func _input(event):
	if event.is_action_pressed("open_turret_menu"):
		toggle_menu()
	elif event.is_action_pressed("mouse_right") and visible:
		toggle_menu()
		get_viewport().set_input_as_handled()
