extends Node3D
class_name RaftBuildingSystem

## Main building system for Raft
## Handles grid-based placement, preview, physics integration, and tile management

signal tile_placed(tile: RaftTile, grid_pos: Vector2i)
signal tile_removed(grid_pos: Vector2i)
signal build_mode_started(item_type: String)
signal build_mode_cancelled
signal placement_invalid(reason: String)

# Grid settings
const GRID_SIZE: float = 2.0  # Each tile is 2x2 units
const GRID_HEIGHT: int = 1    # Single layer for now

# References
var crafting_system: CraftingSystem
var inventory_system: Node  # Will be found by group
var water_physics: WaterPhysics
var player: Node3D

# Build state
var is_build_mode_active: bool = false
var current_build_item: String = ""
var current_recipe: Recipes.Recipe = null
var preview_tile: Node3D = null
var ghost_material: StandardMaterial3D

# Placed tiles registry
var placed_tiles: Dictionary = {}  # Vector2i -> RaftTile
var raft_center_of_mass: Vector3 = Vector3.ZERO

# Buildable items configuration
var buildable_items: Dictionary = {}

# Placement validation
var valid_placement_positions: Array[Vector2i] = []
var adjacent_tiles_required: bool = true

# Sound effects
var place_sound: AudioStream
var invalid_sound: AudioStream
var audio_manager: AudioManager

func _ready() -> void:
	add_to_group("building_system")
	_setup_ghost_material()
	_initialize_buildable_items()
	_scan_initial_raft()
	_find_audio_manager()


func _initialize_buildable_items() -> void:
	# Define all buildable raft pieces with their properties
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
			"mesh": null  # Will be set by scene
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
		},
		"window": {
			"category": "Decor",
			"display_name": "Simple Window",
			"description": "Decorative window for roofs",
			"cost": {Recipes.ItemType.WOOD: 8, Recipes.ItemType.GLASS: 4},
			"size": Vector2i(1, 1),
			"is_walkable": false,
			"is_storage": false,
			"max_health": 40.0,
			"repair_cost": {Recipes.ItemType.WOOD: 2, Recipes.ItemType.GLASS: 1},
			"collision_shape": BoxShape3D.new(),
			"mesh": null
		}
	}


func _setup_ghost_material() -> void:
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.3, 1.0, 0.3, 0.5)  # Green transparent
	ghost_material.emission_enabled = true
	ghost_material.emission = Color(0.3, 1.0, 0.3)
	ghost_material.emission_energy_multiplier = 0.5


func _scan_initial_raft() -> void:
	# Scan for existing raft tiles in the scene
	for child in get_children():
		if child is RaftTile:
			_register_existing_tile(child)


func _register_existing_tile(tile: RaftTile) -> void:
	placed_tiles[tile.grid_position] = tile
	_update_raft_center_of_mass()


# ========== BUILD MODE CONTROL ==========

## Start build mode for a specific item
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
	
	# Update valid positions
	_update_valid_placement_positions()
	
	build_mode_started.emit(item_type)
	return true


## Cancel build mode
func cancel_build_mode() -> void:
	if not is_build_mode_active:
		return
	
	is_build_mode_active = false
	current_build_item = ""
	current_recipe = null
	
	# Remove preview tile
	if preview_tile:
		preview_tile.queue_free()
		preview_tile = null
	
	build_mode_cancelled.emit()


## Confirm placement at current position
func confirm_placement() -> bool:
	if not is_build_mode_active or not preview_tile:
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
		# Update grid
		placed_tiles[grid_pos] = tile
		_update_raft_center_of_mass()
		_update_valid_placement_positions()
		
		# Play success feedback
		_play_placement_sound()
		_play_placement_effect(tile.global_position)
		
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
	
	# Check if position is adjacent to existing tiles (unless it's the first foundation)
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
	
	# Check item-specific size requirements
	var item_config = buildable_items.get(item_type)
	if item_config:
		var size = item_config.get("size", Vector2i(1, 1))
		# Check all positions the item would occupy
		for x in range(size.x):
			for z in range(size.y):
				var check_pos = grid_pos + Vector2i(x, z)
				if placed_tiles.has(check_pos):
					return false
	
	return true


# ========== PREVIEW TILE ==========

func _create_preview_tile() -> void:
	if preview_tile:
		preview_tile.queue_free()
	
	preview_tile = Node3D.new()
	preview_tile.name = "PreviewTile"
	preview_tile.set_script(load("res://entities/raft_tile.gd"))
	
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
	if not preview_tile or not player:
		return
	
	# Get position in front of player
	var player_pos = player.global_position
	var forward = -player.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	# Snap to grid
	var target_pos = player_pos + forward * 3.0
	target_pos.y = 0  # Water level
	
	var grid_pos = _world_to_grid(target_pos)
	var snapped_pos = _grid_to_world(grid_pos)
	snapped_pos.y = 0.5  # Slightly above water
	
	preview_tile.global_position = snapped_pos
	
	# Update color based on validity
	var is_valid = _is_valid_placement(grid_pos, current_build_item)
	if is_valid:
		ghost_material.albedo_color = Color(0.3, 1.0, 0.3, 0.5)
		ghost_material.emission = Color(0.3, 1.0, 0.3)
	else:
		ghost_material.albedo_color = Color(1.0, 0.3, 0.3, 0.5)
		ghost_material.emission = Color(1.0, 0.3, 0.3)


# ========== TILE CREATION ==========

func _create_actual_tile(grid_pos: Vector2i) -> RaftTile:
	var item_config = buildable_items.get(current_build_item)
	if not item_config:
		return null
	
	# Create tile node
	var tile = RaftTile.new()
	tile.name = current_build_item + "_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	tile.tile_type = current_build_item
	tile.max_health = item_config.get("max_health", 100.0)
	tile.current_health = tile.max_health
	tile.is_walkable = item_config.get("is_walkable", true)
	tile.is_storage = item_config.get("is_storage", false)
	tile.storage_capacity = item_config.get("storage_capacity", 20)
	tile.repair_cost = item_config.get("repair_cost", {})
	tile.grid_position = grid_pos
	
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box = BoxMesh.new()
	box.size = Vector3(GRID_SIZE - 0.05, 0.3, GRID_SIZE - 0.05)
	mesh_instance.mesh = box
	
	# Set material based on item type
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
	
	# Position tile
	var world_pos = _grid_to_world(grid_pos)
	world_pos.y = 0.5
	tile.global_position = world_pos
	
	# Add to scene
	add_child(tile)
	
	# Setup physics properties for water floating
	tile.mass = 50.0
	tile.linear_damp = 2.0
	tile.angular_damp = 3.0
	tile.freeze = true  # Tiles are static, physics handled by water system
	
	return tile


func _get_tile_material(item_type: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	
	match item_type:
		"foundation":
			mat.albedo_color = Color(0.55, 0.35, 0.2)  # Wood brown
		"bed":
			mat.albedo_color = Color(0.4, 0.25, 0.15)  # Dark wood
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.05, 0.02)
		"storage":
			mat.albedo_color = Color(0.6, 0.4, 0.2)  # Light wood
		"grill":
			mat.albedo_color = Color(0.3, 0.3, 0.3)  # Metal gray
			mat.metallic = 0.8
			mat.roughness = 0.4
		"water_purifier":
			mat.albedo_color = Color(0.2, 0.6, 0.8)  # Blue
			mat.metallic = 0.3
		"garden":
			mat.albedo_color = Color(0.3, 0.5, 0.2)  # Green
		"sail":
			mat.albedo_color = Color(0.9, 0.9, 0.85)  # Canvas white
		"antenna":
			mat.albedo_color = Color(0.5, 0.5, 0.5)  # Metal
			mat.metallic = 0.9
		"engine":
			mat.albedo_color = Color(0.4, 0.4, 0.45)  # Dark metal
			mat.metallic = 0.8
		"rudder":
			mat.albedo_color = Color(0.45, 0.3, 0.2)  # Wood
		"roof":
			mat.albedo_color = Color(0.5, 0.35, 0.2)  # Wood
		"window":
			mat.albedo_color = Color(0.6, 0.8, 0.9, 0.5)  # Glass blue
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_:
			mat.albedo_color = Color(0.5, 0.5, 0.5)
	
	return mat


# ========== RESOURCE MANAGEMENT ==========

func _can_afford_item(item_type: String) -> bool:
	var item_config = buildable_items.get(item_type)
	if not item_config:
		return false
	
	var cost = item_config.get("cost", {})
	
	# Find inventory
	inventory_system = get_tree().get_first_node_in_group("inventory")
	if not inventory_system:
		# Try to get from crafting system
		if crafting_system and crafting_system.inventory:
			inventory_system = crafting_system.inventory
	
	if not inventory_system:
		push_warning("No inventory system found")
		return false  # No inventory to check
	
	# Check each resource
	for item_type_key in cost.keys():
		var required = cost[item_type_key]
		var available = _get_item_count_for_cost(item_type_key)
		if available < required:
			return false
	
	return true


func _deduct_resource_cost(item_type: String) -> bool:
	var item_config = buildable_items.get(item_type)
	if not item_config:
		return false
	
	var cost = item_config.get("cost", {})
	
	if not inventory_system:
		inventory_system = get_tree().get_first_node_in_group("inventory")
		if not inventory_system and crafting_system:
			inventory_system = crafting_system.inventory
	
	if not inventory_system:
		return false
	
	# Deduct each resource - handle both enum and string keys
	for item_type_key in cost.keys():
		var amount = cost[item_type_key]
		# Try direct removal first
		var removed = false
		if inventory_system.has_method("remove_item"):
			removed = inventory_system.remove_item(item_type_key, amount)
		if not removed:
			# Try as string key
			var item_key = str(item_type_key).to_lower()
			if inventory_system.has_method("remove_item"):
				inventory_system.remove_item(item_key, amount)
	
	return true


func _get_item_count(item_type) -> int:
	if not inventory_system:
		return 0
	
	# Handle Recipes.ItemType enum - convert to string key
	var item_key = item_type
	if item_type is Recipes.ItemType:
		item_key = Recipes.get_item_type_name(item_type).to_lower()
		# Try direct enum lookup first
		if inventory_system.has_method("get_item_count"):
			return inventory_system.get_item_count(item_type)
	
	# Try as string key
	if inventory_system.has_method("get_item_count"):
		return inventory_system.get_item_count(item_key)
	elif inventory_system.has_method("get_item_quantity"):
		return inventory_system.get_item_quantity(item_key)
	elif inventory_system.has("items"):
		return inventory_system.items.get(item_key, 0)
	return 0


func _get_item_count_for_cost(item_type) -> int:
	"""Get item count specifically for cost checking - handles both enum and string keys"""
	if not inventory_system:
		return 0
	
	# Try as Recipes.ItemType enum first
	if item_type is Recipes.ItemType:
		if inventory_system.has_method("get_item_count"):
			return inventory_system.get_item_count(item_type)
		elif inventory_system.has_method("get_item_quantity"):
			return inventory_system.get_item_quantity(item_type)
	
	# Handle as string key
	var item_key = str(item_type).to_lower()
	if inventory_system.has_method("get_item_count"):
		# Try the key directly
		var count = inventory_system.get_item_count(item_key)
		if count > 0:
			return count
		# Try lowercase
		count = inventory_system.get_item_count(item_key)
		if count > 0:
			return count
	
	# Fallback: check items dict directly
	if "items" in inventory_system:
		var items = inventory_system.items
		if items.has(item_key):
			return items[item_key]
		# Try with enum name lookup
		if item_type is Recipes.ItemType:
			var enum_name = Recipes.get_item_type_name(item_type).to_lower()
			if items.has(enum_name):
				return items[enum_name]
	
	return 0


func _get_recipe_for_item(item_type: String) -> Recipes.Recipe:
	# Map build item to recipe
	var recipe_id = item_type
	return Recipes.get_recipe_by_id(recipe_id)


# ========== PHYSICS & WATER INTEGRATION ==========

func _update_raft_center_of_mass() -> void:
	if placed_tiles.is_empty():
		raft_center_of_mass = Vector3.ZERO
		return
	
	var total = Vector3.ZERO
	for tile in placed_tiles.values():
		total += tile.global_position
	
	raft_center_of_mass = total / placed_tiles.size()


func register_tile(tile: RaftTile) -> void:
	placed_tiles[tile.grid_position] = tile
	_update_raft_center_of_mass()
	_update_valid_placement_positions()


func unregister_tile(tile: RaftTile, grid_pos: Vector2i) -> void:
	placed_tiles.erase(grid_pos)
	_update_raft_center_of_mass()
	_update_valid_placement_positions()


## Get the raft's total health (average of all tiles)
func get_raft_health_percent() -> float:
	if placed_tiles.is_empty():
		return 1.0
	
	var total_health = 0.0
	for tile in placed_tiles.values():
		total_health += tile.get_health_percent()
	
	return total_health / placed_tiles.size()


## Check if raft can move (has engine and fuel)
func can_raft_move() -> bool:
	for tile in placed_tiles.values():
		if tile.tile_type == "engine" and not tile.is_destroyed:
			return true
	return false


## Get raft propulsion force from engines
func get_raft_thrust() -> Vector3:
	var thrust = Vector3.ZERO
	
	for tile in placed_tiles.values():
		if tile.tile_type == "engine" and not tile.is_destroyed:
			# Engines provide forward thrust
			thrust += Vector3(0, 0, -1) * 20.0  # Base thrust
	
	return thrust


## Get raft steering from rudders
func get_raft_steering() -> float:
	var steering = 0.0
	
	for tile in placed_tiles.values():
		if tile.tile_type == "rudder" and not tile.is_destroyed:
			steering += 1.0
	
	return steering


# ========== AUDIO & VISUALS ==========

func _play_placement_sound() -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("place_building")


func _play_invalid_sound() -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("invalid_action")


func _play_placement_effect(world_pos: Vector3) -> void:
	# Create particle effect at placement position
	# In production: spawn a particle system
	var tween = create_tween()
	# Flash effect
	var mesh = get_node_or_null("Mesh") if preview_tile else null
	if mesh:
		tween.tween_property(mesh, "scale", Vector3.ONE * 1.2, 0.1)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.1)


# ========== PROCESS LOOP ==========

func _process(delta: float) -> void:
	if is_build_mode_active and preview_tile and player:
		_update_preview_position()


func _input(event: InputEvent) -> void:
	if not is_build_mode_active:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("place_building"):
		# Confirm placement
		confirm_placement()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_building"):
		# Cancel build mode
		cancel_build_mode()


# ========== EXTERNAL CONTROL ==========

## Initialize the building system with required references
func initialize(crafting: CraftingSystem, inventory: Node, player_ref: Node3D) -> void:
	crafting_system = crafting
	inventory_system = inventory
	player = player_ref
	
	# Get water physics reference
	water_physics = get_tree().get_first_node_in_group("water")


## Get all placed tiles
func get_placed_tiles() -> Dictionary:
	return placed_tiles


## Get tile at grid position
func get_tile_at(grid_pos: Vector2i) -> RaftTile:
	return placed_tiles.get(grid_pos)


## Remove a tile (for destruction)
func remove_tile(grid_pos: Vector2i) -> bool:
	var tile = placed_tiles.get(grid_pos)
	if not tile:
		return false
	
	tile.queue_free()
	placed_tiles.erase(grid_pos)
	_update_raft_center_of_mass()
	_update_valid_placement_positions()
	
	tile_removed.emit(grid_pos)
	return true


## Get building categories
func get_build_categories() -> Array[String]:
	var categories: Array[String] = []
	for item in buildable_items.values():
		var cat = item.get("category", "Other")
		if cat not in categories:
			categories.append(cat)
	return categories


## Get buildable items by category
func get_items_by_category(category: String) -> Array[String]:
	var items: Array[String] = []
	for item_type in buildable_items.keys():
		if buildable_items[item_type].get("category") == category:
			items.append(item_type)
	return items


## Get item info
func get_item_info(item_type: String) -> Dictionary:
	return buildable_items.get(item_type, {})


## Check if currently in build mode
func is_in_build_mode() -> bool:
	return is_build_mode_active


# ========== SAVE/LOAD ==========

func save_raft_data() -> Dictionary:
	var tiles_data: Array[Dictionary] = []
	
	for grid_pos in placed_tiles.keys():
		var tile = placed_tiles[grid_pos]
		if is_instance_valid(tile):
			tiles_data.append(tile.save_state())
	
	return {
		"tiles": tiles_data,
		"raft_center": {
			"x": raft_center_of_mass.x,
			"y": raft_center_of_mass.y,
			"z": raft_center_of_mass.z
		}
	}


func load_raft_data(data: Dictionary) -> void:
	# Clear existing tiles
	for tile in placed_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	placed_tiles.clear()
	
	# Load tiles
	if data.has("tiles"):
		for tile_data in data["tiles"]:
			var item_type = tile_data.get("tile_type", "foundation")
			var grid_pos = Vector2i(tile_data.get("grid_position", {}).get("x", 0), tile_data.get("grid_position", {}).get("y", 0))
			
			# Temporarily set current build item for tile creation
			var prev_item = current_build_item
			current_build_item = item_type
			
			var tile = _create_actual_tile(grid_pos)
			if tile:
				tile.load_state(tile_data)
				placed_tiles[grid_pos] = tile
			
			current_build_item = prev_item
	
	_update_raft_center_of_mass()
	_update_valid_placement_positions()
