# ScoreManager.gd
extends Node

signal score_changed(new_score: int)
signal purchase_failed

const DEFAULT_SCORE: int = 500  # Default starting score
var current_score: int = DEFAULT_SCORE

func _ready() -> void:
	# Emit initial score
	score_changed.emit(current_score)
	print("ScoreManager initialized with score: ", current_score)

func reset_score() -> void:
	current_score = DEFAULT_SCORE
	score_changed.emit(current_score)
	print("Score reset to default: ", current_score)

func add_score(points: int) -> void:
	current_score += points
	score_changed.emit(current_score)
	print("Score changed by ", points, ". New score: ", current_score)

func get_score() -> int:
	return current_score

func has_enough_points(cost: int) -> bool:
	return current_score >= cost

func purchase_turret(cost: int) -> bool:
	if has_enough_points(cost):
		add_score(-cost)  # Deduct the cost
		print("Turret purchased for ", cost, " points")
		return true
	else:
		purchase_failed.emit()
		print("Purchase failed: Not enough points")
		return false
		
func refund_points(amount: int) -> void:
	current_score += amount
	score_changed.emit(current_score)
	print("Refunded points: ", amount, " (Total score: ", current_score, ")")
