extends Control

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://map.tscn")

func _on_settings_button_pressed() -> void:
	var settings = preload("res://settings.tscn").instantiate()
	add_child(settings)

func _on_exit_pressed() -> void:
	get_tree().quit()
