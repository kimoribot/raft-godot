extends Node
class_name RaftPhysics
## Manages all raft tiles as connected system
## Calculates combined center of mass
## Distributes wave forces across all tiles
## Handles tile destruction gracefully

signal tiles_updated(tile_count: int)
signal center_of_mass_changed(new_com: Vector3)
signal raft_state_changed(is_stable: bool)

#== CONFIGURATION ==#
@export_category("Physics Settings")
@export var stiffness: float = 50.0  # How rigidly tiles are connected
@export var damping: float = 5.0     # Velocity damping between tiles
@export var max_angular_deviation: float = 0.1  # Max tilt before correction
@export var force_distribution_weight: float = 0.8  # How much individual tile forces matter

#== STATE ==#
var main_raft: Raft = null
var tile_connections: Array[TileConnection] = []
var center_of_mass: Vector3 = Vector3.ZERO
var total_mass: float = 100.0
var is_stable: bool = true
var physics_enabled: bool = true

# Wave sampling
var wave_sample_timer: float = 0.0
var wave_sample_rate: float = 0.05  # 20 Hz - balance between responsiveness and performance
var cached_wave_data: Dictionary = {}

# Smoothed values for interpolation
var smoothed_velocity: Vector3 = Vector3.ZERO
var smoothed_angular_velocity: Vector3 = Vector3.ZERO
var smoothed_center_offset: Vector3 = Vector3.ZERO

#== TILE CONNECTION CLASS ==#
class TileConnection:
	var tile_a: Node
	var tile_b: Node
	var grid_distance: int
	var connection_strength: float
	
	func _init(t_a: Node, t_b: Node, dist: int):
		tile_a = t_a
		tile_b = t_b
		grid_distance = dist
		# Strength decreases with distance
		connection_strength = 1.0 / float(dist + 1)

func _ready() -> void:
	# Find main raft
	_find_main_raft()

func _find_main_raft() -> void:
	# Search for raft in parent hierarchy
	var parent = get_parent()
	if parent is Raft:
		main_raft = parent
		_initialize_system()
		return
	
	# Search siblings
	for sibling in parent.get_children():
		if sibling is Raft:
			main_raft = sibling
			_initialize_system()
			return
	
	# Search scene
	var scene = get_tree().current_scene
	if scene:
		for child in scene.get_children():
			if child is Raft:
				main_raft = child
				_initialize_system()
				return

func _initialize_system() -> void:
	if main_raft == null:
		return
	
	# Connect to raft signals
	main_raft.tile_added.connect(_on_tile_added)
	main_raft.tile_removed.connect(_on_tile_removed)
	main_raft.tile_destroyed.connect(_on_tile_destroyed)
	
	# Initialize connections
	_rebuild_connections()

func _physics_process(delta: float) -> void:
	if not physics_enabled or main_raft == null:
		return
	
	# Update wave sampling
	wave_sample_timer += delta
	if wave_sample_timer >= wave_sample_rate:
		wave_sample_timer = 0.0
		_sample_waves(delta)
	
	# Calculate forces
	_distribute_wave_forces(delta)
	_apply_inter_tile_forces(delta)
	_update_center_of_mass(delta)
	_stabilize_raft(delta)

func _sample_waves(delta: float) -> void:
	if main_raft.water_physics == null:
		return
	
	var water = main_raft.water_physics
	var tiles = main_raft.get_connected_tiles()
	
	# Sample each tile position
	for tile in tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		
		var world_pos = tile.global_position
		var height = water.get_wave_height(world_pos)
		var normal = water.get_wave_normal(world_pos)
		var bob = water.get_bob_offset(world_pos)
		
		cached_wave_data[tile.get_instance_id()] = {
			"height": height,
			"normal": normal,
			"bob": bob,
			"position": world_pos
		}

func _distribute_wave_forces(delta: float) -> void:
	if main_raft.water_physics == null:
		return
	
	var water = main_raft.water_physics
	var tiles = main_raft.get_connected_tiles()
	
	# Calculate force per tile based on wave position
	var total_wave_force = Vector3.ZERO
	
	for tile in tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		
		var wave_info = cached_wave_data.get(tile.get_instance_id())
		if wave_info == null:
			continue
		
		# Calculate submersion
		var tile_y = tile.global_position.y
		var water_y = wave_info.height
		var submersion = water_y - tile_y + 0.5
		
		if submersion > 0:
			# Buoyancy force
			var buoyancy = Vector3.UP * submersion * main_raft.buoyancy_force * tile.get_buoyancy_factor()
			
			# Wave push force (horizontal)
			var wave_normal = wave_info.normal
			var push_force = Vector3(wave_normal.x, 0, wave_normal.z) * water.storm_intensity * 5.0
			
			# Combined force
			var tile_force = buoyancy + push_force
			
			# Apply with stiffness-based interpolation
			var force_contribution = tile_force * force_distribution_weight
			total_wave_force += force_contribution * (1.0 - force_distribution_weight)
			
			# Apply torque based on wave normal for tilt
			var torque = _calculate_wave_torque(tile, wave_info)
			main_raft.apply_torque(torque * tile.get_buoyancy_factor() * delta)
	
	# Apply distributed force to raft
	main_raft.apply_central_force(total_wave_force)

func _calculate_wave_torque(tile: Node, wave_info: Dictionary) -> Vector3:
	var world_pos = tile.global_position
	var center = main_raft.global_position
	
	# Direction from center to tile
	var arm = world_pos - center
	
	# Wave normal
	var normal = wave_info.normal
	
	# Torque = arm × force direction
	var force_dir = Vector3(normal.x, 0, normal.z).normalized()
	var torque = arm.cross(force_dir) * main_raft.tilt_strength
	
	return torque

func _apply_inter_tile_forces(delta: float) -> void:
	# Apply spring forces between connected tiles
	for connection in tile_connections:
		if not _validate_connection(connection):
			continue
		
		var tile_a = connection.tile_a
		var tile_b = connection.tile_b
		
		# Calculate ideal distance
		var ideal_distance = connection.grid_distance * main_raft.grid_size
		
		# Current distance
		var current_distance = tile_a.global_position.distance_to(tile_b.global_position)
		
		# Spring force
		var displacement = current_distance - ideal_distance
		var direction = (tile_b.global_position - tile_a.global_position).normalized()
		
		var spring_force = direction * displacement * stiffness * connection.connection_strength
		
		# Apply equal and opposite forces
		if tile_a.is_connected:
			tile_a.apply_central_force(spring_force)
		if tile_b.is_connected:
			tile_b.apply_central_force(-spring_force)

func _validate_connection(connection: TileConnection) -> bool:
	return (
		connection.tile_a != null and 
		connection.tile_b != null and 
		is_instance_valid(connection.tile_a) and 
		is_instance_valid(connection.tile_b) and
		connection.tile_a.is_connected and 
		connection.tile_b.is_connected
	)

func _update_center_of_mass(delta: float) -> void:
	var tiles = main_raft.get_connected_tiles()
	
	if tiles.size() == 0:
		center_of_mass = main_raft.global_position
		total_mass = main_raft.mass
		return
	
	var position_sum = Vector3.ZERO
	total_mass = main_raft.mass
	
	for tile in tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		
		position_sum += tile.global_position
		total_mass += tile.mass * tile.get_mass_contribution()
	
	var new_center = position_sum / float(tiles.size()) if tiles.size() > 0 else main_raft.global_position
	
	# Smooth center of mass change
	center_of_mass = center_of_mass.lerp(new_center, delta * 5.0)
	
	# Emit signal if significant change
	var old_com = smoothed_center_offset
	smoothed_center_offset = center_of_mass - main_raft.global_position
	
	if old_com.distance_to(smoothed_center_offset) > 0.1:
		center_of_mass_changed.emit(center_of_mass)

func _stabilize_raft(delta: float) -> void:
	# Apply corrective forces to keep raft stable
	var current_tilt = _get_current_tilt()
	var tilt_magnitude = current_tilt.length()
	
	# Check stability
	var was_stable = is_stable
	is_stable = tilt_magnitude < max_angular_deviation
	
	if was_stable != is_stable:
		raft_state_changed.emit(is_stable)
	
	# Apply stabilization torque if too tilted
	if tilt_magnitude > max_angular_deviation * 0.5:
		var correction = -current_tilt * stiffness * delta * 0.5
		main_raft.apply_torque(correction)
	
	# Dampen angular velocity for smooth motion
	var angular_vel = main_raft.angular_velocity
	main_raft.angular_velocity = angular_vel.lerp(Vector3.ZERO, delta * damping)

func _get_current_tilt() -> Vector3:
	# Get current pitch and roll
	var basis = main_raft.global_transform.basis
	var up = basis.y
	
	# Calculate deviation from world up
	var tilt = Vector3.ZERO
	
	# Pitch (X rotation)
	tilt.x = atan2(-basis.z.y, basis.y)
	
	# Roll (Z rotation)
	tilt.z = atan2(basis.x.y, basis.y)
	
	return tilt

#== CONNECTION MANAGEMENT ==#

func _rebuild_connections() -> void:
	tile_connections.clear()
	
	var tiles = main_raft.get_connected_tiles()
	var tile_count = tiles.size()
	
	# Create connections between adjacent tiles
	for i in range(tile_count):
		for j in range(i + 1, tile_count):
			var tile_a = tiles[i]
			var tile_b = tiles[j]
			
			# Calculate grid distance
			var grid_dist = _calculate_grid_distance(tile_a.grid_position, tile_b.grid_position)
			
			# Only connect if within range
			if grid_dist <= 2:  # Connect to neighbors and diagonals
				var connection = TileConnection.new(tile_a, tile_b, grid_dist)
				tile_connections.append(connection)

func _calculate_grid_distance(pos_a: Vector2i, pos_b: Vector2i) -> int:
	return int(max(abs(pos_a.x - pos_b.x), abs(pos_a.y - pos_b.y)))

#== SIGNAL HANDLERS ==#

func _on_tile_added(tile: Node) -> void:
	_rebuild_connections()
	tiles_updated.emit(main_raft.get_connected_tiles().size())

func _on_tile_removed(tile: Node) -> void:
	# Remove connections involving this tile
	tile_connections = tile_connections.filter(
		func(c): return c.tile_a != tile and c.tile_b != tile
	)
	tiles_updated.emit(main_raft.get_connected_tiles().size())

func _on_tile_destroyed(tile: Node) -> void:
	_on_tile_removed(tile)

#== PUBLIC API ==#

func get_center_of_mass() -> Vector3:
	return center_of_mass

func get_total_mass() -> float:
	return total_mass

func get_raft_stability() -> float:
	return 1.0 - (_get_current_tilt().length() / max_angular_deviation)

func is_raft_stable() -> bool:
	return is_stable

func get_tile_at_grid(grid_pos: Vector2i) -> RaftTile:
	if main_raft == null:
		return null
	return main_raft.get_tile_at(grid_pos)

func get_adjacent_tiles(tile: Node) -> Array[RaftTile]:
	var adjacent: Array[RaftTile] = []
	var tiles = main_raft.get_connected_tiles()
	
	for other in tiles:
		if other == tile:
			continue
		if _calculate_grid_distance(tile.grid_position, other.grid_position) == 1:
			adjacent.append(other)
	
	return adjacent

func get_tile_count() -> int:
	if main_raft == null:
		return 0
	return main_raft.get_connected_tiles().size()

func set_physics_enabled(enabled: bool) -> void:
	physics_enabled = enabled

#== PREDICTION ==#

func predict_wave_position(world_pos: Vector3, time_ahead: float) -> Vector3:
	if main_raft == null or main_raft.water_physics == null:
		return world_pos
	
	var water = main_raft.water_physics
	var future_time = Time.get_ticks_msec() / 1000.0 + time_ahead
	
	# Sample future wave height
	var future_height = water.get_wave_height(world_pos)
	var future_bob = water.get_bob_offset(world_pos)
	
	return Vector3(
		world_pos.x + future_bob.x,
		future_height + 0.5,
		world_pos.z + future_bob.z
	)

func get_buoyancy_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var tiles = main_raft.get_connected_tiles()
	
	for tile in tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		
		# Sample at each corner of tile
		var center = tile.global_position
		var half_size = main_raft.grid_size / 2.0
		
		points.append(center + Vector3(-half_size, 0, -half_size))
		points.append(center + Vector3(half_size, 0, -half_size))
		points.append(center + Vector3(-half_size, 0, half_size))
		points.append(center + Vector3(half_size, 0, half_size))
	
	return points
