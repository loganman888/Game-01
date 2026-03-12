# attack.gd
class_name Attack
extends Resource

var damage: float
var attacker: Node

func _init(dmg: float, attacking_node: Node) -> void:
	damage = dmg
	attacker = attacking_node
	
