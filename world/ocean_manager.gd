extends Node3D
class_name OceanManager

## Ocean Manager - Manages spawning, despawning, and pooling of floating debris
## Handles currents, spawn rates, and island proximity bonuses

## Singleton reference
static var instance: OceanManager

## Spawn settings
@export var spawn_radius_min: float = 30.0
@export var spawn_radius_max: float = 150.0
@export var despawn_distance: float = 500.0
@export var base_spawn_interval: float = 5.0
@export var max_active_debris: int = 50

## Current settings
@export var current_strength: float = 1.0
@export var current_variation: float = 0.3

## Island proximity settings
@export var island_spawn_bonus: float = 2.0
@export var island_detection_radius: float = 200.0

## Object pooling
var debris_pool: Array[FloatingDebris] = []
var active_debris: Array[FloatingDebris] = []

## Spawn timers
var spawn_timer: float = 0.0
var current_spawn_interval: float = 5.0

## Player reference
var player: Node3D = null
var water_physics: WaterPhysics = null

## Island positions
var island_positions: Array[Vector3] = []

## Loot table weights
var debris_type_weights: Dictionary = {
	FloatingDebris.DebrisType.LOG: 30,
	FloatingDebris.DebrisType.BARREL: 25,
	FloatingDebris.DebrisType.CRATE: 20,
	FloatingDebris.DebrisType.PALM_DEBRIS: 15,
	FloatingDebris.DebrisType.SUPPLY_BUNDLE: 10
}

## Loot tables
var loot_tables: Dictionary = {}

## Debris scene for instantiation (we create procedurally if not set)
var debris_scene: PackedScene = null

signal debris_spawned(debris: FloatingDebris)
signal debris_collected(debris: FloatingDebris, loot: Dictionary)
signal debris_despawned(debris: FloatingDebris)

func _ready() -> void:
	add_to_group("ocean_manager")
	instance = self
	
	# Get references
	player = get_tree().get_first_node_in_group("player")
	water_physics = get_tree().get_first_node_in_group("water")
	
	# Initialize loot tables
	_initialize_loot_tables()
	
	# Pre-populate pool
	_prepopulate_pool(20)
	
	# Spawn initial debris around player
	_spawn_initial_debris(30)


func _process(delta: float) -> void:
	# Update spawn timer
	spawn_timer += delta
	if spawn_timer >= current_spawn_interval:
		spawn_timer = 0.0
		_spawn_debris_near_player()
	
	# Update active debris
	_update_debris_states(delta)
	
	# Check for debris to despawn
	_check_debris_despawn()


func _initialize_loot_tables() -> void:
	loot_tables = {
		"common": {
			"wood": {"weight": 40, "min": 1, "max": 3},
			"plastic": {"weight": 30, "min": 1, "max": 2},
			"food": {"weight": 20, "min": 1, "max": 2},
			"leaf": {"weight": 10, "min": 1, "max": 4}
		},
		"uncommon": {
			"wood": {"weight": 25, "min": 3, "max": 6},
			"plastic": {"weight": 25, "min": 2, "max": 4},
			"food": {"weight": 20, "min": 2, "max": 4},
			"stone": {"weight": 15, "min": 2, "max": 5},
			"fiber": {"weight": 15, "min": 2, "max": 4}
		},
		"rare": {
			"stone": {"weight": 25, "min": 5, "max": 10},
			"metal": {"weight": 20, "min": 2, "max": 5},
			"fiber": {"weight": 20, "min": 4, "max": 8},
			"blueprint": {"weight": 10, "min": 1, "max": 1},
			"medicine": {"weight": 15, "min": 1, "max": 2},
			"battery": {"weight": 10, "min": 1, "max": 2}
		},
		"legendary": {
			"gold": {"weight": 30, "min": 5, "max": 15},
			"gemstone": {"weight": 20, "min": 1, "max": 3},
			"ancient_artifact": {"weight": 25, "min": 1, "max": 1},
			"rare_blueprint": {"weight": 15, "min": 1, "max": 1},
			"compass": {"weight": 10, "min": 1, "max": 1}
		}
	}


func _prepopulate_pool(count: int) -> void:
	for i in range(count):
		var debris = _create_debris_instance(FloatingDebris.DebrisType.LOG)
		if debris:
			debris.visible = false
			debris.set_process(false)
			debris.set_physics_process(false)
			debris_pool.append(debris)


func _create_debris_instance(debris_type: FloatingDebris.DebrisType) -> FloatingDebris:
	var debris = FloatingDebris.new()
	debris.debris_type = debris_type
	add_child(debris)
	return debris


func _spawn_initial_debris(count: int) -> void:
	if not player:
		return
	
	for i in range(count):
		var spawn_pos = _get_random_spawn_position()
		_spawn_debris_at_position(spawn_pos)


func _spawn_debris_near_player() -> void:
	if not player:
		return
	
	# Don't exceed max debris
	if active_debris.size() >= max_active_debris:
		return
	
	# Check spawn interval based on island proximity
	var near_island = _is_near_island(player.global_position)
	var spawn_multiplier = island_spawn_bonus if near_island else 1.0
	current_spawn_interval = base_spawn_interval / spawn_multiplier
	
	# Spawn at random position around player
	var spawn_pos = _get_random_spawn_position()
	_spawn_debris_at_position(spawn_pos)


func _get_random_spawn_position() -> Vector3:
	if not player:
		return Vector3.ZERO
	
	var angle = randf() * TAU
	var distance = randf_range(spawn_radius_min, spawn_radius_max)
	
	var spawn_x = player.global_position.x + cos(angle) * distance
	var spawn_z = player.global_position.z + sin(angle) * distance
	
	# Get wave height at this position
	var wave_height = 0.0
	if water_physics:
		wave_height = water_physics.get_wave_height(Vector3(spawn_x, 0, spawn_z))
	
	return Vector3(spawn_x, wave_height, spawn_z)


func _spawn_debris_at_position(position: Vector3) -> void:
	# Get debris type based on weights
	var debris_type = _get_random_debris_type()
	
	# Get from pool or create new
	var debris: FloatingDebris
	if debris_pool.size() > 0:
		debris = debris_pool.pop_back()
		debris.debris_type = debris_type
	else:
		debris = _create_debris_instance(debris_type)
	
	# Setup debris
	debris.global_position = position
	debris.base_y = 0.0
	debris.rotation = Vector3(randf() * 0.2, randf() * TAU, randf() * 0.2)
	
	# Set drift speed based on type
	match debris_type:
		FloatingDebris.DebrisType.LOG:
			debris.drift_speed = 0.8
			debris.bob_amplitude = 0.4
			debris.set_contents(_generate_loot("common"))
		FloatingDebris.DebrisType.BARREL:
			debris.drift_speed = 1.0
			debris.bob_amplitude = 0.3
			debris.set_contents(_generate_loot("uncommon"))
		FloatingDebris.DebrisType.CRATE:
			debris.drift_speed = 0.5
			debris.bob_amplitude = 0.25
			debris.set_contents(_generate_loot(_get_random_loot_table()))
		FloatingDebris.DebrisType.PALM_DEBRIS:
			debris.drift_speed = 1.2
			debris.bob_amplitude = 0.35
			debris.set_contents({
				"wood": randi_range(1, 3),
				"leaf": randi_range(1, 2)
			})
		FloatingDebris.DebrisType.SUPPLY_BUNDLE:
			debris.drift_speed = 0.7
			debris.bob_amplitude = 0.2
			debris.set_contents(_generate_loot("rare"))
	
	# Activate debris
	debris.visible = true
	debris.set_process(true)
	debris.set_physics_process(true)
	
	active_debris.append(debris)
	emit_signal("debris_spawned", debris)


func _get_random_debris_type() -> FloatingDebris.DebrisType:
	var total_weight = 0.0
	for weight in debris_type_weights.values():
		total_weight += weight
	
	var roll = randf() * total_weight
	var current = 0.0
	
	for type in debris_type_weights:
		current += debris_type_weights[type]
		if roll <= current:
			return type
	
	return FloatingDebris.DebrisType.LOG


func _get_random_loot_table() -> String:
	var roll = randf()
	if roll < 0.6:
		return "common"
	elif roll < 0.85:
		return "uncommon"
	elif roll < 0.95:
		return "rare"
	else:
		return "legendary"


func _generate_loot(table_name: String) -> Dictionary:
	var table = loot_tables.get(table_name, {})
	var loot = {}
	
	var total_weight = 0.0
	for item_data in table.values():
		total_weight += item_data["weight"]
	
	var num_items = randi_range(1, 3)
	var remaining_weight = total_weight
	
	for i in range(num_items):
		if remaining_weight <= 0:
			break
		
		var item_roll = randf() * remaining_weight
		var current_weight = 0.0
		
		for item_name in table:
			var item_data = table[item_name]
			current_weight += item_data["weight"]
			
			if item_roll <= current_weight:
				var amount = randi_range(item_data["min"], item_data["max"])
				loot[item_name] = loot.get(item_name, 0) + amount
				remaining_weight -= item_data["weight"]
				break
	
	return loot


func _update_debris_states(delta: float) -> void:
	for debris in active_debris:
		if is_instance_valid(debris):
			# Apply current-based drift
			if water_physics and not debris.is_attached_to_hook:
				var current = water_physics.get_current(debris.global_position)
				debris.global_position.x += current.x * debris.drift_speed * delta * current_strength
				debris.global_position.z += current.z * debris.drift_speed * delta * current_strength


func _check_debris_despawn() -> void:
	if not player:
		return
	
	var to_remove: Array[FloatingDebris] = []
	
	for debris in active_debris:
		var distance = debris.global_position.distance_to(player.global_position)
		
		# Despawn if too far
		if distance > despawn_distance:
			to_remove.append(debris)
			emit_signal("debris_despawned", debris)
	
	# Return to pool
	for debris in to_remove:
		_remove_debris_from_active(debris)


func _remove_debris_from_active(debris: FloatingDebris) -> void:
	active_debris.erase(debris)
	
	# Return to pool or free
	if debris_pool.size() < 30:
		debris.visible = false
		debris.set_process(false)
		debris.set_physics_process(false)
		debris_pool.append(debris)
	else:
		debris.queue_free()


func _is_near_island(position: Vector3) -> bool:
	for island_pos in island_positions:
		if position.distance_to(island_pos) < island_detection_radius:
			return true
	return false


func _on_collectible_collected(collect_position: Vector3) -> void:
	# Called when debris is collected - spawn replacement nearby
	if active_debris.size() < max_active_debris:
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max * 0.5)
		var new_pos = collect_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		# Add slight delay for pacing
		get_tree().create_timer(randf_range(1.0, 3.0)).timeout.connect(
			func(): _spawn_debris_at_position(new_pos)
		)


## Called when debris is collected
func on_debris_collected(debris: FloatingDebris, loot: Dictionary) -> void:
	emit_signal("debris_collected", debris, loot)
	_remove_debris_from_active(debris)
	
	# Schedule replacement spawn
	_on_collectible_collected(debris.global_position)


## Register an island position
func register_island(position: Vector3) -> void:
	if not position in island_positions:
		island_positions.append(position)


## Unregister island position
func unregister_island(position: Vector3) -> void:
	island_positions.erase(position)


## Get debris near position
func get_debris_near_position(position: Vector3, radius: float) -> Array[FloatingDebris]:
	var nearby: Array[FloatingDebris] = []
	
	for debris in active_debris:
		if is_instance_valid(debris) and debris.global_position.distance_to(position) <= radius:
			nearby.append(debris)
	
	return nearby


## Get all active debris
func get_all_active_debris() -> Array[FloatingDebris]:
	return active_debris.duplicate()


## Force spawn debris at position (for testing/cheats)
func spawn_debris_at(position: Vector3, force_type: FloatingDebris.DebrisType = FloatingDebris.DebrisType.CRATE) -> FloatingDebris:
	_spawn_debris_at_position(position)
	# Return the last spawned debris
	return active_debris.back() if active_debris.size() > 0 else null


## Save ocean state
func get_save_data() -> Dictionary:
	var debris_data: Array = []
	
	for debris in active_debris:
		if is_instance_valid(debris):
			debris_data.append(debris.get_save_data())
	
	return {
		"debris": debris_data,
		"island_positions": island_positions,
		"spawn_timer": spawn_timer
	}


## Load ocean state
func load_save_data(data: Dictionary) -> void:
	# Clear existing debris
	for debris in active_debris:
		if is_instance_valid(debris):
			debris.queue_free()
	active_debris.clear()
	
	# Load island positions
	if data.has("island_positions"):
		island_positions = data["island_positions"]
	
	# Load spawn timer
	if data.has("spawn_timer"):
		spawn_timer = data["spawn_timer"]
	
	# Load debris
	if data.has("debris"):
		for debris_info in data["debris"]:
			var debris_type = debris_info.get("type", FloatingDebris.DebrisType.CRATE)
			var debris = _create_debris_instance(debris_type)
			debris.load_from_data(debris_info)
			debris.visible = true
			debris.set_process(true)
			debris.set_physics_process(true)
			active_debris.append(debris)
