extends Area3D

@export var relic_name: String = "Generic Relic"
@export var relic_icon: Texture2D 

enum RelicType { DISCOUNT, RAPID_FIRE }
@export var type: RelicType = RelicType.DISCOUNT
@export var buff_amount: float = 0.2

func apply_relic_buff(player: Node) -> void:
	# The Enemy script handles duplicate checking now, 
	# so this script just focuses on applying the goods.
	
	match type:
		RelicType.DISCOUNT:
			if "turret_cost_multiplier" in player:
				player.turret_cost_multiplier -= buff_amount
				print("Applied Discount: ", relic_name)
		RelicType.RAPID_FIRE:
			if "turret_fire_rate_multiplier" in player:
				player.turret_fire_rate_multiplier += buff_amount
				print("Applied Fire Rate: ", relic_name)

	# Update the HUD
	var hud = get_tree().get_first_node_in_group("relic_ui")
	if hud and hud.has_method("add_relic_icon"):
		hud.add_relic_icon(relic_icon, relic_name)
