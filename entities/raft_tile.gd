extends RigidBody3D
class_name RaftTile

## Base class for all raft building pieces
## Handles health, damage, repair, and interaction with physics

signal tile_destroyed(tile: RaftTile)
signal tile_damaged(tile: RaftTile, damage: float)
signal tile_repaired(tile: RaftTile, amount: float)

# Tile properties
@export var tile_type: String = "foundation"
@export var max_health: float = 100.0
@export var repair_cost: Dictionary = {}  # {item_type: count}
@export var is_walkable: bool = true
@export var is_storage: bool = false
@export var storage_capacity: int = 20

# Current state
var current_health: float = 100.0
var is_destroyed: bool = false
var grid_position: Vector2i = Vector2i.ZERO
var placed_at_time: float = 0.0

# Visual
var damage_material: StandardMaterial3D

# References
var raft_center: Vector3

func _ready() -> void:
	current_health = max_health
	placed_at_time = Time.get_ticks_msec() / 1000.0
	
	# Setup collision layer for raft pieces
	collision_layer = 1 << 2  # Layer 3: Raft
	collision_mask = 1 << 1  # Mask layer 2: Water
	
	# Setup mass for realistic floating
	mass = 50.0
	linear_damp = 2.0
	angular_damp = 3.0
	
	# Create damage visual material
	_setup_damage_material()
	
	# Connect to raft system
	_connect_to_raft_system()


func _setup_damage_material() -> void:
	damage_material = StandardMaterial3D.new()
	damage_material.albedo_color = Color(0.8, 0.3, 0.3, 1.0)


func _connect_to_raft_system() -> void:
	var building_system = get_tree().get_first_node_in_group("building_system")
	if building_system:
		building_system.register_tile(self)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	
	# Apply wave motion if we have a reference to water physics
	var water = get_tree().get_first_node_in_group("water")
	if water and water is WaterPhysics:
		var wave_height = water.get_wave_height(global_position)
		var bob_offset = water.get_bob_offset(global_position)
		
		# Smoothly adjust to wave height
		var target_y = wave_height + bob_offset.y
		global_position.y = lerp(global_position.y, target_y, delta * 2.0)
		
		# Apply wave tilt
		var wave_normal = water.get_wave_normal(global_position)
		var target_basis = _basis_from_normal(wave_normal)
		basis = basis.slerp(target_basis, delta * 1.5).orthonormalized()


func _basis_from_normal(normal: Vector3) -> Basis:
	# Create a basis from wave normal
	var up = normal
	var forward = Vector3.FORWARD
	if abs(normal.dot(Vector3.FORWARD)) > 0.99:
		forward = Vector3.RIGHT
	var right = forward.cross(up).normalized()
	forward = up.cross(right).normalized()
	return Basis(right, up, forward)


## Take damage from shark or other sources
func take_damage(amount: float, source: Node = null) -> void:
	if is_destroyed:
		return
	
	current_health -= amount
	tile_damaged.emit(self, amount)
	
	# Visual feedback - flash red
	_play_damage_effect()
	
	# Check for destruction
	if current_health <= 0:
		destroy_tile(source)


## Destroy this tile
func destroy_tile(source: Node = null) -> void:
	if is_destroyed:
		return
	
	is_destroyed = true
	current_health = 0.0
	
	# Visual destruction effect
	_play_destruction_effect()
	
	# Remove from raft compound body
	_remove_from_raft_compound()
	
	# Make tile fall into ocean with physics
	linear_damp = 0.5
	angular_damp = 0.3
	
	# Apply downward force to sink
	apply_central_force(Vector3.DOWN * 100.0)
	
	tile_destroyed.emit(self)
	
	# Notify building system
	var building_system = get_tree().get_first_node_in_group("building_system")
	if building_system:
		building_system.unregister_tile(self, grid_position)


## Repair this tile
func repair(amount: float) -> bool:
	if is_destroyed:
		return false
	
	# Check if we have repair resources
	var inventory = get_tree().get_first_node_in_group("inventory")
	if not inventory:
		return false
	
	for item_type in repair_cost:
		var required = repair_cost[item_type]
		if not inventory.has_item(item_type, required):
			return false
	
	# Deduct resources
	for item_type in repair_cost:
		var cost = repair_cost[item_type]
		inventory.remove_item(item_type, cost)
	
	# Apply repair
	current_health = min(current_health + amount, max_health)
	tile_repaired.emit(self, amount)
	
	# Update visual
	_update_visual_health()
	
	return true


## Get health percentage
func get_health_percent() -> float:
	return current_health / max_health


## Check if tile needs repair
func needs_repair() -> bool:
	return current_health < max_health * 0.5 and not is_destroyed


func _play_damage_effect() -> void:
	# Simple visual feedback - in production would be particle effect
	var mesh = get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		var tween = create_tween()
		var original_color = mesh.get_surface_override_material(0).albedo_color if mesh.get_surface_override_material(0) else Color.WHITE
		tween.tween_property(mesh, "surface_override_material:albedo_color", Color.RED, 0.1)
		tween.tween_property(mesh, "surface_override_material:albedo_color", original_color, 0.2)


func _play_destruction_effect() -> void:
	# Particle effect for destruction
	# In production: spawn debris particles
	pass


func _remove_from_raft_compound() -> void:
	# Remove collision shape from compound body
	# This is handled by the building system
	pass


func _update_visual_health() -> void:
	# Update material based on health
	var mesh = get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		var health_percent = get_health_percent()
		if health_percent < 0.3:
			mesh.set_surface_override_material(0, damage_material)
		else:
			mesh.set_surface_override_material(0, null)  # Reset to default


## Called when player interacts with this tile
func interact(interactor: Node) -> void:
	if is_destroyed:
		return
	
	# Check for repair
	if needs_repair():
		# Show repair prompt
		pass
	
	# Otherwise interact based on tile type
	match tile_type:
		"storage":
			# Open storage UI
			pass
		"bed":
			# Rest functionality
			pass
		"grill", "fireplace":
			# Cooking functionality
			pass


## Save tile state
func save_state() -> Dictionary:
	return {
		"tile_type": tile_type,
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"current_health": current_health,
		"global_position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"transform": {
			"basis_x": [basis.x.x, basis.x.y, basis.x.z],
			"basis_y": [basis.y.x, basis.y.y, basis.y.z],
			"basis_z": [basis.z.x, basis.z.y, basis.z.z]
		},
		"placed_at_time": placed_at_time
	}


## Load tile state
func load_state(data: Dictionary) -> void:
	if data.has("current_health"):
		current_health = data["current_health"]
	
	if data.has("grid_position"):
		grid_position = Vector2i(data["grid_position"]["x"], data["grid_position"]["y"])
	
	if data.has("global_position"):
		var pos = data["global_position"]
		global_position = Vector3(pos["x"], pos["y"], pos["z"])
	
	if data.has("transform"):
		var t = data["transform"]
		basis = Basis(
			Vector3(t["basis_x"][0], t["basis_x"][1], t["basis_x"][2]),
			Vector3(t["basis_y"][0], t["basis_y"][1], t["basis_y"][2]),
			Vector3(t["basis_z"][0], t["basis_z"][1], t["basis_z"][2])
		)
