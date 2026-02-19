extends Node

## Manages ocean debris spawning and collection

@export var spawn_radius: float = 80.0
@export var despawn_radius: float = 100.0
@export var max_debris: int = 30
@export var spawn_interval: float = 5.0

var debris_pool = []
var active_debris = []
var spawn_timer: float = 0.0

# Debris types as constants
enum DebrisType { LOG, BARREL, CRATE, PALM_DEBRIS, SUPPLY_BUNDLE }

var debris_weights = {
	DebrisType.LOG: 30,
	DebrisType.BARREL: 25,
	DebrisType.CRATE: 20,
	DebrisType.PALM_DEBRIS: 15,
	DebrisType.SUPPLY_BUNDLE: 10
}

@onready var ocean = get_parent().get_node("Ocean")

func _ready():
	add_to_group("ocean_manager")
	print("[OceanManager] Initialized with max_debris=", max_debris)

func _process(delta: float):
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0
		if active_debris.size() < max_debris:
			_spawn_random_debris()

func _spawn_random_debris():
	var debris_type = _get_random_debris_type()
	var position = _get_spawn_position()
	_create_debris_instance(debris_type, position)

func _get_random_debris_type() -> int:
	var total = 0
	for w in debris_weights.values():
		total += w
	var rand = randi() % total
	var cumulative = 0
	for type in debris_weights.keys():
		cumulative += debris_weights[type]
		if rand < cumulative:
			return type
	return DebrisType.LOG

func _get_spawn_position() -> Vector3:
	var angle = randf() * PI * 2
	var distance = spawn_radius + randf() * 20
	return Vector3(cos(angle) * distance, 0, sin(angle) * distance)

func _create_debris_instance(debris_type: int, position: Vector3):
	# Simple debris creation without type dependencies
	var debris = RigidBody3D.new()
	debris.position = position + Vector3(0, 0.5, 0)
	debris.add_to_group("debris")
	debris.add_to_group("collectible")
	
	var mesh_inst = MeshInstance3D.new()
	var mesh
	var color
	
	match debris_type:
		DebrisType.LOG:
			mesh = CylinderMesh.new()
			mesh.top_radius = 0.15
			mesh.bottom_radius = 0.12
			mesh.height = 2.5
			color = Color(0.45, 0.3, 0.15)
		DebrisType.BARREL:
			mesh = CylinderMesh.new()
			mesh.top_radius = 0.28
			mesh.bottom_radius = 0.3
			mesh.height = 0.8
			color = Color(0.35, 0.25, 0.15)
		DebrisType.CRATE, DebrisType.SUPPLY_BUNDLE:
			mesh = BoxMesh.new()
			mesh.size = Vector3(0.8, 0.6, 0.8)
			color = Color(0.55, 0.4, 0.25)
		_:
			mesh = BoxMesh.new()
			mesh.size = Vector3(1, 0.5, 1)
			color = Color(0.4, 0.3, 0.2)
	
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	debris.add_child(mesh_inst)
	
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	debris.add_child(shape)
	
	get_parent().add_child(debris)
	active_debris.append(debris)
	print("[OceanManager] Spawned debris at ", position)

func get_debris_near_position(position: Vector3, radius: float):
	var nearby = []
	for debris in active_debris:
		if is_instance_valid(debris) and debris.position.distance_to(position) < radius:
			nearby.append(debris)
	return nearby

func remove_debris(debris):
	if debris in active_debris:
		active_debris.erase(debris)
	if is_instance_valid(debris):
		debris.queue_free()
