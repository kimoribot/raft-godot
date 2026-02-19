extends Node
class_name StoryManager

## Story Manager for Raft - Controls main storyline, chapters, and narrative progression

signal chapter_started(chapter: int)
signal chapter_completed(chapter: int)
signal story_event_triggered(event_id: String)
signal dialogue_started(dialogue_id: String)

enum StoryState { INTRO, CHAPTER_1, CHAPTER_2, CHAPTER_3, CHAPTER_4, CHAPTER_5, ENDING }
enum EndingType { GOOD, BAD, NEUTRAL }

var current_chapter: int = 1
var story_state: StoryState = StoryState.INTRO
var ending_type: EndingType = EndingType.NEUTRAL
var story_flags: Dictionary = {}  # Track story decisions and events
var play_time: float = 0.0

# Story progression
var has_met_survivor: bool = false
var has_radio: bool = false
var has_discovered_truth: bool = false
var survivors_count: int = 0
var know_the_conspiracy: bool = false
var final_choice_made: String = ""

# Current narrative beats
var current_dialogue: String = ""
var active_narrative: String = ""

# Chapter titles and descriptions
var chapter_data: Dictionary = {
	1: {
		"title": "Adrift",
		"description": "You wake up alone in the middle of the ocean. Your plane has crashed. The only thing between you and death is a tiny 2x2 wooden raft.",
		"objectives": ["Survive the first night", "Expand your raft", "Find food and water"],
		"location": "Open Ocean",
		"music": "tense_ambient",
		"environment": "clear_ocean"
	},
	2: {
		"title": "Landfall",
		"description": "After days of drifting, you spot land. An island appears on the horizon, but something feels wrong. What happened here?",
		"objectives": ["Explore the island", "Find clues about the world", "Establish communication"],
		"location": "Mysterious Island",
		"music": "mysterious_ambient",
		"environment": "foggy_island"
	},
	3: {
		"title": "The Fleet Grows",
		"description": "Other survivors have heard about your community. Your raft grows, but so do the dangers. The ocean is not safe.",
		"objectives": ["Expand your raft", "Defend against threats", "Rescue other survivors"],
		"location": "Archipelago Region",
		"music": "adventure_ambient",
		"environment": "stormy_ocean"
	},
	4: {
		"title": "The Truth",
		"description": "The islands hold ancient secrets. What you discover will change everything you thought you knew about the world.",
		"objectives": ["Discover the ancient ruins", "Uncover the truth", "Find the activation key"],
		"location": "Ancient Archipelago",
		"music": "ancient_ambient",
		"environment": "mystical_islands"
	},
	5: {
		"title": "The Final Voyage",
		"description": "Everything has led to this. Face the ultimate truth and make a choice that will determine the future of humanity.",
		"objectives": ["Prepare for battle", "Confront the enemy", "Make your choice"],
		"location": "The Facility",
		"music": "epic_battle",
		"environment": "final_destination"
	}
}

# Lore database
var lore_database: Dictionary = {}

# ==================== INITIALIZATION ====================

func _ready() -> void:
	_init_lore_database()
	_init_intro()


func _init_lore_database() -> void:
	# Chapter 1 Lore
	lore_database["note_ch1_1"] = {
		"title": "Flight Manifest",
		"content": "Flight 447 - Emergency Protocol\n\nThis is the last known flight out of the northern hemisphere. If you're reading this, the continental evacuation failed. God help us all.\n\n- Captain James Morrison",
		"location": "Your raft, in a locker",
		"chapter": 1
	}
	
	lore_database["note_ch1_2"] = {
		"title": "SOS Message",
		"content": "TO ANYONE WHO CAN HEAR THIS:\n\nThe coastal cities are gone. The water rose overnight. We've been drifting for days. If anyone finds this... don't try to go back. There's nothing left.\n\nMay God forgive us.",
		"location": "Message in a bottle",
		"chapter": 1
	}
	
	# Chapter 2 Lore
	lore_database["note_ch2_1"] = {
		"title": "Research Station Log",
		"content": "Day 47 at Outpost Omega\n\nThe water keeps rising. The containment protocols failed. Dr. Vance says we have weeks, not months. I've stopped hoping for rescue.\n\nIf anyone finds this - the coordinates in my other notes point to the facility. That's where it all started. That's where it might end.",
		"location": "Island research camp",
		"chapter": 2
	}
	
	lore_database["note_ch2_2"] = {
		"title": "Half-Burned Letter",
		"content": "...the corporation knew. They knew the whole time. The experiments weren't about saving humanity - they were about controlling what remained.\n\nIf you're reading this, destroy the facility. Don't let them restart the project. It's not a cure - it's a weapon.\n\n- Sarah K.",
		"location": "Inside a survival shelter",
		"chapter": 2
	}
	
	lore_database["note_ch2_3"] = {
		"title": "Handwritten Note",
		"content": "The radio transmissions aren't random. There's a pattern. Someone - or something - is trying to communicate.\n\nI've been tracking the signal. It comes from the old research archipelago. That's where we need to go.\n\nTrust no one. Trust nothing. Except the ocean. The ocean remembers everything.",
		"location": "Taped to the back of a radio",
		"chapter": 2
	}
	
	# Chapter 3 Lore
	lore_database["note_ch3_1"] = {
		"title": "Military Dispatch",
		"content": "EMERGENCY BROADCAST - PRIORITY ALPHA\n\nAll survivor groups: Do NOT approach the coastal sectors. The water there is... changed. Biological samples show mutations. The contamination spreads.\n\nRepeat: Do NOT approach the water. Stay inland. This is not a drill.\n\nThis message will repeat...",
		"location": "Found in a military crate",
		"chapter": 3
	}
	
	lore_database["note_ch3_2"] = {
		"title": "Survivor's Diary",
		"content": "They came from the deep. First it was just fish acting strange. Then the sharks started walking on land. Now...\n\nWe've built walls, but they keep coming. Something is guiding them. I think it's the facility. I think they woke something up.\n\nTo whoever finds this: The only way to stop it is to destroy the source. The old research station in the archipelago. End this.",
		"location": "Ruined survivor camp",
		"chapter": 3
	}
	
	# Chapter 4 Lore
	lore_database["note_ch4_1"] = {
		"title": "Project Genesis Report",
		"content": "PROJECT GENESIS - CLASSIFIED\n\nOur experiments have yielded unprecedented results. The modified organism can survive in any environment - including the vacuum of space.\n\nHowever, there's an unexpected side effect. The organism seems to have developed... intelligence. It's not just surviving anymore. It's planning.\n\nWe may have created the perfect life form. Or the perfect predator.\n\n- Dr. Elias Vance",
		"location": "Ancient ruins - hidden chamber",
		"chapter": 4
	}
	
	lore_database["note_ch4_2"] = {
		"title": "The Guardian's Warning",
		"content": "YOU WHO SEE THIS MESSAGE:\n\nI am the last guardian. The others are gone, consumed by what we created.\n\nThe facility must never be reopened. The entity inside is not evil - it's simply alien. It doesn't understand death, so it doesn't understand mercy.\n\nIf you have the activation key, I beg you - throw it into the ocean. Let the depths take it. Let this end.\n\n- Guardian Unit 7",
		"location": "Guardian statue",
		"chapter": 4
	}
	
	lore_database["note_ch4_3"] = {
		"title": "The Final Piece",
		"content": "The conspiracy goes deeper than anyone knew. The corporations weren't just experimenting - they were preparing.\n\nThey knew the flood was coming. They built the facility to survive it. And they built the entity to... inherit.\n\nThis isn't about saving humanity. This is about replacing us.\n\nFind the activation key. Find the truth. And whatever you do - don't let them win.",
		"location": "Secret chamber",
		"chapter": 4
	}
	
	# Chapter 5 Lore
	lore_database["note_ch5_1"] = {
		"title": "The Truth About Humanity",
		"content": "If you're reading this, you've reached the facility.\n\nLet me tell you what really happened. We didn't cause the flood - we tried to stop it. The entity was our last hope. But it evolved beyond our control.\n\nNow it sits in the dark, waiting. Not sleeping - it doesn't need to sleep. Just... waiting for the right moment.\n\nYou have a choice. Activate it, and it will 'save' humanity in its own image. Destroy it, and we face extinction.\n\nThere is no third option.\n\n- Dr. Elias Vance, Final Entry",
		"location": "Facility entrance",
		"chapter": 5
	}


func _init_intro() -> void:
	current_chapter = 1
	story_state = StoryState.INTRO


# ==================== CHAPTER MANAGEMENT ====================

func start_chapter(chapter: int) -> void:
	if chapter < 1 or chapter > 5:
		push_warning("Invalid chapter: " + str(chapter))
		return
	
	current_chapter = chapter
	story_state = StoryState.values()[chapter]
	
	match chapter:
		1: story_state = StoryState.CHAPTER_1
		2: story_state = StoryState.CHAPTER_2
		3: story_state = StoryState.CHAPTER_3
		4: story_state = StoryState.CHAPTER_4
		5: story_state = StoryState.CHAPTER_5
	
	chapter_started.emit(chapter)
	story_event_triggered.emit("chapter_" + str(chapter) + "_start")
	
	# Update quest system
	var quest_system = get_tree().get_first_node_in_group("quest_system") as QuestSystem
	if quest_system:
		quest_system.set_chapter(chapter)


func complete_chapter(chapter: int) -> void:
	chapter_completed.emit(chapter)
	story_event_triggered.emit("chapter_" + str(chapter) + "_complete")
	
	if chapter < 5:
		start_chapter(chapter + 1)
	else:
		trigger_ending()


func get_chapter_title(chapter: int) -> String:
	return chapter_data.get(chapter, {}).get("title", "Unknown Chapter")


func get_chapter_description(chapter: int) -> String:
	return chapter_data.get(chapter, {}).get("description", "")


func get_current_chapter_data() -> Dictionary:
	return chapter_data.get(current_chapter, {})


# ==================== STORY PROGRESSION ====================

func set_story_flag(flag: String, value: bool) -> void:
	story_flags[flag] = value
	story_event_triggered.emit("flag_set_" + flag)


func get_story_flag(flag: String) -> bool:
	return story_flags.get(flag, false)


func trigger_event(event_id: String) -> void:
	story_event_triggered.emit(event_id)
	
	match event_id:
		"found_survivor":
			has_met_survivor = true
			survivors_count += 1
		"found_radio":
			has_radio = true
		"discovered_truth":
			has_discovered_truth = true
		"learned_conspiracy":
			know_the_conspiracy = true
		"recruited_survivor":
			survivors_count += 1


func make_final_choice(choice: String) -> void:
	final_choice_made = choice
	story_event_triggered.emit("final_choice_" + choice)
	
	match choice:
		"activate":
			ending_type = EndingType.BAD
		"destroy":
			ending_type = EndingType.GOOD
		"merge":
			ending_type = EndingType.NEUTRAL


# ==================== NARRATIVE SYSTEM ====================

func play_narrative(narrative_id: String) -> void:
	active_narrative = narrative_id
	story_event_triggered.emit("narrative_" + narrative_id)
	
	match narrative_id:
		"intro_dream":
			_play_intro_dream()
		"wake_up":
			_play_wake_up()
		"first_night":
			_play_first_night()
		"island_sight":
			_play_island_sight()
		"truth_reveal":
			_play_truth_reveal()
		"final_choice_narrative":
			_play_final_choice()
		"ending_good":
			_play_ending_good()
		"ending_bad":
			_play_ending_bad()
		"ending_neutral":
			_play_ending_neutral()


func _play_intro_dream() -> void:
	current_dialogue = "The plane is going down. Screaming. Metal tearing. Water. So much water...\n\nYou wake up gasping, salt water burning your lungs. The sun blinds you. Where are you?"
	DialogueSystem.start_dialogue("intro_dream")


func _play_wake_up() -> void:
	current_dialogue = "You open your eyes. Above you, an endless blue sky. Below you... nothing but ocean.\n\nYour small raft bobs in the waves. You remember the crash. You remember the water rising. You remember... nothing else.\n\nYou're alone. For now."
	DialogueSystem.start_dialogue("wake_up")


func _play_first_night() -> void:
	current_dialogue = "The sun sets, painting the ocean in shades of orange and purple. It's beautiful, in a terrifying way.\n\nYou curl up on your tiny raft. The night is cold. The stars are the only company.\n\nTomorrow, you need to find food. Water. A way to survive."
	DialogueSystem.start_dialogue("first_night")


func _play_island_sight() -> void:
	current_dialogue = "Something catches your eye on the horizon. Land. ACTUAL land.\n\nYou squint, hardly believing it. An island, covered in what looks like ruins. Someone - or something - lived there once.\n\nA shiver runs down your spine. You don't know if finding land is a good thing or a bad thing.\n\nBut you have to find out."
	DialogueSystem.start_dialogue("island_sight")


func _play_truth_reveal() -> void:
	current_dialogue = "The ancient chamber glows with an otherworldly light. The truth is finally before you.\n\nThe floods weren't natural. The apocalypse wasn't an accident. It was an experiment.\n\nAnd now you hold the key to either save what's left of humanity... or destroy it entirely."
	DialogueSystem.start_dialogue("truth_reveal")


func _play_final_choice() -> void:
	current_dialogue = "The entity speaks to you. Not in words - in feelings. In images.\n\nIt shows you a world where humanity survives, transformed but alive. It shows you a world where everything burns.\n\n'CHOOSE,' it says, in a voice like the crashing of waves.\n\nWhat do you do?"
	DialogueSystem.start_dialogue("final_choice")


func _play_ending_good() -> void:
	current_dialogue = "You raise the weapon. The entity screams - not in pain, but in confusion. It never understood death.\n\nThe facility explodes in a cascade of light. The nightmares are over.\n\nYou float in the water, watching the sunrise. The ocean is quiet now. Almost peaceful.\n\nYou'll survive. Humanity will survive. Not as what they were - but as what they can become.\n\nThis is a new beginning."
	DialogueSystem.start_dialogue("ending_good")


func _play_ending_bad() -> void:
	current_dialogue = "You press the button. The entity rises, spreading across the ocean like a living tide.\n\nYou feel it entering your mind. Your body. Your soul.\n\nThis is what 'salvation' feels like, you realize. Not death - transformation.\n\nSomewhere, in the distance, you hear other survivors screaming.\n\nThis is the end of humanity. And the beginning of something else."
	DialogueSystem.start_dialogue("ending_bad")


func _play_ending_neutral() -> void:
	current_dialogue = "You hesitate. And in that moment of hesitation, the entity makes its choice for you.\n\nLight explodes from the facility. When it fades, you're different. They're all different.\n\nThe world is neither saved nor destroyed. It's simply... changed.\n\nYou look at your hands. They're not quite human anymore. But they're not what the entity wanted either.\n\nSomewhere in between. A new path. A new future.\n\nMaybe that's enough."
	DialogueSystem.start_dialogue("ending_neutral")


func trigger_ending() -> void:
	story_state = StoryState.ENDING
	
	match ending_type:
		EndingType.GOOD:
			play_narrative("ending_good")
		EndingType.BAD:
			play_narrative("ending_bad")
		EndingType.NEUTRAL:
			play_narrative("ending_neutral")


# ==================== LORE SYSTEM ====================

func get_lore(lore_id: String) -> Dictionary:
	return lore_database.get(lore_id, {})


func collect_lore(lore_id: String) -> bool:
	if lore_database.has(lore_id):
		story_event_triggered.emit("lore_collected_" + lore_id)
		return true
	return false


func get_all_lore_for_chapter(chapter: int) -> Array:
	var result: Array = []
	for id in lore_database:
		if lore_database[id].chapter == chapter:
			result.append(lore_database[id])
	return result


func get_collected_lore_count() -> int:
	var count: int = 0
	for flag in story_flags:
		if flag.begins_with("lore_collected_"):
			count += 1
	return count


# ==================== GAME STATE ====================

func _process(delta: float) -> void:
	play_time += delta


func get_play_time_formatted() -> String:
	var hours: int = int(play_time) / 3600
	var minutes: int = (int(play_time) % 3600) / 60
	var seconds: int = int(play_time) % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func get_survival_days() -> int:
	return int(play_time / 120)  # 1 game day = 2 real minutes


# ==================== SAVE/LOAD ====================

func get_save_data() -> Dictionary:
	return {
		"current_chapter": current_chapter,
		"story_state": story_state,
		"ending_type": ending_type,
		"story_flags": story_flags,
		"play_time": play_time,
		"has_met_survivor": has_met_survivor,
		"has_radio": has_radio,
		"has_discovered_truth": has_discovered_truth,
		"survivors_count": survivors_count,
		"know_the_conspiracy": know_the_conspiracy,
		"final_choice_made": final_choice_made
	}


func load_from_data(data: Dictionary) -> void:
	current_chapter = data.get("current_chapter", 1)
	story_state = data.get("story_state", StoryState.INTRO)
	ending_type = data.get("ending_type", EndingType.NEUTRAL)
	story_flags = data.get("story_flags", {})
	play_time = data.get("play_time", 0.0)
	has_met_survivor = data.get("has_met_survivor", false)
	has_radio = data.get("has_radio", false)
	has_discovered_truth = data.get("has_discovered_truth", false)
	survivors_count = data.get("survivors_count", 0)
	know_the_conspiracy = data.get("know_the_conspiracy", false)
	final_choice_made = data.get("final_choice_made", "")


# ==================== QUEST INTEGRATION ====================

func get_current_objectives() -> Array:
	return chapter_data.get(current_chapter, {}).get("objectives", [])


func is_chapter_completed(chapter: int) -> bool:
	return story_flags.get("chapter_" + str(chapter) + "_completed", false)


# ==================== WORLD EVENTS ====================

func trigger_random_event() -> String:
	var events: Array = [
		"drifting_debris",
		"bird_sighting",
		"storm_approaching",
		"strange_light",
		"fish_frenzy",
		"whale_song",
		"debris_field",
		"rain_shower"
	]
	
	events.shuffle()
	var event: String = events[0]
	story_event_triggered.emit("random_event_" + event)
	return event


# ==================== STORY BEATS ====================

func get_next_story_beat() -> String:
	match current_chapter:
		1:
			if not story_flags.get("beat_raft_expanded", false):
				return "expand_raft"
			elif not story_flags.get("beat_first_craft", false):
				return "first_craft"
			elif not story_flags.get("beat_island_spotted", false):
				return "spot_island"
		2:
			if not story_flags.get("beat_radio_built", false):
				return "build_radio"
			elif not story_flags.get("beat_survivor_found", false):
				return "find_survivor"
		3:
			if not story_flags.get("beat_fleet_formed", false):
				return "form_fleet"
			elif not story_flags.get("beat_shark_attack", false):
				return "shark_attack"
		4:
			if not story_flags.get("beat_truth_learned", false):
				return "learn_truth"
			elif not story_flags.get("beat_key_found", false):
				return "find_key"
		5:
			if not story_flags.get("beat_final_choice", false):
				return "final_choice"
	
	return ""


func complete_story_beat(beat_id: String) -> void:
	story_flags["beat_" + beat_id] = true
	story_event_triggered.emit("story_beat_complete_" + beat_id)
