#ifndef RECIPES_GD
#define RECIPES_GD

class_name Recipes
extends RefCounted

## Recipe Database for Raft Game
## Balanced for 50-hour gameplay with progression-based unlocks

# Recipe Categories
enum Category { TOOL, RAFT_PIECE, UPGRADE, CONSUMABLE }

# Item Types
enum ItemType { 
	# Tools
	HOOK, SPEAR, RAFT_PADDLE, FISHING_ROD, KNIFE, AXE, HAMMER,
	# Raft Pieces
	FOUNDATION, BED, STORAGE, GRILL, WATER_PURIFIER, GARDEN_PATCH, 
	FIREPLACE, SMOKER, ROCKET_LAUNCHER,
	# Upgrades
	FISHING_NET, SAIL, ANTENNA, ENGINE, RUDDER, WATER_CATCHER, SIMPLE_ROOF,
	# Consumables
	WATER, COOKED_FISH, BURGER, COCONUT, JUICE, MEAT, COOKED_MEAT,
	# Materials
	PLASTIC, WOOD, LEATHER, METAL, STONE, GLASS, ELECTRONICS, FABRIC
}

# Unlock Requirements
enum UnlockRequirement { 
	LEVEL_1, LEVEL_2, LEVEL_3, LEVEL_4, LEVEL_5, LEVEL_6, LEVEL_7, LEVEL_8, LEVEL_9, LEVEL_10,
	FISHING, COOKING, BUILDING, EXPLORATION, SURVIVAL
}

# Recipe structure
class Recipe:
	var id: String
	var name: String
	var description: String
	var category: Category
	var item_type: ItemType
	var unlock_requirement: UnlockRequirement
	var unlock_level: int = 1
	
	# Crafting costs
	var cost: Dictionary = {}  # {ItemType: count}
	var craft_time: float = 1.0  # seconds
	var yield_count: int = 1
	
	# Usage/scaling
	var hunger_restore: float = 0
	var thirst_restore: float = 0
	var health_restore: float = 0
	var experience_given: float = 0

# All recipes database
static func get_all_recipes() -> Array[Recipe]:
	var recipes: Array[Recipe] = []
	
	# ========== TOOLS (Early Game - Levels 1-3) ==========
	
	var hook := Recipe.new()
	hook.id = "hook"
	hook.name = "Hook"
	hook.description = "A simple metal hook for catching debris from the ocean"
	hook.category = Category.TOOL
	hook.item_type = ItemType.HOOK
	hook.unlock_requirement = UnlockRequirement.LEVEL_1
	hook.unlock_level = 1
	hook.cost = {ItemType.PLASTIC: 2, ItemType.STONE: 1}
	hook.craft_time = 2.0
	hook.experience_given = 5.0
	recipes.append(hook)
	
	var spear := Recipe.new()
	spear.id = "spear"
	spear.name = "Spear"
	spear.description = "A wooden spear for hunting and defense"
	spear.category = Category.TOOL
	spear.item_type = ItemType.SPEAR
	spear.unlock_requirement = UnlockRequirement.LEVEL_2
	spear.unlock_level = 2
	spear.cost = {ItemType.WOOD: 4, ItemType.STONE: 2}
	spear.craft_time = 3.0
	spear.experience_given = 10.0
	recipes.append(spear)
	
	var raft_paddle := Recipe.new()
	raft_paddle.id = "raft_paddle"
	raft_paddle.name = "Raft Paddle"
	raft_paddle.description = "Propel your raft through the waters"
	raft_paddle.category = Category.TOOL
	raft_paddle.item_type = ItemType.RAFT_PADDLE
	raft_paddle.unlock_requirement = UnlockRequirement.LEVEL_1
	raft_paddle.unlock_level = 1
	raft_paddle.cost = {ItemType.WOOD: 6}
	raft_paddle.craft_time = 2.0
	raft_paddle.experience_given = 5.0
	recipes.append(raft_paddle)
	
	var fishing_rod := Recipe.new()
	fishing_rod.id = "fishing_rod"
	fishing_rod.name = "Fishing Rod"
	fishing_rod.description = "Catch fish from your raft"
	fishing_rod.category = Category.TOOL
	fishing_rod.item_type = ItemType.FISHING_ROD
	fishing_rod.unlock_requirement = UnlockRequirement.FISHING
	fishing_rod.unlock_level = 3
	fishing_rod.cost = {ItemType.WOOD: 4, ItemType.PLASTIC: 2}
	fishing_rod.craft_time = 4.0
	fishing_rod.experience_given = 15.0
	recipes.append(fishing_rod)
	
	var knife := Recipe.new()
	knife.id = "knife"
	knife.name = "Knife"
	knife.description = "Essential tool for cutting and preparing food"
	knife.category = Category.TOOL
	knife.item_type = ItemType.KNIFE
	knife.unlock_requirement = UnlockRequirement.LEVEL_2
	knife.unlock_level = 2
	knife.cost = {ItemType.WOOD: 2, ItemType.STONE: 3}
	knife.craft_time = 3.0
	knife.experience_given = 10.0
	recipes.append(knife)
	
	var axe := Recipe.new()
	axe.id = "axe"
	axe.name = "Axe"
	axe.description = "Chop wood more efficiently"
	axe.category = Category.TOOL
	axe.item_type = ItemType.AXE
	axe.unlock_requirement = UnlockRequirement.LEVEL_3
	axe.unlock_level = 3
	axe.cost = {ItemType.WOOD: 3, ItemType.STONE: 5, ItemType.PLASTIC: 2}
	axe.craft_time = 5.0
	axe.experience_given = 15.0
	recipes.append(axe)
	
	var hammer := Recipe.new()
	hammer.id = "hammer"
	hammer.name = "Hammer"
	hammer.description = "Build and repair raft structures"
	hammer.category = Category.TOOL
	hammer.item_type = ItemType.HAMMER
	hammer.unlock_requirement = UnlockRequirement.BUILDING
	hammer.unlock_level = 4
	hammer.cost = {ItemType.WOOD: 4, ItemType.STONE: 4, ItemType.PLASTIC: 3}
	hammer.craft_time = 4.0
	hammer.experience_given = 20.0
	recipes.append(hammer)
	
	# ========== RAFT PIECES (Progression: Levels 1-7) ==========
	
	var foundation := Recipe.new()
	foundation.id = "foundation"
	foundation.name = "Foundation"
	foundation.description = "Basic raft foundation piece"
	foundation.category = Category.RAFT_PIECE
	foundation.item_type = ItemType.FOUNDATION
	foundation.unlock_requirement = UnlockRequirement.LEVEL_1
	foundation.unlock_level = 1
	foundation.cost = {ItemType.WOOD: 10, ItemType.PLASTIC: 4}
	foundation.craft_time = 5.0
	foundation.experience_given = 10.0
	recipes.append(foundation)
	
	var bed := Recipe.new()
	bed.id = "bed"
	bed.name = "Bed"
	bed.description = "Rest and restore health faster"
	bed.category = Category.RAFT_PIECE
	bed.item_type = ItemType.BED
	bed.unlock_requirement = UnlockRequirement.LEVEL_4
	bed.unlock_level = 4
	bed.cost = {ItemType.WOOD: 20, ItemType.FABRIC: 8, ItemType.LEATHER: 4}
	bed.craft_time = 10.0
	bed.experience_given = 30.0
	recipes.append(bed)
	
	var storage := Recipe.new()
	storage.id = "storage"
	storage.name = "Storage Box"
	storage.description = "Store your resources and items"
	storage.category = Category.RAFT_PIECE
	storage.item_type = ItemType.STORAGE
	storage.unlock_requirement = UnlockRequirement.LEVEL_2
	storage.unlock_level = 2
	storage.cost = {ItemType.WOOD: 15, ItemType.PLASTIC: 6}
	storage.craft_time = 6.0
	storage.experience_given = 15.0
	recipes.append(storage)
	
	var grill := Recipe.new()
	grill.id = "grill"
	grill.name = "Grill"
	grill.description = "Cook food over an open flame"
	grill.category = Category.RAFT_PIECE
	grill.item_type = ItemType.GRILL
	grill.unlock_requirement = UnlockRequirement.COOKING
	grill.unlock_level = 3
	grill.cost = {ItemType.WOOD: 12, ItemType.STONE: 8, ItemType.METAL: 3}
	grill.craft_time = 8.0
	grill.experience_given = 25.0
	recipes.append(grill)
	
	var water_purifier := Recipe.new()
	water_purifier.id = "water_purifier"
	water_purifier.name = "Water Purifier"
	water_purifier.description = "Purify dirty water into drinkable water"
	water_purifier.category = Category.RAFT_PIECE
	water_purifier.item_type = ItemType.WATER_PURIFIER
	water_purifier.unlock_requirement = UnlockRequirement.SURVIVAL
	water_purifier.unlock_level = 5
	water_purifier.cost = {ItemType.PLASTIC: 10, ItemType.GLASS: 4, ItemType.METAL: 3}
	water_purifier.craft_time = 10.0
	water_purifier.experience_given = 30.0
	recipes.append(water_purifier)
	
	var garden_patch := Recipe.new()
	garden_patch.id = "garden_patch"
	garden_patch.name = "Garden Patch"
	garden_patch.description = "Grow your own vegetables"
	garden_patch.category = Category.RAFT_PIECE
	garden_patch.item_type = ItemType.GARDEN_PATCH
	garden_patch.unlock_requirement = UnlockRequirement.LEVEL_6
	garden_patch.unlock_level = 6
	garden_patch.cost = {ItemType.WOOD: 15, ItemType.FABRIC: 6, ItemType.STONE: 5}
	garden_patch.craft_time = 12.0
	garden_patch.experience_given = 35.0
	recipes.append(garden_patch)
	
	var fireplace := Recipe.new()
	fireplace.id = "fireplace"
	fireplace.name = "Fireplace"
	fireplace.description = "Warmth and cooking station"
	fireplace.category = Category.RAFT_PIECE
	fireplace.item_type = ItemType.FIREPLACE
	fireplace.unlock_requirement = UnlockRequirement.LEVEL_5
	fireplace.unlock_level = 5
	fireplace.cost = {ItemType.STONE: 20, ItemType.WOOD: 8}
	fireplace.craft_time = 8.0
	fireplace.experience_given = 25.0
	recipes.append(fireplace)
	
	var smoker := Recipe.new()
	smoker.id = "smoker"
	smoker.name = "Smoker"
	smoker.description = "Smoke meat for long-term storage"
	smoker.category = Category.RAFT_PIECE
	smoker.item_type = ItemType.SMOKER
	smoker.unlock_requirement = UnlockRequirement.LEVEL_7
	smoker.unlock_level = 7
	smoker.cost = {ItemType.WOOD: 25, ItemType.STONE: 12, ItemType.METAL: 5}
	smoker.craft_time = 15.0
	smoker.experience_given = 40.0
	recipes.append(smoker)
	
	var rocket_launcher := Recipe.new()
	rocket_launcher.id = "rocket_launcher"
	rocket_launcher.name = "Rocket Launcher"
	rocket_launcher.description = "Signal for rescue - endgame goal"
	rocket_launcher.category = Category.RAFT_PIECE
	rocket_launcher.item_type = ItemType.ROCKET_LAUNCHER
	rocket_launcher.unlock_requirement = UnlockRequirement.LEVEL_10
	rocket_launcher.unlock_level = 10
	rocket_launcher.cost = {ItemType.METAL: 30, ItemType.ELECTRONICS: 15, ItemType.GLASS: 10, ItemType.PLASTIC: 20}
	rocket_launcher.craft_time = 30.0
	rocket_launcher.experience_given = 100.0
	recipes.append(rocket_launcher)
	
	# ========== UPGRADES (Progression: Levels 2-8) ==========
	
	var fishing_net := Recipe.new()
	fishing_net.id = "fishing_net"
	fishing_net.name = "Fishing Net"
	fishing_net.description = "Automatically collect debris from water"
	fishing_net.category = Category.UPGRADE
	fishing_net.item_type = ItemType.FISHING_NET
	fishing_net.unlock_requirement = UnlockRequirement.FISHING
	fishing_net.unlock_level = 3
	fishing_net.cost = {ItemType.FABRIC: 10, ItemType.WOOD: 8}
	fishing_net.craft_time = 8.0
	fishing_net.experience_given = 20.0
	recipes.append(fishing_net)
	
	var sail := Recipe.new()
	sail.id = "sail"
	sail.name = "Sail"
	sail.description = "Passive movement powered by wind"
	sail.category = Category.UPGRADE
	sail.item_type = ItemType.SAIL
	sail.unlock_requirement = UnlockRequirement.LEVEL_4
	sail.unlock_level = 4
	sail.cost = {ItemType.FABRIC: 15, ItemType.WOOD: 12, ItemType.LEATHER: 5}
	sail.craft_time = 10.0
	sail.experience_given = 25.0
	recipes.append(sail)
	
	var antenna := Recipe.new()
	antenna.id = "antenna"
	antenna.name = "Antenna"
	antenna.description = "Detect nearby islands and supplies"
	antenna.category = Category.UPGRADE
	antenna.item_type = ItemType.ANTENNA
	antenna.unlock_requirement = UnlockRequirement.EXPLORATION
	antenna.unlock_level = 5
	antenna.cost = {ItemType.METAL: 8, ItemType.ELECTRONICS: 5, ItemType.PLASTIC: 6}
	antenna.craft_time = 12.0
	antenna.experience_given = 30.0
	recipes.append(antenna)
	
	var engine := Recipe.new()
	engine.id = "engine"
	engine.name = "Engine"
	engine.description = "Motorized raft propulsion"
	engine.category = Category.UPGRADE
	engine.item_type = ItemType.ENGINE
	engine.unlock_requirement = UnlockRequirement.LEVEL_7
	engine.unlock_level = 7
	engine.cost = {ItemType.METAL: 25, ItemType.ELECTRONICS: 10, ItemType.PLASTIC: 15}
	engine.craft_time = 15.0
	engine.experience_given = 40.0
	recipes.append(engine)
	
	var rudder := Recipe.new()
	rudder.id = "rudder"
	rudder.name = "Rudder"
	rudder.description = "Improved steering control"
	rudder.category = Category.UPGRADE
	rudder.item_type = ItemType.RUDDER
	rudder.unlock_requirement = UnlockRequirement.LEVEL_6
	rudder.unlock_level = 6
	rudder.cost = {ItemType.WOOD: 15, ItemType.METAL: 8, ItemType.PLASTIC: 5}
	rudder.craft_time = 8.0
	rudder.experience_given = 25.0
	recipes.append(rudder)
	
	var water_catcher := Recipe.new()
	water_catcher.id = "water_catcher"
	water_catcher.name = "Water Catcher"
	water_catcher.description = "Collect rainwater automatically"
	water_catcher.category = Category.UPGRADE
	water_catcher.item_type = ItemType.WATER_CATCHER
	water_catcher.unlock_requirement = UnlockRequirement.SURVIVAL
	water_catcher.unlock_level = 4
	water_catcher.cost = {ItemType.PLASTIC: 12, ItemType.GLASS: 4}
	water_catcher.craft_time = 8.0
	water_catcher.experience_given = 20.0
	recipes.append(water_catcher)
	
	var simple_roof := Recipe.new()
	simple_roof.id = "simple_roof"
	simple_roof.name = "Simple Roof"
	simple_roof.description = "Protection from the elements"
	simple_roof.category = Category.UPGRADE
	simple_roof.item_type = ItemType.SIMPLE_ROOF
	simple_roof.unlock_requirement = UnlockRequirement.LEVEL_5
	simple_roof.unlock_level = 5
	simple_roof.cost = {ItemType.WOOD: 20, ItemType.FABRIC: 10, ItemType.PLASTIC: 8}
	simple_roof.craft_time = 10.0
	simple_roof.experience_given = 25.0
	recipes.append(simple_roof)
	
	# ========== CONSUMABLES (Progression: Levels 1-8) ==========
	
	var water := Recipe.new()
	water.id = "water"
	water.name = "Purified Water"
	water.description = "Clean drinking water"
	water.category = Category.CONSUMABLE
	water.item_type = ItemType.WATER
	water.unlock_requirement = UnlockRequirement.LEVEL_2
	water.unlock_level = 2
	water.cost = {}  # Created from water purifier
	water.craft_time = 3.0
	water.yield_count = 1
	water.thirst_restore = 40.0
	water.experience_given = 5.0
	recipes.append(water)
	
	var cooked_fish := Recipe.new()
	cooked_fish.id = "cooked_fish"
	cooked_fish.name = "Cooked Fish"
	cooked_fish.description = "Delicious cooked fish"
	cooked_fish.category = Category.CONSUMABLE
	cooked_fish.item_type = ItemType.COOKED_FISH
	cooked_fish.unlock_requirement = UnlockRequirement.COOKING
	cooked_fish.unlock_level = 3
	cooked_fish.cost = {}  # Cooked on grill/fireplace from raw fish
	cooked_fish.craft_time = 5.0
	cooked_fish.yield_count = 1
	cooked_fish.hunger_restore = 35.0
	cooked_fish.health_restore = 5.0
	cooked_fish.experience_given = 15.0
	recipes.append(cooked_fish)
	
	var burger := Recipe.new()
	burger.id = "burger"
	burger.name = "Burger"
	burger.description = "A filling meal"
	burger.category = Category.CONSUMABLE
	burger.item_type = ItemType.BURGER
	burger.unlock_requirement = UnlockRequirement.LEVEL_6
	burger.unlock_level = 6
	burger.cost = {}  # Complex recipe requiring garden produce
	burger.craft_time = 10.0
	burger.yield_count = 1
	burger.hunger_restore = 60.0
	burger.health_restore = 15.0
	burger.experience_given = 25.0
	recipes.append(burger)
	
	var coconut := Recipe.new()
	coconut.id = "coconut"
	coconut.name = "Coconut"
	coconut.description = "Found on islands - provides hydration"
	coconut.category = Category.CONSUMABLE
	coconut.item_type = ItemType.COCONUT
	coconut.unlock_requirement = UnlockRequirement.LEVEL_1
	coconut.unlock_level = 1
	coconut.cost = {}  # Foraged from islands
	coconut.craft_time = 1.0
	coconut.yield_count = 1
	coconut.hunger_restore = 10.0
	coconut.thirst_restore = 20.0
	coconut.experience_given = 5.0
	recipes.append(coconut)
	
	var juice := Recipe.new()
	juice.id = "juice"
	juice.name = "Fruit Juice"
	juice.description = "Refreshing drink from island fruits"
	juice.category = Category.CONSUMABLE
	juice.item_type = ItemType.JUICE
	juice.unlock_requirement = UnlockRequirement.LEVEL_5
	juice.unlock_level = 5
	juice.cost = {}  # Made from garden produce
	juice.craft_time = 4.0
	juice.yield_count = 1
	juice.thirst_restore = 50.0
	juice.health_restore = 10.0
	juice.experience_given = 15.0
	recipes.append(juice)
	
	var meat := Recipe.new()
	meat.id = "meat"
	meat.name = "Raw Meat"
	meat.description = "From hunting animals"
	meat.category = Category.CONSUMABLE
	meat.item_type = ItemType.MEAT
	meat.unlock_requirement = UnlockRequirement.LEVEL_3
	meat.unlock_level = 3
	meat.cost = {}  # Hunted from islands
	meat.craft_time = 1.0
	meat.yield_count = 1
	meat.hunger_restore = -10.0  # Makes you sick if eaten raw!
	meat.experience_given = 10.0
	recipes.append(meat)
	
	var cooked_meat := Recipe.new()
	cooked_meat.id = "cooked_meat"
	cooked_meat.name = "Cooked Meat"
	cooked_meat.description = "Properly cooked meat"
	cooked_meat.category = Category.CONSUMABLE
	cooked_meat.item_type = ItemType.COOKED_MEAT
	cooked_meat.unlock_requirement = UnlockRequirement.COOKING
	cooked_meat.unlock_level = 3
	cooked_meat.cost = {}  # Cooked from raw meat
	cooked_meat.craft_time = 6.0
	cooked_meat.yield_count = 1
	cooked_meat.hunger_restore = 45.0
	cooked_meat.health_restore = 10.0
	cooked_meat.experience_given = 15.0
	recipes.append(cooked_meat)
	
	return recipes


# Get recipe by ID
static func get_recipe_by_id(recipe_id: String) -> Recipe:
	for recipe in get_all_recipes():
		if recipe.id == recipe_id:
			return recipe
	return null


# Get recipes by category
static func get_recipes_by_category(category: Category) -> Array[Recipe]:
	var result: Array[Recipe] = []
	for recipe in get_all_recipes():
		if recipe.category == category:
			result.append(recipe)
	return result


# Get recipes unlocked at a given level
static func get_recipes_unlocked_at_level(level: int) -> Array[Recipe]:
	var result: Array[Recipe] = []
	for recipe in get_all_recipes():
		if recipe.unlock_level <= level:
			result.append(recipe)
	return result


# Get item type display name
static func get_item_type_name(item_type: ItemType) -> String:
	match item_type:
		ItemType.HOOK: return "Hook"
		ItemType.SPEAR: return "Spear"
		ItemType.RAFT_PADDLE: return "Raft Paddle"
		ItemType.FISHING_ROD: return "Fishing Rod"
		ItemType.KNIFE: return "Knife"
		ItemType.AXE: return "Axe"
		ItemType.HAMMER: return "Hammer"
		ItemType.FOUNDATION: return "Foundation"
		ItemType.BED: return "Bed"
		ItemType.STORAGE: return "Storage Box"
		ItemType.GRILL: return "Grill"
		ItemType.WATER_PURIFIER: return "Water Purifier"
		ItemType.GARDEN_PATCH: return "Garden Patch"
		ItemType.FIREPLACE: return "Fireplace"
		ItemType.SMOKER: return "Smoker"
		ItemType.ROCKET_LAUNCHER: return "Rocket Launcher"
		ItemType.FISHING_NET: return "Fishing Net"
		ItemType.SAIL: return "Sail"
		ItemType.ANTENNA: return "Antenna"
		ItemType.ENGINE: return "Engine"
		ItemType.RUDDER: return "Rudder"
		ItemType.WATER_CATCHER: return "Water Catcher"
		ItemType.SIMPLE_ROOF: return "Simple Roof"
		ItemType.WATER: return "Water"
		ItemType.COOKED_FISH: return "Cooked Fish"
		ItemType.BURGER: return "Burger"
		ItemType.COCONUT: return "Coconut"
		ItemType.JUICE: return "Juice"
		ItemType.MEAT: return "Raw Meat"
		ItemType.COOKED_MEAT: return "Cooked Meat"
		ItemType.PLASTIC: return "Plastic"
		ItemType.WOOD: return "Wood"
		ItemType.LEATHER: return "Leather"
		ItemType.METAL: return "Metal"
		ItemType.STONE: return "Stone"
		ItemType.GLASS: return "Glass"
		ItemType.ELECTRONICS: return "Electronics"
		ItemType.FABRIC: return "Fabric"
		_: return "Unknown"


# Get category display name
static func get_category_name(category: Category) -> String:
	match category:
		Category.TOOL: return "Tool"
		Category.RAFT_PIECE: return "Raft Piece"
		Category.UPGRADE: return "Upgrade"
		Category.CONSUMABLE: return "Consumable"
		_: return "Unknown"

#endif
