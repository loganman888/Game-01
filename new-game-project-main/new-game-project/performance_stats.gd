extends CanvasLayer

@onready var label = $Label

func _ready():
	# Make sure it's visible by default
	visible = true

func _process(_delta: float) -> void:
	# 1. Grab the metrics
	var fps = Engine.get_frames_per_second()
	
	# TIME_PROCESS is the total time per frame in seconds. Multiply by 1000 for ms.
	var frame_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
	
	# Static memory currently used by the game
	var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	
	# 2. Update the Label
	label.text = "FPS: %d\n" % fps
	label.text += "Frame Time: %.2f ms\n" % frame_time
	label.text += "Mem: %.2f MB" % mem

func _input(event: InputEvent) -> void:
	# 1. Check if it's a key event
	# 2. Check if the key was just pressed down
	# 3. 'not event.echo' ensures it doesn't trigger 60 times a second if you hold it
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			visible = !visible
