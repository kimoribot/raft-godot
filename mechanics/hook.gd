extends Node3D
class_name Hook

## Hook - Handles throwing, grabbing, and pulling floating objects
## Integrates with FloatingDebris and Collectible entities

enum State { IDLE, THROWING, STICKING, RETRACTING, GRABBING }

@export var throw_speed: float = 25.0
@export var retract_speed: float = 18.0
@export var max_range: float = 35.0
@export var grab_detection_radius: float = 1.5

var current_state: State = State.IDLE
var throw_direction: Vector3 = Vector3.FORWARD
var target_position: Vector3 = Vector3.ZERO
var current_target: Node3D = null

var player: Node3D = null
var water_physics: WaterPhysics = null

# Detection area
var detection_area: Area3D = null

# Visual components
var hook_mesh: MeshInstance3D = null
var rope_mesh: MeshInstance3D = null
var trail_particles: GPUParticles3D

# Audio
var throw_sound: AudioStreamPlayer3D = null
var grab_sound: AudioStreamPlayer3D = null
var retract_sound: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("hook")
	
	# Get player and water physics references
	player = get_parent()
	water_physics = get_tree().get_first_node_in_group("WaterPhysics")
	if water_physics == null:
		water_physics = get_tree().get_first_node_in_group("water")
	
	_setup_detection_area()
	_setup_visuals()
	_setup_audio()


func _process(delta: float) -> void:
	match current_state:
		State.THROWING:
			_process_throwing(delta)
		State.STICKING:
			_process_sticking(delta)
		State.RETRACTING:
			_process_retracting(delta)
		State.GRABBING:
			_process_grabbing(delta)
	
	# Update rope visualization
	_update_rope(delta)


func _setup_detection_area() -> void:
	detection_area = Area3D.new()
	detection_area.collision_layer = 1
	detection_area.collision_mask = 1
	
	var shape = SphereShape3D.new()
	shape.radius = grab_detection_radius
	
	var collision = CollisionShape3D.new()
	collision.shape = shape
	detection_area.add_child(collision)
	
	detection_area.connect("body_entered", _on_body_entered)
	add_child(detection_area)


func _setup_visuals() -> void:
	# Hook mesh
	hook_mesh = MeshInstance3D.new()
	var hook_shape = BoxMesh.new()
	hook_shape.size = Vector3(0.2, 0.3, 0.1)
	hook_mesh.mesh = hook_shape
	
	var hook_mat = StandardMaterial3D.new()
	hook_mat.albedo_color = Color(0.3, 0.3, 0.35)
	hook_mat.metallic = 0.8
	hook_mat.roughness = 0.3
	hook_mesh.mesh.surface_set_material(0, hook_mat)
	
	add_child(hook_mesh)
	
	# Trail particles
	trail_particles = GPUParticles3D.new()
	trail_particles.emitting = false
	trail_particles.amount = 30
	trail_particles.lifetime = 0.3
	
	var trail_mat = ParticleProcessMaterial.new()
	trail_mat.direction = Vector3.DOWN
	trail_mat.spread = 30.0
	trail_mat.initial_velocity_min = 1.0
	trail_mat.initial_velocity_max = 3.0
	trail_mat.gravity = Vector3(0, -5, 0)
	trail_mat.scale_min = 0.1
	trail_mat.scale_max = 0.2
	
	var particle_mat = StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.albedo_color = Color(0.6, 0.8, 1.0, 0.5)
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	particle_mesh.material = particle_mat
	
	trail_particles.process_material = trail_mat
	trail_particles.draw_pass_1 = particle_mesh
	
	add_child(trail_particles)


func _setup_audio() -> void:
	throw_sound = AudioStreamPlayer3D.new()
	throw_sound.bus = "SFX"
	throw_sound.volume_db = -5.0
	add_child(throw_sound)
	
	grab_sound = AudioStreamPlayer3D.new()
	grab_sound.bus = "SFX"
	add_child(grab_sound)
	
	retract_sound = AudioStreamPlayer3D.new()
	retract_sound.bus = "SFX"
	retract_sound.volume_db = -10.0
	add_child(retract_sound)


func _update_rope(delta: float) -> void:
	# Rope is drawn from player to hook position
	# This would be handled by a Line3D in a real implementation
	pass


## Throw the hook in a direction
func throw_hook(direction: Vector3) -> void:
	if current_state != State.IDLE:
		return
	
	throw_direction = direction.normalized()
	target_position = player.global_position + throw_direction * max_range
	current_state = State.THROWING
	
	# Enable detection area
	detection_area.monitorable = true
	detection_area.monitoring = true
	
	# Play throw sound
	_play_sound(throw_sound)
	
	# Start trail
	trail_particles.emitting = true


func _process_throwing(delta: float) -> void:
	# Move hook forward
	var move_vec = throw_direction * throw_speed * delta
	global_position += move_vec
	
	# Check max range
	if global_position.distance_to(player.global_position) >= max_range:
		current_state = State.RETRACTING
		return
	
	# Check water surface collision
	if water_physics:
		var wave_height = water_physics.get_wave_height(global_position)
		if global_position.y < wave_height - 0.5:
			# Hit water surface - stick briefly
			current_state = State.STICKING
			return
	
	# Detection is handled by Area3D signal


func _on_body_entered(body: Node3D) -> void:
	if current_state != State.THROWING:
		return
	
	# Check if it's a collectible object
	if body.is_in_group("collectible") or body.is_in_group("floating_debris"):
		_grab_object(body)


func _grab_object(body: Node3D) -> void:
	current_target = body
	current_state = State.GRABBING
	
	# Call the object's hook hit method
	if body.has_method("on_hook_hit"):
		body.on_hook_hit(self)
	
	# Play grab sound
	_play_sound(grab_sound)
	
	# Stop trail particles while carrying
	trail_particles.emitting = false


func _process_sticking(delta: float) -> void:
	# Brief pause at max range or water hit, then retract
	# Use a timer-based approach
	await get_tree().create_timer(0.3).timeout
	current_state = State.RETRACTING


func _process_retracting(delta: float) -> void:
	# Calculate direction back to player
	var to_player = (player.global_position - global_position).normalized()
	var distance = global_position.distance_to(player.global_position)
	
	# Move toward player
	global_position += to_player * retract_speed * delta
	
	# Check if close enough to return to idle
	if distance < 2.0 or global_position.distance_to(player.global_position) < 2.0:
		_reset_hook()


func _process_grabbing(delta: float) -> void:
	if not is_instance_valid(current_target):
		current_state = State.RETRACTING
		return
	
	# Move target toward player while keeping hook attached
	var direction = (player.global_position - global_position).normalized()
	var distance = global_position.distance_to(player.global_position)
	
	# Move the hook
	global_position += direction * retract_speed * delta
	
	# Also move the attached object
	current_target.global_position = global_position
	
	# Apply some rotation for visual effect
	current_target.rotation.y += delta * 2.0
	
	# Check if close enough to collect
	if distance < 2.5:
		_collect_target()


func _collect_target() -> void:
	if is_instance_valid(current_target):
		# Call collect method
		if current_target.has_method("collect"):
			current_target.collect()
		elif current_target.has_method("on_hook_pull"):
			# Alternative method for collectibles
			current_target.on_hook_pull(self, player)
		
		# Visual feedback
		_create_collect_effect()
		
		# Play collection sound
		_play_sound(grab_sound)
	
	_reset_hook()


func _create_collect_effect() -> void:
	# Create particle burst at collection point
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.explosiveness = 1.0
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3.UP
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 6.0
	process_mat.gravity = Vector3(0, -8, 0)
	
	var particle_mat = StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.albedo_color = Color(1, 0.9, 0.5)
	particle_mat.emission_enabled = true
	particle_mat.emission = Color(1, 0.8, 0.3)
	particle_mat.emission_energy_multiplier = 3.0
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.material = particle_mat
	
	particles.process_material = process_mat
	particles.draw_pass_1 = mesh
	particles.global_position = global_position
	
	get_tree().current_scene.add_child(particles)
	
	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()


func _reset_hook() -> void:
	current_state = State.IDLE
	current_target = null
	
	# Disable detection
	detection_area.monitorable = false
	detection_area.monitoring = false
	
	# Stop particles
	trail_particles.emitting = false
	
	# Reset position to player
	global_position = player.global_position
	
	# Play retract sound
	_play_sound(retract_sound)


func cancel_hook() -> void:
	# Detach any target
	if is_instance_valid(current_target):
		if current_target.has_method("detach"):
			current_target.detach()
	
	current_state = State.RETRACTING
	current_target = null


func _play_sound(sound_player: AudioStreamPlayer3D) -> void:
	if sound_player and sound_player.stream:
		sound_player.play()


## Check if hook is currently busy
func is_busy() -> bool:
	return current_state != State.IDLE


## Get current state name
func get_state_name() -> String:
	return State.keys()[current_state]


## Get current target info
func get_target_info() -> Dictionary:
	if is_instance_valid(current_target):
		return {
			"valid": true,
			"name": current_target.name,
			"type": current_target.get_class()
		}
	return {"valid": false}
