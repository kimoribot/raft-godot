## Weapon Upgrade System for RaftGodot
## Handles weapon progression from Basic -> Reinforced -> Titanium -> Plasma

class_name WeaponUpgradeSystem
extends Node

## ══════════════════════════════════════════════════════════════════════════════
## SIGNALS
## ══════════════════════════════════════════════════════════════════════════════

signal upgrade_started(weapon_id: String, from_tier: int, to_tier: int)
signal upgrade_completed(weapon_id: String, new_tier: int, stats: Dictionary)
signal upgrade_failed(weapon_id: String, reason: String)
signal material_changed(added: Dictionary, removed: Dictionary)

## ══════════════════════════════════════════════════════════════════════════════
## ENUMS
## ══════════════════════════════════════════════════════════════════════════════

enum UpgradeResult {
	SUCCESS,
	INSUFFICIENT_MATERIALS,
	MAX_TIER_REACHED,
	INVALID_WEAPON,
	NOT_CRAFTABLE
}

## ══════════════════════════════════════════════════════════════════════════════
## PUBLIC VARIABLES
## ══════════════════════════════════════════════════════════════════════════════

var weapon_tier_progress: Dictionary = {}  # weapon_id -> current_tier
var unlocked_tiers: Array = [0]  # Tiers player has unlocked
var upgrade_speed_multiplier: float = 1.0

## ══════════════════════════════════════════════════════════════════════════════
## TIER DEFINITIONS
## ══════════════════════════════════════════════════════════════════════════════

var tier_definitions: Dictionary = {
	0: {
		"name": "Basic",
		"tier_id": 0,
		"damage_multiplier": 1.0,
		"durability_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"crit_bonus": 0.0,
		"special_effects": [],
		"visual_tier": "basic",
		"color": Color.WHITE,
		"required_blueprints": []
	},
	1: {
		"name": "Reinforced",
		"tier_id": 1,
		"damage_multiplier": 1.5,
		"durability_multiplier": 1.5,
		"speed_multiplier": 1.1,
		"crit_bonus": 0.05,
		"special_effects": ["reinforced_strike"],
		"visual_tier": "reinforced",
		"color": Color.SILVER,
		"required_blueprints": ["reinforced_blueprint"]
	},
	2: {
		"name": "Titanium",
		"tier_id": 2,
		"damage_multiplier": 2.5,
		"durability_multiplier": 2.5,
		"speed_multiplier": 1.2,
		"crit_bonus": 0.1,
		"special_effects": ["titanium_edge", "armor_penetration"],
		"visual_tier": "titanium",
		"color": Color.CYAN,
		"required_blueprints": ["titanium_blueprint"]
	},
	3: {
		"name": "Plasma",
		"tier_id": 3,
		"damage_multiplier": 4.0,
		"durability_multiplier": 3.0,
		"speed_multiplier": 1.3,
		"crit_bonus": 0.2,
		"special_effects": ["plasma_burn", "plasma_arc", "energy_surge"],
		"visual_tier": "plasma",
		"color": Color.MAGENTA,
		"required_blueprints": ["plasma_blueprint"]
	}
}

## Special effect definitions
var special_effects: Dictionary = {
	"reinforced_strike": {
		"name": "Reinforced Strike",
		"description": "Attacks have increased knockback",
		"knockback_bonus": 0.5,
		"stamina_cost_reduction": 0.1
	},
	"titanium_edge": {
		"name": "Titanium Edge",
		"description": "25% armor penetration",
		"armor_penetration": 0.25,
		"durability_loss_reduction": 0.2
	},
	"plasma_burn": {
		"name": "Plasma Burn",
		"description": "Deals 10 burn damage per second for 5 seconds",
		"burn_damage": 10.0,
		"burn_duration": 5.0,
		"tick_rate": 1.0
	},
	"plasma_arc": {
		"name": "Plasma Arc",
		"description": "Chain lightning effect on hit",
		"chain_count": 3,
		"chain_distance": 5.0,
		"damage_reduction_per_chain": 0.5
	},
	"energy_surge": {
		"name": "Energy Surge",
		"description": "Chance to deal double damage",
		"surge_chance": 0.15,
		"surge_multiplier": 2.0
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## UPGRADE COSTS (Per weapon type)
## ══════════════════════════════════════════════════════════════════════════════

var upgrade_costs: Dictionary = {
	"spear": {
		1: {"metal": 15, "wood": 8},
		2: {"titanium": 5, "metal": 20, "wood": 5},
		3: {"plasma_core": 1, "titanium": 10, "electronics": 5}
	},
	"trident": {
		1: {"metal": 20, "wood": 10},
		2: {"titanium": 8, "metal": 30},
		3: {"plasma_core": 1, "titanium": 15, "electronics": 10}
	},
	"knife": {
		1: {"metal": 8, "leather": 3},
		2: {"titanium": 5, "metal": 15, "leather": 5},
		3: {"plasma_core": 1, "titanium": 8, "electronics": 8}
	},
	"axe": {
		1: {"metal": 15, "wood": 25},
		2: {"titanium": 10, "metal": 35},
		3: {"plasma_core": 2, "titanium": 15, "electronics": 5}
	},
	"harpoon_gun": {
		1: {"metal": 20, "rope": 10},
		2: {"titanium": 10, "metal": 30, "electronics": 5},
		3: {"plasma_core": 2, "titanium": 15, "electronics": 15}
	},
	"flare_gun": {
		1: {"plastic": 15, "cloth": 10},
		2: {"titanium": 5, "plastic": 25, "electronics": 5},
		3: {"plasma_core": 1, "titanium": 10, "electronics": 10}
	},
	"anchor_bomb": {
		1: {"metal": 30, "explosive": 5},
		2: {"titanium": 15, "metal": 40, "explosive": 8},
		3: {"plasma_core": 3, "titanium": 20, "electronics": 10}
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## BLUEPRINT DATA
## ══════════════════════════════════════════════════════════════════════════════

var blueprint_data: Dictionary = {
	"reinforced_blueprint": {
		"name": "Reinforced Weapons Blueprint",
		"description": "Unlocks reinforced tier upgrades",
		"unlocks_tier": 1,
		"rarity": "uncommon",
		"drop_sources": ["shark_chest", "wreckage", "trade"],
		"crafting_recipe": {"paper": 5, "metal": 10}
	},
	"titanium_blueprint": {
		"name": "Titanium Weapons Blueprint",
		"description": "Unlocks titanium tier upgrades",
		"rarity": "rare",
		"unlocks_tier": 2,
		"drop_sources": ["big_shark", "deep_wreckage", "rare_trade"],
		"crafting_recipe": {"paper": 10, "titanium": 5, "electronics": 5}
	},
	"plasma_blueprint": {
		"name": "Plasma Weapons Blueprint",
		"description": "Unlocks plasma tier upgrades",
		"rarity": "legendary",
		"unlocks_tier": 3,
		"drop_sources": ["elder_shark", "secret_island", "elite_trade"],
		"crafting_recipe": {"paper": 20, "plasma_core": 1, "electronics": 15}
	}
}

var unlocked_blueprints: Array = []

## ══════════════════════════════════════════════════════════════════════════════
## INITIALIZATION
## ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_progress()

## ══════════════════════════════════════════════════════════════════════════════
## CORE UPGRADE FUNCTIONS
## ══════════════════════════════════════════════════════════════════════════════

func can_upgrade_weapon(weapon_id: String) -> UpgradeResult:
	if not upgrade_costs.has(weapon_id):
		return UpgradeResult.INVALID_WEAPON
	
	var current_tier = weapon_tier_progress.get(weapon_id, 0)
	
	if current_tier >= 3:  # Max tier
		return UpgradeResult.MAX_TIER_REACHED
	
	# Check blueprint unlock
	var next_tier = current_tier + 1
	var tier_def = tier_definitions[next_tier]
	var required_blueprints = tier_def.get("required_blueprints", [])
	
	for blueprint in required_blueprints:
		if blueprint not in unlocked_blueprints:
			return UpgradeResult.NOT_CRAFTABLE
	
	# Check materials (would integrate with inventory system)
	var cost = upgrade_costs[weapon_id][next_tier]
	if not _has_materials(cost):
		return UpgradeResult.INSUFFICIENT_MATERIALS
	
	return UpgradeResult.SUCCESS

func upgrade_weapon(weapon_id: String, skip_materials: bool = false) -> Dictionary:
	var can_upgrade_result = can_upgrade_weapon(weapon_id)
	
	if can_upgrade_result != UpgradeResult.SUCCESS:
		upgrade_failed.emit(weapon_id, UpgradeResult.keys()[can_upgrade_result])
		return {"success": false, "reason": UpgradeResult.keys()[can_upgrade_result]}
	
	var current_tier = weapon_tier_progress.get(weapon_id, 0)
	var next_tier = current_tier + 1
	var cost = upgrade_costs[weapon_id][next_tier]
	
	upgrade_started.emit(weapon_id, current_tier, next_tier)
	
	# Consume materials
	if not skip_materials:
		_consume_materials(cost)
	
	# Update progress
	weapon_tier_progress[weapon_id] = next_tier
	_save_progress()
	
	# Calculate new stats
	var new_stats = _calculate_upgraded_stats(weapon_id, next_tier)
	
	upgrade_completed.emit(weapon_id, next_tier, new_stats)
	
	return {
		"success": true,
		"weapon_id": weapon_id,
		"new_tier": next_tier,
		"stats": new_stats
	}

func downgrade_weapon(weapon_id: String, refund_materials: bool = true) -> Dictionary:
	var current_tier = weapon_tier_progress.get(weapon_id, 0)
	
	if current_tier <= 0:
		return {"success": false, "reason": "Already at lowest tier"}
	
	var prev_tier = current_tier - 1
	
	# Refund some materials
	if refund_materials and upgrade_costs.has(weapon_id):
		var cost = upgrade_costs[weapon_id][current_tier]
		var refund = _calculate_refund(cost)
		_refund_materials(refund)
	
	weapon_tier_progress[weapon_id] = prev_tier
	_save_progress()
	
	return {
		"success": true,
		"weapon_id": weapon_id,
		"new_tier": prev_tier
	}

## ══════════════════════════════════════════════════════════════════════════════
## BLUEPRINT MANAGEMENT
## ══════════════════════════════════════════════════════════════════════════════

func unlock_blueprint(blueprint_id: String) -> bool:
	if blueprint_data.has(blueprint_id) and blueprint_id not in unlocked_blueprints:
		unlocked_blueprints.append(blueprint_id)
		
		# Auto-unlock tier
		var tier_to_unlock = blueprint_data[blueprint_id]["unlocks_tier"]
		if tier_to_unlock not in unlocked_tiers:
			unlocked_tiers.append(tier_to_unlock)
		
		_save_progress()
		return true
	return false

func has_blueprint(blueprint_id: String) -> bool:
	return blueprint_id in unlocked_blueprints

func is_tier_unlocked(tier: int) -> bool:
	return tier in unlocked_tiers

func get_blueprint_info(blueprint_id: String) -> Dictionary:
	return blueprint_data.get(blueprint_id, {})

## ══════════════════════════════════════════════════════════════════════════════
## STAT CALCULATION
## ══════════════════════════════════════════════════════════════════════════════

func get_weapon_tier(weapon_id: String) -> int:
	return weapon_tier_progress.get(weapon_id, 0)

func get_tier_name(tier: int) -> String:
	return tier_definitions.get(tier, {}).get("name", "Unknown")

func get_tier_color(tier: int) -> Color:
	return tier_definitions.get(tier, {}).get("color", Color.WHITE)

func _calculate_upgraded_stats(weapon_id: String, tier: int) -> Dictionary:
	var weapon_stats = _get_base_weapon_stats(weapon_id)
	var tier_def = tier_definitions[tier]
	
	var stats = {
		"tier": tier,
		"tier_name": tier_def["name"],
		"damage": weapon_stats["damage"] * tier_def["damage_multiplier"],
		"durability": int(weapon_stats["durability"] * tier_def["durability_multiplier"]),
		"attack_speed": weapon_stats["attack_speed"] * tier_def["speed_multiplier"],
		"crit_bonus": weapon_stats.get("crit_bonus", 0.0) + tier_def["crit_bonus"],
		"special_effects": tier_def["special_effects"],
		"color": tier_def["color"]
	}
	
	# Add special effect details
	var effect_details: Array = []
	for effect in stats["special_effects"]:
		if special_effects.has(effect):
			effect_details.append(special_effects[effect])
	stats["effect_details"] = effect_details
	
	return stats

func _get_base_weapon_stats(weapon_id: String) -> Dictionary:
	# Load from weapon_stats.gd
	var weapon_data = {}
	
	if ResourceLoader.exists("res://data/weapon_stats.gd"):
		var ws = load("res://data/weapon_stats.gd")
		weapon_data = ws.get_weapon_by_id(weapon_id)
	
	# Fallback defaults
	if weapon_data.is_empty():
		weapon_data = {
			"damage": 25.0,
			"durability": 100,
			"attack_speed": 1.0,
			"crit_bonus": 0.05
		}
	
	return weapon_data

func get_full_weapon_info(weapon_id: String) -> Dictionary:
	var tier = get_weapon_tier(weapon_id)
	var stats = _calculate_upgraded_stats(weapon_id, tier)
	
	return {
		"weapon_id": weapon_id,
		"current_tier": tier,
		"tier_name": stats["tier_name"],
		"stats": stats,
		"can_upgrade": can_upgrade_weapon(weapon_id) == UpgradeResult.SUCCESS,
		"upgrade_cost": get_upgrade_cost(weapon_id),
		"next_tier_stats": _calculate_upgraded_stats(weapon_id, tier + 1) if tier < 3 else null
	}

## ══════════════════════════════════════════════════════════════════════════════
## MATERIAL MANAGEMENT
## ══════════════════════════════════════════════════════════════════════════════

func get_upgrade_cost(weapon_id: String) -> Dictionary:
	if not upgrade_costs.has(weapon_id):
		return {}
	
	var current_tier = weapon_tier_progress.get(weapon_id, 0)
	if current_tier >= 3:
		return {}
	
	return upgrade_costs[weapon_id][current_tier + 1]

func _has_materials(cost: Dictionary) -> bool:
	# This would integrate with inventory system
	# For now, always return true (testing mode)
	return true

func _consume_materials(cost: Dictionary) -> void:
	# This would integrate with inventory system
	# Remove materials from player inventory
	pass

func _refund_materials(materials: Dictionary) -> void:
	# This would integrate with inventory system
	# Add materials back to player inventory
	pass

func _calculate_refund(cost: Dictionary) -> Dictionary:
	# 50% refund
	var refund: Dictionary = {}
	for material in cost:
		refund[material] = int(cost[material] * 0.5)
	return refund

## ══════════════════════════════════════════════════════════════════════════════
## BATCH UPGRADES
## ══════════════════════════════════════════════════════════════════════════════

func upgrade_all_weapons_of_type(weapon_type: String) -> int:
	var upgraded_count = 0
	
	# This would iterate through player's weapons of this type
	# For each weapon that can be upgraded, perform upgrade
	
	return upgraded_count

func get_upgradeable_weapons() -> Array:
	var upgradeable: Array = []
	
	for weapon_id in upgrade_costs.keys():
		if can_upgrade_weapon(weapon_id) == UpgradeResult.SUCCESS:
			upgradeable.append({
				"weapon_id": weapon_id,
				"cost": get_upgrade_cost(weapon_id)
			})
	
	return upgradeable

func get_total_upgrade_cost(weapon_ids: Array) -> Dictionary:
	var total_cost: Dictionary = {}
	
	for weapon_id in weapon_ids:
		var cost = get_upgrade_cost(weapon_id)
		for material in cost:
			if not total_cost.has(material):
				total_cost[material] = 0
			total_cost[material] += cost[material]
	
	return total_cost

## ══════════════════════════════════════════════════════════════════════════════
## SAVE/LOAD SYSTEM
## ══════════════════════════════════════════════════════════════════════════════

func _load_progress() -> void:
	# Load from save file
	pass

func _save_progress() -> void:
	# Save to save file
	pass

func reset_progress() -> void:
	weapon_tier_progress.clear()
	unlocked_tiers = [0]
	unlocked_blueprints.clear()
	_save_progress()

## ══════════════════════════════════════════════════════════════════════════════
## VISUAL/PARTICLE HELPERS
## ══════════════════════════════════════════════════════════════════════════════

func get_tier_particle_effect(tier: int) -> String:
	return tier_definitions.get(tier, {}).get("particle_effect", "")

func get_tier_visual_name(tier: int) -> String:
	return tier_definitions.get(tier, {}).get("visual_tier", "basic")

func should_show_tier_glow(tier: int) -> bool:
	return tier >= 2  # Titanium and above glow

## ══════════════════════════════════════════════════════════════════════════════
## DEBUG/TESTING
## ══════════════════════════════════════════════════════════════════════════════

func debug_unlock_all() -> void:
	unlocked_tiers = [0, 1, 2, 3]
	for blueprint in blueprint_data.keys():
		unlocked_blueprints.append(blueprint)

func debug_set_tier(weapon_id: String, tier: int) -> void:
	weapon_tier_progress[weapon_id] = clamp(tier, 0, 3)

func get_all_weapon_ids() -> Array:
	return upgrade_costs.keys()
