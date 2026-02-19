extends RigidBody3D
class_name FloatingDebris

## Floating Debris - 3D floating objects that bob with waves and drift with currents
## Supports: logs, barrels, crates, palm debris, supply bundles

enum DebrisType {
	LOG,
	BARREL,
	CRATE,
	PALM_DEBRIS,
	SUPPLY_BUNDLE
}

## Visual settings
@export var debris_type: DebrisType = DebrisType.LOG
@export var bob_amplitude: float = 0.3
@export var bob_frequency: float = 1.0
@export var rotation_speed: float = 0.1

## Physics settings
@export var drift_speed: float = 1.0
@export var buoyancy: float = 1.0
@export var water_drag: float = 0.95

## References
var water_physics: WaterPhysics = null
var ocean_manager: Node = null
var collectible_data: Dictionary = {}

## State
var is_attached_to_hook: bool = false
var hook_parent: Node3D = null
var base_y: float = 0.0
var time_offset: float = 0.0
var current_drift: Vector3 = Vector3.ZERO
var spawn_time: float = 0.0

## Collision detection
var collision_layer: int = 1
var collision_mask: int = 1

## Audio
var splash_sound: AudioStreamPlayer3D = null
var collect_sound: AudioStreamPlayer3D = null

## Visuals
@onready var mesh_instance: MeshInstance3D = null
@onready var collision_shape: CollisionShape3D = null

func _ready() -> void:
	add_to_group("floating_debris")
	add_to_group("collectible")
	
	# Get water physics reference
	water_physics = get_tree().get_first_node_in_group("water")
	ocean_manager = get_tree().get_first_node_in_group("ocean_manager")
	
	# Random time offset for varied bobbing
	time_offset = randf() * TAU
	spawn_time = Time.get_ticks_msec() / 1000.0
	
	# Setup collision
	_setup_collision()
	
	# Setup visuals
	_setup_visuals()
	
	# Setup audio
	_setup_audio()
	
	# Disable gravity (we handle it manually)
	gravity_scale = 0.0
	
	# Set mass for realistic floating
	mass = _get_debris_mass()
	
	# Linear damping for water resistance
	linear_damp = 2.0
	angular_damp = 1.0


func _physics_process(delta: float) -> void:
	if is_attached_to_hook:
		_process_attached_state(delta)
	else:
		_process_floating_state(delta)


func _process_floating_state(delta: float) -> void:
	if not water_physics:
		return
	
	var world_pos = global_position
	
	# Get wave height for this position
	var wave_height = water_physics.get_wave_height(world_pos)
	
	# Get bob offset for realistic wave motion
	var bob_offset = water_physics.get_bob_offset(world_pos, time_offset)
	
	# Get current for drift
	current_drift = water_physics.get_current(world_pos) * drift_speed
	
	# Apply wave motion to position
	var target_y = wave_height + bob_offset.y * bob_amplitude + base_y
	global_position.y = lerp(global_position.y, target_y, delta * 3.0)
	
	# Apply horizontal drift with current
	global_position.x += current_drift.x * delta
	global_position.z += current_drift.z * delta
	
	# Apply gentle rotation with wave motion
	var rot_offset = water_physics.get_bob_offset(world_pos, time_offset + 0.5)
	rotation.x = lerp(rotation.x, rot_offset.x * 0.1, delta * 2.0)
	rotation.z = lerp(rotation.z, rot_offset.z * 0.1, delta * 2.0)
	
	# Slow rotation for visual interest
	rotation.y += rotation_speed * delta
	
	# Check if too far from player - despawn
	_check_despawn_distance()


func _process_attached_state(delta: float) -> void:
	if is_instance_valid(hook_parent):
		# Follow the hook
		global_position = hook_parent.global_position
		global_rotation = hook_parent.global_rotation


func _check_despawn_distance() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance = global_position.distance_to(player.global_position)
		
		# Despawn if too far (beyond 500 units)
		if distance > 500.0:
			_despawn()
		
		# Spawn new debris if player is in water and far from any objects
		elif ocean_manager and distance < 50.0:
			ocean_manager._on_collectible_collected(global_position)


func _setup_collision() -> void:
	# Create appropriate collision shape based on debris type
	match debris_type:
		DebrisType.LOG:
			var capsule = CapsuleShape3D.new()
			capsule.radius = 0.3
			capsule.height = 3.0
			collision_shape = CollisionShape3D.new()
			collision_shape.shape = capsule
			collision_shape.rotation_degrees.z = 90
			add_child(collision_shape)
		
		DebrisType.BARREL:
			var cylinder = CylinderShape3D.new()
			cylinder.radius = 0.5
			cylinder.height = 1.2
			collision_shape = CollisionShape3D.new()
			collision_shape.shape = cylinder
			add_child(collision_shape)
		
		DebrisType.CRATE:
			var box = BoxShape3D.new()
			box.size = Vector3(1.0, 0.8, 1.0)
			collision_shape = CollisionShape3D.new()
			collision_shape.shape = box
			add_child(collision_shape)
		
		DebrisType.PALM_DEBRIS:
			var box = BoxShape3D.new()
			box.size = Vector3(0.8, 0.3, 0.8)
			collision_shape = CollisionShape3D.new()
			collision_shape.shape = box
			add_child(collision_shape)
		
		DebrisType.SUPPLY_BUNDLE:
			var box = BoxShape3D.new()
			box.size = Vector3(1.2, 0.6, 0.8)
			collision_shape = CollisionShape3D.new()
			collision_shape.shape = box
			add_child(collision_shape)


func _setup_visuals() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	match debris_type:
		DebrisType.LOG:
			mesh_instance.mesh = _create_log_mesh()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.45, 0.3, 0.15)  # Brown
			mat.roughness = 0.9
			mesh_instance.mesh.surface_set_material(0, mat)
		
		DebrisType.BARREL:
			mesh_instance.mesh = _create_barrel_mesh()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.3, 0.35)  # Blue-gray
			mat.roughness = 0.6
			mesh_instance.mesh.surface_set_material(0, mat)
		
		DebrisType.CRATE:
			mesh_instance.mesh = _create_crate_mesh()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.35, 0.2)  # Light brown
			mat.roughness = 0.8
			mesh_instance.mesh.surface_set_material(0, mat)
		
		DebrisType.PALM_DEBRIS:
			mesh_instance.mesh = _create_palm_mesh()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.5, 0.15)  # Green
			mat.roughness = 0.7
			mesh_instance.mesh.surface_set_material(0, mat)
		
		DebrisType.SUPPLY_BUNDLE:
			mesh_instance.mesh = _create_bundle_mesh()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0.5, 0.3)  # Tan
			mat.roughness = 0.7
			mesh_instance.mesh.surface_set_material(0, mat)


func _setup_audio() -> void:
	splash_sound = AudioStreamPlayer3D.new()
	splash_sound.bus = "SFX"
	add_child(splash_sound)
	
	collect_sound = AudioStreamPlayer3D.new()
	collect_sound.bus = "SFX"
	add_child(collect_sound)


## Create mesh primitives
func _create_log_mesh() -> ArrayMesh:
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.3
	mesh.height = 3.0
	mesh.radial_segments = 12
	return mesh


func _create_barrel_mesh() -> ArrayMesh:
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.5
	mesh.height = 1.2
	mesh.radial_segments = 16
	return mesh


func _create_crate_mesh() -> ArrayMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 0.8, 1.0)
	return mesh


func _create_palm_mesh() -> ArrayMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.8, 0.3, 0.8)
	return mesh


func _create_bundle_mesh() -> ArrayMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.2, 0.6, 0.8)
	return mesh


func _get_debris_mass() -> float:
	match debris_type:
		DebrisType.LOG: return 20.0
		DebrisType.BARREL: return 30.0
		DebrisType.CRATE: return 40.0
		DebrisType.PALM_DEBRIS: return 5.0
		DebrisType.SUPPLY_BUNDLE: return 25.0
	return 20.0


## Called when hook hits this debris
func on_hook_hit(hook: Node3D) -> void:
	is_attached_to_hook = true
	hook_parent = hook
	
	# Play grab sound
	if collect_sound and collect_sound.stream:
		collect_sound.play()


## Called when this debris is collected by player
func collect() -> Dictionary:
	# Get loot from collectible data
	var loot = collectible_data.get("contents", {})
	
	# Play collection sound
	if collect_sound and collect_sound.stream:
		collect_sound.play()
	
	# Add to inventory via Collectibles singleton
	var collectibles = get_tree().get_first_node_in_group("collectibles")
	if collectibles:
		collectibles.add_loot(loot)
	
	# Return collected loot for UI feedback
	return loot


## Attach to hook
func attach_to_hook(hook: Node3D) -> void:
	is_attached_to_hook = true
	hook_parent = hook


## Detach from hook
func detach_from_hook() -> void:
	is_attached_to_hook = false
	hook_parent = null


## Set loot contents
func set_contents(contents: Dictionary) -> void:
	collectible_data["contents"] = contents


## Get debris type name
func get_debris_type_name() -> String:
	match debris_type:
		DebrisType.LOG: return "Log"
		DebrisType.BARREL: return "Barrel"
		DebrisType.CRATE: return "Crate"
		DebrisType.PALM_DEBRIS: return "Palm Debris"
		DebrisType.SUPPLY_BUNDLE: return "Supply Bundle"
	return "Unknown"


## Despawn this debris
func _despawn() -> void:
	queue_free()


## Get save data
func get_save_data() -> Dictionary:
	return {
		"type": debris_type,
		"position": global_position,
		"rotation": global_rotation,
		"contents": collectible_data.get("contents", {})
	}


## Load from save data
func load_from_data(data: Dictionary) -> void:
	if data.has("type"):
		debris_type = data["type"]
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("contents"):
		collectible_data["contents"] = data["contents"]
