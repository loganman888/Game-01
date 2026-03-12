extends Control

# Path to save/load configuration file
var SETTINGS_PATH := "user://settings.cfg"
# Volume decibel mappings
var db_values = [-20, -32, -44, -56]  # 100%, 75%, 50%, 25%

func _ready() -> void:
	# Populate the volume dropdown (OptionButton) with levels
	$MarginContainer/VBoxContainer/Volume.clear()
	$MarginContainer/VBoxContainer/Volume.add_item("100%")
	$MarginContainer/VBoxContainer/Volume.add_item("75%")
	$MarginContainer/VBoxContainer/Volume.add_item("50%")
	$MarginContainer/VBoxContainer/Volume.add_item("25%")
	# If you dynamically create the resolutions OptionButton, do it here
	load_settings()
	# Set mute button status to current audio bus mute
	$MarginContainer/VBoxContainer/Mute.button_pressed = AudioServer.is_bus_mute(0)

# Handler for user selecting a new volume
func _on_volume_item_selected(index: int) -> void:
	var db = db_values[index]
	AudioServer.set_bus_volume_db(0, db)
	save_settings()

# Handler for user selecting a new resolution
func _on_resolutions_item_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_size(Vector2i(1920,1080))
		1:
			DisplayServer.window_set_size(Vector2i(1600,900))
		2:
			DisplayServer.window_set_size(Vector2i(1280,960))
	save_settings()

# Handler for user toggling mute
func _on_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0, toggled_on)
	save_settings()

# Handler for Back button - just closes this menu
func _on_back_button_pressed() -> void:
	queue_free()

# Save all user settings to file
func save_settings() -> void:
	var cfg = ConfigFile.new()
	var volume_index = $MarginContainer/VBoxContainer/Volume.selected
	var resolution_index = $MarginContainer/VBoxContainer/Resolutions.selected
	var mute_status = $MarginContainer/VBoxContainer/Mute.button_pressed
	cfg.set_value("audio", "volume_index", volume_index)
	cfg.set_value("audio", "volume_db", db_values[volume_index])
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("audio", "mute", mute_status)
	cfg.save(SETTINGS_PATH)

# Load settings from file and set OptionButtons and mute to match
func load_settings() -> void:
	var cfg = ConfigFile.new()
	var volume_index = 0
	var resolution_index = 0
	var mute_status = false
	if cfg.load(SETTINGS_PATH) == OK:
		if cfg.has_section_key("audio", "volume_index"):
			volume_index = int(cfg.get_value("audio", "volume_index"))
		if cfg.has_section_key("display", "resolution_index"):
			resolution_index = int(cfg.get_value("display", "resolution_index"))
		if cfg.has_section_key("audio", "mute"):
			mute_status = bool(cfg.get_value("audio", "mute"))
	# Clamp indices to safe values
	volume_index = clamp(volume_index, 0, db_values.size() - 1)
	resolution_index = clamp(resolution_index, 0, 2)
	# Set the OptionButtons and states to loaded values
	$MarginContainer/VBoxContainer/Volume.select(volume_index)
	$MarginContainer/VBoxContainer/Resolutions.select(resolution_index)
	AudioServer.set_bus_volume_db(0, db_values[volume_index])
	AudioServer.set_bus_mute(0, mute_status)
	match resolution_index:
		0:
			DisplayServer.window_set_size(Vector2i(1920,1080))
		1:
			DisplayServer.window_set_size(Vector2i(1600,900))
		2:
			DisplayServer.window_set_size(Vector2i(1280,960))
