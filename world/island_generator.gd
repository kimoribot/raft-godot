## Island Generator
## Procedural island generation with biome support, resources, and treasures

class_name IslandGenerator
extends Node

## Reference to biome data
var biome_data: BiomeData

## Generated islands storage
var islands: Array[Dictionary] = []

## Secret locations
var secret_locations: Array[Dictionary] = []

## Treasure locations
var treasure_locations: Array[Dictionary] = []

## Resource nodes on islands
var resource_nodes: Array[Dictionary] = []

## World bounds for island placement
var world_bounds: Rect2 = Rect2(-500, -500, 1000, 1000)

## Minimum distance between islands
var min_island_distance: float = 100.0

## Seed for reproducible generation
var seed_value: int = 0


func _ready():
	if seed_value != 0:
		seed(seed_value)


## Initialize with a specific biome
func initialize(new_biome: String, new_seed: int = 0):
	if new_seed != 0:
		seed_value = new_seed
		seed(seed_value)
	
	biome_data = BiomeData.create_biome(new_biome)
	islands.clear()
	secret_locations.clear()
	treasure_locations.clear()
	resource_nodes.clear()


## Generate all islands for the world
func generate_world() -> void:
	var island_count = randi_range(biome_data.min_island_count, biome_data.max_island_count)
	
	for i in range(island_count):
		var island_pos = _find_valid_island_position()
		if island_pos != Vector2.INF:
			var island = _generate_single_island(island_pos, i)
			islands.append(island)
			
			# Generate resources for this island
			_generate_island_resources(island)
			
			# Generate treasures
			_generate_treasures(island)
			
			# Generate secrets
			_generate_secrets(island)
	
	_print_generation_summary()


## Find a valid position for a new island
func _find_valid_position() -> Vector2:
	var max_attempts = 100
	var bounds_center = world_bounds.get_center()
	var bounds_size = world_bounds.size
	
	for attempt in range(max_attempts):
		var test_pos = Vector2(
			randf_range(bounds_center.x - bounds_size.x / 2, bounds_center.x + bounds_size.x / 2),
			randf_range(bounds_center.y - bounds_size.y / 2, bounds_center.y + bounds_size.y / 2)
		)
		
		# Check distance from other islands
		var valid = true
		for island in islands:
			if test_pos.distance_to(island["position"]) < min_island_distance:
				valid = false
				break
		
		if valid:
			return test_pos
	
	# Fallback: return random position in bounds
	return Vector2(
		randf_range(bounds_center.x - bounds_size.x / 3, bounds_center.x + bounds_size.x / 3),
		randf_range(bounds_center.y - bounds_size.y / 3, bounds_center.y + bounds_size.y / 3)
	)


## Generate a single island with procedural shape
func _generate_single_island(position: Vector2, index: int) -> Dictionary:
	var radius = biome_data.get_random_radius()
	
	# Generate procedural coastline using noise
	var coastline_points = _generate_coastline(position, radius)
	
	# Determine island height profile
	var height_map = _generate_height_map(radius)
	
	# Calculate island area
	var area = _calculate_polygon_area(coastline_points)
	
	var island = {
		"id": index,
		"position": position,
		"radius": radius,
		"coastline": coastline_points,
		"height_map": height_map,
		"area": area,
		"biome": biome_data.biome_id,
		"resources": [],
		"secrets": [],
		"treasures": [],
		"caves": [],
		"beaches": [],
		"vegetation": []
	}
	
	# Identify beaches
	island["beaches"] = _identify_beaches(coastline_points, height_map)
	
	# Identify vegetation zones
	island["vegetation"] = _identify_vegetation_zones(height_map)
	
	# Generate cave systems if supported
	if biome_data.hidden_caves:
		island["caves"] = _generate_caves(coastline_points, height_map)
	
	return island


## Generate procedural coastline using noise
func _generate_coastline(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var segments = 32 + int(radius / 5)  # More segments for larger islands
	
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		
		# Use multiple noise octaves for interesting shapes
		var noise_value = _get_noise_value(angle * 2.0) * 0.3
		noise_value += _get_noise_value(angle * 4.0) * 0.15
		noise_value += _get_noise_value(angle * 8.0) * 0.05
		
		var r = radius * (0.7 + noise_value)
		
		var point = center + Vector2(cos(angle), sin(angle)) * r
		points.append(point)
	
	return points


## Get noise value for procedural generation
func _get_noise_value(angle: float) -> float:
	# Simple hash-based noise for procedural shapes
	var hash = sin(angle * 12.9898) * 43758.5453
	return fract(hash) * 2.0 - 1.0


## Generate height map for island terrain
func _generate_height_map(radius: float) -> Array:
	var height_map = []
	var resolution = 16
	
	for y in range(resolution):
		var row = []
		for x in range(resolution):
			var px = (float(x) / (resolution - 1) - 0.5) * 2.0
			var py = (float(y) / (resolution - 1) - 0.5) * 2.0
			
			var dist = sqrt(px * px + py * py)
			var height = clamp(1.0 - dist, 0.0, 1.0)
			
			# Add noise to height
			var noise = _get_noise_value(px * 5.0 + py * 3.0) * 0.2
			height = clamp(height + noise, 0.0, 1.0)
			
			row.append(height)
		height_map.append(row)
	
	return height_map


## Calculate polygon area
func _calculate_polygon_area(points: PackedVector2Array) -> float:
	var area = 0.0
	var n = points.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += points[i].cross(points[j])
	
	return abs(area) / 2.0


## Identify beach areas on the island
func _identify_beaches(coastline: PackedVector2Array, height_map: Array) -> Array:
	var beaches = []
	
	# Simple beach detection: low-elevation areas near edges
	for i in range(0, len(height_map), 4):
		for j in range(0, len(height_map[i]), 4):
			if height_map[i][j] < 0.2:
				beaches.append({
					"grid_x": i,
					"grid_y": j,
					"elevation": height_map[i][j]
				})
	
	return beaches


## Identify vegetation zones
func _identify_vegetation_zones(height_map: Array) -> Array:
	var zones = []
	var resolution = height_map.size()
	
	for i in range(0, resolution, 4):
		for j in range(0, resolution, 4):
			var elevation = height_map[i][j]
			
			if elevation > 0.3 and elevation < 0.7:
				zones.append({
					"type": "forest",
					"grid_x": i,
					"grid_y": j,
					"elevation": elevation
				})
			elif elevation >= 0.7:
				zones.append({
					"type": "highland",
					"grid_x": i,
					"grid_y": j,
					"elevation": elevation
				})
	
	return zones


## Generate cave systems
func _generate_caves(coastline: PackedVector2Array, height_map: Array) -> Array:
	var caves = []
	
	# Chance to generate caves based on biome
	if randf() < 0.5:
		var cave_count = randi_range(1, 3)
		for i in range(cave_count):
			var angle = randf() * TAU
			var dist = randf_range(0.3, 0.6)  # Inside the island
			
			var cave_pos = Vector2(
				cos(angle) * dist,
				sin(angle) * dist
			)
			
			caves.append({
				"position": cave_pos,
				"size": randf_range(3.0, 8.0),
				"depth": randi_range(2, 5),
				"has_loot": randf() < biome_data.treasure_chance,
				"secret_type": _get_secret_type()
			})
	
	return caves


## Generate resources for an island
func _generate_island_resources(island: Dictionary) -> void:
	var area_factor = island["area"] / 10000.0  # Normalize by typical area
	
	# Wood resources
	if randf() < biome_data.wood_chance:
		var wood_count = int(biome_data.get_resource_count(randi_range(3, 8) * area_factor))
		for i in range(wood_count):
			var pos = _get_random_point_in_polygon(island["coastline"])
			if _is_on_land(pos, island):
				resource_nodes.append({
					"type": "wood",
					"position": pos,
					"island_id": island["id"],
					"amount": randi_range(2, 6),
					"regrow_time": 300.0  # 5 minutes
				})
	
	# Stone resources
	if randf() < biome_data.stone_chance:
		var stone_count = int(biome_data.get_resource_count(randi_range(2, 5) * area_factor))
		for i in range(stone_count):
			var pos = _get_random_point_in_polygon(island["coastline"])
			if _is_on_land(pos, island):
				resource_nodes.append({
					"type": "stone",
					"position": pos,
					"island_id": island["id"],
					"amount": randi_range(3, 8),
					"regrow_time": 600.0  # 10 minutes
				})
	
	# Food sources
	if randf() < biome_data.food_chance:
		var food_count = int(biome_data.get_resource_count(randi_range(2, 6) * area_factor))
		for i in range(food_count):
			var pos = _get_random_point_in_polygon(island["coastline"])
			if _is_on_land(pos, island):
				resource_nodes.append({
					"type": "food",
					"subtype": _get_food_type(),
					"position": pos,
					"island_id": island["id"],
					"amount": randi_range(1, 3),
					"regrow_time": 180.0  # 3 minutes
				})


## Generate treasure locations
func _generate_treasures(island: Dictionary) -> void:
	if randf() > biome_data.treasure_chance:
		return
	
	var treasure_count = randi_range(1, 3)
	for i in range(treasure_count):
		var pos = _get_random_point_in_polygon(island["coastline"])
		
		# Determine treasure type
		var treasure_types = ["supplies", "materials", "blueprint", "rare"]
		var weights = [0.4, 0.3, 0.2, 0.1]
		var treasure_type = _weighted_random(treasure_types, weights)
		
		var treasure = {
			"position": pos,
			"island_id": island["id"],
			"type": treasure_type,
			"contents": _generate_treasure_contents(treasure_type),
			"hidden": randf() < 0.3,  # Some treasures are hidden
			"found": false
		}
		
		treasure_locations.append(treasure)
		island["treasures"].append(treasure)


## Generate secret locations
func _generate_secrets(island: Dictionary) -> void:
	if not biome_data.should_generate_secret():
		return
	
	# Hidden caves
	if biome_data.hidden_caves and island["caves"].size() > 0:
		for cave in island["caves"]:
			if cave.has_loot:
				var secret = {
					"type": "hidden_cave",
					"position": cave["position"],
					"island_id": island["id"],
					"contents": _generate_treasure_contents("rare"),
					"found": false,
					"hints": _generate_secret_hint()
				}
				secret_locations.append(secret)
	
	# Underwater caches
	if biome_data.underwater_caches:
		if randf() < 0.3:
			var pos = _get_random_point_near_coast(island)
			secret_locations.append({
				"type": "underwater_cache",
				"position": pos,
				"island_id": island["id"],
				"contents": _generate_treasure_contents("materials"),
				"found": false,
				"depth": randf_range(1.0, 3.0),
				"hints": _generate_secret_hint()
			})
	
	# Ancient markers
	if randf() < 0.2:
		var pos = _get_high_point(island)
		secret_locations.append({
			"type": "ancient_marker",
			"position": pos,
			"island_id": island["id"],
			"contents": _generate_treasure_contents("blueprint"),
			"found": false,
			"hints": "The stones align with the rising sun"
		})


## Helper: Get random point in polygon
func _get_random_point_in_polygon(polygon: PackedVector2Array) -> Vector2:
	var bounds = polygon[0]
	for p in polygon:
		bounds.x = min(bounds.x, p.x)
		bounds.y = min(bounds.y, p.y)
	
	var max_x = polygon[0].x
	var max_y = polygon[0].y
	for p in polygon:
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	
	# Try to find a point inside
	for _attempt in range(50):
		var test_pos = Vector2(
			randf_range(bounds.x, max_x),
			randf_range(bounds.y, max_y)
		)
		
		if _is_point_in_polygon(test_pos, polygon):
			return test_pos
	
	# Fallback to center
	return polygon.get_center()


## Check if point is in polygon (ray casting)
func _is_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
		   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = not inside
		j = i
	
	return inside


## Check if position is on land
func _is_on_land(pos: Vector2, island: Dictionary) -> bool:
	return _is_point_in_polygon(pos, island["coastline"])


## Get random point near coast
func _get_random_point_near_coast(island: Dictionary) -> Vector2:
	var coastline = island["coastline"]
	if coastline.size() < 2:
		return island["position"]
	
	var index = randi() % coastline.size()
	var point = coastline[index]
	var next_point = coastline[(index + 1) % coastline.size()]
	
	# Move slightly offshore
	var direction = (point - next_point).normalized()
	return point + direction * randf_range(5.0, 15.0)


## Get highest point on island
func _get_high_point(island: Dictionary) -> Vector2:
	var height_map = island["height_map"]
	var max_height = 0.0
	var max_pos = island["position"]
	
	var resolution = height_map.size()
	for i in range(resolution):
		for j in range(resolution):
			if height_map[i][j] > max_height:
				max_height = height_map[i][j]
				var px = island["position"].x + (float(j) / resolution - 0.5) * island["radius"] * 2
				var py = island["position"].y + (float(i) / resolution - 0.5) * island["radius"] * 2
				max_pos = Vector2(px, py)
	
	return max_pos


## Get food type based on biome
func _get_food_type() -> String:
	match biome_data.biome_id:
		"tropical": return ["coconut", "banana", "mango", "fish"].pick_random()
		"desert": return ["cactus_fruit", "date", "fish"].pick_random()
		"rocky": return ["fish", "shellfish", "mushroom"].pick_random()
		"volcanic": return ["fish", "thermal_plant"].pick_random()
		"frozen": return ["fish", "berry"].pick_random()
		_: return "fish"


## Generate treasure contents
func _generate_treasure_contents(treasure_type: String) -> Dictionary:
	match treasure_type:
		"supplies":
			return {
				"wood": randi_range(5, 15),
				"plastic": randi_range(3, 10),
				"food": randi_range(2, 5),
				"medicine": randi_range(0, 2)
			}
		"materials":
			return {
				"stone": randi_range(5, 15),
				"metal": randi_range(2, 8),
				"fiber": randi_range(3, 8)
			}
		"blueprint":
			return {
				"blueprint": _get_random_blueprint(),
				"materials": randi_range(1, 3)
			}
		"rare":
			return {
				"rare_item": _get_random_rare_item(),
				"gold": randi_range(5, 20)
			}
		_:
			return {}


## Get random blueprint
func _get_random_blueprint() -> String:
	var blueprints = [
		"advanced_fishing_rod",
		"water_purifier",
		"grill",
		"compass",
		"bigger_raft",
		"wind_turbine",
		"solar_panel",
		"anchor",
		"bed",
		"storage"
	]
	return blueprints.pick_random()


## Get random rare item
func _get_random_rare_item() -> String:
	var items = [
		"ancient_coin",
		"gemstone",
		"pearl",
		"compass_artifact",
		"ancient_map",
		"treasure_chest_key"
	]
	return items.pick_random()


## Generate secret hint
func _generate_secret_hint() -> String:
	var hints = [
		"Strange markings lead to the water's edge",
		"A bird nests where others fear to go",
		"Follow the largest rock to its base",
		"The cave mouth hides in plain sight",
		"Only at low tide does the path reveal itself",
		"Ancient stones mark the sacred spot"
	]
	return hints.pick_random()


## Weighted random selection
func _weighted_random(options: Array, weights: Array) -> String:
	var total_weight = 0.0
	for w in weights:
		total_weight += w
	
	var random = randf() * total_weight
	var current = 0.0
	
	for i in range(options.size()):
		current += weights[i]
		if random <= current:
			return options[i]
	
	return options.back()


## Print generation summary
func _print_generation_summary():
	print("=== Island Generation Complete ===")
	print("Biome: ", biome_data.display_name)
	print("Islands generated: ", islands.size())
	print("Resource nodes: ", resource_nodes.size())
	print("Treasure locations: ", treasure_locations.size())
	print("Secret locations: ", secret_locations.size())


## Find nearest island to a position
func find_nearest_island(pos: Vector2) -> Dictionary:
	var nearest = {}
	var min_dist = INF
	
	for island in islands:
		var dist = pos.distance_to(island["position"])
		if dist < min_dist:
			min_dist = dist
			nearest = island
	
	return nearest


## Find island by ID
func get_island_by_id(id: int) -> Dictionary:
	for island in islands:
		if island["id"] == id:
			return island
	return {}


## Get resources near a position
func get_resources_near_position(pos: Vector2, radius: float) -> Array:
	var nearby = []
	for resource in resource_nodes:
		if pos.distance_to(resource["position"]) <= radius:
			nearby.append(resource)
	return nearby


## Get secrets near a position
func get_secrets_near_position(pos: Vector2, radius: float) -> Array:
	var nearby = []
	for secret in secret_locations:
		if pos.distance_to(secret["position"]) <= radius:
			nearby.append(secret)
	return nearby


## Discover a secret
func discover_secret(secret_pos: Vector2) -> Dictionary:
	for i in range(secret_locations.size()):
		var secret = secret_locations[i]
		if secret["position"].distance_to(secret_pos) < 5.0:
			secret_locations[i]["found"] = true
			return secret_locations[i]
	return {}


## Get world data for serialization
func get_world_data() -> Dictionary:
	return {
		"biome": biome_data.biome_id,
		"seed": seed_value,
		"islands": islands,
		"resources": resource_nodes,
		"treasures": treasure_locations,
		"secrets": secret_locations
	}
