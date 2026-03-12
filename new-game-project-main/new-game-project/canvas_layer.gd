extends CanvasLayer

@onready var score_label = $Label

func _ready() -> void:
	# Set up initial label properties
	score_label.text = "Score: 500"
	score_label.add_theme_font_size_override("font_size", 24)
	
	# Position the label in the top-right corner
	var viewport_size = get_viewport().get_visible_rect().size
	score_label.position = Vector2(viewport_size.x - 150, 20)
	
	# Connect to ScoreManager
	ScoreManager.score_changed.connect(_on_score_changed)

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score
