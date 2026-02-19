extends Node
class_name RaftBuildingSystem

## Main building system for Raft
## Handles grid-based placement, preview, physics integration, and tile management

signal tile_placed(tile: RaftTile, grid_pos: Vector2i)
signal tile_removed(grid_pos: Vector2i)
signal build_mode_started(item_type: String)
signal build_mode_cancelled
signal placement_invalid(reason: String)
signal resource_updated(item_type: int, count: int)

# Grid settings
const GRID_SIZE: float = 2.0  # Each tile is 2x2 units
const GRID_HEIGHT: int = 1

# References - will be set by initialize()
var main_raft: Raft = null
var water_physics: WaterPhysics = null
var player: Node3D = null
var crafting_system: Node = null

# Build state
var is_build_mode_active: bool = false
var current_build_item: String = ""
var current_recipe: Recipes.Recipe = null
var preview_tile: Node3D = null
var ghost_material: StandardMaterial3D
var invalid_material: StandardMaterial3D

# Tile registry - managed by BuildingManager
var placed_tiles: Dictionary = {}  # Vector2i -> RaftTile

# Buildable items configuration
var buildable_items: Dictionary = {}

# Valid placement positions
var valid_placement_positions: Array[Vector2i] = []
var adjacent_tiles_required: bool = true

# Audio
var audio_manager: AudioManager = null

func _ready() -> void:
	_setup_ghost_materials()
	_initialize_buildable_items()
	_find_references()


func _find_references() -> void:
	# Find main raft
	main_raft = get_tree().get_first_node_in_group("raft")
	if not main_raft:
		# Try to find in parent
		var parent = get_parent()
		if parent and parent is Raft:
			main_raft = parent
	
	# Find water physics
	water_physics = get_tree().get_first_node_in_group("water")
	if not water_physics:
		water_physics = get_tree().get_first_node_in_group("water_physics")
	
	# Find audio
	audio_manager = get_tree().get_first_node_in_group("audio_manager")


func _setup_ghost_materials() -> void:
	# Valid placement (green)
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.3, 1.0, 0.3, 0.5)
	ghost_material.emission_enabled = true
	ghost_material.emission = Color(0.3, 1.0, 0.3)
	ghost_material.emission_energy_multiplier = 0.5
	
	# Invalid placement (red)
	invalid_material = StandardMaterial3D.new()
	invalid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	invalid_material.albedo_color = Color(1.0, 0.3, 0.3, 0.5)
	invalid_material.emission_enabled = true
	invalid_material.emission = Color(1.0, 0.3, 0.3)
	invalid_material.emission_energy_multiplier = 0.5


func _initialize_buildable_items() -> void:
	# Define all buildable raft pieces
	buildable_items = {
		"foundation": {
			"category": "Raft",
			"display_name": "Foundation",
			"description": "Basic raft foundation piece - expands your raft",
			"cost": {Recipes.ItemType.WOOD: 10, Recipes.ItemType.PLASTIC: 4},
			"size": Vector2i(1, 1),
			"is_walkable": true,
			"is_storage": false,
			"max_health": 150.0,
			"repair_cost": {Recipes.ItemType.WOOD: 3, Recipes.ItemType.PLASTIC: 1},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"bed": {
			"category": "Survival",
			"display_name": "Bed",
			"description": "Rest and restore health faster",
			"cost": {Recipes.ItemType.WOOD: 20, Recipes.ItemType.FABRIC: 8, Recipes.ItemType.LEATHER: 4},
			"size": Vector2i(2, 1),
			"is_walkable": true,
			"is_storage": false,
			"max_health": 100.0,
			"repair_cost": {Recipes.ItemType.WOOD: 5, Recipes.ItemType.FABRIC: 2},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"storage": {
			"category": "Storage",
			"display_name": "Storage Box",
			"description": "Store your resources and items",
			"cost": {Recipes.ItemType.WOOD: 15, Recipes.ItemType.PLASTIC: 6},
			"size": Vector2i(1, 1),
			"is_walkable": true,
			"is_storage": true,
			"storage_capacity": 20,
			"max_health": 100.0,
			"repair_cost": {Recipes.ItemType.WOOD: 4, Recipes.ItemType.PLASTIC: 2},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"grill": {
			"category": "Survival",
			"display_name": "Grill",
			"description": "Cook food over an open flame",
			"cost": {Recipes.ItemType.WOOD: 12, Recipes.ItemType.STONE: 8, Recipes.ItemType.METAL: 3},
			"size": Vector2i(1, 1),
			"is_walkable": true,
			"is_storage": false,
			"max_health": 80.0,
			"repair_cost": {Recipes.ItemType.WOOD: 3, Recipes.ItemType.STONE: 2},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"water_purifier": {
			"category": "Survival",
			"display_name": "Water Purifier",
			"description": "Purify dirty water into drinkable water",
			"cost": {Recipes.ItemType.PLASTIC: 10, Recipes.ItemType.GLASS: 4, Recipes.ItemType.METAL: 3},
			"size": Vector2i(1, 1),
			"is_walkable": true,
			"is_storage": false,
			"max_health": 80.0,
			"repair_cost": {Recipes.ItemType.PLASTIC: 3, Recipes.ItemType.GLASS: 1},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"garden": {
			"category": "Survival",
			"display_name": "Garden Patch",
			"description": "Grow your own vegetables",
			"cost": {Recipes.ItemType.WOOD: 15, Recipes.ItemType.FABRIC: 6, Recipes.ItemType.STONE: 5},
			"size": Vector2i(1, 1),
			"is_walkable": true,
			"is_storage": false,
			"max_health": 60.0,
			"repair_cost": {Recipes.ItemType.WOOD: 4, Recipes.ItemType.FABRIC: 2},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"sail": {
			"category": "Raft",
			"display_name": "Sail",
			"description": "Passive movement powered by wind",
			"cost": {Recipes.ItemType.FABRIC: 15, Recipes.ItemType.WOOD: 12, Recipes.ItemType.LEATHER: 5},
			"size": Vector2i(2, 1),
			"is_walkable": false,
			"is_storage": false,
			"max_health": 100.0,
			"repair_cost": {Recipes.ItemType.FABRIC: 4, Recipes.ItemType.WOOD: 3},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"antenna": {
			"category": "Decor",
			"display_name": "Antenna",
			"description": "Detect nearby islands and supplies",
			"cost": {Recipes.ItemType.METAL: 8, Recipes.ItemType.ELECTRONICS: 5, Recipes.ItemType.PLASTIC: 6},
			"size": Vector2i(1, 1),
			"is_walkable": false,
			"is_storage": false,
			"max_health": 60.0,
			"repair_cost": {Recipes.ItemType.METAL: 2, Recipes.ItemType.ELECTRONICS: 1},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"engine": {
			"category": "Raft",
			"display_name": "Engine",
			"description": "Motorized raft propulsion",
			"cost": {Recipes.ItemType.METAL: 25, Recipes.ItemType.ELECTRONICS: 10, Recipes.ItemType.PLASTIC: 15},
			"size": Vector2i(1, 1),
			"is_walkable": false,
			"is_storage": false,
			"max_health": 120.0,
			"repair_cost": {Recipes.ItemType.METAL: 6, Recipes.ItemType.ELECTRONICS: 3},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"rudder": {
			"category": "Raft",
			"display_name": "Rudder",
			"description": "Improved steering control",
			"cost": {Recipes.ItemType.WOOD: 15, Recipes.ItemType.METAL: 8, Recipes.ItemType.PLASTIC: 5},
			"size": Vector2i(1, 1),
			"is_walkable": false,
			"is_storage": false,
			"max_health": 80.0,
			"repair_cost": {Recipes.ItemType.WOOD: 4, Recipes.ItemType.METAL: 2},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		},
		"roof": {
			"category": "Decor",
			"display_name": "Simple Roof",
			"description": "Protection from the elements",
			"cost": {Recipes.ItemType.WOOD: 20, Recipes.ItemType.FABRIC: 10, Recipes.ItemType.PLASTIC: 8},
			"size": Vector2i(2, 2),
			"is_walkable": false,
			"is_storage": false,
			"max_health": 100.0,
			"repair_cost": {Recipes.ItemType.WOOD: 5, Recipes.ItemType.FABRIC: 3},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		}
	}


# ========== INITIALIZATION ==========

func initialize(raft: Raft, player_ref: Node3D = null) -> void:
	main_raft = raft
	player = player_ref
	
	# Scan existing tiles
	_scan_existing_tiles()
	_update_valid_placement_positions()


func _scan_existing_tiles() -> void:
	if not main_raft:
		return
	
	# Get tiles from raft
	var existing_tiles = main_raft.get_connected_tiles()
	for tile in existing_tiles:
		if is_instance_valid(tile):
			placed_tiles[tile.grid_position] = tile


# ========== BUILD MODE CONTROL ==========

func start_build_mode(item_type: String) -> bool:
	if not buildable_items.has(item_type):
		push_error("Unknown build item: " + item_type)
		return false
	
	# Check if player has required resources
	if not _can_afford_item(item_type):
		placement_invalid.emit("Not enough resources")
		return false
	
	is_build_mode_active = true
	current_build_item = item_type
	current_recipe = _get_recipe_for_item(item_type)
	
	# Create preview tile
	_create_preview_tile()
	_update_valid_placement_positions()
	
	build_mode_started.emit(item_type)
	return true


func cancel_build_mode() -> void:
	if not is_build_mode_active:
		return
	
	is_build_mode_active = false
	current_build_item = ""
	current_recipe = null
	
	if is_instance_valid(preview_tile):
		preview_tile.queue_free()
		preview_tile = null
	
	build_mode_cancelled.emit()


func confirm_placement() -> bool:
	if not is_build_mode_active or not is_instance_valid(preview_tile):
		return false
	
	var grid_pos = _world_to_grid(preview_tile.global_position)
	
	# Validate placement
	if not _is_valid_placement(grid_pos, current_build_item):
		placement_invalid.emit("Invalid placement")
		_play_invalid_sound()
		return false
	
	# Deduct resources
	if not _deduct_resource_cost(current_build_item):
		placement_invalid.emit("Not enough resources")
		return false
	
	# Place the tile
	var tile = _create_actual_tile(grid_pos)
	if tile:
		# Register with system
		placed_tiles[grid_pos] = tile
		
		# Connect to main raft physics - THIS IS CRITICAL
		if main_raft:
			main_raft.add_tile(tile, grid_pos)
		
		_update_valid_placement_positions()
		
		_play_placement_sound()
		tile_placed.emit(tile, grid_pos)
		
		# Check if we can afford another
		if not _can_afford_item(current_build_item):
			cancel_build_mode()
		
		return true
	
	return false


# ========== GRID & PLACEMENT ==========

func _world_to_grid(world_pos: Vector3) -> Vector2i:
	var x = round(world_pos.x / GRID_SIZE)
	var z = round(world_pos.z / GRID_SIZE)
	return Vector2i(int(x), int(z))


func _grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * GRID_SIZE, 0, grid_pos.y * GRID_SIZE)


func _update_valid_placement_positions() -> void:
	valid_placement_positions.clear()
	
	# All positions adjacent to existing tiles are valid
	for grid_pos in placed_tiles.keys():
		var neighbors = [
			grid_pos + Vector2i(1, 0),
			grid_pos + Vector2i(-1, 0),
			grid_pos + Vector2i(0, 1),
			grid_pos + Vector2i(0, -1)
		]
		for neighbor in neighbors:
			if not placed_tiles.has(neighbor):
				valid_placement_positions.append(neighbor)


func _is_valid_placement(grid_pos: Vector2i, item_type: String) -> bool:
	# Check if position is already occupied
	if placed_tiles.has(grid_pos):
		return false
	
	# Check adjacency (unless it's the first tile)
	if adjacent_tiles_required and placed_tiles.size() > 0:
		var has_adjacent = false
		var neighbors = [
			grid_pos + Vector2i(1, 0),
			grid_pos + Vector2i(-1, 0),
			grid_pos + Vector2i(0, 1),
			grid_pos + Vector2i(0, -1)
		]
		for neighbor in neighbors:
			if placed_tiles.has(neighbor):
				has_adjacent = true
				break
		if not has_adjacent:
			return false
	
	# Check item size requirements
	var item_config = buildable_items.get(item_type)
	if item_config:
		var size = item_config.get("size", Vector2i(1, 1))
		for x in range(size.x):
			for z in range(size.y):
				var check_pos = grid_pos + Vector2i(x, z)
				if placed_tiles.has(check_pos):
					return false
	
	return true


# ========== PREVIEW TILE ==========

func _create_preview_tile() -> void:
	if is_instance_valid(preview_tile):
		preview_tile.queue_free()
	
	preview_tile = Node3D.new()
	preview_tile.name = "PreviewTile"
	
	# Create mesh for preview
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box = BoxMesh.new()
	box.size = Vector3(GRID_SIZE - 0.1, 0.3, GRID_SIZE - 0.1)
	mesh_instance.mesh = box
	mesh_instance.set_surface_override_material(0, ghost_material)
	preview_tile.add_child(mesh_instance)
	
	add_child(preview_tile)
	_update_preview_position()


func _update_preview_position() -> void:
	if not is_instance_valid(preview_tile) or not is_instance_valid(player):
		return
	
	# Get position in front of player
	var player_pos = player.global_position
	var forward = -player.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	# Snap to grid
	var target_pos = player_pos + forward * 3.0
	target_pos.y = 0
	
	var grid_pos = _world_to_grid(target_pos)
	var snapped_pos = _grid_to_world(grid_pos)
	
	# Get water height for positioning
	var water_height = 0.0
	if water_physics:
		water_height = water_physics.get_wave_height(snapped_pos)
	snapped_pos.y = water_height + 0.5
	
	preview_tile.global_position = snapped_pos
	
	# Update color based on validity
	var is_valid = _is_valid_placement(grid_pos, current_build_item)
	var mesh = preview_tile.get_node_or_null("Mesh")
	if mesh:
		if is_valid:
			mesh.set_surface_override_material(0, ghost_material)
		else:
			mesh.set_surface_override_material(0, invalid_material)


# ========== TILE CREATION ==========

func _create_actual_tile(grid_pos: Vector2i) -> RaftTile:
	var item_config = buildable_items.get(current_build_item)
	if not item_config:
		return null
	
	# Create tile node
	var tile = RaftTile.new()
	tile.name = current_build_item + "_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	tile.tile_name = current_build_item
	tile.tile_description = item_config.get("description", "")
	tile.max_tile_health = item_config.get("max_health", 100.0)
	tile.tile_health = tile.max_tile_health
	tile.grid_size = item_config.get("size", Vector2i(1, 1))
	tile.grid_position = grid_pos
	
	# Set tile type enum
	tile.tile_type = _get_tile_type_enum(current_build_item)
	
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box = BoxMesh.new()
	box.size = Vector3(GRID_SIZE - 0.05, 0.3, GRID_SIZE - 0.05)
	mesh_instance.mesh = box
	
	var mat = _get_tile_material(current_build_item)
	mesh_instance.set_surface_override_material(0, mat)
	tile.add_child(mesh_instance)
	
	# Create collision shape
	var collision = CollisionShape3D.new()
	collision.name = "Collision"
	var shape = BoxShape3D.new()
	shape.size = Vector3(GRID_SIZE - 0.05, 0.3, GRID_SIZE - 0.05)
	collision.shape = shape
	tile.add_child(collision)
	
	# Position tile - calculate world position relative to raft
	if main_raft:
		var raft_transform = main_raft.global_transform
		var local_offset = Vector3(grid_pos.x * GRID_SIZE, 0, grid_pos.y * GRID_SIZE)
		var world_pos = raft_transform * local_offset
		tile.global_position = world_pos
		
		# Connect to raft physics
		tile.connect_to_raft(main_raft, grid_pos)
	else:
		# Fallback if no raft
		var world_pos = _grid_to_world(grid_pos)
		world_pos.y = 0.5
		tile.global_position = world_pos
	
	return tile


func _get_tile_type_enum(item_type: String) -> RaftTile.TileType:
	match item_type:
		"foundation": return RaftTile.TileType.FOUNDATION
		"bed": return RaftTile.TileType.BED
		"storage": return RaftTile.TileType.STORAGE
		"grill": return RaftTile.TileType.GRILL
		"water_purifier": return RaftTile.TileType.WATER_CATCHER
		"garden": return RaftTile.TileType.PLANTER
		"engine": return RaftTile.TileType.ENGINE
		"antenna": return RaftTile.TileType.ANTENNA
		"sail": return RaftTile.TileType.SIMPLE
		"rudder": return RaftTile.TileType.SIMPLE
		"roof": return RaftTile.TileType.SIMPLE
		_: return RaftTile.TileType.SIMPLE


func _get_tile_material(item_type: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	
	match item_type:
		"foundation":
			mat.albedo_color = Color(0.55, 0.35, 0.2)
		"bed":
			mat.albedo_color = Color(0.4, 0.25, 0.15)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.05, 0.02)
		"storage":
			mat.albedo_color = Color(0.6, 0.4, 0.2)
		"grill":
			mat.albedo_color = Color(0.3, 0.3, 0.3)
			mat.metallic = 0.8
			mat.roughness = 0.4
		"water_purifier":
			mat.albedo_color = Color(0.2, 0.6, 0.8)
			mat.metallic = 0.3
		"garden":
			mat.albedo_color = Color(0.3, 0.5, 0.2)
		"sail":
			mat.albedo_color = Color(0.9, 0.9, 0.85)
		"antenna":
			mat.albedo_color = Color(0.5, 0.5, 0.5)
			mat.metallic = 0.9
		"engine":
			mat.albedo_color = Color(0.4, 0.4, 0.45)
			mat.metallic = 0.8
		"rudder":
			mat.albedo_color = Color(0.45, 0.3, 0.2)
		"roof":
			mat.albedo_color = Color(0.5, 0.35, 0.2)
		_:
			mat.albedo_color = Color(0.5, 0.5, 0.5)
	
	return mat


# ========== RESOURCE MANAGEMENT ==========

func _can_afford_item(item_type: String) -> bool:
	var item_config = buildable_items.get(item_type)
	if not item_config:
		return false
	
	var cost = item_config.get("cost", {})
	
	# Get inventory system
	var inventory = get_tree().get_first_node_in_group("inventory")
	if not inventory and crafting_system:
		if crafting_system.has_method("get_inventory"):
			inventory = crafting_system.get_inventory()
	
	if not inventory:
		push_warning("No inventory system found")
		return false
	
	for item_type_key in cost.keys():
		var required = cost[item_type_key]
		var available = _get_item_count(inventory, item_type_key)
		if available < required:
			return false
	
	return true


func _deduct_resource_cost(item_type: String) -> bool:
	var item_config = buildable_items.get(item_type)
	if not item_config:
		return false
	
	var cost = item_config.get("cost", {})
	
	var inventory = get_tree().get_first_node_in_group("inventory")
	if not inventory and crafting_system:
		if crafting_system.has_method("get_inventory"):
			inventory = crafting_system.get_inventory()
	
	if not inventory:
		return false
	
	for item_type_key in cost.keys():
		var amount = cost[item_type_key]
		if inventory.has_method("remove_item"):
			inventory.remove_item(item_type_key, amount)
	
	return true


func _get_item_count(inventory: Node, item_type) -> int:
	if not inventory:
		return 0
	
	if inventory.has_method("get_item_count"):
		return inventory.get_item_count(item_type)
	elif inventory.has_method("get_item_quantity"):
		return inventory.get_item_quantity(item_type)
	elif "items" in inventory:
		var key = str(item_type).to_lower()
		return inventory.items.get(key, 0)
	
	return 0


func _get_recipe_for_item(item_type: String) -> Recipes.Recipe:
	if Recipes.has_method("get_recipe_by_id"):
		return Recipes.get_recipe_by_id(item_type)
	return null


# ========== AUDIO ==========

func _play_placement_sound() -> void:
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("place_building")


func _play_invalid_sound() -> void:
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("invalid_action")


# ========== PROCESS LOOP ==========

func _process(delta: float) -> void:
	if is_build_mode_active and is_instance_valid(preview_tile) and is_instance_valid(player):
		_update_preview_position()


func _unhandled_input(event: InputEvent) -> void:
	if not is_build_mode_active:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("place_building"):
		confirm_placement()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_building"):
		cancel_build_mode()


# ========== PUBLIC API ==========

func initialize_with_player(raft: Raft, player_ref: Node3D, craft_sys: Node = null) -> void:
	main_raft = raft
	player = player_ref
	crafting_system = craft_sys
	
	if raft:
		_scan_existing_tiles()
		_update_valid_placement_positions()


func get_placed_tiles() -> Dictionary:
	return placed_tiles


func get_tile_at(grid_pos: Vector2i) -> RaftTile:
	return placed_tiles.get(grid_pos)


func remove_tile(grid_pos: Vector2i, destroy: bool = true) -> bool:
	var tile = placed_tiles.get(grid_pos)
	if not tile:
		return false
	
	if destroy and main_raft:
		main_raft.destroy_tile(tile)
	elif is_instance_valid(tile):
		tile.queue_free()
	
	placed_tiles.erase(grid_pos)
	_update_valid_placement_positions()
	
	tile_removed.emit(grid_pos)
	return true


func get_build_categories() -> Array[String]:
	var categories: Array[String] = []
	for item in buildable_items.values():
		var cat = item.get("category", "Other")
		if cat not in categories:
			categories.append(cat)
	return categories


func get_items_by_category(category: String) -> Array[String]:
	var items: Array[String] = []
	for item_type in buildable_items.keys():
		if buildable_items[item_type].get("category") == category:
			items.append(item_type)
	return items


func get_item_info(item_type: String) -> Dictionary:
	return buildable_items.get(item_type, {})


func is_in_build_mode() -> bool:
	return is_build_mode_active


func get_current_item() -> String:
	return current_build_item


func get_raft_health_percent() -> float:
	if placed_tiles.is_empty():
		return 1.0
	
	var total_health = 0.0
	for tile in placed_tiles.values():
		if is_instance_valid(tile):
			total_health += tile.tile_health / tile.max_tile_health
	
	return total_health / placed_tiles.size()


# ========== SAVE/LOAD ==========

func save_raft_data() -> Dictionary:
	var tiles_data: Array[Dictionary] = []
	
	for grid_pos in placed_tiles.keys():
		var tile = placed_tiles[grid_pos]
		if is_instance_valid(tile):
			tiles_data.append(tile.get_save_data())
	
	return {
		"tiles": tiles_data
	}


func load_raft_data(data: Dictionary) -> void:
	# Clear existing tiles
	for tile in placed_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	placed_tiles.clear()
	
	if not main_raft:
		return
	
	# Load tiles
	if data.has("tiles"):
		for tile_data in data["tiles"]:
			var item_type = tile_data.get("tile_type", RaftTile.TileType.FOUNDATION)
			var grid_pos = Vector2i(
				tile_data.get("grid_position", {}).get("x", 0),
				tile_data.get("grid_position", {}).get("y", 0)
			)
			
			# Create tile
			var prev_item = current_build_item
			current_build_item = _get_item_type_string(item_type)
			
			var tile = _create_actual_tile(grid_pos)
			if tile and tile_data.has("health"):
				tile.tile_health = tile_data.get("health", tile.max_tile_health)
			
			if tile:
				placed_tiles[grid_pos] = tile
				main_raft.add_tile(tile, grid_pos)
			
			current_build_item = prev_item
	
	_update_valid_placement_positions()


func _get_item_type_string(tile_type) -> String:
	match tile_type:
		RaftTile.TileType.FOUNDATION: return "foundation"
		RaftTile.TileType.BED: return "bed"
		RaftTile.TileType.STORAGE: return "storage"
		RaftTile.TileType.GRILL: return "grill"
		RaftTile.TileType.WATER_CATCHER: return "water_purifier"
		RaftTile.TileType.PLANTER: return "garden"
		RaftTile.TileType.ENGINE: return "engine"
		RaftTile.TileType.ANTENNA: return "antenna"
		_: return "foundation"


# ========== PHYSICS INTEGRATION ==========

func register_tile_with_raft(tile: RaftTile, grid_pos: Vector2i) -> void:
	placed_tiles[grid_pos] = tile
	_update_valid_placement_positions()


func unregister_tile_from_raft(grid_pos: Vector2i) -> void:
	placed_tiles.erase(grid_pos)
	_update_valid_placement_positions()


func get_raft_thrust() -> Vector3:
	var thrust = Vector3.ZERO
	
	for tile in placed_tiles.values():
		if is_instance_valid(tile) and tile.tile_type == RaftTile.TileType.ENGINE:
			thrust += Vector3(0, 0, -1) * 20.0
	
	return thrust


func get_raft_steering() -> float:
	var steering = 0.0
	
	for tile in placed_tiles.values():
		if is_instance_valid(tile) and tile.tile_type == RaftTile.TileType.ANTENNA:
			steering += 1.0
	
	return steering
