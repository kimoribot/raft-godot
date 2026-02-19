## Combat System for RaftGodot
## Implements deep melee/ranged combat with weapon progression

class_name CombatSystem
extends Node

## ══════════════════════════════════════════════════════════════════════════════
## ENUMS & CONSTANTS
## ══════════════════════════════════════════════════════════════════════════════

enum CombatState {
	IDLE,
	AIMING,
	ATTACKING,
	DEFENDING,
	COOLDOWN
}

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

enum DefenseType {
	SHIELD,
	PARRY,
	DODGE
}

enum WeaponTier {
	BASIC,
	REINFORCED,
	TITANIUM,
	PLASMA
}

## ══════════════════════════════════════════════════════════════════════════════
## SIGNALS
## ══════════════════════════════════════════════════════════════════════════════

signal weapon_swapped(new_weapon: String)
signal attack_performed(weapon_name: String, damage: float, is_critical: bool)
signal damage_dealt(target: Node, damage: float, damage_type: DamageType, is_critical: bool)
signal combat_state_changed(new_state: CombatState)
signal durability_changed(current: int, max: int)
signal weapon_broken(weapon_name: String)
signal parry_successful(attacker: Node)
signal dodge_successful()
signal critical_hit_landed(target: Node, damage: float, bonus_damage: float)

## ══════════════════════════════════════════════════════════════════════════════
## EXPORTED VARIABLES
## ══════════════════════════════════════════════════════════════════════════════

@export_category("Player Combat Stats")
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var base_crit_chance: float = 0.15
@export var base_crit_multiplier: float = 2.0
@export var parry_window: float = 0.2
@export var dodge_distance: float = 3.0
@export var parry_stamina_cost: float = 15.0
@export var dodge_stamina_cost: float = 25.0

@export_category("Defense Stats")
@export var shield_coverage: float = 0.75
@export var shield_block_bonus: float = 0.5
@export var parry_damage_reflection: float = 0.3
@export var damage_reduction_while_blocking: float = 0.6

@export_category("Raft Integration")
@export var is_on_raft: bool = true
@export var raft_defense_system: Node = null

## ══════════════════════════════════════════════════════════════════════════════
## PUBLIC VARIABLES
## ══════════════════════════════════════════════════════════════════════════════

var current_state: CombatState = CombatState.IDLE
var current_weapon: Dictionary = {}
var equipped_melee: MeleeWeapon = MeleeWeapon.SPEAR
var equipped_ranged: RangedWeapon = RangedWeapon.HARPOON_GUN
var is_aiming: bool = false
var is_blocking: bool = false
var can_attack: bool = true
var can_parry: bool = true
var can_dodge: bool = true
var current_combo: int = 0
var combo_timer: float = 0.0

var weapon_tiers: Dictionary = {}
var damage_multipliers: Dictionary = {
	DamageType.PIERCING: 1.0,
	DamageType.SLASHING: 1.0,
	DamageType.BLUNT: 1.0
}

## ══════════════════════════════════════════════════════════════════════════════
## DAMAGE TYPE DATA
## ══════════════════════════════════════════════════════════════════════════════

var damage_type_effects: Dictionary = {
	DamageType.PIERCING: {
		"vs_shark": 1.25,
		"vs_armored": 1.5,
		"stun_chance": 0.1,
		"bleed_chance": 0.25
	},
	DamageType.SLASHING: {
		"vs_shark": 1.0,
		"vs_armored": 0.8,
		"stun_chance": 0.15,
		"bleed_chance": 0.4
	},
	DamageType.BLUNT: {
		"vs_shark": 0.8,
		"vs_armored": 1.3,
		"stun_chance": 0.3,
		"bleed_chance": 0.0
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## WEAPON STATS (Loaded from weapon_stats.gd)
## ══════════════════════════════════════════════════════════════════════════════

var melee_weapon_data: Dictionary = {}
var ranged_weapon_data: Dictionary = {}
var ammo_data: Dictionary = {}

## ══════════════════════════════════════════════════════════════════════════════
## INITIALIZATION
## ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_weapon_data()
	_setup_weapon_tiers()
	_equip_default_weapons()

func _load_weapon_data() -> void:
	# Load weapon stats from weapon_stats.gd
	if ResourceLoader.exists("res://data/weapon_stats.gd"):
		var weapon_stats_script = load("res://data/weapon_stats.gd")
		if weapon_stats_script:
			melee_weapon_data = weapon_stats_script.get_melee_weapon_data()
			ranged_weapon_data = weapon_stats_script.get_ranged_weapon_data()
			ammo_data = weapon_stats_script.get_ammo_data()
	
	# Fallback default data if file not found
	if melee_weapon_data.is_empty():
		_set_default_melee_data()
	if ranged_weapon_data.is_empty():
		_set_default_ranged_data()
	if ammo_data.is_empty():
		_set_default_ammo_data()

func _set_default_melee_data() -> void:
	melee_weapon_data = {
		MeleeWeapon.SPEAR: {
			"name": "Spear",
			"damage": 25.0,
			"damage_type": DamageType.PIERCING,
			"range": 4.0,
			"attack_speed": 1.2,
			"durability": 100,
			"durability_per_hit": 2,
			"crit_bonus": 0.05,
			"combo_enabled": true,
			"description": "Versatile polearm, good reach and piercing damage"
		},
		MeleeWeapon.TRIDENT: {
			"name": "Trident",
			"damage": 35.0,
			"damage_type": DamageType.PIERCING,
			"range": 3.5,
			"attack_speed": 1.0,
			"durability": 120,
			"durability_per_hit": 3,
			"crit_bonus": 0.1,
			"combo_enabled": true,
			"description": "Three-pronged spear, hits multiple targets"
		},
		MeleeWeapon.KNIFE: {
			"name": "Knife",
			"damage": 15.0,
			"damage_type": DamageType.SLASHING,
			"range": 1.5,
			"attack_speed": 2.0,
			"durability": 80,
			"durability_per_hit": 1,
			"crit_bonus": 0.2,
			"combo_enabled": true,
			"description": "Fast slashing weapon, high critical chance"
		},
		MeleeWeapon.AXE: {
			"name": "Axe",
			"damage": 45.0,
			"damage_type": DamageType.SLASHING,
			"range": 2.0,
			"attack_speed": 0.8,
			"durability": 150,
			"durability_per_hit": 4,
			"crit_bonus": 0.15,
			"combo_enabled": false,
			"description": "Heavy chopping weapon, high damage but slow"
		}
	}

func _set_default_ranged_data() -> void:
	ranged_weapon_data = {
		RangedWeapon.HARPOON_GUN: {
			"name": "Harpoon Gun",
			"damage": 50.0,
			"damage_type": DamageType.PIERCING,
			"range": 20.0,
			"fire_rate": 1.5,
			"durability": 80,
			"durability_per_shot": 2,
			"ammo_type": "harpoon",
			"piercing": true,
			"pierce_count": 3,
			"description": "Fires harpoons that pierce through enemies"
		},
		RangedWeapon.FLARE_GUN: {
			"name": "Flare Gun",
			"damage": 20.0,
			"damage_type": DamageType.BLUNT,
			"range": 15.0,
			"fire_rate": 3.0,
			"durability": 50,
			"durability_per_shot": 1,
			"ammo_type": "flare",
			"area_damage": true,
			"burn_damage": 5.0,
			"burn_duration": 5.0,
			"description": "Lights up area and deals burn damage"
		},
		RangedWeapon.ANCHOR_BOMB: {
			"name": "Anchor Bomb",
			"damage": 80.0,
			"damage_type": DamageType.BLUNT,
			"range": 12.0,
			"fire_rate": 2.5,
			"durability": 40,
			"durability_per_shot": 3,
			"ammo_type": "anchor_bomb",
			"explosive": true,
			"explosion_radius": 5.0,
			"description": "Thrown explosive anchor, area damage"
		}
	}

func _set_default_ammo_data() -> void:
	ammo_data = {
		"harpoon": {
			"name": "Harpoon",
			"stack_size": 50,
			"damage": 0,
			"effect": "pierce",
			"crafting_recipe": {"wood": 2, "metal": 1}
		},
		"flare": {
			"name": "Flare",
			"stack_size": 20,
			"damage": 0,
			"effect": "light",
			"burn_damage": 5.0,
			"crafting_recipe": {"cloth": 2, "plastic": 1}
		},
		"anchor_bomb": {
			"name": "Anchor Bomb",
			"stack_size": 10,
			"damage": 0,
			"effect": "explode",
			"crafting_recipe": {"metal": 5, "explosive": 1}
		}
	}

func _setup_weapon_tiers() -> void:
	weapon_tiers = {
		WeaponTier.BASIC: {
			"damage_multiplier": 1.0,
			"durability_multiplier": 1.0,
			"crit_bonus": 0.0,
			"speed_bonus": 1.0,
			"special_effect": "",
			"color": Color.WHITE
		},
		WeaponTier.REINFORCED: {
			"damage_multiplier": 1.5,
			"durability_multiplier": 1.5,
			"crit_bonus": 0.05,
			"speed_bonus": 1.1,
			"special_effect": "reinforced",
			"color": Color.SILVER
		},
		WeaponTier.TITANIUM: {
			"damage_multiplier": 2.5,
			"durability_multiplier": 2.5,
			"crit_bonus": 0.1,
			"speed_bonus": 1.2,
			"special_effect": "titanium",
			"color": Color.CYAN
		},
		WeaponTier.PLASMA: {
			"damage_multiplier": 4.0,
			"durability_multiplier": 3.0,
			"crit_bonus": 0.2,
			"speed_bonus": 1.3,
			"special_effect": "plasma_burn",
			"color": Color.MAGENTA
		}
	}

func _equip_default_weapons() -> void:
	current_weapon = {
		"category": WeaponCategory.MELEE,
		"type": equipped_melee,
		"tier": WeaponTier.BASIC,
		"current_durability": melee_weapon_data[equipped_melee]["durability"],
		"max_durability": melee_weapon_data[equipped_melee]["durability"]
	}

## ══════════════════════════════════════════════════════════════════════════════
## COMBAT STATE MANAGEMENT
## ══════════════════════════════════════════════════════════════════════════════

func set_combat_state(new_state: CombatState) -> void:
	if current_state != new_state:
		current_state = new_state
		combat_state_changed.emit(new_state)
		
		match new_state:
			CombatState.IDLE:
				is_aiming = false
				is_blocking = false
			CombatState.AIMING:
				is_aiming = true
			CombatState.ATTACKING:
				pass
			CombatState.DEFENDING:
				is_blocking = true

func get_current_state_name() -> String:
	return CombatState.keys()[current_state]

## ══════════════════════════════════════════════════════════════════════════════
## WEAPON MANAGEMENT
## ══════════════════════════════════════════════════════════════════════════════

func equip_weapon(category: WeaponCategory, weapon_type: int, tier: int = 0) -> void:
	var weapon_data: Dictionary
	
	match category:
		WeaponCategory.MELEE:
			weapon_data = melee_weapon_data[weapon_type]
			equipped_melee = weapon_type
		WeaponCategory.RANGED:
			weapon_data = ranged_weapon_data[weapon_type]
			equipped_ranged = weapon_type
	
	var tier_data = weapon_tiers[tier]
	
	current_weapon = {
		"category": category,
		"type": weapon_type,
		"tier": tier,
		"current_durability": weapon_data["durability"] * tier_data["durability_multiplier"],
		"max_durability": weapon_data["durability"] * tier_data["durability_multiplier"],
		"tier_data": tier_data
	}
	
	weapon_swapped.emit(weapon_data["name"])

func swap_weapon_category() -> void:
	if current_weapon["category"] == WeaponCategory.MELEE:
		current_weapon["category"] = WeaponCategory.RANGED
		current_weapon["type"] = equipped_ranged
		current_weapon["current_durability"] = ranged_weapon_data[equipped_ranged]["durability"]
		current_weapon["max_durability"] = ranged_weapon_data[equipped_ranged]["durability"]
	else:
		current_weapon["category"] = WeaponCategory.MELEE
		current_weapon["type"] = equipped_melee
		current_weapon["current_durability"] = melee_weapon_data[equipped_melee]["durability"]
		current_weapon["max_durability"] = melee_weapon_data[equipped_melee]["durability"]

func upgrade_weapon_tier() -> bool:
	var current_tier = current_weapon["tier"]
	if current_tier >= WeaponTier.PLASMA:
		return false
	
	var new_tier = current_tier + 1
	var category = current_weapon["category"]
	var weapon_type = current_weapon["type"]
	
	equip_weapon(category, weapon_type, new_tier)
	return true

func get_current_weapon_name() -> String:
	var weapon_data = _get_current_weapon_data()
	var tier_data = current_weapon.get("tier_data", weapon_tiers[WeaponTier.BASIC])
	var tier_name = WeaponTier.keys()[current_weapon["tier"]]
	return "%s (%s)" % [weapon_data["name"], tier_name]

func _get_current_weapon_data() -> Dictionary:
	match current_weapon["category"]:
		WeaponCategory.MELEE:
			return melee_weapon_data[current_weapon["type"]]
		WeaponCategory.RANGED:
			return ranged_weapon_data[current_weapon["type"]]
	return {}

## ══════════════════════════════════════════════════════════════════════════════
## ATTACK SYSTEM
## ══════════════════════════════════════════════════════════════════════════════

func can_attack_now() -> bool:
	return can_attack and current_health > 0

func perform_attack(target: Node = null) -> Dictionary:
	if not can_attack_now():
		return {"success": false, "reason": "Cannot attack"}
	
	var weapon_data = _get_current_weapon_data()
	var tier_data = current_weapon.get("tier_data", weapon_tiers[WeaponTier.BASIC])
	
	set_combat_state(CombatState.ATTACKING)
	can_attack = false
	
	# Calculate damage
	var base_damage = weapon_data["damage"]
	var tier_multiplier = tier_data["damage_multiplier"]
	var damage_type = weapon_data["damage_type"]
	
	# Check for critical hit
	var crit_chance = base_crit_chance + weapon_data.get("crit_bonus", 0.0) + tier_data["crit_bonus"]
	var is_critical = randf() < crit_chance
	var crit_multiplier = base_crit_multiplier
	
	var final_damage = base_damage * tier_multiplier * crit_multiplier if is_critical else base_damage * tier_multiplier
	
	# Apply damage type multipliers
	final_damage *= damage_type_effects[damage_type].get("vs_shark", 1.0)
	
	# Apply combo bonus
	if weapon_data.get("combo_enabled", false):
		current_combo = mini(current_combo + 1, 3)
		combo_timer = 1.5
		final_damage *= (1.0 + current_combo * 0.1)
	
	# Deal damage to target if exists
	var damage_dealt = 0.0
	if is_instance_valid(target):
		damage_dealt = _deal_damage_to_target(target, final_damage, damage_type, is_critical)
	
	# Reduce durability
	_reduce_durability(weapon_data.get("durability_per_hit", 1))
	
	# Emit signals
	attack_performed.emit(weapon_data["name"], final_damage, is_critical)
	if is_critical and damage_dealt > 0:
		critical_hit_landed.emit(target, final_damage, final_damage - base_damage)
	
	# Set cooldown
	var attack_speed = weapon_data.get("attack_speed", 1.0) * tier_data["speed_bonus"]
	await get_tree().create_timer(1.0 / attack_speed).timeout
	
	set_combat_state(CombatState.IDLE)
	can_attack = true
	
	return {
		"success": true,
		"damage": damage_dealt,
		"is_critical": is_critical,
		"weapon_name": weapon_data["name"]
	}

func perform_ranged_attack(target_position: Vector3) -> Dictionary:
	if not can_attack_now():
		return {"success": false, "reason": "Cannot attack"}
	
	var weapon_data = _get_current_weapon_data()
	var tier_data = current_weapon.get("tier_data", weapon_tiers[WeaponTier.BASIC])
	
	set_combat_state(CombatState.AIMING)
	can_attack = false
	
	# Calculate damage
	var base_damage = weapon_data["damage"]
	var tier_multiplier = tier_data["damage_multiplier"]
	var damage_type = weapon_data["damage_type"]
	var final_damage = base_damage * tier_multiplier
	
	# Reduce ammo
	_reduce_ammo(weapon_data.get("ammo_type", "harpoon"))
	
	# Reduce durability
	_reduce_durability(weapon_data.get("durability_per_shot", 1))
	
	# Emit attack signal for projectile spawning
	attack_performed.emit(weapon_data["name"], final_damage, false)
	
	# Set cooldown
	var fire_rate = weapon_data.get("fire_rate", 1.0)
	await get_tree().create_timer(1.0 / fire_rate).timeout
	
	set_combat_state(CombatState.IDLE)
	can_attack = true
	
	return {
		"success": true,
		"damage": final_damage,
		"target_position": target_position,
		"weapon_data": weapon_data,
		"tier_data": tier_data,
		"damage_type": damage_type
	}

func _deal_damage_to_target(target: Node, damage: float, damage_type: DamageType, is_critical: bool) -> float:
	if target.has_method("take_damage"):
		var actual_damage = target.take_damage(damage, damage_type, is_critical)
		damage_dealt.emit(target, actual_damage, damage_type, is_critical)
		return actual_damage
	return 0.0

func _reduce_durability(amount: int) -> void:
	current_weapon["current_durability"] = maxi(0, current_weapon["current_durability"] - amount)
	durability_changed.emit(
		current_weapon["current_durability"],
		current_weapon["max_durability"]
	)
	
	if current_weapon["current_durability"] <= 0:
		weapon_broken.emit(get_current_weapon_name())
		_equip_default_weapons()

func _reduce_ammo(ammo_type: String) -> void:
	# This would interact with inventory system
	pass

## ══════════════════════════════════════════════════════════════════════════════
## DEFENSE SYSTEM
## ══════════════════════════════════════════════════════════════════════════════

func start_blocking() -> void:
	if not is_blocking:
		set_combat_state(CombatState.DEFENDING)
		is_blocking = true

func stop_blocking() -> void:
	if is_blocking:
		set_combat_state(CombatState.IDLE)
		is_blocking = false

func get_block_damage_reduction() -> float:
	if is_blocking:
		return damage_reduction_while_blocking
	return 0.0

func attempt_parry(attacker: Node) -> bool:
	if not can_parry:
		return false
	
	can_parry = false
	
	# Create parry window
	await get_tree().create_timer(parry_window).timeout
	
	# Check if attacker is in range (simplified)
	var parry_success = true
	
	if parry_success:
		parry_successful.emit(attacker)
		# Reflect some damage back
		if attacker.has_method("take_damage"):
			attacker.take_damage(
				attacker.get_damage() * parry_damage_reflection,
				DamageType.BLUNT,
				false
			)
	else:
		# Failed parry, take extra damage
		pass
	
	# Reset parry ability
	await get_tree().create_timer(1.0).timeout
	can_parry = true
	
	return parry_success

func attempt_dodge(direction: Vector3 = Vector3.FORWARD) -> bool:
	if not can_dodge:
		return false
	
	can_dodge = false
	
	# Play dodge animation/movement
	# This would integrate with character controller
	dodge_successful.emit()
	
	# Reset dodge ability
	await get_tree().create_timer(0.8).timeout
	can_dodge = true
	
	return true

## ══════════════════════════════════════════════════════════════════════════════
## DAMAGE RECEIVING
## ══════════════════════════════════════════════════════════════════════════════

func take_damage(amount: float, damage_type: DamageType, is_critical: bool = false) -> float:
	var final_damage = amount
	
	# Apply defense reduction if blocking
	if is_blocking:
		final_damage *= (1.0 - get_block_damage_reduction())
	
	# Apply damage type resistance
	final_damage *= damage_type_effects[damage_type].get("vs_shark", 1.0)
	
	current_health = maxi(0, current_health - final_damage)
	
	if current_health <= 0:
		_die()
	
	return final_damage

func heal(amount: float) -> void:
	current_health = mini(max_health, current_health + amount)

func _die() -> void:
	set_combat_state(CombatState.COOLDOWN)
	# Handle player death
	print("Player died!")

## ══════════════════════════════════════════════════════════════════════════════
## COMBO SYSTEM
## ══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			current_combo = 0

## ══════════════════════════════════════════════════════════════════════════════
## RAFT INTEGRATION
## ══════════════════════════════════════════════════════════════════════════════

func is_near_raft_defense() -> bool:
	if raft_defense_system and is_instance_valid(raft_defense_system):
		return raft_defense_system.has_nearby_defense(global_position)
	return false

func get_nearest_defense() -> Node:
	if raft_defense_system and is_instance_valid(raft_defense_system):
		return raft_defense_system.get_nearest_defense(global_position)
	return null

## ══════════════════════════════════════════════════════════════════════════════
## UTILITY FUNCTIONS
## ══════════════════════════════════════════════════════════════════════════════

func get_durability_percentage() -> float:
	return float(current_weapon["current_durability"]) / float(current_weapon["max_durability"])

func is_weapon_broken() -> bool:
	return current_weapon["current_durability"] <= 0

func get_weapon_info() -> Dictionary:
	var weapon_data = _get_current_weapon_data()
	var tier_data = current_weapon.get("tier_data", weapon_tiers[WeaponTier.BASIC])
	
	return {
		"name": weapon_data.get("name", "Unknown"),
		"damage": weapon_data.get("damage", 0) * tier_data["damage_multiplier"],
		"damage_type": DamageType.keys()[weapon_data.get("damage_type", 0)],
		"range": weapon_data.get("range", 0),
		"durability": current_weapon["current_durability"],
		"max_durability": current_weapon["max_durability"],
		"tier": WeaponTier.keys()[current_weapon["tier"]],
		"tier_color": tier_data["color"],
		"special_effect": tier_data["special_effect"]
	}

func apply_damage_type_multiplier(dtype: DamageType, multiplier: float) -> void:
	damage_multipliers[dtype] = multiplier
