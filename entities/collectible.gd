extends RigidBody3D
class_name Collectible

## Collectible - Base class for all grab-able items
## Handles hook attachment, collection, and inventory integration

enum CollectibleType {
	RESOURCE,
	FOOD,
	MEDICINE,
	BLUEPRINT,
	TREASURE,
	SPECIAL
}

## Visual settings
@export var collectible_type: CollectibleType = CollectibleType.RESOURCE
@export var item_id: String = ""
@export var item_amount: int = 1
@export var bob_amplitude: float = 0.2
@export var bob_frequency: float = 1.5
@export var rotation_speed: float = 0.5

## Collection settings
@export var collect_range: float = 3.0
@export var hook_grab_range: float = 2.0
@export var auto_collect_distance: float = 2.0
@export var pull_speed: float = 10.0

## State
var is_attached_to_hook: bool = false
var is_being_pulled: bool = false
var hook_parent: Node3D = null
var player_target: Node3D = null
var base_y: float = 0.0
var time_offset: float = 0.0
var collectible_data: Dictionary = {}

## Visual feedback
var glow_material: StandardMaterial3D = nil
var original_material: StandardMaterial3D = nil

## Audio
var hover_sound: AudioStreamPlayer3D = null
var grab_sound: AudioStreamPlayer3D = nil
var collect_sound: AudioStreamPlayer3D = null

## References
var water_physics: WaterPhysics = null
var collectibles_system: Node = null

## Particles
var collect_particles: GPUParticles3D = nil

func _ready() -> void:
	add_to_group("collectible")
	
	# Get references
	water_physics = get_tree().get_first_node_in_group("water")
	collectibles_system = get_tree().get_first_node_in_group("collectibles")
	
	# Random time offset for bobbing
	time_offset = randf() * TAU
	
	# Setup physics
	_setup_collectible_physics()
	
	# Setup visuals
	_setup_collectible_visuals()
	
	# Setup audio
	_setup_collectible_audio()
	
	# Setup particles
	_setup_particles()
	
	# Disable gravity - we handle it
	gravity_scale = 0.0
	linear_damp = 3.0
	angular_damp = 2.0


func _physics_process(delta: float) -> void:
	if is_attached_to_hook:
		_process_hook_attached(delta)
	elif is_being_pulled:
		_process_being_pulled(delta)
	else:
		_process_floating(delta)


func _process_floating(delta: float) -> void:
	if not water_physics:
		return
	
	var world_pos = global_position
	
	# Get wave motion
	var wave_height = water_physics.get_wave_height(world_pos)
	var bob_offset = water_physics.get_bob_offset(world_pos, time_offset)
	
	# Apply bobbing
	var target_y = wave_height + bob_offset.y * bob_amplitude + base_y
	global_position.y = lerp(global_position.y, target_y, delta * 3.0)
	
	# Gentle rotation
	rotation.y += rotation_speed * delta
	
	# Apply current drift
	var current = water_physics.get_current(world_position)
	global_position.x += current.x * delta * 0.5
	global_position.z += current.z * delta * 0.5
	
	# Check if player is nearby for auto-collect
	_check_auto_collect()


func _process_hook_attached(delta: float) -> void:
	if is_instance_valid(hook_parent):
		# Follow the hook
		global_position = hook_parent.global_position
		global_rotation = hook_parent.global_rotation
		
		# Apply slight lag for weight feel
		var direction = (hook_parent.global_position - global_position).normalized()
		if direction.length() > 0.1:
			global_position += direction * pull_speed * delta * 0.5


func _process_being_pulled(delta: float) -> void:
	if not is_instance_valid(player_target):
		is_being_pulled = false
		is_attached_to_hook = false
		return
	
	# Move towards player
	var direction = (player_target.global_position - global_position).normalized()
	var distance = global_position.distance_to(player_target.global_position)
	
	# Pull speed increases as we get closer
	var current_pull_speed = pull_speed * (1.0 + (10.0 / (distance + 1.0)))
	global_position += direction * current_pull_speed * delta
	
	# Spin faster as we get pulled
	rotation.y += rotation_speed * 3.0 * delta
	
	# Check if reached player
	if distance < auto_collect_distance:
		_perform_collection()


func _check_auto_collect() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance < auto_collect_distance:
			_perform_collection()


func _setup_collectible_physics() -> void:
	# Create collision shape
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	
	var collision = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func _setup_collectible_visuals() -> void:
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mesh_instance.mesh = sphere
	
	# Create material based on type
	original_material = StandardMaterial3D.new()
	_apply_type_visuals(original_material)
	mesh_instance.mesh.surface_set_material(0, original_material)
	
	add_child(mesh_instance)


func _apply_type_visuals(material: StandardMaterial3D) -> void:
	match collectible_type:
		CollectibleType.RESOURCE:
			material.albedo_color = Color(0.6, 0.5, 0.3)
			material.emission_enabled = true
			material.emission = Color(0.3, 0.25, 0.15)
			material.emission_energy_multiplier = 0.3
		CollectibleType.FOOD:
			material.albedo_color = Color(0.9, 0.4, 0.3)
			material.emission_enabled = true
			material.emission = Color(0.4, 0.2, 0.1)
			material.emission_energy_multiplier = 0.5
		CollectibleType.MEDICINE:
			material.albedo_color = Color(0.3, 0.9, 0.5)
			material.emission_enabled = true
			material.emission = Color(0.1, 0.4, 0.2)
			material.emission_energy_multiplier = 0.5
		CollectibleType.BLUEPRINT:
			material.albedo_color = Color(0.3, 0.5, 0.9)
			material.emission_enabled = true
			material.emission = Color(0.1, 0.2, 0.5)
			material.emission_energy_multiplier = 0.6
		CollectibleType.TREASURE:
			material.albedo_color = Color(1.0, 0.85, 0.3)
			material.emission_enabled = true
			material.emission = Color(0.5, 0.4, 0.1)
			material.emission_energy_multiplier = 0.8
		CollectibleType.SPECIAL:
			material.albedo_color = Color(0.7, 0.3, 0.8)
			material.emission_enabled = true
			material.emission = Color(0.3, 0.1, 0.4)
			material.emission_energy_multiplier = 0.7
	
	material.roughness = 0.4
	material.metallic = 0.3


func _setup_collectible_audio() -> void:
	hover_sound = AudioStreamPlayer3D.new()
	hover_sound.bus = "SFX"
	hover_sound.volume_db = -10.0
	add_child(hover_sound)
	
	grab_sound = AudioStreamPlayer3D.new()
	grab_sound.bus = "SFX"
	add_child(grab_sound)
	
	collect_sound = AudioStreamPlayer3D.new()
	collect_sound.bus = "SFX"
	add_child(collect_sound)


func _setup_particles() -> void:
	collect_particles = GPUParticles3D.new()
	collect_particles.emitting = false
	collect_particles.amount = 20
	collect_particles.lifetime = 0.5
	collect_particles.explosiveness = 1.0
	
	# Particle process material
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.5
	process_mat.direction = Vector3.UP
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 5.0
	process_mat.gravity = Vector3(0, -5, 0)
	process_mat.scale_min = 0.1
	process_mat.scale_max = 0.3
	
	var particle_mat = StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.albedo_color = Color(1, 0.9, 0.5)
	particle_mat.emission_enabled = true
	particle_mat.emission = Color(1, 0.8, 0.3)
	particle_mat.emission_energy_multiplier = 2.0
	
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.1
	particle_mesh.height = 0.2
	particle_mesh.material = particle_mat
	
	collect_particles.process_material = process_mat
	collect_particles.draw_pass_1 = particle_mesh
	
	add_child(collect_particles)


## Called when hook hits this collectible
func on_hook_hit(hook: Node3D) -> void:
	is_attached_to_hook = true
	hook_parent = hook
	
	# Play grab sound
	_play_sound(grab_sound)
	
	# Visual feedback - pulse
	_pulse_effect()


## Called when hook starts pulling this
func on_hook_pull(hook: Node3D, player: Node3D) -> void:
	is_attached_to_hook = false
	is_being_pulled = true
	hook_parent = null
	player_target = player
	
	# Play pull sound
	_play_sound(grab_sound)


## Called when player collects this
func collect() -> Dictionary:
	return _perform_collection()


func _perform_collection() -> void:
	# Play collection particles
	if collect_particles:
		collect_particles.global_position = global_position
		collect_particles.emitting = true
	
	# Play collection sound
	_play_sound(collect_sound)
	
	# Add to inventory
	var collected_item = {item_id: item_amount}
	if collectibles_system:
		collectibles_system.add_loot(collected_item)
	
	# Emit signal
	emit_signal("collected", item_id, item_amount)
	
	# Despawn
	queue_free()


func _pulse_effect() -> void:
	# Create glow effect
	if not glow_material:
		glow_material = original_material.duplicate()
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.1)


func _play_sound(sound_player: AudioStreamPlayer3D) -> void:
	if sound_player and sound_player.stream:
		sound_player.play()


## Detach from hook
func detach() -> void:
	is_attached_to_hook = false
	is_being_pulled = false
	hook_parent = null
	player_target = null


## Set item data
func set_item(item_id: String, amount: int) -> void:
	self.item_id = item_id
	self.item_amount = amount
	
	# Update visuals based on item type
	_update_visuals_for_item(item_id)


func _update_visuals_for_item(item_id: String) -> void:
	# Update collectible type and visuals based on item
	if collectibles_system:
		var item_def = collectibles_system.get_item_definition(item_id)
		var category = item_def.get("category", 0)
		
		match category:
			0: collectible_type = CollectibleType.RESOURCE  # MATERIAL
			1: collectible_type = CollectibleType.FOOD
			2: collectible_type = CollectibleType.MEDICINE
			3: collectible_type = CollectibleType.TREASURE
		
		# Update material
		var mesh = get_node_or_null("MeshInstance3D")
		if mesh and mesh.mesh and mesh.mesh.get_surface_count() > 0:
			var mat = mesh.mesh.surface_get_material(0)
			if mat:
				_apply_type_visuals(mat)


## Check if hook is in range
func is_hook_in_range(hook_position: Vector3) -> bool:
	return global_position.distance_to(hook_position) < hook_grab_range


## Get collection info for UI
func get_collection_info() -> Dictionary:
	return {
		"item_id": item_id,
		"amount": item_amount,
		"type": CollectibleType.keys()[collectible_type]
	}


## Save data
func get_save_data() -> Dictionary:
	return {
		"item_id": item_id,
		"amount": item_amount,
		"position": global_position,
		"rotation": global_rotation,
		"type": collectible_type
	}


## Load data
func load_from_data(data: Dictionary) -> void:
	if data.has("item_id"):
		item_id = data["item_id"]
	if data.has("amount"):
		item_amount = data["amount"]
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("type"):
		collectible_data = data["type"]
	
	# Apply item visuals
	if item_id != "":
		_update_visuals_for_item(item_id)


## Signal for external listeners
signal collected(item_id: String, amount: int)
