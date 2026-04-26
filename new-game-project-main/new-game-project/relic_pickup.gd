extends Area3D

@export var relic_name: String = "Generic Relic"
@export var relic_icon: Texture2D 

enum RelicType { DISCOUNT, RAPID_FIRE, SIPHONING_SHOT } # Added SIPHONING_SHOTT, RAPID_FIRE }
@export var type: RelicType = RelicType.DISCOUNT
@export var buff_amount: float = 0.2


func apply_relic_buff(player: Node) -> void:
	print("\n[DEBUG] apply_relic_buff() triggered for: ", relic_name)
	
	match type:
		RelicType.DISCOUNT:
			if "turret_cost_multiplier" in player:
				player.turret_cost_multiplier = max(0.1, player.turret_cost_multiplier - buff_amount)
		RelicType.RAPID_FIRE:
			if "turret_fire_rate_multiplier" in player:
				player.turret_fire_rate_multiplier += buff_amount
		# --- NEW LIFESTEAL LOGIC ---
		RelicType.SIPHONING_SHOT:
			if "turret_siphon_percent" in player:
				player.turret_siphon_percent += buff_amount
				print("Siphoning Shot Level Up! Current Lifesteal: ", player.turret_siphon_percent * 100, "%")

	# Update the HUD (make sure the string exactly matches the dictionary!)
	var hud = get_tree().get_first_node_in_group("relic_ui")
	if hud and hud.has_method("add_relic_icon"):
		hud.add_relic_icon(relic_icon, relic_name)
