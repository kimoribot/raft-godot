#ifndef PROGRESSION_SYSTEM_GD
#define PROGRESSION_SYSTEM_GD

class_name ProgressionSystem
extends Node

## Progression System for Raft Game
## Handles XP, levels, skills, achievements, and save/load

signal experience_gained(amount: float, total: float)
signal level_up(new_level: int, old_level: int)
signal skill_unlocked(skill_name: String)
signal achievement_unlocked(achievement_id: String)
signal milestone_reached(milestone_id: String)

# Level System
var current_level: int = 1
var current_xp: float = 0.0
var total_xp_earned: float = 0.0

# XP curve - balanced for ~50 hour gameplay
# Level formula: XP required = base * level^exponent
var xp_base: float = 100.0
var xp_exponent: float = 1.5

# Level caps
var max_level: int = 10

# Skills
enum SkillType {
	FISHING,
	COOKING,
	BUILDING,
	EXPLORATION,
	SURVIVAL,
	CRAFTING,
	COMBAT,
	SWIMMING
}

class Skill:
	var name: String
	var type: SkillType
	var description: String
	var level_required: int
	var xp_required: float
	var unlocked: bool = false
	
	func _init(n: String, t: SkillType, d: String, lvl: int, xp: float):
		name = n
		type = t
		description = d
		level_required = lvl
		xp_required = xp

var skills: Array[Skill] = []
var unlocked_skills: Array[String] = []

# Achievements
class Achievement:
	var id: String
	var name: String
	var description: String
	var xp_reward: float
	var unlocked: bool = false
	var unlock_condition: Callable  # Function to check condition
	var progress: float = 0.0
	var target: float = 1.0
	
	func _init(i: String, n: String, d: String, xp: float, cond: Callable, t: float = 1.0):
		id = i
		name = n
		description = d
		xp_reward = xp
		unlock_condition = cond
		target = t

var achievements: Array[Achievement] = []
var unlocked_achievements: Array[String] = []

# Statistics tracking
var stats: Dictionary = {
	"time_played": 0.0,
	"items_crafted": 0,
	"fish_caught": 0,
	"food_cooked": 0,
	"distance_traveled": 0.0,
	"islands_visited": 0,
	"enemies_killed": 0,
	"times_died": 0,
	"items_collected": 0,
	"raft_pieces_built": 0,
	"distance_from_start": 0.0
}

# Game time tracking
var game_time: float = 0.0

func _ready() -> void:
	initialize_skills()
	initialize_achievements()


# Initialize skills
func initialize_skills() -> void:
	skills = [
		Skill.new("Fishing", SkillType.FISHING, "Catch fish and seafood", 2, 50.0),
		Skill.new("Cooking", SkillType.COOKING, "Prepare food and drinks", 2, 50.0),
		Skill.new("Building", SkillType.BUILDING, "Construct raft structures", 3, 75.0),
		Skill.new("Exploration", SkillType.EXPLORATION, "Discover islands and locations", 3, 75.0),
		Skill.new("Survival", SkillType.SURVIVAL, "Stay alive longer", 4, 100.0),
		Skill.new("Crafting", SkillType.CRAFTING, "Create advanced items", 5, 150.0),
		Skill.new("Combat", SkillType.COMBAT, "Fight enemies and predators", 5, 150.0),
		Skill.new("Swimming", SkillType.SWIMMING, "Swim efficiently", 2, 50.0)
	]


# Initialize achievements
func initialize_achievements() -> void:
	# Early game achievements
	achievements.append(Achievement.new(
		"first_craft", "First Steps", "Craft your first item", 25.0,
		func(): return stats["items_crafted"] >= 1
	))
	
	achievements.append(Achievement.new(
		"fishing_beginner", "Hook Line and Sinker", "Catch your first fish", 25.0,
		func(): return stats["fish_caught"] >= 1
	))
	
	achievements.append(Achievement.new(
		"island_discovery", "Land Ahoy!", "Discover your first island", 50.0,
		func(): return stats["islands_visited"] >= 1
	))
	
	achievements.append(Achievement.new(
		"survivor_1h", "One Hour Survivor", "Survive for 1 hour", 30.0,
		func(): return game_time >= 3600.0
	))
	
	# Mid-game achievements
	achievements.append(Achievement.new(
		"master_chef", "Master Chef", "Cook 10 meals", 75.0,
		func(): return stats["food_cooked"] >= 10
	))
	
	achievements.append(Achievement.new(
		"raft_builder", "Raft Builder", "Build 10 raft pieces", 75.0,
		func(): return stats["raft_pieces_built"] >= 10
	))
	
	achievements.append(Achievement.new(
		"explorer", "Explorer", "Visit 5 islands", 100.0,
		func(): return stats["islands_visited"] >= 5
	))
	
	achievements.append(Achievement.new(
		"survivor_10h", "Seasoned Survivor", "Survive for 10 hours", 100.0,
		func(): return game_time >= 36000.0
	))
	
	# Late game achievements
	achievements.append(Achievement.new(
		"fisherman", "Master Fisherman", "Catch 50 fish", 150.0,
		func(): return stats["fish_caught"] >= 50
	))
	
	achievements.append(Achievement.new(
		"distance_1km", "Far Wanderer", "Travel 1km from start", 150.0,
		func(): return stats["distance_from_start"] >= 1000.0
	))
	
	achievements.append(Achievement.new(
		"survivor_25h", "Expert Survivor", "Survive for 25 hours", 200.0,
		func(): return game_time >= 90000.0
	))
	
	achievements.append(Achievement.new(
		"all_skills", "Jack of All Trades", "Unlock all skills", 250.0,
		func(): return unlocked_skills.size() >= skills.size()
	))
	
	# Endgame achievements
	achievements.append(Achievement.new(
		"max_level", "Reaching the Top", "Reach level 10", 200.0,
		func(): return current_level >= 10
	))
	
	achievements.append(Achievement.new(
		"distance_5km", "Ocean Voyager", "Travel 5km from start", 300.0,
		func(): return stats["distance_from_start"] >= 5000.0
	))
	
	achievements.append(Achievement.new(
		"survivor_50h", "Ultimate Survivor", "Survive for 50 hours", 500.0,
		func(): return game_time >= 180000.0
	))


# Get XP required for a specific level
func get_xp_for_level(level: int) -> float:
	if level <= 1:
		return 0.0
	return xp_base * pow(level - 1, xp_exponent)


# Get total XP required to reach a level
func get_total_xp_for_level(level: int) -> float:
	var total: float = 0.0
	for i in range(1, level + 1):
		total += get_xp_for_level(i)
	return total


# Get current level progress (0.0 to 1.0)
func get_level_progress() -> float:
	var xp_for_current = get_xp_for_level(current_level)
	var xp_for_next = get_xp_for_level(current_level + 1)
	var xp_into_level = current_xp
	
	if xp_for_next == xp_for_current:
		return 1.0
	
	return (current_xp - xp_for_current) / (xp_for_next - xp_for_current)


# Add experience points
func add_experience(amount: float) -> void:
	if amount <= 0:
		return
	
	var old_level = current_level
	current_xp += amount
	total_xp_earned += amount
	
	# Check for level ups
	while current_level < max_level and current_xp >= get_xp_for_level(current_level + 1):
		level_up_internal()
	
	experience_gained.emit(amount, total_xp_earned)
	
	# Check skill unlocks
	check_skill_unlocks()
	
	# Check achievements
	check_achievements()


# Internal level up handler
func level_up_internal() -> void:
	current_level += 1
	level_up.emit(current_level, current_level - 1)
	milestone_reached.emit("level_" + str(current_level))
	check_skill_unlocks()


# Get current level
func get_current_level() -> int:
	return current_level


# Get current XP
func get_current_xp() -> float:
	return current_xp


# Get unlocked skills
func get_unlocked_skills() -> Array[String]:
	return unlocked_skills.duplicate()


# Check and unlock skills based on level
func check_skill_unlocks() -> void:
	for skill in skills:
		if not skill.unlocked and current_level >= skill.level_required:
			skill.unlocked = true
			unlocked_skills.append(skill.name.to_lower())
			skill_unlocked.emit(skill.name)
			milestone_reached.emit("skill_" + skill.name.to_lower())


# Check if has skill
func has_skill(skill_type: SkillType) -> bool:
	for skill in skills:
		if skill.type == skill_type:
			return skill.unlocked
	return false


# Get skill by type
func get_skill(skill_type: SkillType) -> Skill:
	for skill in skills:
		if skill.type == skill_type:
			return skill
	return null


# Get all skills
func get_all_skills() -> Array[Skill]:
	return skills.duplicate()


# Check achievements
func check_achievements() -> void:
	for achievement in achievements:
		if not achievement.unlocked:
			if achievement.unlock_condition.call():
				unlock_achievement(achievement.id)


# Unlock achievement
func unlock_achievement(achievement_id: String) -> void:
	for achievement in achievements:
		if achievement.id == achievement_id and not achievement.unlocked:
			achievement.unlocked = true
			unlocked_achievements.append(achievement_id)
			add_experience(achievement.xp_reward)
			achievement_unlocked.emit(achievement_id)
			milestone_reached.emit("achievement_" + achievement_id)
			break


# Get achievement progress
func get_achievement_progress(achievement_id: String) -> float:
	for achievement in achievements:
		if achievement.id == achievement_id:
			return achievement.progress / achievement.target
	return 0.0


# Get all achievements
func get_all_achievements() -> Array[Achievement]:
	return achievements.duplicate()


# Get unlocked achievements
func get_unlocked_achievements() -> Array[Achievement]:
	var result: Array[Achievement] = []
	for achievement in achievements:
		if achievement.unlocked:
			result.append(achievement)
	return result


# Update statistics
func update_stat(stat_name: String, amount: float = 1.0) -> void:
	if stats.has(stat_name):
		stats[stat_name] += amount
		check_achievements()


# Set specific stat value
func set_stat(stat_name: String, value: float) -> void:
	if stats.has(stat_name):
		stats[stat_name] = value
		check_achievements()


# Get stat value
func get_stat(stat_name: String) -> float:
	return stats.get(stat_name, 0.0)


# Update game time
func update_game_time(delta: float) -> void:
	game_time += delta
	stats["time_played"] += delta
	check_achievements()


# Get formatted play time
func get_formatted_play_time() -> String:
	var hours = int(game_time / 3600)
	var minutes = int((game_time % 3600) / 60)
	var seconds = int(game_time % 60)
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


# Get all stats
func get_all_stats() -> Dictionary:
	return stats.duplicate()


# Calculate estimated hours to max level
func get_estimated_hours_to_max() -> float:
	var xp_needed = get_total_xp_for_level(max_level) - total_xp_earned
	# Average XP gain rate (will vary based on gameplay)
	var avg_xp_per_hour = 200.0  # Rough estimate
	return xp_needed / avg_xp_per_hour


# Reset progression (for new game)
func reset_progression() -> void:
	current_level = 1
	current_xp = 0.0
	total_xp_earned = 0.0
	game_time = 0.0
	unlocked_skills.clear()
	unlocked_achievements.clear()
	
	# Reset skills
	for skill in skills:
		skill.unlocked = false
	
	# Reset achievements
	for achievement in achievements:
		achievement.unlocked = false
		achievement.progress = 0.0
	
	# Reset stats
	stats = {
		"time_played": 0.0,
		"items_crafted": 0,
		"fish_caught": 0,
		"food_cooked": 0,
		"distance_traveled": 0.0,
		"islands_visited": 0,
		"enemies_killed": 0,
		"times_died": 0,
		"items_collected": 0,
		"raft_pieces_built": 0,
		"distance_from_start": 0.0
	}


# Save/Load functionality
func save_data() -> Dictionary:
	var skills_data: Array[Dictionary] = []
	for skill in skills:
		skills_data.append({
			"type": skill.type,
			"unlocked": skill.unlocked
		})
	
	var achievements_data: Array[Dictionary] = []
	for achievement in achievements:
		achievements_data.append({
			"id": achievement.id,
			"unlocked": achievement.unlocked,
			"progress": achievement.progress
		})
	
	return {
		"current_level": current_level,
		"current_xp": current_xp,
		"total_xp_earned": total_xp_earned,
		"game_time": game_time,
		"skills": skills_data,
		"achievements": achievements_data,
		"stats": stats
	}


func load_data(data: Dictionary) -> void:
	if data.has("current_level"):
		current_level = data["current_level"]
	if data.has("current_xp"):
		current_xp = data["current_xp"]
	if data.has("total_xp_earned"):
		total_xp_earned = data["total_xp_earned"]
	if data.has("game_time"):
		game_time = data["game_time"]
	
	# Load skills
	if data.has("skills"):
		for skill_data in data["skills"]:
			for skill in skills:
				if skill.type == skill_data["type"]:
					skill.unlocked = skill_data["unlocked"]
					if skill.unlocked:
						unlocked_skills.append(skill.name.to_lower())
	
	# Load achievements
	if data.has("achievements"):
		for achievement_data in data["achievements"]:
			for achievement in achievements:
				if achievement.id == achievement_data["id"]:
					achievement.unlocked = achievement_data["unlocked"]
					achievement.progress = achievement_data["progress"]
					if achievement.unlocked:
						unlocked_achievements.append(achievement.id)
	
	# Load stats
	if data.has("stats"):
		stats = data["stats"]

#endif
