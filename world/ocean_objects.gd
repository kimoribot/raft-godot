## Ocean Objects
## Floating collectibles, debris, sharks, and supply bundles

class_name OceanObjects
extends Node

## Ocean object types
enum OceanObjectType {
	CRATE,
	PALM_DEBRIS,
	SUPPLY_BUNDLE,
	BARREL,
	SHARK,
	WHALE,
	DOLPHIN,
	SEA_TURTLE,
	BIRD
}

## All active ocean objects
var active_objects: Array[Dictionary] = []

## Object pools for performance
var crate_pool: Array[Node3D] = []
var debris_pool: Array[Node3D] = []
var shark_pool: Array[Node3D] = []

## World settings
var world_bounds: Rect2 = Rect2(-500, -500, 1000, 1000)
var ocean_level: float = 0.0

## Spawn settings
var spawn_area: Rect2 = Rect2(-400, -400, 800, 800)
var min_object_distance: float = 30.0

## Loot tables
var loot_tables: Dictionary = {}

## Timer for spawning
var spawn_timer: float = 0.0
var spawn_interval: float = 10.0

## Shark spawn settings
var shark_territories: Array[Dictionary] = []
var max_sharks: int = 5
var current_sharks: int = 0


func _ready():
	_initialize_loot_tables()


func _process(delta):
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_random_ocean_object()
	
	_update_ocean_objects(delta)


## Initialize loot tables
func _initialize_loot_tables():
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
			" blueprint": {"weight": 10, "min": 1, "max": 1},
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


## Generate initial ocean objects
func generate_initial_objects(config: Dictionary = {}):
	var crate_count = config.get("crates", 20)
	var debris_count = config.get("debris", 30)
	var bundle_count = config.get("bundles", 10)
	var shark_count = config.get("sharks", 3)
	
	# Spawn crates
	for i in range(crate_count):
		_spawn_object(OceanObjectType.CRATE)
	
	# Spawn palm debris
	for i in range(debris_count):
		_spawn_object(OceanObjectType.PALM_DEBRIS)
	
	# Spawn supply bundles
	for i in range(bundle_count):
		_spawn_object(OceanObjectType.SUPPLY_BUNDLE)
	
	# Spawn sharks
	for i in range(shark_count):
		_spawn_object(OceanObjectType.SHARK)
	
	# Spawn ambient wildlife
	_spawn_wildlife(5)


## Spawn a random ocean object
func _spawn_random_ocean_object():
	var object_types = [
		OceanObjectType.CRATE,
		OceanObjectType.PALM_DEBRIS,
		OceanObjectType.BARREL,
		OceanObjectType.SUPPLY_BUNDLE
	]
	
	# Weighted random
	var weights = [0.4, 0.3, 0.2, 0.1]
	var selected = _weighted_pick(object_types, weights)
	
	_spawn_object(selected)


## Spawn specific object type
func _spawn_object(type: OceanObjectType, position: Vector2 = Vector2.INF):
	var new_object: Dictionary = {
		"type": type,
		"loot_table": "common",
		"contents": {},
		"rotation": 0.0,
		"velocity": Vector2.ZERO,
		"bob_offset": randf() * TAU,
		"lifetime": 0.0,
		"max_lifetime": -1,  # -1 means infinite
		"collectible": true,
		"health": 1.0
	}
	
	# Determine position
	if position == Vector2.INF:
		position = _get_valid_spawn_position()
	
	new_object["position"] = position
	new_object["spawn_position"] = position
	
	# Type-specific setup
	match type:
		OceanObjectType.CRATE:
			new_object["loot_table"] = _get_random_loot_table()
			new_object["contents"] = _generate_loot(new_object["loot_table"])
			new_object["max_lifetime"] = 600.0  # 10 minutes
			new_object["model"] = "crate"
			new_object["collectible"] = true
		
		OceanObjectType.PALM_DEBRIS:
			new_object["loot_table"] = "common"
			new_object["contents"] = {
				"wood": randi_range(1, 3),
				"leaf": randi_range(1, 2)
			}
			new_object["max_lifetime"] = 300.0  # 5 minutes
			new_object["model"] = "palm_debris"
			new_object["collectible"] = true
		
		OceanObjectType.BARREL:
			new_object["loot_table"] = "uncommon"
			new_object["contents"] = _generate_loot("uncommon")
			new_object["contents"]["plastic"] = new_object["contents"].get("plastic", 0) + randi_range(2, 5)
			new_object["max_lifetime"] = 480.0  # 8 minutes
			new_object["model"] = "barrel"
			new_object["collectible"] = true
		
		OceanObjectType.SUPPLY_BUNDLE:
			new_object["loot_table"] = "rare"
			new_object["contents"] = _generate_loot("rare")
			new_object["max_lifetime"] = 900.0  # 15 minutes
			new_object["model"] = "supply_bundle"
			new_object["collectible"] = true
		
		OceanObjectType.SHARK:
			new_object["loot_table"] = ""
			new_object["contents"] = {}
			new_object["model"] = "shark"
			new_object["collectible"] = false
			new_object["health"] = 100.0
			new_object["speed"] = randf_range(5.0, 10.0)
			new_object["territory_center"] = position
			new_object["territory_radius"] = randf_range(80.0, 150.0)
			current_sharks += 1
			
			# Add to shark territories
			shark_territories.append({
				"center": position,
				"radius": new_object["territory_radius"],
				"shark": new_object
			})
		
		OceanObjectType.WHALE, OceanObjectType.DOLPHIN, OceanObjectType.SEA_TURTLE:
			new_object["loot_table"] = ""
			new_object["contents"] = {}
			new_object["model"] = _get_wildlife_model(type)
			new_object["collectible"] = false
			new_object["speed"] = randf_range(2.0, 5.0)
			new_object["direction"] = Vector2.RIGHT.rotated(randf() * TAU)
		
		OceanObjectType.BIRD:
			new_object["loot_table"] = ""
			new_object["contents"] = {}
			new_object["model"] = "seagull"
			new_object["collectible"] = false
			new_object["speed"] = randf_range(8.0, 15.0)
			new_object["direction"] = Vector2.RIGHT.rotated(randf() * TAU)
	
	active_objects.append(new_object)


## Spawn ambient wildlife
func _spawn_wildlife(count: int):
	var wildlife_types = [
		OceanObjectType.WHALE,
		OceanObjectType.DOLPHIN,
		OceanObjectType.SEA_TURTLE,
		OceanObjectType.BIRD
	]
	
	for i in range(count):
		var pos = _get_valid_spawn_position()
		_spawn_object(wildlife_types.pick_random(), pos)


## Get valid spawn position
func _get_valid_spawn_position() -> Vector2:
	var max_attempts = 50
	var bounds_center = spawn_area.get_center()
	var bounds_size = spawn_area.size
	
	for _attempt in range(max_attempts):
		var test_pos = Vector2(
			randf_range(bounds_center.x - bounds_size.x / 2, bounds_center.x + bounds_size.x / 2),
			randf_range(bounds_center.y - bounds_size.y / 2, bounds_center.y + bounds_size.y / 2)
		)
		
		# Check distance from other objects
		var valid = true
		for obj in active_objects:
			if test_pos.distance_to(obj["position"]) < min_object_distance:
				valid = false
				break
		
		if valid:
			return test_pos
	
	# Fallback
	return Vector2(
		randf_range(bounds_center.x - bounds_size.x / 3, bounds_center.x + bounds_size.x / 3),
		randf_range(bounds_center.y - bounds_size.y / 3, bounds_center.y + bounds_size.y / 3)
	)


## Update ocean objects each frame
func _update_ocean_objects(delta: float):
	var objects_to_remove: Array[int] = []
	
	for i in range(active_objects.size()):
		var obj = active_objects[i]
		obj["lifetime"] += delta
		
		# Remove expired objects
		if obj["max_lifetime"] > 0 and obj["lifetime"] > obj["max_lifetime"]:
			objects_to_remove.append(i)
			continue
		
		# Update position based on type
		match obj["type"]:
			OceanObjectType.SHARK:
				_update_shark(obj, delta)
			
			OceanObjectType.WHALE, OceanObjectType.DOLPHIN, OceanObjectType.SEA_TURTLE:
				_update_wildlife(obj, delta)
			
			OceanObjectType.BIRD:
				_update_bird(obj, delta)
			
			_:
				# Floating objects - gentle drift
				_update_floating_object(obj, delta)
	
	# Remove expired objects (reverse order)
	objects_to_remove.reverse()
	for index in objects_to_remove:
		var obj = active_objects[index]
		if obj["type"] == OceanObjectType.SHARK:
			current_sharks -= 1
		active_objects.remove_at(index)


## Update floating object (crates, debris, etc)
func _update_floating_object(obj: Dictionary, delta: float):
	# Gentle drift with waves
	var wave_time = Time.get_ticks_msec() / 1000.0
	var wave_offset = sin(wave_time * 0.5 + obj["bob_offset"]) * 0.5
	
	# Slow random drift
	obj["velocity"] = obj["velocity"].lerp(Vector2(
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5)
	), delta * 0.1)
	
	obj["position"] += obj["velocity"] * delta
	obj["rotation"] += delta * 0.1 * randf_range(-1, 1)
	
	# Keep in bounds
	_keep_in_bounds(obj)


## Update shark AI
func _update_shark(obj: Dictionary, delta: float):
	var target_pos = obj["position"]
	var speed = obj["speed"]
	
	# Simple patrol behavior
	var dist_from_center = obj["position"].distance_to(obj["territory_center"])
	
	if dist_from_center > obj["territory_radius"]:
		# Return to territory
		target_pos = obj["territory_center"]
		speed *= 1.5
	elif randf() < 0.01:
		# Random patrol point
		target_pos = obj["territory_center"] + Vector2.RIGHT.rotated(randf() * TAU) * randf() * obj["territory_radius"]
	
	# Move towards target
	var direction = (target_pos - obj["position"]).normalized()
	obj["position"] += direction * speed * delta
	
	# Update rotation to face movement
	if direction.length() > 0.01:
		obj["rotation"] = direction.angle()
	
	# Keep in world bounds
	_keep_in_bounds(obj)


## Update wildlife movement
func _update_wildlife(obj: Dictionary, delta: float):
	var direction = obj["direction"]
	var speed = obj["speed"]
	
	# Random direction change occasionally
	if randf() < 0.005:
		direction = direction.rotated(randf_range(-0.5, 0.5))
	
	# Keep moving
	obj["position"] += direction * speed * delta
	
	# Boundary avoidance
	var bounds_center = spawn_area.get_center()
	var bounds_size = spawn_area.size
	var boundary = Rect2(
		bounds_center.x - bounds_size.x / 2,
		bounds_center.y - bounds_size.y / 2,
		bounds_size.x,
		bounds_size.y
	)
	
	if not boundary.has_point(obj["position"]):
		# Turn back towards center
		direction = (bounds_center - obj["position"]).normalized()
		obj["direction"] = direction
	
	# Update rotation
	if direction.length() > 0.01:
		obj["rotation"] = direction.angle()


## Update bird movement
func _update_bird(obj: Dictionary, delta: float):
	var direction = obj["direction"]
	var speed = obj["speed"]
	
	# Birds fly in patterns
	if randf() < 0.02:
		direction = direction.rotated(randf_range(-1.0, 1.0))
	
	# Keep in air (higher Y = altitude in 2D representation)
	obj["position"] += direction * speed * delta
	obj["position"].y = clamp(obj["position"].y, -200, -50)  # Birds fly high
	
	# Boundary handling
	var bounds_center = spawn_area.get_center()
	var bounds_size = spawn_area.size
	var boundary = Rect2(
		bounds_center.x - bounds_size.x / 2,
		-300,
		bounds_size.x,
		300
	)
	
	if not boundary.has_point(obj["position"]):
		direction = direction.rotated(PI * 0.5)
		obj["direction"] = direction
	
	if direction.length() > 0.01:
		obj["rotation"] = direction.angle()


## Keep object in world bounds
func _keep_in_bounds(obj: Dictionary):
	var bounds_center = world_bounds.get_center()
	var bounds_size = world_bounds.size
	
	if obj["position"].x < bounds_center.x - bounds_size.x / 2:
		obj["position"].x = bounds_center.x - bounds_size.x / 2
		obj["velocity"].x = abs(obj["velocity"].x)
	elif obj["position"].x > bounds_center.x + bounds_size.x / 2:
		obj["position"].x = bounds_center.x + bounds_size.x / 2
		obj["velocity"].x = -abs(obj["velocity"].x)
	
	if obj["position"].y < bounds_center.y - bounds_size.y / 2:
		obj["position"].y = bounds_center.y - bounds_size.y / 2
		obj["velocity"].y = abs(obj["velocity"].y)
	elif obj["position"].y > bounds_center.y + bounds_size.y / 2:
		obj["position"].y = bounds_center.y + bounds_size.y / 2
		obj["velocity"].y = -abs(obj["velocity"].y)


## Get random loot table based on rarity
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


## Generate loot from table
func _generate_loot(table_name: String) -> Dictionary:
	var table = loot_tables.get(table_name, {})
	var loot = {}
	
	# Select items based on weights
	var total_weight = 0.0
	for item_data in table.values():
		total_weight += item_data["weight"]
	
	var num_items = randi_range(1, 3)
	var remaining_weight = total_weight
	
	for i in range(num_items):
		if remaining_weight <= 0:
			break
		
		var roll = randf() * remaining_weight
		var current = 0.0
		
		for item_name in table:
			var item_data = table[item_name]
			current += item_data["weight"]
			
			if roll <= current:
				var amount = randi_range(item_data["min"], item_data["max"])
				loot[item_name] = loot.get(item_name, 0) + amount
				remaining_weight -= item_data["weight"]
				break
	
	return loot


## Weighted random pick
func _weighted_pick(options: Array, weights: Array) -> var:
	var total = 0.0
	for w in weights:
		total += w
	
	var roll = randf() * total
	var current = 0.0
	
	for i in range(options.size()):
		current += weights[i]
		if roll <= current:
			return options[i]
	
	return options.back()


## Get wildlife model name
func _get_wildlife_model(type: OceanObjectType) -> String:
	match type:
		OceanObjectType.WHALE: return "whale"
		OceanObjectType.DOLPHIN: return "dolphin"
		OceanObjectType.SEA_TURTLE: return "sea_turtle"
		OceanObjectType.BIRD: return "seagull"
		_: return "fish"


## Get objects near position
func get_objects_near_position(pos: Vector2, radius: float, collectible_only: bool = true) -> Array:
	var nearby: Array[Dictionary] = []
	
	for obj in active_objects:
		if collectible_only and not obj["collectible"]:
			continue
		
		if pos.distance_to(obj["position"]) <= radius:
			nearby.append(obj)
	
	return nearby


## Collect an object
func collect_object(object_index: int) -> Dictionary:
	if object_index < 0 or object_index >= active_objects.size():
		return {}
	
	var obj = active_objects[object_index]
	
	if not obj["collectible"]:
		return {}
	
	var loot = obj["contents"].duplicate()
	
	# Remove object
	active_objects.remove_at(object_index)
	
	# Spawn replacement after delay
	if obj["type"] == OceanObjectType.CRATE or obj["type"] == OceanObjectType.BARREL:
		call_deferred("_spawn_replacement", obj["type"])
	
	return loot


## Spawn replacement after delay
func _spawn_replacement(type: OceanObjectType):
	await get_tree().create_timer(randf_range(30.0, 60.0)).timeout
	_spawn_object(type)


## Attack shark
func damage_shark(object_index: int, damage: float) -> Dictionary:
	if object_index < 0 or object_index >= active_objects.size():
		return {}
	
	var obj = active_objects[object_index]
	
	if obj["type"] != OceanObjectType.SHARK:
		return {}
	
	obj["health"] -= damage
	
	if obj["health"] <= 0:
		# Shark dies
		current_sharks -= 1
		var loot = {
			"shark_meat": randi_range(3, 8),
			"shark_fin": randi_range(1, 3),
			"bone": randi_range(2, 5)
		}
		active_objects.remove_at(object_index)
		
		# Spawn new shark eventually
		call_deferred("_spawn_replacement_shark")
		
		return loot
	
	return {"health": obj["health"]}


## Spawn replacement shark
func _spawn_replacement_shark():
	await get_tree().create_timer(randf_range(60.0, 120.0)).timeout
	if current_sharks < max_sharks:
		_spawn_object(OceanObjectType.SHARK)


## Get shark at position
func get_shark_at_position(pos: Vector2, radius: float) -> Dictionary:
	for obj in active_objects:
		if obj["type"] == OceanObjectType.SHARK:
			if pos.distance_to(obj["position"]) <= radius:
				return obj
	return {}


## Get all collectibles
func get_all_collectibles() -> Array:
	var collectibles: Array[Dictionary] = []
	for obj in active_objects:
		if obj["collectible"]:
			collectibles.append(obj)
	return collectibles


## Get ocean data for serialization
func get_ocean_data() -> Dictionary:
	return {
		"objects": active_objects,
		"shark_count": current_sharks,
		"spawn_timer": spawn_timer
	}
