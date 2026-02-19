## Biome Data
## Defines biome types, visual properties, resources, and danger levels

class_name BiomeData
extends Resource

## Biome identifier
@export var biome_id: String = "tropical"

## Display name
@export var display_name: String = "Tropical Island"

## Visual properties
@export_group("Visual Properties")
@export var ground_color: Color = Color("4a7c59")
@export var sand_color: Color = Color("f4d79e")
@export var vegetation_color: Color = Color("2d5a27")
@export var water_color: Color = Color("1a5f7a")
@export var sky_color: Color = Color("87ceeb")
@export var fog_color: Color = Color("b8d4e3")
@export var fog_density: float = 0.02

## Island size ranges
@export_group("Island Sizes")
@export var min_island_radius: float = 20.0
@export var max_island_radius: float = 80.0
@export var min_island_count: int = 3
@export var max_island_count: int = 8

## Resource probabilities (0-1)
@export_group("Resource Chances")
@export var wood_chance: float = 0.8
@export var stone_chance: float = 0.5
@export var food_chance: float = 0.6
@export var rare_item_chance: float = 0.1
@export var treasure_chance: float = 0.15

## Danger level (0-10)
@export_group("Danger")
@export var danger_level: int = 2
@export var shark_spawn_rate: float = 0.3
@export var predator_chance: float = 0.2

## Biome-specific modifiers
@export_group("Modifiers")
@export var resource_multiplier: float = 1.0
@export var growth_rate: float = 1.0
@export var decay_rate: float = 1.0

## Secret/hidden area settings
@export_group("Secrets")
@export var secret_chance: float = 0.2
@export var hidden_caves: bool = true
@export var underwater_caches: bool = true


## Factory method to create biome from type string
static func create_biome(biome_type: String) -> BiomeData:
	var biome = BiomeData.new()
	
	match biome_type:
		"desert":
			biome._setup_desert()
		"tropical":
			biome._setup_tropical()
		"rocky":
			biome._setup_rocky()
		"volcanic":
			biome._setup_volcanic()
		"frozen":
			biome._setup_frozen()
		_:
			biome._setup_tropical()
	
	return biome


func _setup_desert():
	biome_id = "desert"
	display_name = "Desert Atoll"
	ground_color = Color("c2956e")
	sand_color = Color("e8d4a8")
	vegetation_color = Color("8b7355")
	water_color = Color("4a90a4")
	sky_color = Color("ffe4b5")
	fog_color = Color("ffe4c4")
	fog_density = 0.01
	
	min_island_radius = 15.0
	max_island_radius = 50.0
	min_island_count = 2
	max_island_count = 5
	
	wood_chance = 0.3
	stone_chance = 0.8
	food_chance = 0.2
	rare_item_chance = 0.15
	treasure_chance = 0.25
	
	danger_level = 3
	shark_spawn_rate = 0.4
	predator_chance = 0.3
	
	resource_multiplier = 0.7
	growth_rate = 0.5
	decay_rate = 1.5
	
	secret_chance = 0.3
	hidden_caves = true
	underwater_caches = true


func _setup_tropical():
	biome_id = "tropical"
	display_name = "Tropical Paradise"
	ground_color = Color("4a7c59")
	sand_color = Color("f4d79e")
	vegetation_color = Color("2d5a27")
	water_color = Color("1a5f7a")
	sky_color = Color("87ceeb")
	fog_color = Color("b8d4e3")
	fog_density = 0.02
	
	min_island_radius = 20.0
	max_island_radius = 80.0
	min_island_count = 3
	max_island_count = 8
	
	wood_chance = 0.8
	stone_chance = 0.5
	food_chance = 0.6
	rare_item_chance = 0.1
	treasure_chance = 0.15
	
	danger_level = 2
	shark_spawn_rate = 0.3
	predator_chance = 0.2
	
	resource_multiplier = 1.0
	growth_rate = 1.0
	decay_rate = 1.0
	
	secret_chance = 0.2
	hidden_caves = true
	underwater_caches = true


func _setup_rocky():
	biome_id = "rocky"
	display_name = "Rocky Archipelago"
	ground_color = Color("5a5a5a")
	sand_color = Color("a0a0a0")
	vegetation_color = Color("3a3a3a")
	water_color = Color("2a4a5a")
	sky_color = Color("a0b0c0")
	fog_color = Color("c0c8d0")
	fog_density = 0.03
	
	min_island_radius = 10.0
	max_island_radius = 40.0
	min_island_count = 5
	max_island_count = 12
	
	wood_chance = 0.2
	stone_chance = 0.9
	food_chance = 0.3
	rare_item_chance = 0.2
	treasure_chance = 0.3
	
	danger_level = 5
	shark_spawn_rate = 0.5
	predator_chance = 0.4
	
	resource_multiplier = 1.5
	growth_rate = 0.3
	decay_rate = 0.8
	
	secret_chance = 0.35
	hidden_caves = true
	underwater_caches = false


func _setup_volcanic():
	biome_id = "volcanic"
	display_name = "Volcanic Isles"
	ground_color = Color("2a1a1a")
	sand_color = Color("3a2a2a")
	vegetation_color = Color("1a2a1a")
	water_color = Color("1a3a4a")
	sky_color = Color("ff6b4a")
	fog_color = Color("ff8866")
	fog_density = 0.04
	
	min_island_radius = 15.0
	max_island_radius = 60.0
	min_island_count = 2
	max_island_count = 6
	
	wood_chance = 0.1
	stone_chance = 1.0
	food_chance = 0.1
	rare_item_chance = 0.3
	treasure_chance = 0.4
	
	danger_level = 8
	shark_spawn_rate = 0.6
	predator_chance = 0.6
	
	resource_multiplier = 2.0
	growth_rate = 0.2
	decay_rate = 0.5
	
	secret_chance = 0.5
	hidden_caves = true
	underwater_caches = true


func _setup_frozen():
	biome_id = "frozen"
	display_name = "Frozen Shores"
	ground_color = Color("d0e8f0")
	sand_color = Color("f0f8ff")
	vegetation_color = Color("a0c8d8")
	water_color = Color("306080")
	sky_color = Color("c0d8e8")
	fog_color = Color("e0e8f0")
	fog_density = 0.025
	
	min_island_radius = 25.0
	max_island_radius = 70.0
	min_island_count = 2
	max_island_count = 5
	
	wood_chance = 0.4
	stone_chance = 0.7
	food_chance = 0.2
	rare_item_chance = 0.25
	treasure_chance = 0.2
	
	danger_level = 6
	shark_spawn_rate = 0.1
	predator_chance = 0.7
	
	resource_multiplier = 0.8
	growth_rate = 0.1
	decay_rate = 2.0
	
	secret_chance = 0.15
	hidden_caves = false
	underwater_caches = true


## Get random island radius within biome constraints
func get_random_radius() -> float:
	return randf_range(min_island_radius, max_island_radius)


## Get resource count based on island size
func get_resource_count(base_count: int) -> int:
	return int(base_count * resource_multiplier)


## Check if a secret should be generated
func should_generate_secret() -> bool:
	return randf() < secret_chance


## Get all available biome types
static func get_biome_types() -> Array[String]:
	return ["desert", "tropical", "rocky", "volcanic", "frozen"]
