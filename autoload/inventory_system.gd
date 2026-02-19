extends Node


## Simple Inventory System for Raft
## Handles item storage, retrieval, and querying

signal item_added(item_type, count)
signal item_removed(item_type, count)
signal inventory_updated()

# Item storage: item_type -> count
var items: Dictionary = {}

# Maximum inventory slots (0 = unlimited)
var max_slots: int = 30
var max_stack_size: int = 99

func _ready() -> void:
	add_to_group("inventory")
	add_to_group("InventorySystem")


## Add item to inventory
func add_item(item_type, count: int = 1) -> bool:
	if count <= 0:
		return false
	
	var current = items.get(item_type, 0)
	
	# Check stack limit
	if max_stack_size > 0 and current + count > max_stack_size:
		# Can't exceed stack size
		return false
	
	items[item_type] = current + count
	item_added.emit(item_type, count)
	inventory_updated.emit()
	return true


## Remove item from inventory
func remove_item(item_type, count: int = 1) -> bool:
	if count <= 0:
		return false
	
	var current = items.get(item_type, 0)
	if current < count:
		return false
	
	items[item_type] = current - count
	
	# Remove if 0
	if items[item_type] <= 0:
		items.erase(item_type)
	
	item_removed.emit(item_type, count)
	inventory_updated.emit()
	return true


## Check if player has item
func has_item(item_type, count: int = 1) -> bool:
	return items.get(item_type, 0) >= count


## Get item count
func get_item_count(item_type) -> int:
	return items.get(item_type, 0)


## Get all items as dictionary
func get_all_items() -> Dictionary:
	return items.duplicate()


## Clear inventory
func clear() -> void:
	items.clear()
	inventory_updated.emit()


## Get total item count
func get_total_item_count() -> int:
	var total = 0
	for count in items.values():
		total += count
	return total


## Get occupied slots
func get_occupied_slots() -> int:
	return items.size()


## Can add more items
func can_add_item(item_type, count: int = 1) -> bool:
	if max_slots > 0 and items.size() >= max_slots and not items.has(item_type):
		return false
	
	if max_stack_size > 0:
		var current = items.get(item_type, 0)
		return current + count <= max_stack_size
	
	return true


## Add starter items (for testing)
func add_starter_items() -> void:
	# Give player some basic resources to start building
	add_item("wood", 50)
	add_item("plastic", 20)
	add_item("stone", 10)
	add_item("fabric", 5)


## Save inventory
func save_data() -> Dictionary:
	var save_items: Array = []
	for item_type in items.keys():
		save_items.append({
			"item_type": item_type,
			"count": items[item_type]
		})
	return {"items": save_items}


## Load inventory
func load_data(data: Dictionary) -> void:
	items.clear()
	if data.has("items"):
		for item_data in data["items"]:
			var item_type = item_data.get("item_type")
			var count = item_data.get("count", 0)
			if item_type != null:
				items[item_type] = count
	inventory_updated.emit()
