# projectile.gd
extends Node3D

var target: Node3D
var damage: float
var speed: float
var shooter: Node3D

func _ready() -> void:
	var area = $Area3D

func initialize(target_node: Node3D, dmg: float, projectile_speed: float, shooting_node: Node3D) -> void:
	target = target_node
	damage = dmg
	speed = projectile_speed
	shooter = shooting_node

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
		
	var direction = (target.global_position - global_position).normalized()
	var movement = direction * speed * delta
	
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target < 0.5:
		if distance_to_target < 0.2:
			apply_hit(target)
			return
	
	global_position += movement

func apply_hit(body: Node3D) -> void:
	if body.has_node("HealthComponent"):
		var health_comp = body.get_node("HealthComponent")
		var attack = Attack.new(damage, shooter)
		health_comp.damage(attack)
		
		# --- NEW: SIPHON / LIFESTEAL LOGIC ---
		var player = get_tree().get_first_node_in_group("player")
		if player and "turret_siphon_percent" in player and player.turret_siphon_percent > 0:
			# Calculate how much HP to return to the turret
			var heal_amount = damage * player.turret_siphon_percent
			
			# Make sure the turret hasn't been deleted or sold before the bullet hits!
			if is_instance_valid(shooter) and shooter.has_method("repair_step"):
				shooter.repair_step(heal_amount)
				# Optional: You could spawn a small green particle effect here 
				# at the shooter's global_position to represent the souls returning!
		# -------------------------------------
	
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body == target:
		apply_hit(body)

func _on_area_entered(area: Area3D) -> void:
	var parent = area.get_parent()
	if parent == target:
		apply_hit(parent)
