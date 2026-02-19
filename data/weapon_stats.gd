## Weapon Stats Data for RaftGodot
## All weapon data, damage values, upgrade paths, and ammo types

class_name WeaponStats
extends Node

## ══════════════════════════════════════════════════════════════════════════════
## ENUMS (must match combat_system.gd)
## ══════════════════════════════════════════════════════════════════════════════

enum DamageType {
	PIERCING,
	SLASHING,
	BLUNT
}

enum WeaponCategory {
	MELEE,
	RANGED,
	THROWABLE,
	DEFENSIVE
}

enum MeleeWeapon {
	SPEAR,
	TRIDENT,
	KNIFE,
	AXE
}

enum RangedWeapon {
	HARPOON_GUN,
	FLARE_GUN,
	ANCHOR_BOMB
}

enum WeaponTier {
	BASIC,
	REINFORCED,
	TITANIUM,
	PLASMA
}

## ══════════════════════════════════════════════════════════════════════════════
## STATIC DATA ACCESS
## ══════════════════════════════════════════════════════════════════════════════

static func get_melee_weapon_data() -> Dictionary:
	return _melee_weapon_data

static func get_ranged_weapon_data() -> Dictionary:
	return _ranged_weapon_data

static func get_ammo_data() -> Dictionary:
	return _ammo_data

static func get_defense_data() -> Dictionary:
	return _defense_data

static func get_upgrade_tiers() -> Dictionary:
	return _upgrade_tiers

static func get_all_weapons() -> Array:
	var weapons: Array = []
	
	for weapon in _melee_weapon_data.values():
		weapons.append(weapon)
	
	for weapon in _ranged_weapon_data.values():
		weapons.append(weapon)
	
	return weapons

## ══════════════════════════════════════════════════════════════════════════════
## MELEE WEAPON DATA
## ══════════════════════════════════════════════════════════════════════════════

static var _melee_weapon_data: Dictionary = {
	MeleeWeapon.SPEAR: {
		"name": "Spear",
		"id": "spear",
		"damage": 25.0,
		"damage_type": DamageType.PIERCING,
		"range": 4.0,
		"attack_speed": 1.2,
		"durability": 100,
		"durability_per_hit": 2,
		"crit_bonus": 0.05,
		"combo_enabled": true,
		"max_combo": 3,
		"block_efficiency": 0.3,
		"weight": 1.0,
		"description": "A versatile polearm with good reach. Best for keeping sharks at bay.",
		"flavor_text": "The classic raft survival weapon",
		"icon": "res://assets/icons/spear.png",
		"crafting_recipe": {
			"wood": 8,
			"metal": 2
		},
		"upgrades": {
			WeaponTier.REINFORCED: {
				"damage_multiplier": 1.5,
				"durability_multiplier": 1.5,
				"cost": {"wood": 15, "metal": 8}
			},
			WeaponTier.TITANIUM: {
				"damage_multiplier": 2.5,
				"durability_multiplier": 2.5,
				"cost": {"wood": 5, "metal": 20, "titanium": 5}
			},
			WeaponTier.PLASMA: {
				"damage_multiplier": 4.0,
				"durability_multiplier": 3.0,
				"special": "plasma_burn",
				"cost": {"plasma_core": 1, "titanium": 10, "electronics": 5}
			}
		}
	},
	
	MeleeWeapon.TRIDENT: {
		"name": "Trident",
		"id": "trident",
		"damage": 35.0,
		"damage_type": DamageType.PIERCING,
		"range": 3.5,
		"attack_speed": 1.0,
		"durability": 120,
		"durability_per_hit": 3,
		"crit_bonus": 0.1,
		"combo_enabled": true,
		"max_combo": 3,
		"block_efficiency": 0.4,
		"weight": 1.5,
		"pierce_count": 2,
		"description": "A three-pronged spear that can hit multiple enemies in one thrust.",
		"flavor_text": "Three times the pain",
		"icon": "res://assets/icons/trident.png",
		"crafting_recipe": {
			"wood": 10,
			"metal": 8,
			"rope": 3
		},
		"upgrades": {
			WeaponTier.REINFORCED: {
				"damage_multiplier": 1.5,
				"durability_multiplier": 1.5,
				"pierce_count": 3,
				"cost": {"wood": 20, "metal": 12}
			},
			WeaponTier.TITANIUM: {
				"damage_multiplier": 2.5,
				"durability_multiplier": 2.5,
				"pierce_count": 5,
				"cost": {"metal": 30, "titanium": 8}
			},
			WeaponTier.PLASMA: {
				"damage_multiplier": 4.0,
				"durability_multiplier": 3.0,
				"pierce_count": 10,
				"special": "lightning_chain",
				"cost": {"plasma_core": 1, "titanium": 15, "electronics": 10}
			}
		}
	},
	
	MeleeWeapon.KNIFE: {
		"name": "Knife",
		"id": "knife",
		"damage": 15.0,
		"damage_type": DamageType.SLASHING,
		"range": 1.5,
		"attack_speed": 2.0,
		"durability": 80,
		"durability_per_hit": 1,
		"crit_bonus": 0.2,
		"combo_enabled": true,
		"max_combo": 5,
		"block_efficiency": 0.2,
		"weight": 0.5,
		"description": "A fast slashing weapon. High attack speed and critical chance compensate for low damage.",
		"flavor_text": "Quick and deadly",
		"icon": "res://assets/icons/knife.png",
		"crafting_recipe": {
			"wood": 2,
			"metal": 5
		},
		"upgrades": {
			WeaponTier.REINFORCED: {
				"damage_multiplier": 1.5,
				"durability_multiplier": 1.5,
				"attack_speed_bonus": 0.2,
				"cost": {"metal": 8, "leather": 3}
			},
			WeaponTier.TITANIUM: {
				"damage_multiplier": 2.5,
				"durability_multiplier": 2.5,
				"attack_speed_bonus": 0.4,
				"cost": {"metal": 15, "titanium": 5, "leather": 5}
			},
			WeaponTier.PLASMA: {
				"damage_multiplier": 4.0,
				"durability_multiplier": 3.0,
				"attack_speed_bonus": 0.5,
				"special": "bleed",
				"cost": {"plasma_core": 1, "titanium": 8, "electronics": 8}
			}
		}
	},
	
	MeleeWeapon.AXE: {
		"name": "Axe",
		"id": "axe",
		"damage": 45.0,
		"damage_type": DamageType.SLASHING,
		"range": 2.0,
		"attack_speed": 0.8,
		"durability": 150,
		"durability_per_hit": 4,
		"crit_bonus": 0.15,
		"combo_enabled": false,
		"block_efficiency": 0.5,
		"weight": 2.0,
		"armor_penetration": 0.3,
		"description": "A heavy chopping weapon. Slow but deals massive damage.",
		"flavor_text": "Bring a bigger boat",
		"icon": "res://assets/icons/axe.png",
		"crafting_recipe": {
			"wood": 12,
			"metal": 10
		},
		"upgrades": {
			WeaponTier.REINFORCED: {
				"damage_multiplier": 1.5,
				"durability_multiplier": 1.5,
				"attack_speed_bonus": 0.1,
				"cost": {"wood": 25, "metal": 15}
			},
			WeaponTier.TITANIUM: {
				"damage_multiplier": 2.5,
				"durability_multiplier": 2.5,
				"attack_speed_bonus": 0.2,
				"armor_penetration": 0.5,
				"cost": {"metal": 35, "titanium": 10}
			},
			WeaponTier.PLASMA: {
				"damage_multiplier": 4.0,
				"durability_multiplier": 3.0,
				"special": "cleave",
				"cost": {"plasma_core": 2, "titanium": 15, "electronics": 5}
			}
		}
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## RANGED WEAPON DATA
## ══════════════════════════════════════════════════════════════════════════════

static var _ranged_weapon_data: Dictionary = {
	RangedWeapon.HARPOON_GUN: {
		"name": "Harpoon Gun",
		"id": "harpoon_gun",
		"damage": 50.0,
		"damage_type": DamageType.PIERCING,
		"range": 20.0,
		"fire_rate": 1.5,
		"durability": 80,
		"durability_per_shot": 2,
		"ammo_type": "harpoon",
		"ammo_capacity": 5,
		"piercing": true,
		"pierce_count": 3,
		"reload_time": 2.0,
		"weight": 2.0,
		"description": "Fires harpoons that pierce through enemies. Essential for keeping sharks at range.",
		"flavor_text": "One shot, multiple hits",
		"icon": "res://assets/icons/harpoon_gun.png",
		"crafting_recipe": {
			"wood": 10,
			"metal": 15,
			"rope": 5
		},
		"upgrades": {
			WeaponTier.REINFORCED: {
				"damage_multiplier": 1.5,
				"durability_multiplier": 1.5,
				"pierce_count": 5,
				"cost": {"metal": 20, "rope": 10}
			},
			WeaponTier.TITANIUM: {
				"damage_multiplier": 2.5,
				"durability_multiplier": 2.5,
				"pierce_count": 8,
				"fire_rate_bonus": 0.2,
				"cost": {"metal": 30, "titanium": 10, "electronics": 5}
			},
			WeaponTier.PLASMA: {
				"damage_multiplier": 4.0,
				"durability_multiplier": 3.0,
				"pierce_count": 15,
				"special": "plasma_arc",
				"cost": {"plasma_core": 2, "titanium": 15, "electronics": 15}
			}
		}
	},
	
	RangedWeapon.FLARE_GUN: {
		"name": "Flare Gun",
		"id": "flare_gun",
		"damage": 20.0,
		"damage_type": DamageType.BLUNT,
		"range": 15.0,
		"fire_rate": 3.0,
		"durability": 50,
		"durability_per_shot": 1,
		"ammo_type": "flare",
		"ammo_capacity": 2,
		"area_damage": true,
		"burn_damage": 5.0,
		"burn_duration": 5.0,
		"light_radius": 10.0,
		"light_duration": 10.0,
		"reload_time": 1.0,
		"weight": 1.0,
		"description": "Lights up the area and deals burn damage. Perfect for night-time defense.",
		"flavor_text": "Let there be light",
		"icon": "res://assets/icons/flare_gun.png",
		"crafting_recipe": {
			"wood": 5,
			"plastic": 8,
			"cloth": 5
		},
		"upgrades": {
			WeaponTier.REINFORCED: {
				"damage_multiplier": 1.5,
				"durability_multiplier": 1.5,
				"light_radius": 15.0,
				"cost": {"plastic": 15, "cloth": 10}
			},
			WeaponTier.TITANIUM: {
				"damage_multiplier": 2.5,
				"durability_multiplier": 2.5,
				"burn_damage": 10.0,
				"burn_duration": 10.0,
				"light_radius": 20.0,
				"cost": {"plastic": 25, "titanium": 5, "electronics": 5}
			},
			WeaponTier.PLASMA: {
				"damage_multiplier": 4.0,
				"durability_multiplier": 3.0,
				"special": "incinerate",
				"cost": {"plasma_core": 1, "titanium": 10, "electronics": 10}
			}
		}
	},
	
	RangedWeapon.ANCHOR_BOMB: {
		"name": "Anchor Bomb",
		"id": "anchor_bomb",
		"damage": 80.0,
		"damage_type": DamageType.BLUNT,
		"range": 12.0,
		"fire_rate": 2.5,
		"durability": 40,
		"durability_per_shot": 3,
		"ammo_type": "anchor_bomb",
		"ammo_capacity": 3,
		"explosive": true,
		"explosion_radius": 5.0,
		"knockback_force": 15.0,
		"reload_time": 3.0,
		"weight": 3.0,
		"description": "Thrown explosive anchor. Deals massive area damage but has slow reload.",
		"flavor_text": "Death from above",
		"icon": "res://assets/icons/anchor_bomb.png",
		"crafting_recipe": {
			"metal": 20,
			"explosive": 3,
			"rope": 5
		},
		"upgrades": {
			WeaponTier.REINFORCED: {
				"damage_multiplier": 1.5,
				"durability_multiplier": 1.5,
				"explosion_radius": 7.0,
				"cost": {"metal": 30, "explosive": 5}
			},
			WeaponTier.TITANIUM: {
				"damage_multiplier": 2.5,
				"durability_multiplier": 2.5,
				"explosion_radius": 10.0,
				"knockback_force": 25.0,
				"cost": {"metal": 40, "titanium": 15, "explosive": 8}
			},
			WeaponTier.PLASMA: {
				"damage_multiplier": 4.0,
				"durability_multiplier": 3.0,
				"special": "shockwave",
				"cost": {"plasma_core": 3, "titanium": 20, "electronics": 10}
			}
		}
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## AMMO DATA
## ══════════════════════════════════════════════════════════════════════════════

static var _ammo_data: Dictionary = {
	"harpoon": {
		"name": "Harpoon",
		"id": "harpoon",
		"stack_size": 50,
		"damage_bonus": 0,
		"effect": "pierce",
		"pierce_bonus": 0,
		"special": "",
		"description": "Standard harpoon ammo for the harpoon gun.",
		"icon": "res://assets/icons/harpoon.png",
		"crafting_recipe": {
			"wood": 2,
			"metal": 1
		},
		"drop_chance": 0.3
	},
	
	"explosive_harpoon": {
		"name": "Explosive Harpoon",
		"id": "explosive_harpoon",
		"stack_size": 20,
		"damage_bonus": 20.0,
		"effect": "pierce_explode",
		"pierce_bonus": 0,
		"special": "explosion",
		"explosion_radius": 3.0,
		"description": "Harpoon with explosive tip. Explodes on impact.",
		"icon": "res://assets/icons/explosive_harpoon.png",
		"crafting_recipe": {
			"wood": 3,
			"metal": 2,
			"explosive": 1
		},
		"drop_chance": 0.1
	},
	
	"flare": {
		"name": "Flare",
		"id": "flare",
		"stack_size": 20,
		"damage_bonus": 0,
		"effect": "light",
		"burn_damage": 5.0,
		"burn_duration": 5.0,
		"light_radius": 10.0,
		"light_duration": 10.0,
		"description": "Illuminates the area and causes burn damage.",
		"icon": "res://assets/icons/flare.png",
		"crafting_recipe": {
			"cloth": 2,
			"plastic": 1,
			"gunpowder": 1
		},
		"drop_chance": 0.2
	},
	
	"signal_flare": {
		"name": "Signal Flare",
		"id": "signal_flare",
		"stack_size": 10,
		"damage_bonus": 0,
		"effect": "signal",
		"light_radius": 25.0,
		"light_duration": 30.0,
		"description": "Long-lasting bright flare. Great for signaling or long-term lighting.",
		"icon": "res://assets/icons/signal_flare.png",
		"crafting_recipe": {
			"cloth": 4,
			"plastic": 2,
			"gunpowder": 3
		},
		"drop_chance": 0.05
	},
	
	"anchor_bomb": {
		"name": "Anchor Bomb",
		"id": "anchor_bomb",
		"stack_size": 10,
		"damage_bonus": 0,
		"effect": "explode",
		"explosion_radius": 5.0,
		"knockback_force": 15.0,
		"description": "Explosive anchor for the anchor bomb launcher.",
		"icon": "res://assets/icons/anchor_bomb.png",
		"crafting_recipe": {
			"metal": 5,
			"explosive": 1
		},
		"drop_chance": 0.15
	},
	
	"plasma_charge": {
		"name": "Plasma Charge",
		"id": "plasma_charge",
		"stack_size": 5,
		"damage_bonus": 50.0,
		"effect": "plasma",
		"special": "plasma_burn",
		"burn_damage": 15.0,
		"burn_duration": 8.0,
		"description": "High-tech plasma ammunition. Deals extra damage and causes plasma burn.",
		"icon": "res://assets/icons/plasma_charge.png",
		"crafting_recipe": {
			"plasma_core": 1,
			"electronics": 3,
			"titanium": 3
		},
		"drop_chance": 0.02
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## DEFENSE/SHIELD DATA
## ══════════════════════════════════════════════════════════════════════════════

static var _defense_data: Dictionary = {
	"shield": {
		"name": "Wooden Shield",
		"id": "wooden_shield",
		"block_damage_reduction": 0.4,
		"durability": 50,
		"weight": 1.5,
		"parry_bonus": 0.0,
		"description": "Basic wooden shield for blocking shark attacks.",
		"icon": "res://assets/icons/wooden_shield.png",
		"crafting_recipe": {
			"wood": 15,
			"cloth": 3
		},
		"upgrades": {
			"metal": {
				"block_damage_reduction": 0.6,
				"durability": 100,
				"parry_bonus": 0.1,
				"cost": {"metal": 15, "leather": 5}
			},
			"titanium": {
				"block_damage_reduction": 0.8,
				"durability": 200,
				"parry_bonus": 0.2,
				"cost": {"titanium": 10, "leather": 8}
			},
			"plasma": {
				"block_damage_reduction": 0.95,
				"durability": 300,
				"parry_bonus": 0.3,
				"special": "energy_barrier",
				"cost": {"plasma_core": 1, "titanium": 15, "electronics": 10}
			}
		}
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## UPGRADE TIER DEFINITIONS
## ══════════════════════════════════════════════════════════════════════════════

static var _upgrade_tiers: Dictionary = {
	WeaponTier.BASIC: {
		"name": "Basic",
		"damage_multiplier": 1.0,
		"durability_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"crit_bonus": 0.0,
		"special": "",
		"color": Color.WHITE,
		"particle_effect": ""
	},
	
	WeaponTier.REINFORCED: {
		"name": "Reinforced",
		"damage_multiplier": 1.5,
		"durability_multiplier": 1.5,
		"speed_multiplier": 1.1,
		"crit_bonus": 0.05,
		"special": "reinforced",
		"color": Color.SILVER,
		"particle_effect": "res://assets/particles/reinforced_glow.tres"
	},
	
	WeaponTier.TITANIUM: {
		"name": "Titanium",
		"damage_multiplier": 2.5,
		"durability_multiplier": 2.5,
		"speed_multiplier": 1.2,
		"crit_bonus": 0.1,
		"special": "titanium",
		"color": Color.CYAN,
		"particle_effect": "res://assets/particles/titanium_glow.tres"
	},
	
	WeaponTier.PLASMA: {
		"name": "Plasma",
		"damage_multiplier": 4.0,
		"durability_multiplier": 3.0,
		"speed_multiplier": 1.3,
		"crit_bonus": 0.2,
		"special": "plasma",
		"color": Color.MAGENTA,
		"particle_effect": "res://assets/particles/plasma_glow.tres"
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## HELPER FUNCTIONS
## ══════════════════════════════════════════════════════════════════════════════

static func get_weapon_by_id(weapon_id: String) -> Dictionary:
	for weapon in _melee_weapon_data.values():
		if weapon["id"] == weapon_id:
			return weapon
	
	for weapon in _ranged_weapon_data.values():
		if weapon["id"] == weapon_id:
			return weapon
	
	return {}

static func get_upgrade_cost(weapon_id: String, current_tier: int) -> Dictionary:
	var weapon = get_weapon_by_id(weapon_id)
	if weapon.is_empty():
		return {}
	
	var upgrades = weapon.get("upgrades", {})
	var tier = current_tier + 1
	
	if upgrades.has(tier):
		return upgrades[tier].get("cost", {})
	
	return {}

static func get_tier_info(tier: int) -> Dictionary:
	return _upgrade_tiers.get(tier, {})

static func calculate_upgraded_stats(base_weapon: Dictionary, tier: int) -> Dictionary:
	var tier_data = _upgrade_tiers.get(tier, {})
	
	return {
		"damage": base_weapon["damage"] * tier_data.get("damage_multiplier", 1.0),
		"durability": int(base_weapon["durability"] * tier_data.get("durability_multiplier", 1.0)),
		"attack_speed": base_weapon.get("attack_speed", 1.0) * tier_data.get("speed_multiplier", 1.0),
		"crit_bonus": base_weapon.get("crit_bonus", 0.0) + tier_data.get("crit_bonus", 0.0),
		"special": tier_data.get("special", ""),
		"tier_name": tier_data.get("name", "Basic")
	}

static func get_all_craftable_items() -> Array:
	var items: Array = []
	
	# Add melee weapons
	for weapon in _melee_weapon_data.values():
		items.append({
			"type": "weapon_melee",
			"id": weapon["id"],
			"name": weapon["name"],
			"recipe": weapon["crafting_recipe"]
		})
	
	# Add ranged weapons
	for weapon in _ranged_weapon_data.values():
		items.append({
			"type": "weapon_ranged",
			"id": weapon["id"],
			"name": weapon["name"],
			"recipe": weapon["crafting_recipe"]
		})
	
	# Add ammo
	for ammo in _ammo_data.values():
		items.append({
			"type": "ammo",
			"id": ammo["id"],
			"name": ammo["name"],
			"recipe": ammo["crafting_recipe"]
		})
	
	# Add defenses
	for defense in _defense_data.values():
		items.append({
			"type": "defense",
			"id": defense["id"],
			"name": defense["name"],
			"recipe": defense["crafting_recipe"]
		})
	
	return items
