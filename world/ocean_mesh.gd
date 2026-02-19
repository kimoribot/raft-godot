extends Node3D
class_name OceanMesh

## Creates a proper 3D ocean mesh with wave displacement

@export var ocean_size: float = 500.0
@export var subdivisions: int = 128  # More subdivisions = smoother waves
@export var wave_height: float = 1.5
@export var wave_speed: float = 0.5
@export var wave_frequency: float = 0.1

var mesh_instance: MeshInstance3D
var shader_material: ShaderMaterial

func _ready() -> void:
	_create_ocean_mesh()

func _create_ocean_mesh() -> void:
	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "OceanMesh3D"
	add_child(mesh_instance)
	
	# Create subdivided plane mesh for proper wave displacement
	var plane = PlaneMesh.new()
	plane.size = Vector2(ocean_size, ocean_size)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh_instance.mesh = plane
	
	# Create shader material
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://shaders/ocean.gdshader")
	
	# Set shader parameters
	shader_material.set_shader_parameter("wave_height", wave_height)
	shader_material.set_shader_parameter("wave_speed", wave_speed)
	shader_material.set_shader_parameter("wave_frequency", wave_frequency)
	
	mesh_instance.material_override = shader_material
	
	# Position below everything
	mesh_instance.position.y = -1.0

func set_wave_parameters(height: float, speed: float, frequency: float) -> void:
	wave_height = height
	wave_speed = speed
	wave_frequency = frequency
	
	if shader_material:
		shader_material.set_shader_parameter("wave_height", height)
		shader_material.set_shader_parameter("wave_speed", speed)
		shader_material.set_shader_parameter("wave_frequency", frequency)

func set_storm_intensity(intensity: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("storm_intensity", intensity)
