# health_component.gd
extends Node

signal health_changed(current_health, max_health)

# Enemy type presets
enum EnemyType {
	BASIC,
	CUBE,
	HEALER  # Added new enemy type for the healer
}

@export var enemy_type: EnemyType = EnemyType.BASIC
@export var MaxHealth: float = 100.0  # Default health

var health: float = MaxHealth
var total_damage: float = 0

func _ready() -> void:
	# Set health based on enemy type
	match enemy_type:
		EnemyType.BASIC:
			MaxHealth = 100.0
		EnemyType.CUBE:
			MaxHealth = 150.0
		EnemyType.HEALER:
			MaxHealth = 80.0  # Maybe make healers a bit weaker
	
	health = MaxHealth
	emit_signal("health_changed", health, MaxHealth)

func heal(amount: float) -> void:
	# Increase health but don't exceed max health
	health = min(health + amount, MaxHealth)
	emit_signal("health_changed", health, MaxHealth)

func damage(attack: Attack) -> void:
	health -= attack.damage
	total_damage += attack.damage
	
	emit_signal("health_changed", health, MaxHealth)
	
	var parent: Node3D = get_parent()
	
	if parent.has_method("on_damage"):
		parent.on_damage(attack)
	
	if health <= 0:
		if parent.has_method("on_death"):
			parent.on_death()
		parent.queue_free()
	
