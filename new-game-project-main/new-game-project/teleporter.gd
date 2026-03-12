extends Area3D

@export var target_teleporter: NodePath
@export var cooldown_time: float = 1.0
@export var teleport_sound: AudioStream

# References to effect nodes
@onready var audio_player = $AudioStreamPlayer3D
@onready var particles = $GPUParticles3D

var can_teleport: bool = true

func _ready():
	body_entered.connect(_on_body_entered)
	setup_particles()
	setup_audio()
	# Check if audio bus is muted
	print("Audio bus muted: ", AudioServer.is_bus_mute(0))

func setup_particles():
	# Create the particle material
	var particle_material = ParticleProcessMaterial.new()
	
	# Emission settings
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.5
	
	# Direction and movement
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 3.0
	particle_material.gravity = Vector3.ZERO
	
	# Scale settings
	particle_material.scale_min = 0.2
	particle_material.scale_max = 0.3
	
	# Create scale curve
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0))
	scale_curve.add_point(Vector2(0.2, 1))
	scale_curve.add_point(Vector2(1, 0))
	var scale_curve_texture = CurveTexture.new()
	scale_curve_texture.curve = scale_curve
	particle_material.scale_curve = scale_curve_texture
	
	# Create color gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0, 1, 1, 1))  # Cyan
	gradient.add_point(0.5, Color(0, 0.5, 1, 1))  # Blue-cyan
	gradient.add_point(1.0, Color(0, 0, 1, 0))  # Transparent blue
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_material.color_ramp = gradient_texture
	
	# Create particle mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	
	# Create material for the mesh
	var sphere_material = StandardMaterial3D.new()
	sphere_material.emission_enabled = true
	sphere_material.emission = Color(0, 1, 1)  # Cyan
	sphere_material.emission_energy_multiplier = 2.0
	sphere_mesh.material = sphere_material
	
	# Apply settings to particles node
	particles.process_material = particle_material
	particles.draw_pass_1 = sphere_mesh
	particles.amount = 20
	particles.lifetime = 1.0
	particles.explosiveness = 0.8
	particles.randomness = 0.2
	particles.one_shot = false
	particles.emitting = false

func setup_audio():
	pass
		

func _on_body_entered(body: Node3D):
	if body.is_in_group("player") and can_teleport:
		var target = get_node_or_null(target_teleporter)
		if target:
			# Play effects at source teleporter
			play_effects()
			
			# Teleport the player
			body.global_position = target.global_position
			body.velocity.y = 0
			
			# Play effects at destination teleporter
			target.play_effects()
			
			# Disable teleporting on both teleporters
			can_teleport = false
			target.can_teleport = false
			
			# Start cooldown timer
			get_tree().create_timer(cooldown_time).timeout.connect(
				func():
					can_teleport = true
					target.can_teleport = true
			)

func play_effects():
	if audio_player:
		audio_player.play()
	if particles:
		particles.emitting = true
