extends RigidBody3D
class_name Raft
## Main raft entity that holds all building tiles
## Compound RigidBody - all tiles move together
## Uses WaterPhysics to float on ocean waves

signal tile_added(tile: RaftTile)
signal tile_removed(tile: RaftTile)
signal tile_destroyed(tile: RaftTile)
signal raft_moved(direction: Vector3)
signal health_changed(new_health: float)

#== EXPORTS ==#
@export_category("Raft Settings")
@export var max_tiles: int = 64
@export var grid_size: float = 2.0  # Size of each tile slot
@export var raft_name: String = "Raft"

@export_category("Buoyancy")
@export var buoyancy_force: float = 15.0
@export var water_drag: float = 2.0
@export var water_angular_drag: float = 3.0
@export var bob_strength: float = 1.0
@export var tilt_strength: float = 0.8

@export_category("Movement")
@export var paddle_force: float = 20.0
@export var max_speed: float = 8.0
@export var rotation_speed: float = 2.0
@export var drift_speed: float = 0.5

@export_category("Health")
@export var max_health: float = 100.0

#== NODES ==#
@onready var water_physics: WaterPhysics = $"../water_physics" if has_node("../water_physics") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

#== STATE ==#
var tiles: Array[RaftTile] = []
var tile_grid: Dictionary = {}  # Vector2i -> RaftTile
var connected_tiles: Array[RaftTile] = []
var center_of_mass_offset: Vector3 = Vector3.ZERO
var raft_health: float = max_health
var is_destroyed: bool = false

# Physics smoothing
var target_position: Vector3
var target_rotation: Vector3
var current_bob_offset: Vector3 = Vector3.ZERO
var wave_normal: Vector3 = Vector3.UP

# Movement state
var current_input: Vector2 = Vector2.ZERO
var paddle_active: bool = false
var engine_force: Vector3 = Vector3.ZERO

# Wave sampling points (4 corners + center for tilt calculation)
var sample_points: Array[Vector3] = []

func _ready() -> void:
	_setup_rigid_body()
	_initialize_sample_points()
	
	if water_physics == null:
		# Try to find water physics in scene
		water_physics = _find_water_physics()
	
	target_position = global_position
	target_rotation = rotation

func _setup_rigid_body() -> void:
	# Configure for raft-like floating behavior
	mass = 100.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.1
	
	# High linear/angular damping for water resistance
	linear_damp = water_drag
	angular_damp = water_angular_drag
	
	# Continuous collision for stability
	continuous_cd = true
	
	# Freeze when needed
	freeze = false

func _initialize_sample_points() -> void:
	# Sample wave height at 5 points for tilt calculation
	var half_size = (grid_size * 3.0) / 2.0  # Assume 3x3 raft size
	sample_points = [
		Vector3(-half_size, 0, -half_size),  # Back-left
		Vector3(half_size, 0, -half_size),   # Back-right
		Vector3(-half_size, 0, half_size),   # Front-left
		Vector3(half_size, 0, half_size),    # Front-right
		Vector3.ZERO  # Center
	]

func _find_water_physics() -> WaterPhysics:
	var parent = get_parent()
	if parent and parent is WaterPhysics:
		return parent
	
	# Search in parent hierarchy
	var search_nodes = [self]
	while search_nodes.size() > 0:
		var node = search_nodes.pop_front()
		for child in node.get_children():
			if child is WaterPhysics:
				return child
			search_nodes.append(child)
		if node.get_parent():
			search_nodes.append(node.get_parent())
	
	# Create default if not found
	var wp = WaterPhysics.new()
	wp.name = "water_physics"
	get_tree().current_scene.add_child(wp)
	return wp

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	
	_update_wave_physics(delta)
	_apply_paddle_movement(delta)
	_apply_drift(delta)
	_smooth_transform(delta)

func _update_wave_physics(delta: float) -> void:
	if water_physics == null:
		return
	
	var world_pos = global_position
	
	# Get wave data at multiple points for realistic tilt
	var wave_heights: Array[float] = []
	var total_height: float = 0.0
	
	for point in sample_points:
		var world_point = global_transform * point
		var height = water_physics.get_wave_height(world_point)
		wave_heights.append(height)
		total_height += height
	
	# Average height for position
	var avg_height = total_height / float(sample_points.size())
	
	# Get wave normal for tilt
	var new_wave_normal = water_physics.get_wave_normal(world_pos)
	
	# Smooth normal transition to prevent jitter
	wave_normal = wave_normal.lerp(new_wave_normal, delta * 3.0).normalized()
	
	# Calculate target Y position (water surface)
	var target_y = avg_height + 0.5  # Slight offset above water
	
	# Smooth Y position
	var y_diff = target_y - global_position.y
	target_position.y += y_diff * delta * 5.0
	
	# Calculate pitch and roll from wave heights at corners
	var back_left = wave_heights[0]
	var back_right = wave_heights[1]
	var front_left = wave_heights[2]
	var front_right = wave_heights[3]
	
	# Pitch (forward/back tilt)
	var pitch = atan2((front_left + front_right) - (back_left + back_right), grid_size * 2.0)
	
	# Roll (side to side tilt)
	var roll = atan2((front_left + back_left) - (front_right + back_right), grid_size * 2.0)
	
	# Apply tilt strength modifier
	pitch *= tilt_strength
	roll *= tilt_strength
	
	# Smooth rotation
	target_rotation.x = lerp_angle(target_rotation.x, pitch, delta * 4.0)
	target_rotation.z = lerp_angle(target_rotation.z, roll, delta * 4.0)
	
	# Apply buoyancy force based on submersion
	_apply_buoyancy(delta)

func _apply_buoyancy(delta: float) -> void:
	# Calculate buoyancy for each connected tile
	var total_buoyancy = Vector3.ZERO
	var tile_count = connected_tiles.size() if connected_tiles.size() > 0 else 1
	
	for tile in connected_tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		
		var tile_pos = tile.global_position
		var water_height = water_physics.get_wave_height(tile_pos)
		var submersion = water_height - tile_pos.y + 0.5
		
		if submersion > 0:
			var buoyancy = Vector3.UP * submersion * buoyancy_force * tile.get_buoyancy_factor()
			total_buoyancy += buoyancy
	
	# Apply default buoyancy if no tiles
	if connected_tiles.size() == 0:
		var submersion = water_physics.get_wave_height(global_position) - global_position.y + 0.5
		if submersion > 0:
			total_buoyancy = Vector3.UP * submersion * buoyancy_force
	
	apply_central_force(total_buoyancy)

func _apply_paddle_movement(delta: float) -> void:
	if not paddle_active:
		return
	
	var move_direction = Vector3(current_input.x, 0, current_input.y)
	if move_direction.length() < 0.1:
		return
	
	# Transform input to world space based on raft orientation
	var world_direction = global_transform.basis * move_direction
	world_direction = world_direction.normalized()
	
	# Apply paddle force
	var force = world_direction * paddle_force
	
	# Add engine force if available
	force += engine_force
	
	apply_central_force(force)
	
	# Emit movement signal
	raft_moved.emit(world_direction)
	
	# Apply slight rotation when moving
	if current_input.length() > 0.5:
		apply_torque(Vector3.UP * current_input.x * rotation_speed * 0.1)

func _apply_drift(delta: float) -> void:
	if water_physics == null:
		return
	
	# Get ocean current
	var current = water_physics.get_current(global_position)
	var drift_force = current * drift_speed * mass
	
	# Apply drift force
	apply_central_force(drift_force)

func _smooth_transform(delta: float) -> void:
	# Smooth position interpolation
	var new_pos = global_position
	new_pos.y = lerp(global_position.y, target_position.y, delta * 8.0)
	global_position = new_pos
	
	# Smooth rotation interpolation
	var new_rot = rotation
	new_rot.x = lerp_angle(rotation.x, target_rotation.x, delta * 6.0)
	new_rot.z = lerp_angle(rotation.z, target_rotation.z, delta * 6.0)
	rotation = new_rot
	
	# Clamp velocity for stability
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

#== PUBLIC API ==#

func add_tile(tile: RaftTile, grid_position: Vector2i) -> bool:
	if tiles.size() >= max_tiles:
		return false
	
	if tile_grid.has(grid_position):
		return false  # Position already occupied
	
	tiles.append(tile)
	tile_grid[grid_position] = tile
	connected_tiles.append(tile)
	
	# Connect tile to raft
	tile.connect_to_raft(self, grid_position)
	
	# Recalculate center of mass
	_update_center_of_mass()
	
	# Update collision shape
	_update_collision_shape()
	
	tile_added.emit(tile)
	return true

func remove_tile(tile: RaftTile) -> void:
	if not tile in tiles:
		return
	
	# Find and remove from grid
	for key in tile_grid.keys():
		if tile_grid[key] == tile:
			tile_grid.erase(key)
			break
	
	tiles.erase(tile)
	connected_tiles.erase(tile)
	
	# Disconnect tile from raft
	tile.disconnect_from_raft()
	
	# Recalculate center of mass
	_update_center_of_mass()
	
	# Update collision shape
	_update_collision_shape()
	
	tile_removed.emit(tile)

func destroy_tile(tile: RaftTile) -> void:
	if not tile in connected_tiles:
		return
	
	remove_tile(tile)
	
	# Apply impulse to falling tile
	var impulse = Vector3(
		randf_range(-1, 1),
		randf_range(0.5, 1.5),
		randf_range(-1, 1)
	) * 5.0
	tile.apply_central_impulse(impulse)
	
	tile_destroyed.emit(tile)

func get_tile_at(grid_pos: Vector2i) -> RaftTile:
	return tile_grid.get(grid_pos)

func get_connected_tiles() -> Array[RaftTile]:
	return connected_tiles.duplicate()

func get_center_of_mass() -> Vector3:
	return global_position + center_of_mass_offset

func is_position_occupied(grid_pos: Vector2i) -> bool:
	return tile_grid.has(grid_pos)

func get_nearest_grid_position(world_pos: Vector3) -> Vector2i:
	var local_pos = to_local(world_pos)
	return Vector2i(
		round(local_pos.x / grid_size),
		round(local_pos.z / grid_size)
	)

#== MOVEMENT API ==#

func set_paddle_input(direction: Vector2) -> void:
	current_input = direction
	paddle_active = direction.length() > 0.1

func set_engine_force(force: Vector3) -> void:
	engine_force = force

func get_current_velocity() -> Vector3:
	return linear_velocity

func get_speed() -> float:
	return linear_velocity.length()

#== HEALTH API ==#

func damage(amount: float) -> void:
	raft_health = max(0, raft_health - amount)
	health_changed.emit(raft_health)
	
	if raft_health <= 0:
		_destroy_raft()

func heal(amount: float) -> void:
	raft_health = min(max_health, raft_health + amount)
	health_changed.emit(raft_health)

func get_health() -> float:
	return raft_health

func get_health_percentage() -> float:
	return raft_health / max_health

#== INTERNAL ==#

func _update_center_of_mass() -> void:
	if connected_tiles.size() == 0:
		center_of_mass_offset = Vector3.ZERO
		return
	
	var total_pos = Vector3.ZERO
	var total_mass = mass
	
	for tile in connected_tiles:
		if tile != null and is_instance_valid(tile):
			total_pos += tile.global_position
			total_mass += tile.mass
	
	center_of_mass_offset = (total_pos / float(max(1, connected_tiles.size()))) - global_position

func _update_collision_shape() -> void:
	if collision_shape == null:
		return
	
	# Calculate bounding box from tiles
	if tiles.size() == 0:
		# Default raft size
		var box = BoxShape3D.new()
		box.size = Vector3(3, 0.5, 3)
		collision_shape.shape = box
		return
	
	var min_pos = Vector3.INF
	var max_pos = -Vector3.INF
	
	for tile in tiles:
		if tile == null:
			continue
		var tile_pos = tile.global_position
		min_pos = min_pos.min(tile_pos)
		max_pos = max_pos.max(tile_pos)
	
	var size = max_pos - min_pos
	size.y = max(size.y, 1.0)  # Minimum height
	
	var center = (min_pos + max_pos) / 2.0 - global_position
	
	var box = BoxShape3D.new()
	box.size = size
	collision_shape.shape = box
	collision_shape.position = center

func _destroy_raft() -> void:
	is_destroyed = true
	
	# Break apart all tiles
	for tile in connected_tiles.duplicate():
		if tile != null and is_instance_valid(tile):
			tile.disconnect_from_raft()
			# Apply explosion force
			var dir = (tile.global_position - global_position).normalized()
			tile.apply_central_impulse(dir * 10.0 + Vector3.UP * 5.0)
	
	connected_tiles.clear()
	freeze = true

#== PLAYER INTERACTION ==#

func get_player_paddle_target() -> Vector3:
	# Return position where player stands to paddle
	return global_position + global_transform.basis.z * 2.0

func is_player_near_paddle(player_pos: Vector3) -> bool:
	var paddle_pos = get_player_paddle_target()
	return player_pos.distance_to(paddle_pos) < 2.0
