## Collectibles
## Collectible items: wood, plastic, food, and special items

class_name Collectibles
extends Node

## Collectible item types
enum ItemType {
	WOOD,
	PLASTIC,
	STONE,
	FOOD,
	LEAF,
	FIBER,
	METAL,
	MEDICINE,
	BLUEPRINT,
	RARE_ITEM,
	GOLD,
	GEMSTONE
}

## Item categories
enum ItemCategory {
	MATERIAL,
	FOOD,
	SPECIAL,
	TREASURE
}

## All registered collectible definitions
var item_registry: Dictionary = {}

## Player inventory
var inventory: Dictionary = {}

## Collectible nodes in world
var world_collectibles: Array[Dictionary] = []

## Signals
signal item_collected(item_type: String, amount: int)
signal inventory_updated(inventory: Dictionary)
signal blueprint_learned(blueprint_id: String)


func _ready():
	_initialize_item_registry()


## Initialize item definitions
func _initialize_item_registry():
	item_registry = {
		# Basic Materials
		"wood": {
			"type": ItemType.WOOD,
			"category": ItemCategory.MATERIAL,
			"name": "Wood",
			"description": "Basic building material from palm debris",
			"icon": "res://assets/icons/wood.png",
			"stack_size": 999,
			"nutrition": 0,
			"value": 1
		},
		"plastic": {
			"type": ItemType.PLASTIC,
			"category": ItemCategory.MATERIAL,
			"name": "Plastic",
			"description": "Plastic pieces from debris and barrels",
			"icon": "res://assets/icons/plastic.png",
			"stack_size": 999,
			"nutrition": 0,
			"value": 2
		},
		"stone": {
			"type": ItemType.STONE,
			"category": ItemCategory.MATERIAL,
			"name": "Stone",
			"description": "Stone for crafting and building",
			"icon": "res://assets/icons/stone.png",
			"stack_size": 999,
			"nutrition": 0,
			"value": 3
		},
		"fiber": {
			"type": ItemType.FIBER,
			"category": ItemCategory.MATERIAL,
			"name": "Fiber",
			"description": "Plant fibers for crafting",
			"icon": "res://assets/icons/fiber.png",
			"stack_size": 999,
			"nutrition": 0,
			"value": 2
		},
		"metal": {
			"type": ItemType.METAL,
			"category": ItemCategory.MATERIAL,
			"name": "Metal",
			"description": "Scrap metal for advanced crafting",
			"icon": "res://assets/icons/metal.png",
			"stack_size": 999,
			"nutrition": 0,
			"value": 5
		},
		"leaf": {
			"type": ItemType.LEAF,
			"category": ItemCategory.MATERIAL,
			"name": "Leaf",
			"description": "Palm leaves for crafting and thatching",
			"icon": "res://assets/icons/leaf.png",
			"stack_size": 999,
			"nutrition": 0,
			"value": 1
		},
		
		# Food Items
		"food": {
			"type": ItemType.FOOD,
			"category": ItemCategory.FOOD,
			"name": "Raw Fish",
			"description": "Fresh fish from the ocean",
			"icon": "res://assets/icons/fish.png",
			"stack_size": 64,
			"nutrition": 25,
			"value": 3,
			"hunger_restore": 25,
			"health_restore": 0
		},
		"cooked_fish": {
			"type": ItemType.FOOD,
			"category": ItemCategory.FOOD,
			"name": "Cooked Fish",
			"description": "Cooked fish that restores hunger",
			"icon": "res://assets/icons/cooked_fish.png",
			"stack_size": 64,
			"nutrition": 50,
			"value": 5,
			"hunger_restore": 35,
			"health_restore": 5
		},
		"coconut": {
			"type": ItemType.FOOD,
			"category": ItemCategory.FOOD,
			"name": "Coconut",
			"description": "Fresh coconut from tropical islands",
			"icon": "res://assets/icons/coconut.png",
			"stack_size": 32,
			"nutrition": 30,
			"value": 4,
			"hunger_restore": 20,
			"health_restore": 5
		},
		"banana": {
			"type": ItemType.FOOD,
			"category": ItemCategory.FOOD,
			"name": "Banana",
			"description": "Ripe banana from island vegetation",
			"icon": "res://assets/icons/banana.png",
			"stack_size": 32,
			"nutrition": 20,
			"value": 3,
			"hunger_restore": 15,
			"health_restore": 2
		},
		"mango": {
			"type": ItemType.FOOD,
			"category": ItemCategory.FOOD,
			"name": "Mango",
			"description": "Sweet tropical mango",
			"icon": "res://assets/icons/mango.png",
			"stack_size": 24,
			"nutrition": 35,
			"value": 6,
			"hunger_restore": 25,
			"health_restore": 10
		},
		
		# Medical Items
		"medicine": {
			"type": ItemType.MEDICINE,
			"category": ItemCategory.SPECIAL,
			"name": "Medicine",
			"description": "Medical supplies for healing",
			"icon": "res://assets/icons/medicine.png",
			"stack_size": 16,
			"nutrition": 0,
			"value": 10,
			"health_restore": 25
		},
		"bandage": {
			"type": ItemType.MEDICINE,
			"category": ItemCategory.SPECIAL,
			"name": "Bandage",
			"description": "Clean bandage for wounds",
			"icon": "res://assets/icons/bandage.png",
			"stack_size": 32,
			"nutrition": 0,
			"value": 5,
			"health_restore": 15
		},
		
		# Special Items - Blueprints
		"blueprint": {
			"type": ItemType.BLUEPRINT,
			"category": ItemCategory.SPECIAL,
			"name": "Blueprint",
			"description": "Unknown blueprint - use to learn recipe",
			"icon": "res://assets/icons/blueprint.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 50,
			"blueprint_id": ""
		},
		"advanced_fishing_rod": {
			"type": ItemType.BLUEPRINT,
			"category": ItemCategory.SPECIAL,
			"name": "Advanced Fishing Rod Blueprint",
			"description": "Learn to craft an advanced fishing rod",
			"icon": "res://assets/icons/blueprint_fishing.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 100,
			"blueprint_id": "advanced_fishing_rod"
		},
		"water_purifier": {
			"type": ItemType.BLUEPRINT,
			"category": ItemCategory.SPECIAL,
			"name": "Water Purifier Blueprint",
			"description": "Learn to craft a water purifier",
			"icon": "res://assets/icons/blueprint_purifier.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 100,
			"blueprint_id": "water_purifier"
		},
		"grill": {
			"type": ItemType.BLUEPRINT,
			"category": ItemCategory.SPECIAL,
			"name": "Grill Blueprint",
			"description": "Learn to craft a grill for cooking",
			"icon": "res://assets/icons/blueprint_grill.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 80,
			"blueprint_id": "grill"
		},
		"compass": {
			"type": ItemType.BLUEPRINT,
			"category": ItemCategory.SPECIAL,
			"name": "Compass Blueprint",
			"description": "Learn to craft a compass for navigation",
			"icon": "res://assets/icons/blueprint_compass.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 120,
			"blueprint_id": "compass"
		},
		
		# Treasure Items
		"gold": {
			"type": ItemType.GOLD,
			"category": ItemCategory.TREASURE,
			"name": "Gold Coin",
			"description": "Ancient gold coin",
			"icon": "res://assets/icons/gold.png",
			"stack_size": 999,
			"nutrition": 0,
			"value": 25
		},
		"gemstone": {
			"type": ItemType.GEMSTONE,
			"category": ItemCategory.TREASURE,
			"name": "Gemstone",
			"description": "Precious gemstone",
			"icon": "res://assets/icons/gemstone.png",
			"stack_size": 99,
			"nutrition": 0,
			"value": 50
		},
		"ancient_artifact": {
			"type": ItemType.RARE_ITEM,
			"category": ItemCategory.TREASURE,
			"name": "Ancient Artifact",
			"description": "Mysterious ancient artifact",
			"icon": "res://assets/icons/artifact.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 200
		},
		"compass_artifact": {
			"type": ItemType.RARE_ITEM,
			"category": ItemCategory.TREASURE,
			"name": "Compass Artifact",
			"description": "Ancient compass with strange markings",
			"icon": "res://assets/icons/compass_artifact.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 150
		},
		"ancient_map": {
			"type": ItemType.RARE_ITEM,
			"category": ItemCategory.TREASURE,
			"name": "Ancient Map",
			"description": "Map revealing hidden locations",
			"icon": "res://assets/icons/ancient_map.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 100,
			"reveals_locations": true
		},
		"treasure_chest_key": {
			"type": ItemType.RARE_ITEM,
			"category": ItemCategory.TREASURE,
			"name": "Treasure Chest Key",
			"description": "Key to unlock treasure chests",
			"icon": "res://assets/icons/key.png",
			"stack_size": 1,
			"nutrition": 0,
			"value": 75
		},
		"pearl": {
			"type": ItemType.RARE_ITEM,
			"category": ItemCategory.TREASURE,
			"name": "Pearl",
			"description": "Beautiful pearl from oysters",
			"icon": "res://assets/icons/pearl.png",
			"stack_size": 10,
			"nutrition": 0,
			"value": 80
		},
		
		# Shark Drops
		"shark_meat": {
			"type": ItemType.FOOD,
			"category": ItemCategory.FOOD,
			"name": "Shark Meat",
			"description": "Raw shark meat",
			"icon": "res://assets/icons/shark_meat.png",
			"stack_size": 16,
			"nutrition": 40,
			"value": 8,
			"hunger_restore": 30,
			"health_restore": 0
		},
		"shark_fin": {
			"type": ItemType.RARE_ITEM,
			"category": ItemCategory.SPECIAL,
			"name": "Shark Fin",
			"description": "Valuable shark fin",
			"icon": "res://assets/icons/shark_fin.png",
			"stack_size": 8,
			"nutrition": 0,
			"value": 30
		},
		"bone": {
			"type": ItemType.MATERIAL,
			"category": ItemCategory.MATERIAL,
			"name": "Bone",
			"description": "Bone from shark remains",
			"icon": "res://assets/icons/bone.png",
			"stack_size": 64,
			"nutrition": 0,
			"value": 4
		},
		
		# Battery
		"battery": {
			"type": ItemType.SPECIAL,
			"category": ItemCategory.SPECIAL,
			"name": "Battery",
			"description": "Rechargeable battery",
			"icon": "res://assets/icons/battery.png",
			"stack_size": 8,
			"nutrition": 0,
			"value": 20,
			"charge": 100
		}
	}
	
	# Initialize empty inventory
	_clear_inventory()


## Clear inventory to defaults
func _clear_inventory():
	inventory.clear()
	for item_id in item_registry:
		inventory[item_id] = 0


## Add item to inventory
func add_item(item_id: String, amount: int = 1) -> bool:
	if not item_registry.has(item_id):
		push_warning("Unknown item: " + item_id)
		return false
	
	var item_def = item_registry[item_id]
	var current_amount = inventory.get(item_id, 0)
	var max_stack = item_def.get("stack_size", 999)
	
	# Check if we can add the full amount
	var space = max_stack - current_amount
	if space <= 0:
		return false  # Inventory full for this item
	
	# Add what we can
	var to_add = min(amount, space)
	inventory[item_id] = current_amount + to_add
	
	emit_signal("item_collected", item_id, to_add)
	emit_signal("inventory_updated", inventory)
	
	# Handle blueprint auto-learn
	if item_def.get("type") == ItemType.BLUEPRINT:
		var blueprint_id = item_def.get("blueprint_id", "")
		if blueprint_id != "":
			_learn_blueprint(blueprint_id)
	
	return true


## Remove item from inventory
func remove_item(item_id: String, amount: int = 1) -> bool:
	if not inventory.has(item_id) or inventory[item_id] < amount:
		return false
	
	inventory[item_id] -= amount
	
	emit_signal("inventory_updated", inventory)
	return true


## Get item count
func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)


## Check if player has item
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount


## Add loot dictionary to inventory
func add_loot(loot: Dictionary) -> Dictionary:
	var added_items: Dictionary = {}
	
	for item_id in loot:
		var amount = loot[item_id]
		if add_item(item_id, amount):
			added_items[item_id] = amount
	
	return added_items


## Get item definition
func get_item_definition(item_id: String) -> Dictionary:
	return item_registry.get(item_id, {})


## Get items by category
func get_items_by_category(category: ItemCategory) -> Array:
	var items: Array = []
	for item_id in item_registry:
		if item_registry[item_id].get("category") == category:
			items.append(item_id)
	return items


## Get all material items
func get_materials() -> Array:
	return get_items_by_category(ItemCategory.MATERIAL)


## Get all food items
func get_food_items() -> Array:
	return get_items_by_category(ItemCategory.FOOD)


## Get all special items
func get_special_items() -> Array:
	return get_items_by_category(ItemCategory.SPECIAL)


## Get all treasure items
func get_treasure_items() -> Array:
	return get_items_by_category(ItemCategory.TREASURE)


## Learn a blueprint
var learned_blueprints: Array[String] = []

func _learn_blueprint(blueprint_id: String):
	if blueprint_id in learned_blueprints:
		return
	
	learned_blueprints.append(blueprint_id)
	emit_signal("blueprint_learned", blueprint_id)


## Check if blueprint is learned
func has_learned_blueprint(blueprint_id: String) -> bool:
	return blueprint_id in learned_blueprints


## Get nutrition value of food item
func get_nutrition(item_id: String) -> int:
	var item = item_registry.get(item_id, {})
	return item.get("nutrition", 0)


## Get hunger restore value
func get_hunger_restore(item_id: String) -> int:
	var item = item_registry.get(item_id, {})
	return item.get("hunger_restore", 0)


## Get health restore value
func get_health_restore(item_id: String) -> int:
	var item = item_registry.get(item_id, {})
	return item.get("health_restore", 0)


## Consume food item
func consume_food(item_id: String) -> Dictionary:
	if not has_item(item_id, 1):
		return {}
	
	var item = item_registry.get(item_id, {})
	if item.get("category") != ItemCategory.FOOD:
		return {}
	
	# Remove item
	remove_item(item_id, 1)
	
	# Return nutritional value
	return {
		"hunger": get_hunger_restore(item_id),
		"health": get_health_restore(item_id)
	}


## Create collectible in world
func create_world_collectible(item_id: String, position: Vector3, amount: int = 1) -> Dictionary:
	var collectible: Dictionary = {
		"item_id": item_id,
		"position": position,
		"amount": amount,
		"collectible": true,
		"respawn_time": -1
	}
	
	world_collectibles.append(collectible)
	return collectible


## Remove world collectible
func collect_world_collectible(collectible_index: int) -> bool:
	if collectible_index < 0 or collectible_index >= world_collectibles.size():
		return false
	
	var collectible = world_collectibles[collectible_index]
	
	# Add to inventory
	var success = add_item(collectible["item_id"], collectible["amount"])
	
	if success:
		world_collectibles.remove_at(collectible_index)
	
	return success


## Get world collectibles near position
func get_collectibles_near_position(position: Vector3, radius: float) -> Array:
	var nearby: Array[Dictionary] = []
	
	for i in range(world_collectibles.size()):
		var collectible = world_collectibles[i]
		if position.distance_to(collectible["position"]) <= radius:
			nearby.append({
				"index": i,
				"item_id": collectible["item_id"],
				"position": collectible["position"],
				"amount": collectible["amount"]
			})
	
	return nearby


## Get inventory for UI
func get_inventory_ui_data() -> Array:
	var ui_data: Array = []
	
	for item_id in inventory:
		var count = inventory[item_id]
		if count > 0:
			var def = item_registry.get(item_id, {})
			ui_data.append({
				"id": item_id,
				"name": def.get("name", item_id),
				"description": def.get("description", ""),
				"icon": def.get("icon", ""),
				"count": count,
				"stack_size": def.get("stack_size", 999),
				"category": ItemCategory.keys()[def.get("category", 0)],
				"value": def.get("value", 0)
			})
	
	# Sort by category then name
	ui_data.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.name < b.name
	)
	
	return ui_data


## Get total inventory value
func get_total_value() -> int:
	var total = 0
	for item_id in inventory:
		var count = inventory[item_id]
		var value = item_registry.get(item_id, {}).get("value", 0)
		total += count * value
	return total


## Save inventory data
func get_save_data() -> Dictionary:
	return {
		"inventory": inventory,
		"learned_blueprints": learned_blueprints
	}


## Load inventory data
func load_save_data(data: Dictionary):
	if data.has("inventory"):
		inventory = data["inventory"]
	if data.has("learned_blueprints"):
		learned_blueprints = data["learned_blueprints"]
	
	emit_signal("inventory_updated", inventory)


## Clear all items
func clear_inventory():
	_clear_inventory()
	emit_signal("inventory_updated", inventory)


## Get item name
func get_item_name(item_id: String) -> String:
	return item_registry.get(item_id, {}).get("name", item_id)


## Get item description
func get_item_description(item_id: String) -> String:
	return item_registry.get(item_id, {}).get("description", "")
