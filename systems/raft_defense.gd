## Raft Defense System for RaftGodot
## Placeable defenses, auto-attack, and raft armor mechanics

class_name RaftDefense
extends Node

## ══════════════════════════════════════════════════════════════════════════════
## ENUMS
## ══════════════════════════════════════════════════════════════════════════════

enum DefenseType {
	SPIKE_WALL,
	HARPOON_TURRET,
	SHARK_DETERRENT,
	RAFT_ARMOR,
	WATER_CANNON,
	ELECTRIC_FENCE
}

enum DefenseState {
	INACTIVE,
	ACTIVE,
	COOLDOWN,
	BROKEN
}

enum DefenseTier {
	WOODEN,
	METAL,
	TITANIUM,
	PLASMA
}

## ══════════════════════════════════════════════════════════════════════════════
## SIGNALS
## ══════════════════════════════════════════════════════════════════════════════

signal defense_placed(defense_id: int, defense_type: DefenseType)
signal defense_destroyed(defense_id: int, defense_type: DefenseType)
signal defense_triggered(defense_id: int, target: Node)
signal defense_repaired(defense_id: int)
signal turret_fired(defense_id: int, target_position: Vector3)
signal shark_scared(shark: Node, reason: String)
signal raft_damage_reduced(amount: float, final_damage: float)
signal defense_upgraded(defense_id: int, old_tier: DefenseTier, new_tier: DefenseTier)

## ══════════════════════════════════════════════════════════════════════════════
## EXPORTED VARIABLES
## ══════════════════════════════════════════════════════════════════════════════

@export_category("Raft Properties")
@export var raft_health: float = 500.0
@export var raft_max_health: float = 500.0
@export var raft_armor: float = 0.0
@export var max_raft_armor: float = 100.0
@export var detection_radius: float = 30.0
@export var auto_attack_enabled: bool = true
@export var defense_activation_delay: float = 0.5

@export_category("Defense Costs")
@export var spike_wall_cost: Dictionary = {"wood": 10, "metal": 5}
@export var harpoon_turret_cost: Dictionary = {"wood": 15, "metal": 10, "rope": 5}
@export var shark_deterrent_cost: Dictionary = {"plastic": 20, "electronics": 5}
@export var raft_armor_cost: Dictionary = {"metal": 50}

@export_category("Turret Settings")
@export var turret_fire_rate: float = 1.0
@export var turret_rotation_speed: float = 180.0
@export var turret_projectile_speed: float = 30.0
@export var turret_damage: float = 25.0
@export var max_turret_range: float = 25.0

@export_category("Spike Wall Settings")
@export var spike_damage: float = 10.0
@export var spike_attack_cooldown: float = 1.0
@export var spike_armor_piercing: float = 0.5

@export_category("Deterrent Settings")
@export var deterrent_effect_radius: float = 15.0
@export var deterrent_scare_strength: float = 0.7
@export var deterrent_cooldown: float = 2.0

## ══════════════════════════════════════════════════════════════════════════════
## PUBLIC VARIABLES
## ══════════════════════════════════════════════════════════════════════════════

var defenses: Dictionary = {}  # defense_id -> defense_data
var next_defense_id: int = 0
var nearest_shark: Node = null
var is_raft_damaged: bool = false

## Defense tier data
var defense_tiers: Dictionary = {
	DefenseTier.WOODEN: {
		"damage_multiplier": 1.0,
		"durability": 100,
		"armor_bonus": 0,
		"special": "",
		"color": Color(0.6, 0.4, 0.2)
	},
	DefenseTier.METAL: {
		"damage_multiplier": 1.5,
		"durability": 200,
		"armor_bonus": 10,
		"special": "rust_resistant",
		"color": Color(0.7, 0.7, 0.7)
	},
	DefenseTier.TITANIUM: {
		"damage_multiplier": 2.5,
		"durability": 400,
		"armor_bonus": 25,
		"special": "reinforced",
		"color": Color(0.5, 0.8, 0.9)
	},
	DefenseTier.PLASMA: {
		"damage_multiplier": 4.0,
		"durability": 600,
		"armor_bonus": 50,
		"special": "plasma_burn",
		"color": Color(0.8, 0.2, 1.0)
	}
}

## ══════════════════════════════════════════════════════════════════════════════
## INITIALIZATION
## ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_defense_types()
	_check_for_sharks()

func _setup_defense_types() -> void:
	# Additional setup for defense types if needed
	pass

func _process(delta: float) -> void:
	if auto_attack_enabled:
		_update_defenses(delta)

func _update_defenses(delta: float) -> void:
	nearest_shark = _find_nearest_shark()
	
	if nearest_shark and is_instance_valid(nearest_shark):
		# Update spike walls (passive damage when sharks get close)
		for defense_id in defenses:
			var defense = defenses[defense_id]
			if defense["type"] == DefenseType.SPIKE_WALL and defense["state"] == DefenseState.ACTIVE:
				_update_spike_wall(defense_id, delta)
		
		# Update turrets to target
		for defense_id in defenses:
			var defense = defenses[defense_id]
			if defense["type"] == DefenseType.HARPOON_TURRET and defense["state"] == DefenseState.ACTIVE:
				_update_turret_targeting(defense_id, delta)
		
		# Check shark deterrents
		_update_deterrents()

func _find_nearest_shark() -> Node:
	var sharks = get_tree().get_nodes_in_group("sharks")
	var nearest: Node = null
	var nearest_dist = detection_radius
	
	for shark in sharks:
		if is_instance_valid(shark):
			var dist = global_position.distance_to(shark.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = shark
	
	return nearest

func _update_turret_targeting(defense_id: int, delta: float) -> void:
	var defense = defenses[defense_id]
	
	if not nearest_shark or not is_instance_valid(nearest_shark):
		return
	
	var target_pos = nearest_shark.global_position
	var turret_pos = defense["position"]
	var to_target = target_pos - turret_pos
	var distance = to_target.length()
	
	if distance > max_turret_range:
		return
	
	# Rotate towards target
	var target_rotation = atan2(to_target.x, to_target.z)
	var current_rotation = defense["rotation"]
	var diff = target_rotation - current_rotation
	
	# Normalize angle
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	
	var rotation_step = deg_to_rad(turret_rotation_speed) * delta
	if abs(diff) < rotation_step:
		defense["rotation"] = target_rotation
		_fire_turret(defense_id)
	else:
		defense["rotation"] += sign(diff) * rotation_step

func _update_deterrents() -> void:
	for defense_id in defenses:
		var defense = defenses[defense_id]
		if defense["type"] == DefenseType.SHARK_DETERRENT and defense["state"] == DefenseState.ACTIVE:
			_activate_deterrent(defense_id)

## ══════════════════════════════════════════════════════════════════════════════
## DEFENSE PLACEMENT
## ══════════════════════════════════════════════════════════════════════════════

func can_place_defense(defense_type: DefenseType, position: Vector3) -> bool:
	# Check if position is on the raft
	if not _is_on_raft(position):
		return false
	
	# Check if there's already a defense too close
	for defense_id in defenses:
		var existing = defenses[defense_id]
		if existing["position"].distance_to(position) < 2.0:
			return false
	
	# Check resource costs (would integrate with inventory system)
	return true

func place_defense(defense_type: DefenseType, position: Vector3, tier: DefenseTier = DefenseTier.WOODEN) -> int:
	if not can_place_defense(defense_type, position):
		return -1
	
	var tier_data = defense_tiers[tier]
	var defense_id = next_defense_id
	next_defense_id += 1
	
	var defense_data = {
		"id": defense_id,
		"type": defense_type,
		"position": position,
		"rotation": 0.0,
		"tier": tier,
		"state": DefenseState.ACTIVE,
		"current_durability": tier_data["durability"],
		"max_durability": tier_data["durability"],
		"cooldown_timer": 0.0,
		"fire_timer": 0.0,
		"kills": 0,
		"damage_dealt": 0.0
	}
	
	# Type-specific initialization
	match defense_type:
		DefenseType.SPIKE_WALL:
			defense_data["spike_damage"] = spike_damage * tier_data["damage_multiplier"]
			defense_data["attack_cooldown"] = spike_attack_cooldown
			defense_data["last_attack_time"] = 0.0
		DefenseType.HARPOON_TURRET:
			defense_data["ammo"] = 20
			defense_data["max_ammo"] = 20
		DefenseType.SHARK_DETERRENT:
			defense_data["effect_radius"] = deterrent_effect_radius
			defense_data["scare_strength"] = deterrent_scare_strength
			defense_data["cooldown_timer"] = deterrent_cooldown
		DefenseType.RAFT_ARMOR:
			_apply_armor_bonus(tier_data["armor_bonus"])
	
	defenses[defense_id] = defense_data
	defense_placed.emit(defense_id, defense_type)
	
	return defense_id

func remove_defense(defense_id: int) -> bool:
	if not defenses.has(defense_id):
		return false
	
	var defense = defenses[defense_id]
	var defense_type = defense["type"]
	
	# Return resources (partial based on durability)
	var return_percentage = float(defense["current_durability"]) / float(defense["max_durability"])
	# Would integrate with inventory system to return resources
	
	defenses.erase(defense_id)
	defense_destroyed.emit(defense_id, defense_type)
	
	return true

func _is_on_raft(position: Vector3) -> bool:
	# Simplified check - would integrate with raft system
	return position.y < 2.0 and abs(position.x) < 20.0 and abs(position.z) < 20.0

## ══════════════════════════════════════════════════════════════════════════════
## DEFENSE UPGRADE
## ══════════════════════════════════════════════════════════════════════════════

func upgrade_defense(defense_id: int, new_tier: DefenseTier) -> bool:
	if not defenses.has(defense_id):
		return false
	
	var defense = defenses[defense_id]
	var current_tier = defense["tier"]
	
	if new_tier <= current_tier:
		return false
	
	var old_tier_data = defense_tiers[current_tier]
	var new_tier_data = defense_tiers[new_tier]
	
	# Calculate upgrade cost (difference between tiers)
	# Would integrate with inventory system
	
	defense["tier"] = new_tier
	defense["max_durability"] = new_tier_data["durability"]
	defense["current_durability"] = new_tier_data["durability"]
	defense["damage_multiplier"] = new_tier_data["damage_multiplier"]
	
	# Apply armor bonus if it's a raft armor piece
	if defense["type"] == DefenseType.RAFT_ARMOR:
		_apply_armor_bonus(new_tier_data["armor_bonus"] - old_tier_data["armor_bonus"])
	
	defense_upgraded.emit(defense_id, current_tier, new_tier)
	
	return true

func _apply_armor_bonus(amount: float) -> void:
	raft_armor = clamp(raft_armor + amount, 0, max_raft_armor)

## ══════════════════════════════════════════════════════════════════════════════
## AUTO-ATTACK SYSTEM
## ══════════════════════════════════════════════════════════════════════════════

func _fire_turret(defense_id: int) -> void:
	var defense = defenses[defense_id]
	
	# Check cooldown
	if defense["fire_timer"] > 0:
		return
	
	# Check ammo
	if defense.get("ammo", 0) <= 0:
		return
	
	# Find target
	var target = _find_best_turret_target(defense["position"])
	if not target:
		return
	
	# Fire!
	defense["ammo"] -= 1
	defense["fire_timer"] = 1.0 / turret_fire_rate
	
	var damage = turret_damage * defense["damage_multiplier"]
	
	# Create projectile or deal direct damage
	if target.has_method("take_damage"):
		var actual_damage = target.take_damage(damage, 0, false)  # 0 = piercing
		defense["damage_dealt"] += actual_damage
	
	turret_fired.emit(defense_id, target.global_position)
	defense_triggered.emit(defense_id, target)

func _find_best_turret_target(turret_pos: Vector3) -> Node:
	var sharks = get_tree().get_nodes_in_group("sharks")
	var best_target: Node = null
	var best_score = -1.0
	
	for shark in sharks:
		if not is_instance_valid(shark):
			continue
		
		var dist = turret_pos.distance_to(shark.global_position)
		if dist > max_turret_range:
			continue
		
		# Score based on proximity and health (prefer finishing weak enemies)
		var health_ratio = shark.current_health / shark.max_health
		var score = (1.0 - health_ratio) / (dist / max_turret_range)
		
		if score > best_score:
			best_score = score
			best_target = shark
	
	return best_target

## ══════════════════════════════════════════════════════════════════════════════
## SHARK DETERRENT
## ══════════════════════════════════════════════════════════════════════════════

func _activate_deterrent(defense_id: int) -> void:
	var defense = defenses[defense_id]
	var deterrent_pos = defense["position"]
	var effect_radius = defense["effect_radius"]
	var scare_strength = defense["scare_strength"]
	
	var sharks = get_tree().get_nodes_in_group("sharks")
	
	for shark in sharks:
		if not is_instance_valid(shark):
			continue
		
		var dist = deterrent_pos.distance_to(shark.global_position)
		if dist > effect_radius:
			continue
		
		# Apply fear effect
		if shark.has_method("apply_fear"):
			var fear_amount = scare_strength * (1.0 - dist / effect_radius)
			shark.apply_fear(fear_amount, deterrent_pos)
			shark_scared.emit(shark, "deterrent")

## ══════════════════════════════════════════════════════════════════════════════
## RAFT DAMAGE & ARMOR
## ══════════════════════════════════════════════════════════════════════════════

func damage_raft(amount: float, damage_type: int = 0) -> float:
	# Apply armor reduction
	var damage_reduction = _calculate_armor_reduction()
	var final_damage = amount * (1.0 - damage_reduction)
	
	raft_health = max(0, raft_health - final_damage)
	raft_damage_reduced.emit(amount - final_damage, final_damage)
	
	if raft_health <= 0:
		_raft_destroyed()
	
	return final_damage

func _calculate_armor_reduction() -> float:
	# Armor provides diminishing returns
	# 0 armor = 0%, 50 armor = 50%, 100 armor = 66%
	return clamp(raft_armor / (raft_armor + 100.0), 0, 0.66)

func repair_raft(amount: float) -> void:
	raft_health = min(raft_max_health, raft_health + amount)

func _raft_destroyed() -> void:
	# Handle raft destruction
	print("Raft has been destroyed!")

## ══════════════════════════════════════════════════════════════════════════════
## DEFENSE DURABILITY
## ══════════════════════════════════════════════════════════════════════════════

func damage_defense(defense_id: int, amount: float) -> bool:
	if not defenses.has(defense_id):
		return false
	
	var defense = defenses[defense_id]
	defense["current_durability"] = max(0, defense["current_durability"] - amount)
	
	if defense["current_durability"] <= 0:
		_destroy_defense(defense_id)
		return true
	
	return false

func repair_defense(defense_id: int, amount: float) -> bool:
	if not defenses.has(defense_id):
		return false
	
	var defense = defenses[defense_id]
	defense["current_durability"] = min(
		defense["max_durability"],
		defense["current_durability"] + amount
	)
	defense_repaired.emit(defense_id)
	return true

func _destroy_defense(defense_id: int) -> void:
	var defense = defenses[defense_id]
	defense["state"] = DefenseState.BROKEN
	defense_destroyed.emit(defense_id, defense["type"])
	
	# Remove from active defenses
	defenses.erase(defense_id)

## ══════════════════════════════════════════════════════════════════════════════
## COOLDOWN UPDATES
## ══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	# Update cooldowns
	for defense_id in defenses:
		var defense = defenses[defense_id]
		
		if defense["cooldown_timer"] > 0:
			defense["cooldown_timer"] -= delta
		
		if defense["fire_timer"] > 0:
			defense["fire_timer"] -= delta

## ══════════════════════════════════════════════════════════════════════════════
## UTILITY FUNCTIONS
## ══════════════════════════════════════════════════════════════════════════════

func has_nearby_defense(position: Vector3, radius: float = 5.0) -> bool:
	for defense_id in defenses:
		var defense = defenses[defense_id]
		if defense["position"].distance_to(position) < radius:
			return true
	return false

func get_nearest_defense(position: Vector3) -> Node:
	var nearest_id = -1
	var nearest_dist = INF
	
	for defense_id in defenses:
		var defense = defenses[defense_id]
		var dist = defense["position"].distance_to(position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = defense_id
	
	if nearest_id >= 0:
		return defenses[nearest_id]
	return null

func get_defense_count() -> int:
	return defenses.size()

func get_defense_info(defense_id: int) -> Dictionary:
	if not defenses.has(defense_id):
		return {}
	return defenses[defense_id].duplicate()

func get_all_defenses_of_type(defense_type: DefenseType) -> Array:
	var result: Array = []
	for defense_id in defenses:
		if defenses[defense_id]["type"] == defense_type:
			result.append(defenses[defense_id])
	return result

func get_total_defense_damage() -> float:
	var total = 0.0
	for defense_id in defenses:
		total += defenses[defense_id]["damage_dealt"]
	return total

func get_total_defense_kills() -> int:
	var total = 0
	for defense_id in defenses:
		total += defenses[defense_id]["kills"]
	return total

func get_raft_health_percentage() -> float:
	return raft_health / raft_max_health

func is_raft_destroyed() -> bool:
	return raft_health <= 0

func get_defense_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for defense_id in defenses:
		positions.append(defenses[defense_id]["position"])
	return positions
