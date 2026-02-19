#ifndef SURVIVAL_SYSTEM_GD
#define SURVIVAL_SYSTEM_GD

class_name SurvivalSystem
extends Node

## Survival System for Raft Game
## Manages hunger, thirst, health stats and status effects

signal health_changed(new_value: float, max_value: float)
signal hunger_changed(new_value: float, max_value: float)
signal thirst_changed(new_value: float, max_value: float)
signal status_effect_added(effect: StatusEffect)
signal status_effect_removed(effect: StatusEffect)
signal player_died()
signal stat_depleted(stat_name: String)

# Core stats
var health: float = 100.0
var max_health: float = 100.0
var hunger: float = 100.0
var max_hunger: float = 100.0
var thirst: float = 100.0
var max_thirst: float = 100.0

# Decay rates (per minute)
var hunger_decay_rate: float = 2.0  # 50 minutes from full to empty
var thirst_decay_rate: float = 3.5  # ~28 minutes from full to empty
var health_decay_from_starving: float = 5.0  # Damage per minute when starving
var health_decay_from_dehydrated: float = 8.0  # Damage per minute when dehydrated

# Status effects
enum StatusEffectType {
	NONE,
	STARVING,
	DEHYDRATED,
	POISONED,
	BLEEDING,
	REGENERATING,
	FATIGUED,
	COLD,
	HOT
}

class StatusEffect:
	var type: StatusEffectType
	var duration: float  # -1 for infinite
	var intensity: float = 1.0
	var source: String = ""
	
	func _init(t: StatusEffectType, dur: float = -1.0, src: String = "", inty: float = 1.0):
		type = t
		duration = dur
		source = src
		intensity = inty
	
	func get_name() -> String:
		match type:
			StatusEffectType.STARVING: return "Starving"
			StatusEffectType.DEHYDRATED: return "Dehydrated"
			StatusEffectType.POISONED: return "Poisoned"
			StatusEffectType.BLEEDING: return "Bleeding"
			StatusEffectType.REGENERATING: return "Regenerating"
			StatusEffectType.FATIGUED: return "Fatigued"
			StatusEffectType.WET: return "Wet"
			StatusEffectType.COLD: return "Cold"
			StatusEffectType.HOT: return "Hot"
		return "Unknown"
	
	func get_description() -> String:
		match type:
			StatusEffectType.STARVING: return "Health is decreasing due to hunger"
			StatusEffectType.DEHYDRATED: return "Health is decreasing due to thirst"
			StatusEffectType.POISONED: return "Taking damage over time"
			StatusEffectType.BLEEDING: return "Losing blood, health decreasing"
			StatusEffectType.REGENERATING: return "Recovering health"
			StatusEffectType.FATIGUED: return "Movement speed reduced"
			StatusEffectType.WET: return "Cold increases faster"
			StatusEffectType.COLD: return "Taking cold damage"
			StatusEffectType.HOT: return "Thirst increases faster"
		return ""

var active_status_effects: Array[StatusEffect] = []

# Timers
var decay_timer: float = 0.0
var status_timer: float = 0.0
var tick_rate: float = 1.0  # Update every second

# Settings
var decay_paused: bool = false
var god_mode: bool = false

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if god_mode or decay_paused:
		return
	
	# Update decay timer
	decay_timer += delta
	if decay_timer >= tick_rate:
		decay_timer = 0.0
		process_stat_decay()
	
	# Update status effects
	status_timer += delta
	if status_timer >= tick_rate:
		status_timer = 0.0
		process_status_effects(delta)


# Process stat decay over time
func process_stat_decay() -> void:
	# Decrease hunger
	hunger = maxf(0.0, hunger - (hunger_decay_rate * tick_rate / 60.0))
	hunger_changed.emit(hunger, max_hunger)
	
	# Decrease thirst
	thirst = maxf(0.0, thirst - (thirst_decay_rate * tick_rate / 60.0))
	thirst_changed.emit(thirst, max_thirst)
	
	# Check for starvation
	if hunger <= 0:
		if not has_status_effect(StatusEffectType.STARVING):
			add_status_effect(StatusEffectType.STARVING)
		health = maxf(0.0, health - (health_decay_from_starving * tick_rate / 60.0))
	else:
		if has_status_effect(StatusEffectType.STARVING):
			remove_status_effect(StatusEffectType.STARVING)
	
	# Check for dehydration
	if thirst <= 0:
		if not has_status_effect(StatusEffectType.DEHYDRATED):
			add_status_effect(StatusEffectType.DEHYDRATED)
		health = maxf(0.0, health - (health_decay_from_dehydrated * tick_rate / 60.0))
	else:
		if has_status_effect(StatusEffectType.DEHYDRATED):
			remove_status_effect(StatusEffectType.DEHYDRATED)
	
	# Check for death
	if health <= 0:
		player_died.emit()
	
	health_changed.emit(health, max_health)
	
	# Emit depletion warnings
	if hunger <= 0:
		stat_depleted.emit("hunger")
	if thirst <= 0:
		stat_depleted.emit("thirst")
	if health <= 0:
		stat_depleted.emit("health")


# Process active status effects
func process_status_effects(delta: float) -> void:
	var effects_to_remove: Array[StatusEffect] = []
	
	for effect in active_status_effects:
		# Process effect
		match effect.type:
			StatusEffectType.POISONED:
				health -= 3.0 * effect.intensity
				health_changed.emit(health, max_health)
			
			StatusEffectType.BLEEDING:
				health -= 2.0 * effect.intensity
				health_changed.emit(health, max_health)
			
			StatusEffectType.REGENERATING:
				health = minf(max_health, health + 2.0 * effect.intensity)
				health_changed.emit(health, max_health)
			
			StatusEffectType.COLD:
				hunger -= 1.0 * effect.intensity
				health -= 1.0 * effect.intensity
				hunger_changed.emit(hunger, max_hunger)
				health_changed.emit(health, max_health)
			
			StatusEffectType.HOT:
				thirst -= 2.0 * effect.intensity
				thirst_changed.emit(thirst, max_thirst)
		
		# Update duration
		if effect.duration > 0:
			effect.duration -= delta
			if effect.duration <= 0:
				effects_to_remove.append(effect)
	
	# Remove expired effects
	for effect in effects_to_remove:
		remove_status_effect(effect)
	
	# Check for death
	if health <= 0 and not god_mode:
		player_died.emit()


# Consume food item
func consume_food(item_type: Recipes.ItemType, item_id: String) -> Dictionary:
	var result: Dictionary = {"success": false, "hunger_restored": 0, "thirst_restored": 0, "health_restored": 0}
	
	# Find recipe for this item
	var recipe = Recipes.get_recipe_by_id(item_id)
	if not recipe:
		return result
	
	# Apply effects
	if recipe.hunger_restored > 0:
		hunger = minf(max_hunger, hunger + recipe.hunger_restored)
		result["hunger_restored"] = recipe.hunger_restored
		hunger_changed.emit(hunger, max_hunger)
	
	if recipe.thirst_restore > 0:
		thirst = minf(max_thirst, thirst + recipe.thirst_restore)
		result["thirst_restored"] = recipe.thirst_restore
		thirst_changed.emit(thirst, max_thirst)
	
	if recipe.health_restore > 0:
		health = minf(max_health, health + recipe.health_restore)
		result["health_restored"] = recipe.health_restore
		health_changed.emit(health, max_health)
	
	# Check for negative effects (raw meat, etc.)
	if recipe.hunger_restored < 0:
		add_status_effect(StatusEffectType.POISONED, 30.0, "Raw food")
		health += recipe.hunger_restored  # Negative value
		health_changed.emit(health, max_health)
	
	result["success"] = true
	return result


# Add status effect
func add_status_effect(type: StatusEffectType, duration: float = -1.0, source: String = "", intensity: float = 1.0) -> void:
	# Check if already has this effect
	if has_status_effect(type):
		return
	
	var effect := StatusEffect.new(type, duration, source, intensity)
	active_status_effects.append(effect)
	status_effect_added.emit(effect)


# Remove status effect
func remove_status_effect(type: StatusEffectType) -> void:
	for effect in active_status_effects:
		if effect.type == type:
			active_status_effects.erase(effect)
			status_effect_removed.emit(effect)
			return


# Check if has specific status effect
func has_status_effect(type: StatusEffectType) -> bool:
	for effect in active_status_effects:
		if effect.type == type:
			return true
	return false


# Get status effect by type
func get_status_effect(type: StatusEffectType) -> StatusEffect:
	for effect in active_status_effects:
		if effect.type == type:
			return effect
	return null


# Clear all status effects
func clear_all_status_effects() -> void:
	active_status_effects.clear()


# Take damage
func take_damage(amount: float, source: String = "unknown") -> void:
	if god_mode:
		return
	
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	
	if health <= 0:
		player_died.emit()


# Heal
func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


# Restore hunger
func restore_hunger(amount: float) -> void:
	hunger = minf(max_hunger, hunger + amount)
	hunger_changed.emit(hunger, max_hunger)


# Restore thirst
func restore_thirst(amount: float) -> void:
	thirst = minf(max_thirst, thirst + amount)
	thirst_changed.emit(thirst, max_thirst)


# Get overall health percentage
func get_overall_health() -> float:
	return health / max_health


# Get stat values as dictionary
func get_stats() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"max_hunger": max_hunger,
		"thirst": thirst,
		"max_thirst": max_thirst
	}


# Set stat values from dictionary
func set_stats(stats: Dictionary) -> void:
	if stats.has("health"):
		health = stats["health"]
	if stats.has("max_health"):
		max_health = stats["max_health"]
	if stats.has("hunger"):
		hunger = stats["hunger"]
	if stats.has("max_hunger"):
		max_hunger = stats["max_hunger"]
	if stats.has("thirst"):
		thirst = stats["thirst"]
	if stats.has("max_thirst"):
		max_thirst = stats["max_thirst"]
	
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
	thirst_changed.emit(thirst, max_thirst)


# Check if player is alive
func is_alive() -> bool:
	return health > 0


# Revive player
func revive(full_restore: bool = true) -> void:
	if full_restore:
		health = max_health
		hunger = max_hunger
		thirst = max_thirst
	else:
		health = max_health * 0.5
		hunger = max_hunger * 0.5
		thirst = max_thirst * 0.5
	
	clear_all_status_effects()
	
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
	thirst_changed.emit(thirst, max_thirst)


# Pause decay (for menus, etc.)
func pause_decay() -> void:
	decay_paused = true


# Resume decay
func resume_decay() -> void:
	decay_paused = false


# Get active status effects
func get_active_status_effects() -> Array[StatusEffect]:
	return active_status_effects.duplicate()


# Save/Load functionality
func save_data() -> Dictionary:
	var status_effects_data: Array[Dictionary] = []
	for effect in active_status_effects:
		status_effects_data.append({
			"type": effect.type,
			"duration": effect.duration,
			"intensity": effect.intensity,
			"source": effect.source
		})
	
	return {
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"max_hunger": max_hunger,
		"thirst": thirst,
		"max_thirst": max_thirst,
		"status_effects": status_effects_data
	}


func load_data(data: Dictionary) -> void:
	if data.has("health"):
		health = data["health"]
	if data.has("max_health"):
		max_health = data["max_health"]
	if data.has("hunger"):
		hunger = data["hunger"]
	if data.has("max_hunger"):
		max_hunger = data["max_hunger"]
	if data.has("thirst"):
		thirst = data["thirst"]
	if data.has("max_thirst"):
		max_thirst = data["max_thirst"]
	
	# Load status effects
	clear_all_status_effects()
	if data.has("status_effects"):
		for effect_data in data["status_effects"]:
			var effect := StatusEffect.new(
				effect_data["type"],
				effect_data["duration"],
				effect_data["source"],
				effect_data["intensity"]
			)
			active_status_effects.append(effect)

#endif
