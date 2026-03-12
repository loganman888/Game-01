extends Node3D

@onready var wave_ui = $WaveUI

func _ready():
	var wave_ui_scene = preload("res://Wave_UI.tscn")
	var wave_ui = wave_ui_scene.instantiate()
	
	# Create a CanvasLayer first, then add the UI to it
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10  # Set the layer property on the CanvasLayer
	
	# Add UI to the CanvasLayer
	canvas_layer.add_child(wave_ui)
	
	# Add the CanvasLayer to the scene
	add_child(canvas_layer)
