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
	
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body == target:
		apply_hit(body)

func _on_area_entered(area: Area3D) -> void:
	var parent = area.get_parent()
	if parent == target:
		apply_hit(parent)
