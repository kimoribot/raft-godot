extends Node3D
class_name WaterPhysics
## Ocean water system with dynamic waves and currents
## Provides wave height calculation, surface normals, and current vectors

# Wave parameters
@export_group("Wave Settings")
@export var wave_height: float = 1.5
@export var wave_frequency: float = 0.5
@export var wave_speed: float = 2.0
@export var wave_steepness: float = 0.4
@export var wave_count: int = 4

# Current parameters
@export_group("Current Settings")
@export var current_direction: Vector2 = Vector2(1.0, 0.0)
@export var current_strength: float = 1.0

# Gerstner wave parameters per wave
var wave_directions: Array[Vector2] = []
var wave_amplitudes: Array[float] = []
var wave_wavelengths: Array[float] = []
var wave_phases: Array[float] = []

# Cached time for performance
var _time: float = 0.0

# Signal for wave updates (for visual shader)
signal wave_updated(time: float, wave_data: Dictionary)

func _ready() -> void:
	_init_waves()


func _init_waves() -> void:
	"""Initialize Gerstner wave parameters"""
	wave_directions.clear()
	wave_amplitudes.clear()
	wave_wavelengths.clear()
	wave_phases.clear()
	
	# Create multiple wave layers for more realistic ocean
	for i in range(wave_count):
		var dir_angle = (PI * 2.0 / wave_count) * i + randf() * 0.5
		var dir = Vector2(cos(dir_angle), sin(dir_angle)).normalized()
		
		# Vary wavelengths for different wave scales
		var wavelength = 10.0 + (i * 5.0) + randf() * 3.0
		var amplitude = wave_height * (0.5 + randf() * 0.5) / (i + 1.0)
		
		wave_directions.append(dir)
		wave_amplitudes.append(amplitude)
		wave_wavelengths.append(wavelength)
		wave_phases.append(randf() * PI * 2.0)


func _physics_process(delta: float) -> void:
	_time += delta
	wave_updated.emit(_time, _get_wave_data_dictionary())


## Get wave height at a specific world position
func get_wave_height(world_pos: Vector3) -> float:
	var height: float = 0.0
	
	for i in range(wave_count):
		var dir = wave_directions[i]
		var k = (PI * 2.0) / wave_wavelengths[i]
		var w = sqrt(9.8 * k) * wave_speed
		var phase = k * dir.dot(Vector2(world_pos.x, world_pos.z)) + w * _time + wave_phases[i]
		
		# Gerstner wave displacement
		height += wave_amplitudes[i] * sin(phase)
	
	return height


## Get surface normal at a specific world position
func get_surface_normal(world_pos: Vector3) -> Vector3:
	var dx: float = 0.0
	var dz: float = 0.0
	
	for i in range(wave_count):
		var dir = wave_directions[i]
		var k = (PI * 2.0) / wave_wavelengths[i]
		var w = sqrt(9.8 * k) * wave_speed
		var phase = k * dir.dot(Vector2(world_pos.x, world_pos.z)) + w * _time + wave_phases[i]
		
		var amplitude = wave_amplitudes[i]
		dx += amplitude * k * dir.x * cos(phase)
		dz += amplitude * k * dir.y * cos(phase)
	
	# Normal is pointing up, tilted by wave slope
	var normal = Vector3(-dx, 1.0, -dz).normalized()
	return normal


## Get current velocity vector at a specific world position
func get_current(world_pos: Vector3) -> Vector3:
	# Base current
	var current = Vector3(current_direction.x, 0, current_direction.y) * current_strength
	
	# Add wave-based turbulence near surface
	var wave_influence = clamp(get_wave_height(world_pos) / wave_height, 0.0, 1.0)
	var turbulence = Vector3(
		sin(_time * 0.5 + world_pos.x * 0.1) * 0.3,
		0,
		cos(_time * 0.4 + world_pos.z * 0.1) * 0.3
	) * wave_influence
	
	return current + turbulence


## Get wave data for shader visualization
func _get_wave_data_dictionary() -> Dictionary:
	return {
		"time": _time,
		"wave_height": wave_height,
		"wave_speed": wave_speed,
		"current_direction": current_direction,
		"current_strength": current_strength
	}


## Apply wave motion to a RigidBody3D (for objects floating on water)
func apply_wave_motion(body: RigidBody3D) -> void:
	var pos = body.global_position
	var water_height = get_wave_height(pos)
	
	# Buoyancy: push object up if below water
	var depth = water_height - pos.y
	if depth > 0:
		var buoyancy_force = Vector3(0, depth * 15.0, 0)
		body.apply_central_force(buoyancy_force)
	
	# Apply current
	var current_force = get_current(pos) * body.mass
	body.apply_central_force(current_force)
	
	# Apply wave torque for rotation alignment
	var surface_normal = get_surface_normal(pos)
	var up_axis = Vector3.UP
	var rotation_axis = up_axis.cross(surface_normal)
	var rotation_torque = rotation_axis * 2.0
	body.apply_torque(rotation_torque)


## Calculate bobbing motion for player/objects on raft
func get_bob_offset(delta_time: float, phase_offset: float = 0.0) -> Vector3:
	var bob_x = 0.0
	var bob_y = 0.0
	var bob_z = 0.0
	
	for i in range(wave_count):
		var dir = wave_directions[i]
		var k = (PI * 2.0) / wave_wavelengths[i]
		var w = sqrt(9.8 * k) * wave_speed
		var t = _time + phase_offset
		
		# Horizontal bob (circular motion)
		bob_x += wave_amplitudes[i] * dir.x * cos(k * 0 + w * t + wave_phases[i]) * wave_steepness
		bob_z += wave_amplitudes[i] * dir.y * cos(k * 0 + w * t + wave_phases[i]) * wave_steepness
		
		# Vertical bob
		bob_y += wave_amplitudes[i] * sin(k * 0 + w * t + wave_phases[i])
	
	return Vector3(bob_x, bob_y, bob_z)


## Get pitch and roll angles based on wave surface
func get_surface_tilt(world_pos: Vector3) -> Vector2:
	var normal = get_surface_normal(world_pos)
	
	# Calculate pitch (forward/back tilt) and roll (left/right tilt)
	var right = Vector3.RIGHT.cross(normal).normalized()
	var forward = Vector3.FORWARD.cross(normal).normalized()
	
	var pitch = atan2(normal.z, normal.y)
	var roll = atan2(normal.x, normal.y)
	
	return Vector2(pitch, roll)


## Set wave parameters dynamically (for gameplay events)
func set_storm_intensity(intensity: float) -> void:
	# intensity: 0.0 (calm) to 1.0 (storm)
	wave_height = lerp(1.5, 4.0, intensity)
	wave_speed = lerp(2.0, 4.0, intensity)
	current_strength = lerp(1.0, 3.0, intensity)


## Check if a position is above water
func is_above_water(world_pos: Vector3, threshold: float = 0.5) -> bool:
	return get_wave_height(world_pos) > world_pos.y - threshold
