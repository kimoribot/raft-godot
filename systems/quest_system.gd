extends Node
class_name QuestSystem

## Quest System for Raft - Manages all quest types, objectives, and tracking

signal quest_started(quest: Quest)
signal quest_updated(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_objective_updated(quest: Quest, objective: QuestObjective)
signal quest_reward_claimed(quest: Quest)

enum QuestType { MAIN, SIDE, DAILY, ACHIEVEMENT }
enum ObjectiveType { COLLECT, CRAFT, BUILD, TALK, DISCOVER, KILL }
enum QuestStatus { LOCKED, AVAILABLE, ACTIVE, COMPLETED, CLAIMED }

var active_quests: Dictionary = {}
var completed_quests: Array = []
var daily_quests: Array = []
var quest_journal: Array = []

var _quest_database: Dictionary = {}
var _current_chapter: int = 1

## ==================== QUEST CLASS ====================

class Quest:
	var id: String
	var title: String
	var description: String
	var quest_type: QuestSystem.QuestType
	var chapter: int
	var objectives: Array[QuestObjective] = []
	var rewards: Array[QuestReward] = []
	var prerequisites: Array[String] = []
	var status: QuestSystem.QuestStatus = QuestSystem.QuestStatus.LOCKED
	var is_repeatable: bool = false
	var daily_reset_time: int = 0  # Hour of day for daily reset
	
	func _init() -> void:
		pass
	
	func get_progress() -> float:
		if objectives.is_empty():
			return 1.0
		var completed: int = 0
		for obj in objectives:
			if obj.completed:
				completed += 1
		return float(completed) / float(objectives.size())
	
	func is_completed() -> bool:
		for obj in objectives:
			if not obj.completed:
				return false
		return true


class QuestObjective:
	var id: String
	var objective_type: QuestSystem.ObjectiveType
	var target_id: String  # Item ID, enemy ID, location ID, etc.
	var amount: int
	var current_amount: int = 0
	var description: String
	var completed: bool = false
	var is_optional: bool = false
	var hidden: bool = false
	
	func _init(type: QuestSystem.ObjectiveType, target: String, amt: int, desc: String) -> void:
		objective_type = type
		target_id = target
		amount = amt
		description = desc


class QuestReward:
	var reward_type: String  # "item", "blueprint", "currency", "xp"
	var id: String  # Item ID, blueprint ID, etc.
	var amount: int = 1
	
	func _init(type: String, reward_id: String, amt: int = 1) -> void:
		reward_type = type
		id = reward_id
		amount = amt


## ==================== INITIALIZATION ====================

func _ready() -> void:
	_init_quest_database()


func _init_quest_database() -> void:
	# Main Quests - Chapter 1
	_register_quest(_create_chapter1_quests())
	# Main Quests - Chapter 2
	_register_quest(_create_chapter2_quests())
	# Main Quests - Chapter 3
	_register_quest(_create_chapter3_quests())
	# Main Quests - Chapter 4
	_register_quest(_create_chapter4_quests())
	# Main Quests - Chapter 5
	_register_quest(_create_chapter5_quests())
	# Side Quests
	_register_quest(_create_side_quests())
	# Daily Quests
	_register_quest(_create_daily_quests())
	# Achievement Quests
	_register_quest(_create_achievement_quests())


func _register_quest(quests: Array) -> void:
	for quest in quests:
		quest_database[quest.id] = quest


var quest_database: Dictionary:
	get:
		return _quest_database


## ==================== QUEST MANAGEMENT ====================

func start_quest(quest_id: String) -> Quest:
	if not _quest_database.has(quest_id):
		push_warning("Quest not found: " + quest_id)
		return null
	
	var quest: Quest = _quest_database[quest_id]
	
	if quest.status == QuestStatus.ACTIVE:
		return quest
	
	quest.status = QuestStatus.ACTIVE
	active_quests[quest_id] = quest
	
	if quest.quest_type != QuestType.DAILY:
		quest_journal.append(quest)
	
	quest_started.emit(quest)
	return quest


func update_objective(quest_id: String, objective_id: String, amount: int = 1) -> void:
	if not active_quests.has(quest_id):
		return
	
	var quest: Quest = active_quests[quest_id]
	
	for obj in quest.objectives:
		if obj.id == objective_id:
			obj.current_amount = min(obj.current_amount + amount, obj.amount)
			
			if obj.current_amount >= obj.amount and not obj.completed:
				obj.completed = true
				quest_objective_updated.emit(quest, obj)
				
				if quest.is_completed():
					quest.status = QuestStatus.COMPLETED
					quest_completed.emit(quest)
			else:
				quest_updated.emit(quest)
			break


func complete_quest(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	
	var quest: Quest = active_quests[quest_id]
	quest.status = QuestStatus.COMPLETED
	completed_quests.append(quest)
	quest_completed.emit(quest)


func claim_reward(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	
	var quest: Quest = active_quests[quest_id]
	
	for reward in quest.rewards:
		_apply_reward(reward)
	
	quest.status = QuestStatus.CLAIMED
	active_quests.erase(quest_id)
	quest_reward_claimed.emit(quest)


func _apply_reward(reward: QuestReward) -> void:
	match reward.reward_type:
		"item":
			# Add item to player inventory
			PlayerInventory.add_item(reward.id, reward.amount)
		"blueprint":
			# Unlock blueprint
			PlayerBlueprints.unlock(reward.id)
		"currency":
			# Add currency
			PlayerData.add_currency(reward.id, reward.amount)
		"xp":
			# Add experience
			PlayerData.add_xp(reward.amount)


func get_quest(quest_id: String) -> Quest:
	return _quest_database.get(quest_id)


func get_active_quests() -> Array:
	return active_quests.values()


func get_quests_by_type(qtype: QuestType) -> Array:
	var result: Array = []
	for quest in _quest_database.values():
		if quest.quest_type == qtype:
			result.append(quest)
	return result


func get_quests_for_chapter(chapter: int) -> Array:
	var result: Array = []
	for quest in _quest_database.values():
		if quest.chapter == chapter:
			result.append(quest)
	return result


func set_chapter(chapter: int) -> void:
	_current_chapter = chapter
	_update_quest_availability()


func _update_quest_availability() -> void:
	for quest in _quest_database.values():
		if quest.status == QuestStatus.LOCKED:
			if _check_prerequisites(quest):
				quest.status = QuestStatus.AVAILABLE


func _check_prerequisites(quest: Quest) -> bool:
	for prereq_id in quest.prerequisites:
		var prereq: Quest = _quest_database.get(prereq_id)
		if prereq == null or prereq.status != QuestStatus.COMPLETED:
			return false
	return true


## ==================== DAILY QUEST SYSTEM ====================

func generate_daily_quests() -> void:
	daily_quests.clear()
	var available_dailies: Array = []
	
	for quest in _quest_database.values():
		if quest.quest_type == QuestType.DAILY:
			available_dailies.append(quest)
	
	available_dailies.shuffle()
	var count = min(3, available_dailies.size())
	
	for i in range(count):
		var quest: Quest = available_dailies[i].duplicate()
		quest.status = QuestStatus.AVAILABLE
		daily_quests.append(quest)


func reset_daily_quests() -> void:
	for quest in daily_quests:
		if quest.status == QuestStatus.COMPLETED:
			quest.status = QuestStatus.AVAILABLE
			for obj in quest.objectives:
				obj.current_amount = 0
				obj.completed = false
	generate_daily_quests()


## ==================== QUEST CREATION HELPERS ====================

func _create_chapter1_quests() -> Array:
	var quests: Array = []
	
	# Quest: The Crash
	var quest_crash = Quest.new()
	quest_crash.id = "main_ch1_crash"
	quest_crash.title = "The Crash"
	quest_crash.description = "You wake up in the middle of the ocean. Your plane has crashed. Survive."
	quest_crash.quest_type = QuestType.MAIN
	quest_crash.chapter = 1
	quest_crash.status = QuestStatus.AVAILABLE
	
	var obj_survive = QuestObjective.new(ObjectiveType.DISCOVER, "safe_zone", 1, "Find a safe area on your raft")
	quest_crash.objectives.append(obj_survive)
	
	quests.append(quest_crash)
	
	# Quest: Build Your Raft
	var quest_build = Quest.new()
	quest_build.id = "main_ch1_build_raft"
	quest_build.title = "Build Your Raft"
	quest_build.description = "Your tiny raft won't survive long. Expand it using materials from the ocean."
	quest_build.quest_type = QuestType.MAIN
	quest_build.chapter = 1
	quest_build.prerequisites = ["main_ch1_crash"]
	quest_build.status = QuestStatus.LOCKED
	
	var obj_planks = QuestObjective.new(ObjectiveType.COLLECT, "plank", 10, "Collect 10 planks from the ocean")
	quest_build.objectives.append(obj_planks)
	
	var obj_rope = QuestObjective.new(ObjectiveType.COLLECT, "rope", 5, "Collect 5 ropes from the ocean")
	quest_build.objectives.append(obj_rope)
	
	var obj_expand = QuestObjective.new(ObjectiveType.BUILD, "raft_expansion", 2, "Expand your raft to 4x4")
	quest_build.objectives.append(obj_expand)
	
	var reward_planks = QuestReward.new("item", "plank", 20)
	quest_build.rewards.append(reward_planks)
	var reward_xp = QuestReward.new("xp", "survivor", 50)
	quest_build.rewards.append(reward_xp)
	
	quests.append(quest_build)
	
	# Quest: Hunger and Thirst
	var quest_survival = Quest.new()
	quest_survival.id = "main_ch1_survival"
	quest_survival.title = "Hunger and Thirst"
	quest_survival.description = "The ocean provides, but you need to purify water and catch fish to survive."
	quest_survival.quest_type = QuestType.MAIN
	quest_survival.chapter = 1
	quest_survival.prerequisites = ["main_ch1_build_raft"]
	quest_survival.status = QuestStatus.LOCKED
	
	var obj_water = QuestObjective.new(ObjectiveType.CRAFT, "water", 3, "Craft 3 purified water")
	quest_survival.objectives.append(obj_water)
	
	var obj_fish = QuestObjective.new(ObjectiveType.COLLECT, "fish", 5, "Catch 5 fish")
	quest_survival.objectives.append(obj_fish)
	
	var obj_grill = QuestObjective.new(ObjectiveType.BUILD, "grill", 1, "Build a simple grill")
	quest_survival.objectives.append(obj_grill)
	
	var reward_blueprint = QuestReward.new("blueprint", "grill")
	quest_survival.rewards.append(reward_blueprint)
	var reward_xp2 = QuestReward.new("xp", "survivor", 75)
	quest_survival.rewards.append(reward_xp2)
	
	quests.append(quest_survival)
	
	# Quest: A Signal in the Distance
	var quest_signal = Quest.new()
	quest_signal.id = "main_ch1_signal"
	quest_signal.title = "A Signal in the Distance"
	quest_signal.description = "You spot a mysterious signal on the horizon. Could there be others?"
	quest_signal.quest_type = QuestType.MAIN
	quest_signal.chapter = 1
	quest_signal.prerequisites = ["main_ch1_survival"]
	quest_signal.status = QuestStatus.LOCKED
	
	var obj_reach = QuestObjective.new(ObjectiveType.DISCOVER, "island_reveal", 1, "Reach the visible island")
	quest_signal.objectives.append(obj_reach)
	
	var reward_compass = QuestReward.new("item", "compass", 1)
	quest_signal.rewards.append(reward_compass)
	
	quests.append(quest_signal)
	
	return quests


func _create_chapter2_quests() -> Array:
	var quests: Array = []
	
	# Quest: The First Island
	var quest_island = Quest.new()
	quest_island.id = "main_ch2_first_island"
	quest_island.title = "The First Island"
	quest_island.description = "You've discovered land! But what happened here?"
	quest_island.quest_type = QuestType.MAIN
	quest_island.chapter = 2
	quest_island.status = QuestStatus.LOCKED
	
	var obj_explore = QuestObjective.new(ObjectiveType.DISCOVER, "island_camp", 1, "Explore the island campsite")
	quest_island.objectives.append(obj_explore)
	
	var obj_find_note = QuestObjective.new(ObjectiveType.DISCOVER, "survivor_note_1", 1, "Find the survivor's note")
	quest_island.objectives.append(obj_find_note)
	
	quests.append(quest_island)
	
	# Quest: Uncover the Truth
	var quest_truth = Quest.new()
	quest_truth.id = "main_ch2_uncover_truth"
	quest_truth.title = "Uncover the Truth"
	quest_truth.description = "The note hints at a larger story. Find more clues."
	quest_truth.quest_type = QuestType.MAIN
	quest_truth.chapter = 2
	quest_truth.prerequisites = ["main_ch2_first_island"]
	quest_truth.status = QuestStatus.LOCKED
	
	var obj_find_notes = QuestObjective.new(ObjectiveType.DISCOVER, "lore_note", 3, "Find 3 more lore notes")
	quest_truth.objectives.append(obj_find_notes)
	
	var obj_bottle = QuestObjective.new(ObjectiveType.DISCOVER, "message_bottle", 1, "Find a message in a bottle")
	quest_truth.objectives.append(obj_bottle)
	
	var reward_xp = QuestReward.new("xp", "explorer", 100)
	quest_truth.rewards.append(reward_xp)
	
	quests.append(quest_truth)
	
	# Quest: The Radio
	var quest_radio = Quest.new()
	quest_radio.id = "main_ch2_radio"
	quest_radio.title = "The Radio"
	quest_radio.description = "You found a working radio. Maybe someone is out there..."
	quest_radio.quest_type = QuestType.MAIN
	quest_radio.chapter = 2
	quest_radio.prerequisites = ["main_ch2_uncover_truth"]
	quest_radio.status = QuestStatus.LOCKED
	
	var obj_craft_radio = QuestObjective.new(ObjectiveType.CRAFT, "radio", 1, "Craft a radio")
	quest_radio.objectives.append(obj_craft_radio)
	
	var obj_tune = QuestObjective.new(ObjectiveType.DISCOVER, "radio_signal", 1, "Tune into a signal")
	quest_radio.objectives.append(obj_tune)
	
	var reward_blueprint = QuestReward.new("blueprint", "advanced_cooker")
	quest_radio.rewards.append(reward_blueprint)
	
	quests.append(quest_radio)
	
	# Quest: Meet the Survivor
	var quest_survivor = Quest.new()
	quest_survivor.id = "main_ch2_meet_survivor"
	quest_survivor.title = "Meet the Survivor"
	quest_survivor.description = "The radio leads you to another survivor. Find them."
	quest_survivor.quest_type = QuestType.MAIN
	quest_survivor.chapter = 2
	quest_survivor.prerequisites = ["main_ch2_radio"]
	quest_survivor.status = QuestStatus.LOCKED
	
	var obj_find_survivor = QuestObjective.new(ObjectiveType.TALK, "survivor_npc", 1, "Find and talk to the survivor")
	quest_survivor.objectives.append(obj_find_survivor)
	
	var obj_learn = QuestObjective.new(ObjectiveType.DISCOVER, "survivor_story", 1, "Learn about the ocean mystery")
	quest_survivor.objectives.append(obj_learn)
	
	var reward_companion = QuestReward.new("item", "survivor_companion", 1)
	quest_survivor.rewards.append(reward_companion)
	
	quests.append(quest_survivor)
	
	return quests


func _create_chapter3_quests() -> Array:
	var quests: Array = []
	
	# Quest: Growing Fleet
	var quest_fleet = Quest.new()
	quest_fleet.id = "main_ch3_growing_fleet"
	quest_fleet.title = "Growing Fleet"
	quest_fleet.description = "Survivors want to join you. Build a larger raft to accommodate them."
	quest_fleet.quest_type = QuestType.MAIN
	quest_fleet.chapter = 3
	quest_fleet.status = QuestStatus.LOCKED
	
	var obj_expand_raft = QuestObjective.new(ObjectiveType.BUILD, "large_raft", 1, "Expand raft to large size")
	quest_fleet.objectives.append(obj_expand_raft)
	
	var obj_build_beds = QuestObjective.new(ObjectiveType.BUILD, "bed", 4, "Build 4 beds for survivors")
	quest_fleet.objectives.append(obj_build_beds)
	
	var reward_xp = QuestReward.new("xp", "leader", 150)
	quest_fleet.rewards.append(reward_xp)
	
	quests.append(quest_fleet)
	
	# Quest: New Threats
	var quest_threats = Quest.new()
	quest_threats.id = "main_ch3_new_threats"
	quest_threats.title = "New Threats"
	quest_threats.description = "The ocean has become more dangerous. Sharks are circling your raft."
	quest_threats.quest_type = QuestType.MAIN
	quest_threats.chapter = 3
	quest_threats.prerequisites = ["main_ch3_growing_fleet"]
	quest_threats.status = QuestStatus.LOCKED
	
	var obj_kill_shark = QuestObjective.new(ObjectiveType.KILL, "shark", 3, "Defeat 3 sharks")
	quest_threats.objectives.append(obj_kill_shark)
	
	var obj_build_wep = QuestObjective.new(ObjectiveType.CRAFT, "spear", 1, "Craft a spear for self-defense")
	quest_threats.objectives.append(obj_build_wep)
	
	var reward_blueprint = QuestReward.new("blueprint", "harpoon_gun")
	quest_threats.rewards.append(reward_blueprint)
	
	quests.append(quest_threats)
	
	# Quest: The Supply Run
	var quest_supply = Quest.new()
	quest_supply.id = "main_ch3_supply_run"
	quest_supply.title = "The Supply Run"
	quest_supply.description = "Your survivors need supplies. Organize a scavenging trip."
	quest_supply.quest_type = QuestType.MAIN
	quest_supply.chapter = 3
	quest_supply.prerequisites = ["main_ch3_new_threats"]
	quest_supply.status = QuestStatus.LOCKED
	
	var obj_collect_food = QuestObjective.new(ObjectiveType.COLLECT, "food_supply", 20, "Collect 20 food supplies")
	quest_supply.objectives.append(obj_collect_food)
	
	var obj_collect_mat = QuestObjective.new(ObjectiveType.COLLECT, "building_materials", 30, "Collect 30 building materials")
	quest_supply.objectives.append(obj_collect_mat)
	
	var reward_crate = QuestReward.new("item", "supply_crate", 1)
	quest_supply.rewards.append(reward_crate)
	
	quests.append(quest_supply)
	
	# Quest: A Distress Signal
	var quest_distress = Quest.new()
	quest_distress.id = "main_ch3_distress_signal"
	quest_distress.title = "A Distress Signal"
	quest_distress.description = "You hear a distress signal from another survivor group."
	quest_distress.quest_type = QuestType.MAIN
	quest_distress.chapter = 3
	quest_distress.prerequisites = ["main_ch3_supply_run"]
	quest_distress.status = QuestStatus.LOCKED
	
	var obj_locate = QuestObjective.new(ObjectiveType.DISCOVER, "distress_location", 1, "Locate the distress signal source")
	quest_distress.objectives.append(obj_locate)
	
	var obj_rescue = QuestObjective.new(ObjectiveType.TALK, "trapped_survivors", 1, "Rescue the trapped survivors")
	quest_distress.objectives.append(obj_rescue)
	
	var reward_xp2 = QuestReward.new("xp", "hero", 200)
	quest_distress.rewards.append(reward_xp2)
	
	quests.append(quest_distress)
	
	return quests


func _create_chapter4_quests() -> Array:
	var quests: Array = []
	
	# Quest: The Mysterious Archipelago
	var quest_archipelago = Quest.new()
	quest_archipelago.id = "main_ch4_archipelago"
	quest_archipelago.title = "The Mysterious Archipelago"
	quest_archipelago.description = "Your journey leads you to a cluster of strange islands. Something feels wrong here."
	quest_archipelago.quest_type = QuestType.MAIN
	quest_archipelago.chapter = 4
	quest_archipelago.status = QuestStatus.LOCKED
	
	var obj_discover = QuestObjective.new(ObjectiveType.DISCOVER, "archipelago", 1, "Discover the mysterious archipelago")
	quest_archipelago.objectives.append(obj_discover)
	
	var obj_explore_island = QuestObjective.new(ObjectiveType.DISCOVER, "ancient_ruins", 1, "Explore the ancient ruins")
	quest_archipelago.objectives.append(obj_explore_island)
	
	quests.append(quest_archipelago)
	
	# Quest: The Truth Revealed
	var quest_reveal = Quest.new()
	quest_reveal.id = "main_ch4_truth_revealed"
	quest_reveal.title = "The Truth Revealed"
	quest_reveal.description = "The ruins hold secrets about what really happened to the world."
	quest_reveal.quest_type = QuestType.MAIN
	quest_reveal.chapter = 4
	quest_reveal.prerequisites = ["main_ch4_archipelago"]
	quest_reveal.status = QuestStatus.LOCKED
	
	var obj_find_artifact = QuestObjective.new(ObjectiveType.DISCOVER, "ancient_artifact", 1, "Find the ancient artifact")
	quest_reveal.objectives.append(obj_find_artifact)
	
	var obj_read_inscription = QuestObjective.new(ObjectiveType.DISCOVER, "ancient_inscription", 1, "Read the ancient inscription")
	quest_reveal.objectives.append(obj_read_inscription)
	
	var obj_speak_survivor = QuestObjective.new(ObjectiveType.TALK, "ancient_guardian", 1, "Speak with the ancient guardian")
	quest_reveal.objectives.append(obj_speak_survivor)
	
	var reward_xp = QuestReward.new("xp", "truth_seeker", 300)
	quest_reveal.rewards.append(reward_xp)
	
	quests.append(quest_reveal)
	
	# Quest: The Conspiracy
	var quest_conspiracy = Quest.new()
	quest_conspiracy.id = "main_ch4_conspiracy"
	quest_conspiracy.title = "The Conspiracy"
	quest_conspiracy.description = "The truth is darker than you imagined. Someone caused all of this."
	quest_conspiracy.quest_type = QuestType.MAIN
	quest_conspiracy.chapter = 4
	quest_conspiracy.prerequisites = ["main_ch4_truth_revealed"]
	quest_conspiracy.status = QuestStatus.LOCKED
	
	var obj_investigate = QuestObjective.new(ObjectiveType.DISCOVER, "conspiracy_evidence", 5, "Gather 5 pieces of evidence")
	quest_conspiracy.objectives.append(obj_investigate)
	
	var obj_find_key = QuestObjective.new(ObjectiveType.DISCOVER, "activation_key", 1, "Find the activation key")
	quest_conspiracy.objectives.append(obj_find_key)
	
	var reward_blueprint = QuestReward.new("blueprint", "advanced_weapons")
	quest_conspiracy.rewards.append(reward_blueprint)
	
	quests.append(quest_conspiracy)
	
	# Quest: The Final Piece
	var quest_final = Quest.new()
	quest_final.id = "main_ch4_final_piece"
	quest_final.title = "The Final Piece"
	quest_final.description = "You need one more piece to understand the full picture."
	quest_final.quest_type = QuestType.MAIN
	quest_final.chapter = 4
	quest_final.prerequisites = ["main_ch4_conspiracy"]
	quest_final.status = QuestStatus.LOCKED
	
	var obj_find_last = QuestObjective.new(ObjectiveType.DISCOVER, "final_clue", 1, "Find the final clue")
	quest_final.objectives.append(obj_find_last)
	
	var obj_unlock = QuestObjective.new(ObjectiveType.DISCOVER, "secret_chamber", 1, "Unlock the secret chamber")
	quest_final.objectives.append(obj_unlock)
	
	quests.append(quest_final)
	
	return quests


func _create_chapter5_quests() -> Array:
	var quests: Array = []
	
	# Quest: The Final Challenge
	var quest_final_challenge = Quest.new()
	quest_final_challenge.id = "main_ch5_final_challenge"
	quest_final_challenge.title = "The Final Challenge"
	quest_final_challenge.description = "Everything has led to this. Face the ultimate threat."
	quest_final_challenge.quest_type = QuestType.MAIN
	quest_final_challenge.chapter = 5
	quest_final_challenge.status = QuestStatus.LOCKED
	
	var obj_prepare = QuestObjective.new(ObjectiveType.CRAFT, "ultimate_weapon", 1, "Craft the ultimate weapon")
	quest_final_challenge.objectives.append(obj_prepare)
	
	var obj_rally = QuestObjective.new(ObjectiveType.TALK, "all_survivors", 1, "Rally all survivors")
	quest_final_challenge.objectives.append(obj_rally)
	
	quests.append(quest_final_challenge)
	
	# Quest: The Confrontation
	var quest_confrontation = Quest.new()
	quest_confrontation.id = "main_ch5_confrontation"
	quest_confrontation.title = "The Confrontation"
	quest_confrontation.description = "Face the one responsible for the apocalypse."
	quest_confrontation.quest_type = QuestType.MAIN
	quest_confrontation.chapter = 5
	quest_confrontation.prerequisites = ["main_ch5_final_challenge"]
	quest_confrontation.status = QuestStatus.LOCKED
	
	var obj_reach_boss = QuestObjective.new(ObjectiveType.DISCOVER, "boss_lair", 1, "Reach the enemy's lair")
	quest_confrontation.objectives.append(obj_reach_boss)
	
	var obj_defeat_guard = QuestObjective.new(ObjectiveType.KILL, "guardian_machine", 3, "Defeat 3 guardian machines")
	quest_confrontation.objectives.append(obj_defeat_guard)
	
	quests.append(quest_confrontation)
	
	# Quest: The Choice
	var quest_choice = Quest.new()
	quest_choice.id = "main_ch5_choice"
	quest_choice.title = "The Choice"
	quest_choice.description = "The enemy offers you a choice. What will you do?"
	quest_choice.quest_type = QuestType.MAIN
	quest_choice.chapter = 5
	quest_choice.prerequisites = ["main_ch5_confrontation"]
	quest_choice.status = QuestStatus.LOCKED
	
	var obj_face_choice = QuestObjective.new(ObjectiveType.DISCOVER, "final_choice", 1, "Face the final choice")
	quest_choice.objectives.append(obj_face_choice)
	
	quests.append(quest_choice)
	
	# Quest: A New Beginning
	var quest_ending = Quest.new()
	quest_ending.id = "main_ch5_ending"
	quest_ending.title = "A New Beginning"
	quest_ending.description = "Whatever choice you made, a new chapter begins."
	quest_ending.quest_type = QuestType.MAIN
	quest_ending.chapter = 5
	quest_ending.prerequisites = ["main_ch5_choice"]
	quest_ending.status = QuestStatus.LOCKED
	
	var obj_complete = QuestObjective.new(ObjectiveType.DISCOVER, "new_world", 1, "Complete your journey")
	quest_ending.objectives.append(obj_complete)
	
	var reward_xp = QuestReward.new("xp", "legend", 1000)
	quest_ending.rewards.append(reward_xp)
	var reward_trophy = QuestReward.new("item", "survivor_leader_trophy", 1)
	quest_ending.rewards.append(reward_trophy)
	
	quests.append(quest_ending)
	
	return quests


func _create_side_quests() -> Array:
	var quests: Array = []
	
	# Side Quest: Master Fisher
	var quest_fisher = Quest.new()
	quest_fisher.id = "side_master_fisher"
	quest_fisher.title = "Master Fisher"
	quest_fisher.description = "Catch different types of fish to feed your survivors."
	quest_fisher.quest_type = QuestType.SIDE
	quest_fisher.chapter = 1
	quest_fisher.status = QuestStatus.AVAILABLE
	
	var obj_catch_fish = QuestObjective.new(ObjectiveType.COLLECT, "fish", 50, "Catch 50 fish")
	quest_fisher.objectives.append(obj_catch_fish)
	
	var obj_catch_rare = QuestObjective.new(ObjectiveType.COLLECT, "rare_fish", 5, "Catch 5 rare fish")
	quest_fisher.objectives.append(obj_catch_rare)
	
	var reward_blueprint = QuestReward.new("blueprint", "fishing_net")
	quest_fisher.rewards.append(reward_blueprint)
	
	quests.append(quest_fisher)
	
	# Side Quest: The Collector
	var quest_collector = Quest.new()
	quest_collector.id = "side_collector"
	quest_collector.title = "The Collector"
	quest_collector.description = "Gather resources from the ocean for your growing community."
	quest_collector.quest_type = QuestType.SIDE
	quest_collector.chapter = 1
	quest_collector.status = QuestStatus.AVAILABLE
	
	var obj_plastic = QuestObjective.new(ObjectiveType.COLLECT, "plastic", 100, "Collect 100 plastic")
	quest_collector.objectives.append(obj_plastic)
	
	var obj_wood = QuestObjective.new(ObjectiveType.COLLECT, "wood", 50, "Collect 50 wood")
	quest_collector.objectives.append(obj_wood)
	
	var obj_metal = QuestObjective.new(ObjectiveType.COLLECT, "scrap_metal", 30, "Collect 30 scrap metal")
	quest_collector.objectives.append(obj_metal)
	
	var reward_xp = QuestReward.new("xp", "collector", 75)
	quest_collector.rewards.append(reward_xp)
	
	quests.append(quest_collector)
	
	# Side Quest: Message in a Bottle
	var quest_bottle = Quest.new()
	quest_bottle.id = "side_message_bottle"
	quest_bottle.title = "Message in a Bottle"
	quest_bottle.description = "Find messages floating in the ocean. Someone is trying to communicate."
	quest_bottle.quest_type = QuestType.SIDE
	quest_bottle.chapter = 2
	quest_bottle.status = QuestStatus.AVAILABLE
	
	var obj_find_bottles = QuestObjective.new(ObjectiveType.DISCOVER, "message_bottle", 10, "Find 10 messages in bottles")
	quest_bottle.objectives.append(obj_find_bottles)
	
	var reward_blueprint2 = QuestReward.new("blueprint", "message_in_a_bottle_reader")
	quest_bottle.rewards.append(reward_blueprint2)
	
	quests.append(quest_bottle)
	
	# Side Quest: Deep Sea Hunter
	var quest_hunter = Quest.new()
	quest_hunter.id = "side_deep_sea_hunter"
	quest_hunter.title = "Deep Sea Hunter"
	quest_hunter.description = "Hunt down dangerous ocean creatures."
	quest_hunter.quest_type = QuestType.SIDE
	quest_hunter.chapter = 3
	quest_hunter.status = QuestStatus.AVAILABLE
	
	var obj_kill_shark = QuestObjective.new(ObjectiveType.KILL, "shark", 10, "Hunt 10 sharks")
	quest_hunter.objectives.append(obj_kill_shark)
	
	var obj_kill_creature = QuestObjective.new(ObjectiveType.KILL, "sea_creature", 3, "Hunt 3 dangerous sea creatures")
	quest_hunter.objectives.append(obj_kill_creature)
	
	var reward_blueprint3 = QuestReward.new("blueprint", "shark_trident")
	quest_hunter.rewards.append(reward_blueprint3)
	
	quests.append(quest_hunter)
	
	# Side Quest: Architect
	var quest_architect = Quest.new()
	quest_architect.id = "side_architect"
	quest_architect.title = "Architect"
	quest_architect.description = "Build impressive structures on your raft."
	quest_architect.quest_type = QuestType.SIDE
	quest_architect.chapter = 2
	quest_architect.status = QuestStatus.AVAILABLE
	
	var obj_build_house = QuestObjective.new(ObjectiveType.BUILD, "house", 1, "Build a house")
	quest_architect.objectives.append(obj_build_house)
	
	var obj_build_tower = QuestObjective.new(ObjectiveType.BUILD, "watch_tower", 1, "Build a watch tower")
	quest_architect.objectives.append(obj_build_tower)
	
	var obj_build_garden = QuestObjective.new(ObjectiveType.BUILD, "garden", 1, "Build a garden")
	quest_architect.objectives.append(obj_garden)
	
	var reward_xp2 = QuestReward.new("xp", "architect", 100)
	quest_architect.rewards.append(reward_xp2)
	
	quests.append(quest_architect)
	
	# Side Quest: Radio Enthusiast
	var quest_radio = Quest.new()
	quest_radio.id = "side_radio_enthusiast"
	quest_radio.title = "Radio Enthusiast"
	quest_risher.description = "Tune into different radio frequencies and discover secrets."
	quest_radio.quest_type = QuestType.SIDE
	quest_radio.chapter = 2
	quest_radio.status = QuestStatus.AVAILABLE
	
	var obj_find_freqs = QuestObjective.new(ObjectiveType.DISCOVER, "radio_frequency", 15, "Discover 15 different radio frequencies")
	quest_radio.objectives.append(obj_find_freqs)
	
	var reward_xp3 = QuestReward.new("xp", "radio_enthusiast", 80)
	quest_radio.rewards.append(reward_xp3)
	
	quests.append(quest_radio)
	
	# Side Quest: The Secret Caves
	var quest_caves = Quest.new()
	quest_caves.id = "side_secret_caves"
	quest_caves.title = "The Secret Caves"
	quest_caves.description = "Explore underwater caves for hidden treasures."
	quest_caves.quest_type = QuestType.SIDE
	quest_caves.chapter = 4
	quest_caves.status = QuestStatus.AVAILABLE
	
	var obj_explore_cave = QuestObjective.new(ObjectiveType.DISCOVER, "underwater_cave", 5, "Explore 5 underwater caves")
	quest_caves.objectives.append(obj_explore_cave)
	
	var obj_find_treasure = QuestObjective.new(ObjectiveType.DISCOVER, "cave_treasure", 3, "Find 3 hidden treasures")
	quest_caves.objectives.append(obj_find_treasure)
	
	var reward_blueprint4 = QuestReward.new("blueprint", "diving_gear")
	quest_caves.rewards.append(reward_blueprint4)
	
	quests.append(quest_caves)
	
	return quests


func _create_daily_quests() -> Array:
	var quests: Array = []
	
	# Daily: Supplies Run
	var quest_daily_supplies = Quest.new()
	quest_daily_supplies.id = "daily_supplies"
	quest_daily_supplies.title = "Daily Supplies"
	quest_daily_supplies.description = "Collect basic supplies from the ocean."
	quest_daily_supplies.quest_type = QuestType.DAILY
	quest_daily_supplies.daily_reset_time = 6  # Reset at 6 AM
	quest_daily_supplies.is_repeatable = true
	
	var obj_plastic = QuestObjective.new(ObjectiveType.COLLECT, "plastic", 15, "Collect 15 plastic")
	quest_daily_supplies.objectives.append(obj_plastic)
	
	var obj_wood = QuestObjective.new(ObjectiveType.COLLECT, "wood", 10, "Collect 10 wood")
	quest_daily_supplies.objectives.append(obj_wood)
	
	var reward_xp = QuestReward.new("xp", "daily", 25)
	quest_daily_supplies.rewards.append(reward_xp)
	
	quests.append(quest_daily_supplies)
	
	# Daily: Food Hunt
	var quest_daily_food = Quest.new()
	quest_daily_food.id = "daily_food"
	quest_daily_food.title = "Food Hunt"
	quest_daily_food.description = "Catch fish to feed your survivors."
	quest_daily_food.quest_type = QuestType.DAILY
	quest_daily_food.daily_reset_time = 6
	quest_daily_food.is_repeatable = true
	
	var obj_fish = QuestObjective.new(ObjectiveType.COLLECT, "fish", 10, "Catch 10 fish")
	quest_daily_food.objectives.append(obj_fish)
	
	var obj_cook = QuestObjective.new(ObjectiveType.CRAFT, "cooked_fish", 5, "Cook 5 fish")
	quest_daily_food.objectives.append(obj_cook)
	
	var reward_xp2 = QuestReward.new("xp", "daily", 30)
	quest_daily_food.rewards.append(reward_xp2)
	
	quests.append(quest_daily_food)
	
	# Daily: Maintenance
	var quest_daily_maint = Quest.new()
	quest_daily_maint.id = "daily_maintenance"
	quest_daily_maint.title = "Raft Maintenance"
	quest_daily_maint.description = "Keep your raft in good condition."
	quest_daily_maint.quest_type = QuestType.DAILY
	quest_daily_maint.daily_reset_time = 6
	quest_daily_maint.is_repeatable = true
	
	var obj_repair = QuestObjective.new(ObjectiveType.CRAFT, "repair_kit", 3, "Craft 3 repair kits")
	quest_daily_maint.objectives.append(obj_repair)
	
	var obj_fix = QuestObjective.new(ObjectiveType.BUILD, "raft_repair", 5, "Repair 5 raft tiles")
	quest_daily_maint.objectives.append(obj_fix)
	
	var reward_xp3 = QuestReward.new("xp", "daily", 20)
	quest_daily_maint.rewards.append(reward_xp3)
	
	quests.append(quest_daily_maint)
	
	# Daily: Explore
	var quest_daily_explore = Quest.new()
	quest_daily_explore.id = "daily_explore"
	quest_daily_explore.title = "Daily Exploration"
	quest_daily_explore.description = "Discover new things in the ocean."
	quest_daily_explore.quest_type = QuestType.DAILY
	quest_daily_explore.daily_reset_time = 6
	quest_daily_explore.is_repeatable = true
	
	var obj_discover = QuestObjective.new(ObjectiveType.DISCOVER, "random_event", 3, "Experience 3 random events")
	quest_daily_explore.objectives.append(obj_discover)
	
	var obj_find_item = QuestObjective.new(ObjectiveType.DISCOVER, "ocean_debris", 5, "Investigate 5 debris")
	quest_daily_explore.objectives.append(obj_find_item)
	
	var reward_xp4 = QuestReward.new("xp", "daily", 35)
	quest_daily_explore.rewards.append(reward_xp4)
	
	quests.append(quest_daily_explore)
	
	return quests


func _create_achievement_quests() -> Array:
	var quests: Array = []
	
	# Achievement: First Steps
	var achievement_first = Quest.new()
	achievement_first.id = "achievement_first_steps"
	achievement_first.title = "First Steps"
	achievement_first.description = "Start your journey"
	achievement_first.quest_type = QuestType.ACHIEVEMENT
	achievement_first.status = QuestStatus.AVAILABLE
	
	var obj_start = QuestObjective.new(ObjectiveType.DISCOVER, "game_start", 1, "Begin playing the game")
	achievement_first.objectives.append(obj_start)
	
	quests.append(achievement_first)
	
	# Achievement: Bookworm
	var achievement_book = Quest.new()
	achievement_book.id = "achievement_bookworm"
	achievement_book.title = "Bookworm"
	achievement_book.description = "Read all the lore notes."
	achievement_book.quest_type = QuestType.ACHIEVEMENT
	achievement_book.status = QuestStatus.AVAILABLE
	
	var obj_read = QuestObjective.new(ObjectiveType.DISCOVER, "lore_note", 50, "Read 50 lore notes")
	achievement_book.objectives.append(obj_read)
	
	var reward_xp = QuestReward.new("xp", "lore_master", 500)
	achievement_book.rewards.append(reward_xp)
	
	quests.append(achievement_book)
	
	# Achievement: Master Builder
	var achievement_builder = Quest.new()
	achievement_builder.id = "achievement_master_builder"
	achievement_builder.title = "Master Builder"
	achievement_builder.description = "Build every structure in the game."
	achievement_builder.quest_type = QuestType.ACHIEVEMENT
	achievement_builder.status = QuestStatus.AVAILABLE
	
	var obj_build_all = QuestObjective.new(ObjectiveType.BUILD, "all_structures", 1, "Build all available structures")
	achievement_builder.objectives.append(obj_build_all)
	
	var reward_trophy = QuestReward.new("item", "master_builder_trophy", 1)
	achievement_builder.rewards.append(reward_trophy)
	
	quests.append(achievement_builder)
	
	# Achievement: Shark Hunter
	var achievement_shark = Quest.new()
	achievement_shark.id = "achievement_shark_hunter"
	achievement_shark.title = "Shark Hunter"
	achievement_shark.description = "Defeat 100 sharks."
	achievement_shark.quest_type = QuestType.ACHIEVEMENT
	achievement_shark.status = QuestStatus.AVAILABLE
	
	var obj_kill_shark = QuestObjective.new(ObjectiveType.KILL, "shark", 100, "Defeat 100 sharks")
	achievement_shark.objectives.append(obj_kill_shark)
	
	var reward_xp2 = QuestReward.new("xp", "shark_slayer", 300)
	achievement_shark.rewards.append(reward_xp2)
	
	quests.append(achievement_shark)
	
	# Achievement: Survivor Leader
	var achievement_leader = Quest.new()
	achievement_leader.id = "achievement_survivor_leader"
	achievement_leader.title = "Survivor Leader"
	achievement_leader.description = "Have 10 survivors join your raft."
	achievement_leader.quest_type = QuestType.ACHIEVEMENT
	achievement_leader.status = QuestStatus.AVAILABLE
	
	var obj_survivors = QuestObjective.new(ObjectiveType.TALK, "survivor_npc", 10, "Recruit 10 survivors")
	achievement_leader.objectives.append(obj_survivors)
	
	var reward_trophy2 = QuestReward.new("item", "leader_trophy", 1)
	achievement_leader.rewards.append(reward_trophy2)
	
	quests.append(achievement_leader)
	
	# Achievement: Deep Sea Explorer
	var achievement_explorer = Quest.new()
	achievement_explorer.id = "achievement_deep_sea_explorer"
	achievement_explorer.title = "Deep Sea Explorer"
	achievement_explorer.description = "Discover all island types."
	achievement_explorer.quest_type = QuestType.ACHIEVEMENT
	achievement_explorer.status = QuestStatus.AVAILABLE
	
	var obj_discover = QuestObjective.new(ObjectiveType.DISCOVER, "all_islands", 1, "Discover every island type")
	achievement_explorer.objectives.append(obj_discover)
	
	var reward_xp3 = QuestReward.new("xp", "explorer", 400)
	achievement_explorer.rewards.append(reward_xp3)
	
	quests.append(achievement_explorer)
	
	return quests


## ==================== UI QUERY METHODS ====================

funcournal() get_quest_j -> Array:
	return quest_journal


func get_active_main_quests() -> Array:
	var result: Array = []
	for quest in active_quests.values():
		if quest.quest_type == QuestType.MAIN:
			result.append(quest)
	return result


func get_active_side_quests() -> Array:
	var result: Array = []
	for quest in active_quests.values():
		if quest.quest_type == QuestType.SIDE:
			result.append(quest)
	return result


func get_available_quests() -> Array:
	var result: Array = []
	for quest in _quest_database.values():
		if quest.status == QuestStatus.AVAILABLE:
			result.append(quest)
	return result
