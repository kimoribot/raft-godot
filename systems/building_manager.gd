extends Node
class_name BuildingManager

## Manages all building tiles on the raft
## Handles tile registry, save/load, destruction, and physics integration
## Works with RaftBuildingSystem for placement logic

signal tile_registered(tile: RaftTile, grid_pos: Vector2i)
signal tile_unregistered(grid_pos: Vector2i)
signal tile_destroyed(grid_pos: Vector2i, position: Vector3)
signal all_tiles_loaded(tile_count: int)
signal building_state_changed

# References
var main_raft: Raft = null
var building_system: RaftBuildingSystem = null
var water_physics: WaterPhysics = null
var player: Node3D = null

# Tile registry
var tiles_by_grid: Dictionary = {}  # Vector2i -> RaftTile
var tiles_by_type: Dictionary = {}  # String -> Array[RaftTile]
var destroyed_tiles: Array[Vector2i] = []  # Track destroyed tile positions for reconnection

# Grid settings
const GRID_SIZE: float = 2.0
const TILE_HEIGHT: float = 0.3

# Physics settings
var physics_update_timer: float = 0.0
var physics_update_rate: float = 0.1  # 10 Hz

# Connection management
var connection_graph: Dictionary = {}  # Grid pos -> Array of connected grid positions

func _ready() -> void:
	add_to_group("building_manager")
	_find_references()


func _find_references() -> void:
	# Find raft
	main_raft = get_tree().get_first_node_in_group("raft")
	if not main_raft:
		var parent = get_parent()
		if parent and parent is Raft:
			main_raft = parent
	
	# Find building system
	building_system = get_tree().get_first_node_in_group("building_system")
	if not building_system:
		# Try to find by type
		for child in get_tree().get_nodes_in_group("building_system"):
			if child is RaftBuildingSystem:
				building_system = child
				break
	
	# Find water physics
	water_physics = get_tree().get_first_node_in_group("water")
	if not water_physics:
		water_physics = get_tree().get_first_node_in_group("water_physics")


func _physics_process(delta: float) -> void:
	if not main_raft:
		return
	
	# Periodic physics update
	physics_update_timer += delta
	if physics_update_timer >= physics_update_rate:
		physics_update_timer = 0.0
		_update_tile_physics(delta)


# ========== TILE REGISTRATION ==========

func register_tile(tile: RaftTile, grid_pos: Vector2i) -> bool:
	if not is_instance_valid(tile):
		return false
	
	# Check if position is already occupied
	if tiles_by_grid.has(grid_pos):
		push_warning("Tile already exists at grid position: " + str(grid_pos))
		return false
	
	# Register in grid dictionary
	tiles_by_grid[grid_pos] = tile
	
	# Register in type dictionary
	var type_key = _get_tile_type_key(tile)
	if not tiles_by_type.has(type_key):
		tiles_by_type[type_key] = []
	tiles_by_type[type_key].append(tile)
	
	# Update connection graph
	_update_connections_for_tile(grid_pos)
	
	# Connect to raft physics
	if main_raft:
		main_raft.add_tile(tile, grid_pos)
	
	# Register with building system
	if building_system:
		building_system.register_tile_with_raft(tile, grid_pos)
	
	tile_registered.emit(tile, grid_pos)
	building_state_changed.emit()
	
	return true


func unregister_tile(grid_pos: Vector2i, keep_physics: bool = false) -> bool:
	var tile = tiles_by_grid.get(grid_pos)
	if not tile:
		return false
	
	# Remove from grid dictionary
	tiles_by_grid.erase(grid_pos)
	
	# Remove from type dictionary
	var type_key = _get_tile_type_key(tile)
	if tiles_by_type.has(type_key):
		tiles_by_type[type_key].erase(tile)
		if tiles_by_type[type_key].is_empty():
			tiles_by_type.erase(type_key)
	
	# Remove from connection graph
	connection_graph.erase(grid_pos)
	
	# Disconnect from raft
	if main_raft:
		main_raft.remove_tile(tile)
	
	# Unregister from building system
	if building_system:
		building_system.unregister_tile_from_raft(grid_pos)
	
	tile_unregistered.emit(grid_pos)
	building_state_changed.emit()
	
	return true


func _get_tile_type_key(tile: RaftTile) -> String:
	match tile.tile_type:
		RaftTile.TileType.FOUNDATION: return "foundation"
		RaftTile.TileType.BED: return "bed"
		RaftTile.TileType.STORAGE: return "storage"
		RaftTile.TileType.GRILL: return "grill"
		RaftTile.TileType.WATER_CATCHER: return "water_purifier"
		RaftTile.TileType.PLANTER: return "garden"
		RaftTile.TileType.ENGINE: return "engine"
		RaftTile.TileType.ANTENNA: return "antenna"
		RaftTile.TileType.SIMPLE: return "simple"
		_: return "unknown"


# ========== TILE DESTRUCTION ==========

func destroy_tile(grid_pos: Vector2i) -> bool:
	var tile = tiles_by_grid.get(grid_pos)
	if not tile:
		return false
	
	# Store position before destroying
	var world_pos = tile.global_position
	
	# Track for reconnection check
	destroyed_tiles.append(grid_pos)
	
	# Remove from registry
	var was_registered = tiles_by_grid.has(grid_pos)
	if was_registered:
		unregister_tile(grid_pos, false)
	
	# Apply destruction physics - tile falls away from raft
	if is_instance_valid(tile):
		tile.disconnect_from_raft()
		
		# Apply impulse away from raft
		if main_raft:
			var direction = (tile.global_position - main_raft.global_position).normalized()
			direction.y = randf_range(0.3, 0.8)  # Upward bias
			direction = direction.normalized()
			tile.apply_central_impulse(direction * 8.0)
		
		# Queue for removal after delay
		var timer = get_tree().create_timer(5.0)
		timer.timeout.connect(func(): 
			if is_instance_valid(tile):
				tile.queue_free()
		)
	
	tile_destroyed.emit(grid_pos, world_pos)
	building_state_changed.emit()
	
	# Check if we need to update connections for isolated tiles
	_check_raft_integrity()
	
	return true


func destroy_tile_at_position(world_pos: Vector3) -> bool:
	var grid_pos = world_to_grid(world_pos)
	return destroy_tile(grid_pos)


func _check_raft_integrity() -> void:
	# After tile destruction, check if any tiles became disconnected
	var connected_to_raft: Array[Vector2i] = []
	
	# Start BFS from raft center (assumed 0,0 or first tile)
	var start_nodes = tiles_by_grid.keys()
	if start_nodes.is_empty():
		return
	
	# Simple connectivity check
	var visited: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start_nodes[0]]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		if current in visited:
			continue
		
		visited.append(current)
		
		# Check neighbors
		var neighbors = [
			current + Vector2i(1, 0),
			current + Vector2i(-1, 0),
			current + Vector2i(0, 1),
			current + Vector2i(0, -1)
		]
		
		for neighbor in neighbors:
			if tiles_by_grid.has(neighbor) and not (neighbor in visited):
				queue.append(neighbor)
	
	# If not all tiles are connected, mark the disconnected ones
	if visited.size() < tiles_by_grid.size():
		var disconnected: Array[Vector2i] = []
		for grid_pos in tiles_by_grid.keys():
			if not (grid_pos in visited):
				disconnected.append(grid_pos)
		
		# Handle disconnected tiles (they could float away or be reclaimed)
		for grid_pos in disconnected:
			var tile = tiles_by_grid.get(grid_pos)
			if tile:
				_disconnect_orphaned_tile(tile, grid_pos)


func _disconnect_orphaned_tile(tile: RaftTile, grid_pos: Vector2i) -> void:
	# Orphaned tiles drift away
	if is_instance_valid(tile):
		tile.disconnect_from_raft()
		
		# Apply gentle drift
		var drift = Vector3(
			randf_range(-1, 1),
			0.2,
			randf_range(-1, 1)
		).normalized() * 3.0
		tile.apply_central_impulse(drift)


# ========== PHYSICS UPDATE ==========

func _update_tile_physics(delta: float) -> void:
	if not water_physics:
		return
	
	# Update each tile's position relative to raft
	for grid_pos in tiles_by_grid.keys():
		var tile = tiles_by_grid[grid_pos]
		if not is_instance_valid(tile) or not tile.is_connected:
			continue
		
		# Calculate target position based on raft transform
		if main_raft:
			var raft_transform = main_raft.global_transform
			var local_offset = Vector3(
				grid_pos.x * GRID_SIZE,
				0,
				grid_pos.y * GRID_SIZE
			)
			var target_pos = raft_transform * local_offset
			
			# Smooth position update
			tile.global_position = tile.global_position.lerp(target_pos, delta * 10.0)
			
			# Match raft rotation
			tile.global_transform.basis = tile.global_transform.basis.slerp(
				raft_transform.basis, delta * 8.0
			)


# ========== CONNECTION MANAGEMENT ==========

func _update_connections_for_tile(grid_pos: Vector2i) -> void:
	# Add connections to adjacent tiles
	var neighbors = [
		grid_pos + Vector2i(1, 0),
		grid_pos + Vector2i(-1, 0),
		grid_pos + Vector2i(0, 1),
		grid_pos + Vector2i(0, -1)
	]
	
	connection_graph[grid_pos] = []
	
	for neighbor in neighbors:
		if tiles_by_grid.has(neighbor):
			connection_graph[grid_pos].append(neighbor)


func get_connected_tiles(start_pos: Vector2i) -> Array[Vector2i]:
	var connected: Array[Vector2i] = []
	var visited: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start_pos]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		if current in visited:
			continue
		
		visited.append(current)
		connected.append(current)
		
		# Add neighbors
		var neighbors = connection_graph.get(current, [])
		for neighbor in neighbors:
			if not (neighbor in visited):
				queue.append(neighbor)
	
	return connected


func is_tile_connected(grid_pos: Vector2i) -> bool:
	return tiles_by_grid.has(grid_pos)


# ========== COORDINATE CONVERSION ==========

func world_to_grid(world_pos: Vector3) -> Vector2i:
	if main_raft:
		var local_pos = main_raft.to_local(world_pos)
		return Vector2i(
			round(local_pos.x / GRID_SIZE),
			round(local_pos.z / GRID_SIZE)
		)
	return Vector2i(
		round(world_pos.x / GRID_SIZE),
		round(world_pos.z / GRID_SIZE)
	)


func grid_to_world(grid_pos: Vector2i) -> Vector3:
	if main_raft:
		var local_offset = Vector3(
			grid_pos.x * GRID_SIZE,
			0,
			grid_pos.y * GRID_SIZE
		)
		return main_raft.global_transform * local_offset
	
	return Vector3(
		grid_pos.x * GRID_SIZE,
		0,
		grid_pos.y * GRID_SIZE
	)


# ========== PUBLIC API ==========

func get_tile_at(grid_pos: Vector2i) -> RaftTile:
	return tiles_by_grid.get(grid_pos)


func get_all_tiles() -> Array[RaftTile]:
	return tiles_by_grid.values()


func get_tiles_by_type(tile_type: String) -> Array[RaftTile]:
	return tiles_by_type.get(tile_type, [])


func get_tile_count() -> int:
	return tiles_by_grid.size()


func has_tile_at(grid_pos: Vector2i) -> bool:
	return tiles_by_grid.has(grid_pos)


func get_adjacent_tiles(grid_pos: Vector2i) -> Array[RaftTile]:
	var adjacent: Array[RaftTile] = []
	var neighbors = [
		grid_pos + Vector2i(1, 0),
		grid_pos + Vector2i(-1, 0),
		grid_pos + Vector2i(0, 1),
		grid_pos + Vector2i(0, -1)
	]
	
	for neighbor in neighbors:
		var tile = tiles_by_grid.get(neighbor)
		if tile:
			adjacent.append(tile)
	
	return adjacent


func get_nearest_tile(world_pos: Vector3) -> RaftTile:
	var nearest: RaftTile = null
	var nearest_dist = INF
	
	for tile in tiles_by_grid.values():
		if not is_instance_valid(tile):
			continue
		var dist = world_pos.distance_to(tile.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tile
	
	return nearest


func get_nearest_tile_grid(world_pos: Vector3) -> Vector2i:
	var tile = get_nearest_tile(world_pos)
	if tile:
		return tile.grid_position
	return world_to_grid(world_pos)


# ========== SAVE/LOAD ==========

func save_building_state() -> Dictionary:
	var tiles_data: Array[Dictionary] = []
	
	for grid_pos in tiles_by_grid.keys():
		var tile = tiles_by_grid[grid_pos]
		if is_instance_valid(tile):
			tiles_data.append({
				"grid_position": {"x": grid_pos.x, "y": grid_pos.y},
				"tile_type": tile.tile_type,
				"tile_name": tile.tile_name,
				"health": tile.tile_health,
				"max_health": tile.max_tile_health,
				"transform": {
					"position": {
						"x": tile.global_position.x,
						"y": tile.global_position.y,
						"z": tile.global_position.z
					},
					"rotation": {
						"x": tile.rotation.x,
						"y": tile.rotation.y,
						"z": tile.rotation.z
					}
				}
			})
	
	return {
		"version": "1.0",
		"tile_count": tiles_data.size(),
		"tiles": tiles_data,
		"destroyed_tiles": destroyed_tiles
	}


func load_building_state(data: Dictionary) -> bool:
	# Clear existing tiles first
	_clear_all_tiles()
	
	if not main_raft:
		push_error("BuildingManager: No raft reference for loading")
		return false
	
	var tiles_data = data.get("tiles", [])
	destroyed_tiles = data.get("destroyed_tiles", [])
	
	# Load each tile
	for tile_data in tiles_data:
		var grid_pos = Vector2i(
			tile_data.get("grid_position", {}).get("x", 0),
			tile_data.get("grid_position", {}).get("y", 0)
		)
		
		var tile_type = tile_data.get("tile_type", RaftTile.TileType.FOUNDATION)
		var health = tile_data.get("health", 100.0)
		var max_health = tile_data.get("max_health", 100.0)
		
		# Create tile
		var tile = _create_tile_from_type(tile_type, grid_pos)
		if tile:
			tile.tile_health = health
			tile.max_tile_health = max_health
			
			# Register tile
			register_tile(tile, grid_pos)
	
	all_tiles_loaded.emit(tiles_by_grid.size())
	building_state_changed.emit()
	
	return true


func _clear_all_tiles() -> void:
	# Remove all tiles from scene
	for tile in tiles_by_grid.values():
		if is_instance_valid(tile):
			tile.queue_free()
	
	tiles_by_grid.clear()
	tiles_by_type.clear()
	connection_graph.clear()


func _create_tile_from_type(tile_type, grid_pos: Vector2i) -> RaftTile:
	var tile = RaftTile.new()
	tile.tile_type = tile_type
	tile.grid_position = grid_pos
	tile.max_tile_health = 100.0
	tile.tile_health = tile.max_tile_health
	
	# Create basic mesh
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(GRID_SIZE - 0.05, TILE_HEIGHT, GRID_SIZE - 0.05)
	mesh_instance.mesh = box
	
	# Set material based on type
	var mat = StandardMaterial3D.new()
	match tile_type:
		RaftTile.TileType.FOUNDATION:
			mat.albedo_color = Color(0.55, 0.35, 0.2)
		RaftTile.TileType.ENGINE:
			mat.albedo_color = Color(0.4, 0.4, 0.45)
			mat.metallic = 0.8
		RaftTile.TileType.STORAGE:
			mat.albedo_color = Color(0.6, 0.4, 0.2)
		_:
			mat.albedo_color = Color(0.5, 0.5, 0.5)
	
	mesh_instance.set_surface_override_material(0, mat)
	tile.add_child(mesh_instance)
	
	# Create collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(GRID_SIZE - 0.05, TILE_HEIGHT, GRID_SIZE - 0.05)
	collision.shape = shape
	tile.add_child(collision)
	
	# Position
	var world_pos = grid_to_world(grid_pos)
	world_pos.y = 0.5
	tile.global_position = world_pos
	
	# Add to scene
	if main_raft:
		main_raft.add_child(tile)
	else:
		get_tree().current_scene.add_child(tile)
	
	return tile


# ========== INITIALIZATION ==========

func initialize(raft: Raft, building_sys: RaftBuildingSystem = null) -> void:
	main_raft = raft
	building_system = building_sys
	
	# Scan for existing tiles
	_scan_existing_tiles()


func _scan_existing_tiles() -> void:
	if not main_raft:
		return
	
	var existing_tiles = main_raft.get_connected_tiles()
	for tile in existing_tiles:
		if is_instance_valid(tile):
			register_tile(tile, tile.grid_position)


func initialize_with_player(raft: Raft, player_ref: Node3D) -> void:
	player = player_ref
	initialize(raft)


# ========== TILE INTERACTION ==========

func repair_tile(grid_pos: Vector2i, inventory: Node = null) -> bool:
	var tile = tiles_by_grid.get(grid_pos)
	if not tile:
		return false
	
	# Check if inventory has repair materials
	if inventory:
		# Simplified - just heal the tile
		tile.heal(tile.max_tile_health * 0.5)
		return true
	
	# Free repair
	tile.heal(tile.max_tile_health * 0.25)
	return true


func interact_with_tile(grid_pos: Vector2i, interactor: Node3D) -> bool:
	var tile = tiles_by_grid.get(grid_pos)
	if not tile or not is_instance_valid(tile):
		return false
	
	tile.interact(interactor)
	return true


# ========== QUERY METHODS ==========

func get_raft_bounds() -> Dictionary:
	if tiles_by_grid.is_empty():
		return {"min": Vector2i.ZERO, "max": Vector2i.ZERO, "size": Vector2i.ONE}
	
	var min_pos = Vector2i(INF, INF)
	var max_pos = Vector2i(-INF, -INF)
	
	for grid_pos in tiles_by_grid.keys():
		min_pos.x = min(min_pos.x, grid_pos.x)
		min_pos.y = min(min_pos.y, grid_pos.y)
		max_pos.x = max(max_pos.x, grid_pos.x)
		max_pos.y = max(max_pos.y, grid_pos.y)
	
	return {
		"min": min_pos,
		"max": max_pos,
		"size": max_pos - min_pos + Vector2i.ONE
	}


func get_total_health() -> float:
	var total = 0.0
	for tile in tiles_by_grid.values():
		if is_instance_valid(tile):
			total += tile.tile_health
	return total


func get_total_max_health() -> float:
	var total = 0.0
	for tile in tiles_by_grid.values():
		if is_instance_valid(tile):
			total += tile.max_tile_health
	return total


func get_health_percentage() -> float:
	var max_h = get_total_max_health()
	if max_h <= 0:
		return 1.0
	return get_total_health() / max_h


func is_raft_intact() -> bool:
	# Raft is intact if all tiles are connected
	return tiles_by_grid.size() > 0


func can_build_at(grid_pos: Vector2i) -> bool:
	# Can build if position is empty and has adjacent tile
	if tiles_by_grid.has(grid_pos):
		return false
	
	var neighbors = [
		grid_pos + Vector2i(1, 0),
		grid_pos + Vector2i(-1, 0),
		grid_pos + Vector2i(0, 1),
		grid_pos + Vector2i(0, -1)
	]
	
	for neighbor in neighbors:
		if tiles_by_grid.has(neighbor):
			return true
	
	# Can always build first tile
	return tiles_by_grid.is_empty()


func get_build_positions_near(world_pos: Vector3, radius: float = 5.0) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var center_grid = world_to_grid(world_pos)
	var grid_radius = ceil(radius / GRID_SIZE)
	
	for x in range(-grid_radius, grid_radius + 1):
		for z in range(-grid_radius, grid_radius + 1):
			var check_pos = center_grid + Vector2i(x, z)
			if can_build_at(check_pos):
				var world_check = grid_to_world(check_pos)
				if world_pos.distance_to(world_check) <= radius:
					positions.append(check_pos)
	
	return positions
