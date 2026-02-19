#ifndef CRAFTING_SYSTEM_GD
#define CRAFTING_SYSTEM_GD

class_name CraftingSystem
extends Node

## Crafting System for Raft Game
## Handles recipe database, unlock system, crafting queue, and resource checking

signal recipe_crafted(recipe: Recipes.Recipe, count: int)
signal crafting_started(recipe: Recipes.Recipe, time: float)
signal crafting_progress(recipe: Recipes.Recipe, progress: float)
signal crafting_completed(recipe: Recipes.Recipe)
signal queue_updated()
signal recipe_unlocked(recipe: Recipes.Recipe)
signal resources_updated()

# References
var inventory: InventorySystem
var progression: ProgressionSystem

# Recipe database
var all_recipes: Array[Recipes.Recipe] = []
var unlocked_recipes: Array[Recipes.Recipe] = []
var locked_recipes: Array[Recipes.Recipe] = []

# Crafting queue
class CraftingQueueItem:
	var recipe: Recipes.Recipe
	var count: int
	var time_remaining: float
	var total_time: float
	var is_crafting: bool = false

var crafting_queue: Array[CraftingQueueItem] = []
var current_crafting: CraftingQueueItem = null
var max_queue_size: int = 5
var auto_start_next: bool = true

# Crafting settings
var crafting_speed_multiplier: float = 1.0
var free_crafting: bool = false  # For testing

func _ready() -> void:
	load_recipes()
	
func _process(delta: float) -> void:
	process_crafting_queue(delta)


# Initialize the crafting system
func initialize(inv: InventorySystem, prog: ProgressionSystem) -> void:
	inventory = inv
	progression = prog
	connect_progression_signals()
	update_unlocked_recipes()


# Load and organize recipes
func load_recipes() -> void:
	all_recipes = Recipes.get_all_recipes()
	locked_recipes = all_recipes.duplicate()
	unlocked_recipes.clear()


# Connect to progression system signals
func connect_progression_signals() -> void:
	if progression:
		progression.level_up.connect(_on_level_up)
		progression.skill_unlocked.connect(_on_skill_unlocked)
		progression.achievement_unlocked.connect(_on_achievement_unlocked)


# Update unlocked recipes based on player level and skills
func update_unlocked_recipes() -> void:
	if not progression:
		return
	
	var current_level = progression.get_current_level()
	var unlocked_skills = progression.get_unlocked_skills()
	var achievements = progression.get_achievements()
	
	for recipe in locked_recipes.duplicate():
		var should_unlock = false
		
		match recipe.unlock_requirement:
			Recipes.UnlockRequirement.LEVEL_1, Recipes.UnlockRequirement.LEVEL_2, \
			Recipes.UnlockRequirement.LEVEL_3, Recipes.UnlockRequirement.LEVEL_4, \
			Recipes.UnlockRequirement.LEVEL_5, Recipes.UnlockRequirement.LEVEL_6, \
			Recipes.UnlockRequirement.LEVEL_7, Recipes.UnlockRequirement.LEVEL_8, \
			Recipes.UnlockRequirement.LEVEL_9, Recipes.UnlockRequirement.LEVEL_10:
				should_unlock = current_level >= recipe.unlock_level
			
			Recipes.UnlockRequirement.FISHING:
				should_unlock = "fishing" in unlocked_skills
			
			Recipes.UnlockRequirement.COOKING:
				should_unlock = "cooking" in unlocked_skills
			
			Recipes.UnlockRequirement.BUILDING:
				should_unlock = "building" in unlocked_skills
			
			Recipes.UnlockRequirement.EXPLORATION:
				should_unlock = "exploration" in unlocked_skills
			
			Recipes.UnlockRequirement.SURVIVAL:
				should_unlock = "survival" in unlocked_skills
		
		if should_unlock:
			unlock_recipe(recipe)


# Unlock a specific recipe
func unlock_recipe(recipe: Recipes.Recipe) -> void:
	if recipe in locked_recipes:
		locked_recipes.erase(recipe)
		if recipe not in unlocked_recipes:
			unlocked_recipes.append(recipe)
			recipe_unlocked.emit(recipe)


# Check if player has required resources
func has_resources(recipe: Recipes.Recipe, count: int = 1) -> bool:
	if free_crafting:
		return true
	
	if not inventory:
		return false
	
	for item_type in recipe.cost:
		var required = recipe.cost[item_type] * count
		if not inventory.has_item(item_type, required):
			return false
	return true


# Get missing resources for a recipe
func get_missing_resources(recipe: Recipes.Recipe, count: int = 1) -> Dictionary:
	var missing: Dictionary = {}
	
	if not inventory:
		return missing
	
	for item_type in recipe.cost:
		var required = recipe.cost[item_type] * count
		var available = inventory.get_item_count(item_type)
		if available < required:
			missing[item_type] = required - available
	
	return missing


# Start item
func start_crafting(recipe: Recipes.Recipe, count: int = 1) -> bool:
	if not can_craft(recipe, count):
		return false
	
	# Deduct resources
	if not free_crafting:
		for item_type in recipe.cost:
			var cost = recipe.cost[item_type] * count
			inventory.remove_item(item_type, cost)
	
	# Create queue item
	var queue_item := CraftingQueueItem.new()
	queue_item.recipe = recipe
	queue_item.count = count
	queue_item.total_time = recipe.craft_time * count / crafting_speed_multiplier
	queue_item.time_remaining = queue_item.total_time
	
	crafting_queue.append(queue_item)
	queue_updated.emit()
	
	# Start crafting if nothing else is happening
	if current_crafting == null and auto_start_next:
		start_next_in_queue()
	
	crafting_started.emit(recipe, queue_item.total_time)
	return true


# Check if player can craft an item
func can_craft(recipe: Recipes.Recipe, count: int = 1) -> bool:
	# Check if recipe is unlocked
	if recipe not in unlocked_recipes:
		return false
	
	# Check queue space
	if crafting_queue.size() >= max_queue_size:
		return false
	
	# Check resources
	if not has_resources(recipe, count):
		return false
	
	return true


# Start the next item in the queue
func start_next_in_queue() -> bool:
	if crafting_queue.is_empty():
		return false
	
	# Find first non-crafting item
	for item in crafting_queue:
		if not item.is_crafting:
			current_crafting = item
			item.is_crafting = true
			return true
	
	return false


# Process the crafting queue
func process_crafting_queue(delta: float) -> void:
	if current_crafting == null:
		if auto_start_next:
			start_next_in_queue()
		return
	
	current_crafting.time_remaining -= delta
	
	var progress = 1.0 - (current_crafting.time_remaining / current_crafting.total_time)
	crafting_progress.emit(current_crafting.recipe, progress)
	
	if current_crafting.time_remaining <= 0:
		complete_crafting(current_crafting)


# Complete crafting
func complete_crafting(item: CraftingQueueItem) -> void:
	# Add crafted items to inventory
	if inventory:
		inventory.add_item(item.recipe.item_type, item.recipe.yield_count * item.count)
	
	recipe_crafted.emit(item.recipe, item.recipe.yield_count * item.count)
	crafting_completed.emit(item.recipe)
	
	# Grant experience
	if progression:
		progression.add_experience(item.recipe.experience_given * item.count)
	
	# Remove from queue
	crafting_queue.erase(item)
	current_crafting = null
	queue_updated.emit()
	
	# Start next item
	if auto_start_next:
		start_next_in_queue()


# Cancel crafting at specific index
func cancel_crafting(index: int) -> bool:
	if index < 0 or index >= crafting_queue.size():
		return false
	
	var item = crafting_queue[index]
	
	# Refund resources if not free crafting
	if not free_crafting and item.is_crafting:
		# Only refund for time not spent? For simplicity, refund all
		for item_type in item.recipe.cost:
			var cost = item.recipe.cost[item_type] * item.count
			if inventory:
				inventory.add_item(item_type, cost)
	elif not item.is_crafting:
		# Refund all for queued items
		for item_type in item.recipe.cost:
			var cost = item.recipe.cost[item_type] * item.count
			if inventory:
				inventory.add_item(item_type, cost)
	
	crafting_queue.remove_at(index)
	
	# If this was current crafting, start next
	if current_crafting == item:
		current_crafting = null
		if auto_start_next:
			start_next_in_queue()
	
	queue_updated.emit()
	return true


# Cancel all crafting
func cancel_all_crafting() -> void:
	for i in range(crafting_queue.size() - 1, -1, -1):
		cancel_crafting(i)


# Get current crafting progress (0.0 to 1.0)
func get_current_progress() -> float:
	if current_crafting == null:
		return 0.0
	return 1.0 - (current_crafting.time_remaining / current_crafting.total_time)


# Get crafting queue info
func get_queue_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for item in crafting_queue:
		info.append({
			"recipe": item.recipe,
			"count": item.count,
			"time_remaining": item.time_remaining,
			"is_crafting": item.is_crafting
		})
	return info


# Get unlocked recipes by category
func get_recipes_by_category(category: Recipes.Category) -> Array[Recipes.Recipe]:
	var result: Array[Recipes.Recipe] = []
	for recipe in unlocked_recipes:
		if recipe.category == category:
			result.append(recipe)
	return result


# Search recipes by name
func search_recipes(query: String) -> Array[Recipes.Recipe]:
	query = query.to_lower()
	var result: Array[Recipes.Recipe] = []
	
	for recipe in unlocked_recipes:
		if query in recipe.name.to_lower() or query in recipe.description.to_lower():
			result.append(recipe)
	
	return result


# Signal handlers
func _on_level_up(new_level: int) -> void:
	update_unlocked_recipes()


func _on_skill_unlocked(skill_name: String) -> void:
	update_unlocked_recipes()


func _on_achievement_unlocked(achievement_id: String) -> void:
	update_unlocked_recipes()


# Save/Load functionality
func save_data() -> Dictionary:
	var queue_data: Array[Dictionary] = []
	for item in crafting_queue:
		queue_data.append({
			"recipe_id": item.recipe.id,
			"count": item.count,
			"time_remaining": item.time_remaining,
			"total_time": item.total_time,
			"is_crafting": item.is_crafting
		})
	
	return {
		"crafting_queue": queue_data,
		"crafting_speed_multiplier": crafting_speed_multiplier
	}


func load_data(data: Dictionary) -> void:
	cancel_all_crafting()
	
	if data.has("crafting_speed_multiplier"):
		crafting_speed_multiplier = data["crafting_speed_multiplier"]
	
	if data.has("crafting_queue"):
		for item_data in data["crafting_queue"]:
			var recipe = Recipes.get_recipe_by_id(item_data["recipe_id"])
			if recipe:
				var queue_item := CraftingQueueItem.new()
				queue_item.recipe = recipe
				queue_item.count = item_data["count"]
				queue_item.time_remaining = item_data["time_remaining"]
				queue_item.total_time = item_data["total_time"]
				queue_item.is_crafting = item_data["is_crafting"]
				crafting_queue.append(queue_item)
		
		# Resume crafting if something was in progress
		if auto_start_next:
			start_next_in_queue()

#endif
