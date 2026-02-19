extends Node3D
class_name WaterPhysics

## Gerstner Wave System for realistic 3D ocean

@export var wave_height: float = 1.0
@export var wave_speed: float = 1.0
@export var wave_frequency: float = 0.1
@export var storm_intensity: float = 0.0

var waves: Array[Dictionary] = []

func _ready() -> void:
	# Initialize 4 Gerstner waves with different parameters
	waves = [
		{"direction": Vector2(1, 0).normalized(), "steepness": 0.25, "wavelength": 60.0},
		{"direction": Vector2(1, 0.6).normalized(), "steepness": 0.2, "wavelength": 31.0},
		{"direction": Vector2(1, -0.4).normalized(), "steepness": 0.15, "wavelength": 18.0},
		{"direction": Vector2(0.7, 1).normalized(), "steepness": 0.1, "wavelength": 10.0}
	]

func _process(delta: float) -> void:
	# Update time-based wave animation
	pass

## Get wave height at world position (for 3D)
func get_wave_height(world_pos: Vector3) -> float:
	var time = Time.get_ticks_msec() / 1000.0 * wave_speed
	var height = 0.0
	
	for i in range(waves.size()):
		var wave = waves[i]
		var dir = wave["direction"]
		var steepness = wave["steepness"] * (1.0 + storm_intensity)
		var wavelength = wave["wavelength"]
		
		var k = 2.0 * PI / wavelength
		var c = sqrt(9.8 / k)
		var d = dir * world_pos.x + dir.y * world_pos.z
		
		height += steepness * wave_height * sin(k * (d - c * time))
	
	return height * (1.0 + storm_intensity * 0.5)

## Get wave normal at position (for 3D)
func get_wave_normal(world_pos: Vector3) -> Vector3:
	var delta = 0.1
	var h = get_wave_height(world_pos)
	var hx = get_wave_height(world_pos + Vector3(delta, 0, 0))
	var hz = get_wave_height(world_pos + Vector3(0, 0, delta))
	
	var tangent_x = Vector3(delta, hx - h, 0).normalized()
	var tangent_z = Vector3(0, hz - h, delta).normalized()
	
	return tangent_z.cross(tangent_x).normalized()

## Get bob offset for floating objects (Vector3 for 3D)
func get_bob_offset(world_pos: Vector3, time_offset: float = 0.0) -> Vector3:
	var time = Time.get_ticks_msec() / 1000.0 * wave_speed + time_offset
	var offset = Vector3.ZERO
	
	for i in range(waves.size()):
		var wave = waves[i]
		var dir = wave["direction"]
		var steepness = wave["steepness"] * (1.0 + storm_intensity)
		var wavelength = wave["wavelength"]
		
		var k = 2.0 * PI / wavelength
		var c = sqrt(9.8 / k)
		var d = dir * world_pos.x + dir.y * world_pos.z
		
		# Vertical displacement
		offset.y += steepness * wave_height * sin(k * (d - c * time))
		
		# Horizontal displacement (roll)
		offset.x += steepness * wave_height * 0.3 * cos(k * (d - c * time))
		offset.z += steepness * wave_height * 0.3 * cos(k * (d - c * time))
	
	return offset * (1.0 + storm_intensity * 0.5)

## Get current vector at position
func get_current(world_pos: Vector3) -> Vector3:
	var time = Time.get_ticks_msec() / 1000.0
	var current = Vector3.ZERO
	
	# Base current direction
	current.x = sin(time * 0.1) * 0.5
	current.z = cos(time * 0.15) * 0.3
	
	# Add turbulence near waves
	current += get_wave_normal(world_pos) * 0.2 * storm_intensity
	
	return current

## Apply wave motion to a RigidBody3D
func apply_wave_motion(body: RigidBody3D) -> void:
	var height = get_wave_height(body.global_position)
	var offset = get_bob_offset(body.global_position)
	
	# Apply gentle push based on current
	body.apply_central_force(get_current(body.global_position) * 10.0)
