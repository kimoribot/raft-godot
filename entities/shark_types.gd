## Shark Types for RaftGodot
## Defines all shark variants with unique stats and behaviors

class_name SharkTypes
extends Node

## ══════════════════════════════════════════════════════════════════════════════
## ENUMS
## ══════════════════════════════════════════════════════════════════════════════

enum SharkType {
	BASIC,
	BIG,
	ELDER,
	HAMMERHEAD,
	GHOST
}

enum SharkBehavior {
	AGGRESSIVE,
	PASSIVE,
	STALKING,
	FEEDING,
	RETREATING,
	CHARGE
}

enum AttackPattern {
	SINGLE_BITE,
	LEAP_ATTACK,
	SWEEP_ATTACK,
	CIRCLE_CHARGE,
	SURPRISE_ATTACK
}

## ══════════════════════════════════════════════════════════════════════════════
## SHARK DATA DEFINITIONS
## ══════════════════════════════════════════════════════════════════════════════

static func get_shark_data(shark_type: SharkType) -> Dictionary:
	match shark_type:
		SharkType.BASIC:
			return _get_basic_shark_data()
		SharkType.BIG:
			return _get_big_shark_data()
		SharkType.ELDER:
			return _get_elder_shark_data()
		SharkType.HAMMERHEAD:
			return _get_hammerhead_data()
		SharkType.GHOST:
			return _get_ghost_shark_data()
	return _get_basic_shark_data()

static func _get_basic_shark_data() -> Dictionary:
	return {
		"type": SharkType.BASIC,
		"name": "Shark",
		"display_name": "Oceanic Shark",
		"health": 50.0,
		"max_health": 50.0,
		"damage": 15.0,
		"speed": 8.0,
		"swim_speed": 12.0,
		"turn_speed": 3.0,
		"scale": Vector3(1.0, 1.0, 1.0),
		"collision_radius": 2.0,
		"attack_range": 3.0,
		"detection_range": 25.0,
		"despawn_range": 50.0,
		"attack_cooldown": 3.0,
		"attack_pattern": AttackPattern.SINGLE_BITE,
		"behaviors": [SharkBehavior.AGGRESSIVE, SharkBehavior.STALKING],
		"rarity": 1.0,
		"is_boss": false,
		"special_abilities": [],
		"weak_points": ["eyes", "gills"],
		"resistances": [],
		"vulnerabilities": ["piercing"],
		"loot_table": ["shark_meat", "shark_fin", "fish_meat"],
		"spawn_weight": 70,
		"description": "A common oceanic shark that patrols the waters around your raft."
	}

static func _get_big_shark_data() -> Dictionary:
	return {
		"type": SharkType.BIG,
		"name": "Big Shark",
		"display_name": "Great White Shark",
		"health": 100.0,
		"max_health": 100.0,
		"damage": 25.0,
		"speed": 6.0,
		"swim_speed": 10.0,
		"turn_speed": 2.5,
		"scale": Vector3(1.8, 1.8, 1.8),
		"collision_radius": 3.5,
		"attack_range": 4.5,
		"detection_range": 30.0,
		"despawn_range": 60.0,
		"attack_cooldown": 4.0,
		"attack_pattern": AttackPattern.LEAP_ATTACK,
		"behaviors": [SharkBehavior.AGGRESSIVE, SharkBehavior.CIRCLE_CHARGE],
		"rarity": 1.0,
		"is_boss": false,
		"special_abilities": ["power_bite", "intimidate"],
		"weak_points": ["eyes", "nose"],
		"resistances": ["blunt"],
		"vulnerabilities": ["piercing", "slashing"],
		"loot_table": ["premium_shark_meat", "shark_fin", "shark_tooth", "fish_oil"],
		"spawn_weight": 20,
		"description": "A massive great white shark, more dangerous than its smaller cousins."
	}

static func _get_elder_shark_data() -> Dictionary:
	return {
		"type": SharkType.ELDER,
		"name": "Elder Shark",
		"display_name": "Ancient Elder Shark - BOSS",
		"health": 200.0,
		"max_health": 200.0,
		"damage": 35.0,
		"speed": 5.0,
		"swim_speed": 8.0,
		"turn_speed": 2.0,
		"scale": Vector3(2.5, 2.5, 2.5),
		"collision_radius": 5.0,
		"attack_range": 6.0,
		"detection_range": 40.0,
		"despawn_range": 80.0,
		"attack_cooldown": 5.0,
		"attack_pattern": AttackPattern.SWEEP_ATTACK,
		"behaviors": [SharkBehavior.AGGRESSIVE, SharkBehavior.CIRCLE_CHARGE, SharkBehavior.CHARGE],
		"rarity": 0.05,
		"is_boss": true,
		"special_abilities": ["devastating_bite", "enrage", "regeneration", "call_minions"],
		"weak_points": ["old_injury_scars"],
		"resistances": ["piercing", "slashing", "blunt"],
		"vulnerabilities": ["plasma"],
		"loot_table": ["elder_shark_meat", "ancient_shark_fin", "shark_pearl", "legendary_scale"],
		"spawn_weight": 5,
		"description": "A legendary ancient shark that has survived countless battles. Boss enemy!"
	}

static func _get_hammerhead_data() -> Dictionary:
	return {
		"type": SharkType.HAMMERHEAD,
		"name": "Hammerhead Shark",
		"display_name": "Hammerhead Shark",
		"health": 150.0,
		"max_health": 150.0,
		"damage": 35.0,
		"speed": 9.0,
		"swim_speed": 14.0,
		"turn_speed": 4.0,
		"scale": Vector3(1.3, 1.1, 1.4),
		"collision_radius": 2.5,
		"attack_range": 3.5,
		"detection_range": 35.0,
		"despawn_range": 65.0,
		"attack_cooldown": 2.5,
		"attack_pattern": AttackPattern.CIRCLE_CHARGE,
		"behaviors": [SharkBehavior.AGGRESSIVE, SharkBehavior.STALKING, SharkBehavior.CIRCLE_CHARGE],
		"rarity": 1.0,
		"is_boss": false,
		"special_abilities": ["wide_hammer_attack", "electroreception"],
		"weak_points": ["head_sides", "gills"],
		"resistances": [],
		"vulnerabilities": ["blunt"],
		"loot_table": ["hammerhead_meat", "shark_fin", "electroreceptor"],
		"spawn_weight": 15,
		"description": "A fast hammerhead shark with excellent maneuverability and wide attacks."
	}

static func _get_ghost_shark_data() -> Dictionary:
	return {
		"type": SharkType.GHOST,
		"name": "Ghost Shark",
		"display_name": "Phantom Ghost Shark",
		"health": 80.0,
		"max_health": 80.0,
		"damage": 50.0,
		"speed": 10.0,
		"swim_speed": 16.0,
		"turn_speed": 5.0,
		"scale": Vector3(0.9, 0.9, 0.9),
		"collision_radius": 1.8,
		"attack_range": 2.5,
		"detection_range": 15.0,
		"despawn_range": 40.0,
		"attack_cooldown": 2.0,
		"attack_pattern": AttackPattern.SURPRISE_ATTACK,
		"behaviors": [SharkBehavior.STALKING, SharkBehavior.PASSIVE, SharkBehavior.SURPRISE_ATTACK],
		"rarity": 0.02,
		"is_boss": false,
		"special_abilities": ["invisibility", "phase_through", "sneak_attack", "fear"],
		"weak_points": ["heart_glow"],
		"resistances": ["slashing"],
		"vulnerabilities": ["blunt", "plasma"],
		"loot_table": ["ghost_shark_meat", "spectral_fin", "ghost_essence", "invisibility_crystal"],
		"spawn_weight": 3,
		"description": "A rare spectral shark that can turn invisible and phase through objects."
	}

## ══════════════════════════════════════════════════════════════════════════════
## SPAWN WEIGHTS
## ══════════════════════════════════════════════════════════════════════════════

static func get_spawn_weights() -> Dictionary:
	return {
		SharkType.BASIC: 70,
		SharkType.BIG: 20,
		SharkType.ELDER: 5,
		SharkType.HAMMERHEAD: 15,
		SharkType.GHOST: 3
	}

static func get_random_shark_type(rng: RandomNumberGenerator = null) -> SharkType:
	var random = rng if rng else RandomNumberGenerator.new()
	random.randomize()
	
	var weights = get_spawn_weights()
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	var roll = random.randf() * total_weight
	var current_weight = 0
	
	for shark_type in weights.keys():
		current_weight += weights[shark_type]
		if roll <= current_weight:
			return shark_type
	
	return SharkType.BASIC

## ══════════════════════════════════════════════════════════════════════════════
## DAMAGE TYPE INTERACTIONS
## ══════════════════════════════════════════════════════════════════════════════

static func get_damage_effectiveness(shark_type: SharkType, damage_type: int) -> float:
	var data = get_shark_data(shark_type)
	
	# Check vulnerabilities
	if damage_type in data["vulnerabilities"]:
		return 1.5
	
	# Check resistances
	if damage_type in data["resistances"]:
		return 0.5
	
	return 1.0

## ══════════════════════════════════════════════════════════════════════════════
## BOSS SPECIFIC DATA
## ══════════════════════════════════════════════════════════════════════════════

static func get_boss_phases(shark_type: SharkType) -> Array:
	if shark_type == SharkType.ELDER:
		return [
			{
				"name": "Phase 1",
				"health_percentage": 1.0,
				"speed_multiplier": 1.0,
				"damage_multiplier": 1.0,
				"special_abilities": ["devastating_bite"]
			},
			{
				"name": "Phase 2",
				"health_percentage": 0.6,
				"speed_multiplier": 1.3,
				"damage_multiplier": 1.2,
				"special_abilities": ["enrage", "regeneration"]
			},
			{
				"name": "Phase 3",
				"health_percentage": 0.3,
				"speed_multiplier": 1.5,
				"damage_multiplier": 1.5,
				"special_abilities": ["call_minions", "frenzy"]
			}
		]
	return []

## ══════════════════════════════════════════════════════════════════════════════
## ATTACK PATTERN DEFINITIONS
## ══════════════════════════════════════════════════════════════════════════════

static func get_attack_pattern_data(pattern: AttackPattern) -> Dictionary:
	match pattern:
		AttackPattern.SINGLE_BITE:
			return {
				"name": "Single Bite",
				"damage_multiplier": 1.0,
				"windup_time": 0.5,
				"attack_duration": 0.3,
				"recovery_time": 1.0,
				"push_force": 5.0,
				"can_be_parried": true
			}
		AttackPattern.LEAP_ATTACK:
			return {
				"name": "Leap Attack",
				"damage_multiplier": 1.5,
				"windup_time": 1.0,
				"attack_duration": 0.5,
				"recovery_time": 1.5,
				"push_force": 10.0,
				"can_be_parried": true,
				"leap_distance": 10.0
			}
		AttackPattern.SWEEP_ATTACK:
			return {
				"name": "Sweep Attack",
				"damage_multiplier": 1.2,
				"windup_time": 0.8,
				"attack_duration": 0.8,
				"recovery_time": 1.2,
				"push_force": 8.0,
				"can_be_parried": false,
				"sweep_angle": 180.0,
				"sweep_radius": 8.0
			}
		AttackPattern.CIRCLE_CHARGE:
			return {
				"name": "Circle Charge",
				"damage_multiplier": 1.0,
				"windup_time": 0.3,
				"attack_duration": 2.0,
				"recovery_time": 0.5,
				"push_force": 6.0,
				"can_be_parried": true,
				"charge_circles": 2,
				"circle_radius": 5.0
			}
		AttackPattern.SURPRISE_ATTACK:
			return {
				"name": "Surprise Attack",
				"damage_multiplier": 2.0,
				"windup_time": 0.2,
				"attack_duration": 0.2,
				"recovery_time": 2.0,
				"push_force": 15.0,
				"can_be_parried": false,
				"requires_stealth": true,
				"damage_bonus_from_behind": 1.5
			}
	return {}

## ══════════════════════════════════════════════════════════════════════════════
## BEHAVIOR DEFINITIONS
## ══════════════════════════════════════════════════════════════════════════════

static func get_behavior_data(behavior: SharkBehavior) -> Dictionary:
	match behavior:
		SharkBehavior.AGGRESSIVE:
			return {
				"name": "Aggressive",
				"target_priority": "nearest",
				"attack_threshold": 0.8,
				"retreat_threshold": 0.2,
				"patrol_speed": 0.5,
				"chase_speed": 1.0
			}
		SharkBehavior.PASSIVE:
			return {
				"name": "Passive",
				"target_priority": "none",
				"attack_threshold": 0.0,
				"retreat_threshold": 1.0,
				"patrol_speed": 0.3,
				"chase_speed": 0.0
			}
		SharkBehavior.STALKING:
			return {
				"name": "Stalking",
				"target_priority": "player",
				"stalk_distance": 15.0,
				"stalk_speed": 0.6,
				"reveal_chance": 0.3,
				"can_be_seen_by_player": false
			}
		SharkBehavior.FEEDING:
			return {
				"name": "Feeding",
				"target_priority": "loot",
				"ignore_combat": true,
				"eat_duration": 3.0,
				"interruptible": true
			}
		SharkBehavior.RETREATING:
			return {
				"name": "Retreating",
				"target_priority": "none",
				"retreat_speed": 1.2,
				"health_to_retreat": 0.3,
				"distance_to_retreat": 30.0
			}
		SharkBehavior.CHARGE:
			return {
				"name": "Charge",
				"charge_speed": 2.0,
				"charge_duration": 1.5,
				"charge_cooldown": 5.0,
				"warning_time": 0.5
			}
	return {}

## ══════════════════════════════════════════════════════════════════════════════
## UTILITY FUNCTIONS
## ══════════════════════════════════════════════════════════════════════════════

static func is_boss_shark(shark_type: SharkType) -> bool:
	return get_shark_data(shark_type)["is_boss"]

static func get_rarity_text(shark_type: SharkType) -> String:
	var data = get_shark_data(shark_type)
	var rarity = data["rarity"]
	
	if rarity >= 1.0:
		return "Common"
	elif rarity >= 0.1:
		return "Uncommon"
	elif rarity >= 0.05:
		return "Rare"
	else:
		return "Legendary"

static func get_loot_drops(shark_type: SharkType, rng: RandomNumberGenerator = null) -> Array:
	var random = rng if rng else RandomNumberGenerator.new()
	random.randomize()
	
	var data = get_shark_data(shark_type)
	var loot_table = data["loot_table"]
	var drops: Array = []
	
	# Boss always drops something special
	if data["is_boss"]:
		drops.append(loot_table[loot_table.size() - 1]) # Best item
		drops.append_array(_roll_loot(loot_table, 3, random))
	else:
		drops.append_array(_roll_loot(loot_table, random.randf_range(1, 3), random))
	
	return drops

static func _roll_loot(loot_table: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var drops: Array = []
	for i in range(count):
		if rng.randf() > 0.3: # 70% chance per drop slot
			drops.append(loot_table[rng.randi() % loot_table.size()])
	return drops
