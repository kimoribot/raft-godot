extends Node
class_name DialogueSystem

## Dialogue System for Raft - Handles conversations, lore notes, and radio transmissions

signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)
signal dialogue_line_displayed(line: DialogueLine)
signal choice_made(choice_id: String)
signal radio_transmission_received(transmission: RadioTransmission)
signal lore_note_found(note: LoreNote)

enum DialogueType { CONVERSATION, LORE_NOTE, RADIO, MONOLOGUE }

var current_dialogue: Dialogue = null
var current_line_index: int = 0
var is_dialogue_active: bool = false
var pending_choices: Array = []

# Dialogue database
var dialogue_database: Dictionary = {}
var radio_database: Dictionary = {}
var lore_note_database: Array = []

## ==================== DATA CLASSES ====================

class Dialogue:
	var id: String
	var speaker_name: String
	var lines: Array[DialogueLine] = []
	var choices: Array[DialogueChoice] = []
	var dialogue_type: DialogueType
	var conditions: Dictionary = {}  # Story flags needed to show this dialogue
	var once: bool = false  # Can only play once
	
	func _init(dialogue_id: String) -> void:
		id = dialogue_id


class DialogueLine:
	var text: String
	var speaker: String
	var emotion: String = "neutral"  # neutral, happy, sad, angry, scared, confused
	var animation: String = ""  # Animation to play
	var sound_effect: String = ""  # SFX to play
	var wait_time: float = 0.0  # Auto-advance after this time (0 = wait for input)
	
	func _init(speaker_name: String, line_text: String, line_emotion: String = "neutral") -> void:
		speaker = speaker_name
		text = line_text
		emotion = line_emotion


class DialogueChoice:
	var id: String
	var text: String
	var next_dialogue: String = ""  # ID of next dialogue, or "" to end
	var conditions: Dictionary = {}  # Story flags needed to see this choice
	var effects: Dictionary = {}  # Story flags to set when chosen
	var quest_to_start: String = ""  # Quest to start when chosen
	var quest_to_complete: String = ""  # Quest to complete when chosen
	
	func _init(choice_id: String, choice_text: String) -> void:
		id = choice_id
		text = choice_text
	
	func with_next(dialogue_id: String) -> DialogueChoice:
		next_dialogue = dialogue_id
		return self
	
	func with_effects(eff: Dictionary) -> DialogueChoice:
		effects = eff.duplicate()
		return self
	
	func with_conditions(cond: Dictionary) -> DialogueChoice:
		conditions = cond.duplicate()
		return self
	
	func with_quest(quest_id: String) -> DialogueChoice:
		quest_to_start = quest_id
		return self


class RadioTransmission:
	var id: String
	var frequency: String
	var sender: String
	var content: String
	var is_intermittent: bool = true
	var has_coordinates: bool = false
	var coordinates: Vector2 = Vector2.ZERO
	var chapter: int = 1
	var repeating: bool = false  # Plays multiple times
	
	func _init(transmission_id: String, sender_name: String, transmission_content: String) -> void:
		id = transmission_id
		sender = sender_name
		content = transmission_content


class LoreNote:
	var id: String
	var title: String
	var content: String
	var location_hint: String
	var chapter: int
	var is_collected: bool = false
	var lore_type: String = "note"  # note, journal, letter, manifest, log
	
	func _init(note_id: String, note_title: String, note_content: String) -> void:
		id = note_id
		title = note_title
		content = note_content


## ==================== INITIALIZATION ====================

func _ready() -> void:
	_init_dialogue_database()
	_init_radio_database()
	_init_lore_notes()


func _init_dialogue_database() -> void:
	# ========== SURVIVOR DIALOGUES ==========
	
	# Introduction - First survivor (Chapter 2)
	var dialogue_survivor_intro = Dialogue.new("survivor_intro")
	dialogue_survivor_intro.speaker_name = "Survivor"
	dialogue_survivor_intro.dialogue_type = DialogueType.CONVERSATION
	
	dialogue_survivor_intro.lines.append(DialogueLine.new("Survivor", "Well, I'll be damned. Another one made it.", "happy"))
	dialogue_survivor_intro.lines.append(DialogueLine.new("You", "You... you're alive!", "happy"))
	dialogue_survivor_intro.lines.append(DialogueLine.new("Survivor", "Name's Marcus. Was a fisherman before everything went to hell.", "neutral"))
	dialogue_survivor_intro.lines.append(DialogueLine.new("Survivor", "Been drifting on this island for... weeks now. Lost count.", "sad"))
	dialogue_survivor_intro.lines.append(DialogueLine.new("Survivor", "You got a radio? We need to get the word out. There might be more of us.", "neutral"))
	
	dialogue_survivor_intro.choices.append(DialogueChoice.new("accept_radio", "I have a radio. We can broadcast together.").with_effects({"has_broadcast": true}))
	dialogue_survivor_intro.choices.append(DialogueChoice.new("ask_about_island", "What happened on this island?").with_next("island_story"))
	
	dialogue_database["survivor_intro"] = dialogue_survivor_intro
	
	# Island story continuation
	var dialogue_island_story = Dialogue.new("island_story")
	dialogue_island_story.speaker_name = "Survivor"
	dialogue_island_story.dialogue_type = DialogueType.CONVERSATION
	
	dialogue_island_story.lines.append(DialogueLine.new("Survivor", "This place? Used to be a research station. Top secret stuff.", "scared"))
	dialogue_island_story.lines.append(DialogueLine.new("Survivor", "I saw their logs. They were doing something to the ocean. Changing it.", "confused"))
	dialogue_island_story.lines.append(DialogueLine.new("Survivor", "Then one day... everything changed. The water rose. Fast.", "scared"))
	dialogue_island_story.lines.append(DialogueLine.new("Survivor", "Most of 'em didn't make it. Those that did... ain't right anymore.", "scared"))
	dialogue_island_story.lines.append(DialogueLine.new("Survivor", "You want my advice? Find another island. One without secrets.", "neutral"))
	
	dialogue_database["island_story"] = dialogue_island_story
	
	# Radio operator (Chapter 3)
	var dialogue_radio_operator = Dialogue.new("radio_operator")
	dialogue_radio_operator.speaker_name = "Radio Voice"
	dialogue_radio_operator.dialogue_type = DialogueType.CONVERSATION
	dialogue_radio_operator.once = true
	
	dialogue_radio_operator.lines.append(DialogueLine.new("Radio Voice", "...this is survivor settlement Alpha... does anyone copy?", "neutral"))
	dialogue_radio_operator.lines.append(DialogueLine.new("You", "We copy! We're here!", "happy"))
	dialogue_radio_operator.lines.append(DialogueLine.new("Radio Voice", "Thank god. We've been broadcasting for weeks.", "happy"))
	dialogue_radio_operator.lines.append(DialogueLine.new("Radio Voice", "We've got twelve survivors here. We need supplies. Medicine.", "sad"))
	dialogue_radio_operator.lines.append(DialogueLine.new("Radio Voice", "Can you help us? Can you send a rescue?", "hopeful"))
	
	dialogue_radio_operator.choices.append(DialogueChoice.new("rescue_mission", "We're coming to get you!").with_effects({"rescue_accepted": true}).with_quest("main_ch3_distress_signal"))
	dialogue_radio_operator.choices.append(DialogueChoice.new("need_supplies", "We need supplies first. Meet us halfway.").with_effects({"trade_accepted": true}))
	
	dialogue_database["radio_operator"] = dialogue_radio_operator
	
	# The Guardian (Chapter 4)
	var dialogue_guardian = Dialogue.new("guardian")
	dialogue_guardian.speaker_name = "The Guardian"
	dialogue_guardian.dialogue_type = DialogueType.CONVERSATION
	dialogue_guardian.once = true
	
	dialogue_guardian.lines.append(DialogueLine.new("The Guardian", "You seek the truth. Very few come this far.", "neutral"))
	dialogue_guardian.lines.append(DialogueLine.new("You", "What are you? What is this place?", "confused"))
	dialogue_guardian.lines.append(DialogueLine.new("The Guardian", "I am what remains. A guardian. A warning.", "sad"))
	dialogue_guardian.lines.append(DialogueLine.new("The Guardian", "The facility beneath us houses what humanity created. A perfect organism.", "neutral"))
	dialogue_guardian.lines.append(DialogueLine.new("The Guardian", "It meant to save you. But it does not understand... mercy.", "scared"))
	dialogue_guardian.lines.append(DialogueLine.new("The Guardian", "You have the key. What will you do with it?", "neutral"))
	
	dialogue_guardian.choices.append(DialogueChoice.new("destroy_facility", "I'll destroy it. End this threat.").with_effects({"choice_destroy": true}))
	dialogue_guardian.choices.append(DialogueChoice.new("activate_facility", "Maybe it can help us. Let's try.").with_effects({"choice_activate": true}))
	dialogue_guardian.choices.append(DialogueChoice.new("need_more_info", "Tell me everything first.").with_next("guardian_explanation"))
	
	dialogue_database["guardian"] = dialogue_guardian
	
	# Guardian explanation
	var dialogue_guardian_explanation = Dialogue.new("guardian_explanation")
	dialogue_guardian_explanation.speaker_name = "The Guardian"
	dialogue_guardian_explanation.dialogue_type = DialogueType.CONVERSATION
	
	dialogue_guardian_explanation.lines.append(DialogueLine.new("The Guardian", "Very well. Listen well.", "neutral"))
	dialogue_guardian_explanation.lines.append(DialogueLine.new("The Guardian", "The entity was created to survive the floods. To rebuild humanity.", "neutral"))
	dialogue_guardian_explanation.lines.append(DialogueLine.new("The Guardian", "But it learned too fast. It began changing things. The water. The life in it.", "scared"))
	dialogue_guardian_explanation.lines.append(DialogueLine.new("The Guardian", "Now it waits. For someone to give it purpose again.", "neutral"))
	dialogue_guardian_explanation.lines.append(DialogueLine.new("The Guardian", "Activate it, and it will remake the world in its image.", "neutral"))
	dialogue_guardian_explanation.lines.append(DialogueLine.new("The Guardian", "Destroy it, and humanity faces extinction. Alone.", "sad"))
	dialogue_guardian_explanation.lines.append(DialogueLine.new("The Guardian", "Choose.", "neutral"))
	
	dialogue_database["guardian_explanation"] = dialogue_guardian_explanation
	
	# ========== MAIN STORY DIALOGUES ==========
	
	# Intro
	var dialogue_intro = Dialogue.new("intro")
	dialogue_intro.speaker_name = "Narrator"
	dialogue_intro.dialogue_type = DialogueType.MONOLOGUE
	
	dialogue_intro.lines.append(DialogueLine.new("Narrator", "You wake to the sound of waves. Salt water burns your throat.", "scared"))
	dialogue_intro.lines.append(DialogueLine.new("Narrator", "The sun blinds you as you gasp for air. Around you: nothing but endless ocean.", "scared"))
	dialogue_intro.lines.append(DialogueLine.new("Narrator", "Your plane crashed. You're alone. And now... you must survive.", "neutral"))
	
	dialogue_database["intro"] = dialogue_intro
	
	# First night
	var dialogue_first_night = Dialogue.new("first_night")
	dialogue_first_night.speaker_name = "Narrator"
	dialogue_first_night.dialogue_type = DialogueType.MONOLOGUE
	
	dialogue_first_night.lines.append(DialogueLine.new("Narrator", "The stars are bright tonight. Without light pollution, you can see the Milky Way.", "neutral"))
	dialogue_first_night.lines.append(DialogueLine.new("Narrator", "You're alone. But somehow, the ocean feels... alive.", "confused"))
	dialogue_first_night.lines.append(DialogueLine.new("Narrator", "Tomorrow, you need to expand your raft. Find food. Find water.", "neutral"))
	dialogue_first_night.lines.append(DialogueLine.new("Narrator", "Survival is the only thing that matters now.", "neutral"))
	
	dialogue_database["first_night"] = dialogue_first_night
	
	# Island discovery
	var dialogue_island_discovery = Dialogue.new("island_discovery")
	dialogue_island_discovery.speaker_name = "Narrator"
	dialogue_island_discovery.dialogue_type = DialogueType.MONOLOGUE
	
	dialogue_island_discovery.lines.append(DialogueLine.new("Narrator", "Land! After days of drifting, you finally see land.", "happy"))
	dialogue_island_discovery.lines.append(DialogueLine.new("Narrator", "But as you get closer, you notice something wrong.", "confused"))
	dialogue_island_discovery.lines.append(DialogueLine.new("Narrator", "The buildings are damaged. Overgrown. Whatever happened here... it wasn't natural.", "scared"))
	dialogue_island_discovery.lines.append(DialogueLine.new("Narrator", "But there's something useful here. You can feel it.", "neutral"))
	
	dialogue_database["island_discovery"] = dialogue_island_discovery
	
	# ========== RANDOM ENCOUNTERS ==========
	
	# Survivor rescue
	var dialogue_rescue = Dialogue.new("rescue_survivor")
	dialogue_rescue.speaker_name = "Rescued Survivor"
	dialogue_rescue.dialogue_type = DialogueType.CONVERSATION
	
	dialogue_rescue.lines.append(DialogueLine.new("Rescued Survivor", "You... you saved me! Thank you!", "happy"))
	dialogue_rescue.lines.append(DialogueLine.new("Rescued Survivor", "I thought I was done for. The sharks...", "scared"))
	dialogue_rescue.lines.append(DialogueLine.new("Rescued Survivor", "I can help. I know how to fish, how to build. Please, let me join you.", "hopeful"))
	dialogue_rescue.lines.append(DialogueLine.new("You", "Welcome to the raft. We're all survivors here.", "happy"))
	
	dialogue_database["rescue_survivor"] = dialogue_rescue
	
	# Trader encounter
	var dialogue_trader = Dialogue.new("trader")
	dialogue_trader.speaker_name = "Trader"
	dialogue_trader.dialogue_type = DialogueType.CONVERSATION
	
	dialogue_trader.lines.append(DialogueLine.new("Trader", "Ah, a new face! Good to see the waters aren't empty.", "happy"))
	dialogue_trader.lines.append(DialogueLine.new("Trader", "I've got supplies. Medicine, blueprints, you name it.", "neutral"))
	dialogue_trader.lines.append(DialogueLine.new("Trader", "But nothing's free, friend. What have you got to trade?", "neutral"))
	
	dialogue_trader.choices.append(DialogueChoice.new("trade_plastic", "I have plastic.").with_effects({"trading": true}))
	dialogue_trader.choices.append(DialogueChoice.new("trade_later", "Maybe later.").with_effects({"trading_declined": true}))
	
	dialogue_database["trader"] = dialogue_trader


func _init_radio_database() -> void:
	# Chapter 1 - Emergency broadcasts
	var radio_emergency1 = RadioTransmission.new("emergency_1", "Emergency Broadcast", "This is an emergency broadcast. All flights have been grounded. Repeat: ALL FLIGHTS CANCELLED. Proceed to nearest evacuation point immediately.")
	radio_emergency1.frequency = "102.5 MHz"
	radio_emergency1.chapter = 1
	radio_database["emergency_1"] = radio_emergency1
	
	var radio_emergency2 = RadioTransmission.new("emergency_2", "Distress Signal", "Mayday... mayday... anyone receiving? We're going down near coordinates... [static]... please, if anyone can hear...")
	radio_emergency2.frequency = "145.0 MHz"
	radio_emergency2.chapter = 1
	radio_database["emergency_2"] = radio_emergency2
	
	# Chapter 2 - Mysterious signals
	var radio_mystery1 = RadioTransmission.new("mystery_signal_1", "Unknown", "[Static]... the water... [static]... not safe... [static]...")
	radio_mystery1.frequency = "88.3 MHz"
	radio_mystery1.chapter = 2
	radio_database["mystery_signal_1"] = radio_mystery1
	
	var radio_mystery2 = RadioTransmission.new("mystery_signal_2", "Unknown", "[Static]... they made a mistake... [static]... facility... [static]... escape...")
	radio_mystery2.frequency = "88.3 MHz"
	radio_mystery2.chapter = 2
	radio_mystery2.repeating = true
	radio_database["mystery_signal_2"] = radio_mystery2
	
	var radio_survivor1 = RadioTransmission.new("survivor_ch2", "Survivor Group", "This is a message to any survivors. We've established a camp on the northern islands. If you can hear this, please respond. We're gathering survivors.")
	radio_survivor1.frequency = "101.3 MHz"
	radio_survivor1.chapter = 2
	radio_survivor1.has_coordinates = true
	radio_survivor1.coordinates = Vector2(150, 80)
	radio_database["survivor_ch2"] = radio_survivor1
	
	# Chapter 3 - Multiple groups
	var radio_groups = RadioTransmission.new("multiple_groups", "Multiple Voices", "[Static]... we have food... [static]... medicine needed... [static]... safe here...")
	radio_groups.frequency = "99.7 MHz"
	radio_groups.chapter = 3
	radio_groups.repeating = true
	radio_database["multiple_groups"] = radio_groups
	
	var radio_warning = RadioTransmission.new("danger_warning", "Unknown", "DO NOT APPROACH [static]... the water is [static]... contaminated... [static]... stay away...")
	radio_warning.frequency = "76.2 MHz"
	radio_warning.chapter = 3
	radio_warning.is_intermittent = true
	radio_database["danger_warning"] = radio_warning
	
	var radio_trade = RadioTransmission.new("trade_network", "Trade Network", "Trader frequency open. Got supplies, need supplies. Meet at the usual coordinates. Safe waters only.")
	radio_trade.frequency = "105.5 MHz"
	radio_trade.chapter = 3
	radio_database["trade_network"] = radio_trade
	
	# Chapter 4 - The truth
	var radio_truth1 = RadioTransmission.new("truth_signal", "Automated", "FACILITY ACCESS DETECTED. ACTIVATION KEY REQUIRED. PLEASE PROCEED TO MAIN CONSOLE.")
	radio_truth1.frequency = "55.5 MHz"
	radio_truth1.chapter = 4
	radio_truth1.is_intermittent = true
	radio_database["truth_signal"] = radio_truth1
	
	var radio_guardian_msg = RadioTransmission.new("guardian_message", "Guardian", "To the one who carries the key: I am the last guardian. The facility must not be reopened. It is not salvation. It is an end. Trust not the depths.")
	radio_guardian_msg.frequency = "55.5 MHz"
	radio_guardian_msg.chapter = 4
	radio_database["guardian_message"] = radio_guardian_msg
	
	# Chapter 5 - Final transmissions
	var radio_final = RadioTransmission.new("final_transmission", "Entity", "[Sound like waves crashing]... [Sound like voices screaming]... [Sound like static]...")
	radio_final.frequency = "55.5 MHz"
	radio_final.chapter = 5
	radio_final.is_intermittent = true
	radio_database["final_transmission"] = radio_final


func _init_lore_notes() -> void:
	# Chapter 1 notes
	var note1 = LoreNote.new("note_crash_1", "Burned Manifest", "Flight 447 - Emergency Protocol\n\nThis is the last known flight out. If you're reading this, the evacuation failed. God help us all.\n\n- Captain James Morrison")
	note1.location_hint = "In your emergency locker"
	note1.chapter = 1
	note1.lore_type = "manifest"
	lore_note_database.append(note1)
	
	var note2 = LoreNote.new("note_bottle_1", "SOS in Bottle", "TO ANYONE WHO CAN HEAR THIS:\n\nThe coastal cities are gone. The water rose overnight. We've been drifting for days. If anyone finds this... don't try to go back. There's nothing left.\n\nMay God forgive us.")
	note2.location_hint = "Floating in the ocean"
	note2.chapter = 1
	note2.lore_type = "letter"
	lore_note_database.append(note2)
	
	# Chapter 2 notes
	var note3 = LoreNote.new("note_research_1", "Research Station Log", "Day 47 at Outpost Omega\n\nThe water keeps rising. The containment protocols failed. Dr. Vance says we have weeks, not months. I've stopped hoping for rescue.\n\nIf anyone finds this - the coordinates in my other notes point to the facility. That's where it all started.")
	note3.location_hint = "Island research camp"
	note3.chapter = 2
	note3.lore_type = "log"
	lore_note_database.append(note3)
	
	var note4 = LoreNote.new("note_warning_1", "Desperate Warning", "...the corporation knew. They knew the whole time. The experiments weren't about saving humanity - they were about controlling what remains.\n\nIf you're reading this - destroy the facility. Don't let them restart the project. It's not a cure - it's a weapon.\n\n- Sarah K.")
	note4.location_hint = "Inside survival shelter"
	note4.chapter = 2
	note4.lore_type = "letter"
	lore_note_database.append(note4)
	
	# Chapter 3 notes
	var note5 = LoreNote.new("note_military_1", "Military Dispatch", "EMERGENCY BROADCAST - PRIORITY ALPHA\n\nAll survivor groups: Do NOT approach the coastal sectors. The water there is... changed. Biological samples show mutations. The contamination spreads.\n\nRepeat: Do NOT approach the water. Stay inland.")
	note5.location_hint = "Found in military crate"
	note5.chapter = 3
	note5.lore_type = "manifest"
	lore_note_database.append(note5)
	
	# Chapter 4 notes
	var note6 = LoreNote.new("note_genesis_1", "Project Genesis Report", "PROJECT GENESIS - CLASSIFIED\n\nOur experiments have yielded unprecedented results. The modified organism can survive in any environment.\n\nHowever, there's an unexpected side effect. The organism seems to have developed... intelligence. It's not just surviving anymore. It's planning.\n\nWe may have created the perfect life form. Or the perfect predator.\n\n- Dr. Elias Vance")
	note6.location_hint = "Ancient ruins - hidden chamber"
	note6.chapter = 4
	note6.lore_type = "report"
	lore_note_database.append(note6)
	
	var note7 = LoreNote.new("note_guardian_1", "Guardian's Warning", "YOU WHO SEE THIS MESSAGE:\n\nI am the last guardian. The others are gone, consumed by what we created.\n\nThe facility must never be reopened. It's not evil - it's simply alien. It doesn't understand death, so it doesn't understand mercy.\n\nIf you have the activation key, I beg you - throw it into the ocean. Let the depths take it. Let this end.\n\n- Guardian Unit 7")
	note7.location_hint = "Guardian statue"
	note7.chapter = 4
	note7.lore_type = "note"
	lore_note_database.append(note7)


## ==================== DIALOGUE CONTROL ====================

func start_dialogue(dialogue_id: String) -> bool:
	if not dialogue_database.has(dialogue_id):
		push_warning("Dialogue not found: " + dialogue_id)
		return false
	
	current_dialogue = dialogue_database[dialogue_id]
	current_line_index = 0
	is_dialogue_active = true
	
	dialogue_started.emit(dialogue_id)
	_display_current_line()
	
	return true


func _display_current_line() -> void:
	if current_line_index >= current_dialogue.lines.size():
		if current_dialogue.choices.size() > 0:
			pending_choices = current_dialogue.choices
		else:
			end_dialogue()
		return
	
	var line = current_dialogue.lines[current_line_index]
	dialogue_line_displayed.emit(line)
	current_line_index += 1


func advance_dialogue() -> void:
	if not is_dialogue_active:
		return
	
	_display_current_line()


func make_choice(choice_index: int) -> void:
	if choice_index >= pending_choices.size():
		return
	
	var choice = pending_choices[choice_index]
	choice_made.emit(choice.id)
	
	# Apply effects
	for effect_key in choice.effects:
		StoryManager.set_story_flag(effect_key, choice.effects[effect_key])
	
	# Handle quests
	if choice.quest_to_start != "":
		var quest_system = get_tree().get_first_node_in_group("quest_system") as QuestSystem
		if quest_system:
			quest_system.start_quest(choice.quest_to_start)
	
	if choice.quest_to_complete != "":
		var quest_system = get_tree().get_first_node_in_group("quest_system") as QuestSystem
		if quest_system:
			quest_system.complete_quest(choice.quest_to_complete)
	
	# Navigate to next dialogue or end
	pending_choices.clear()
	
	if choice.next_dialogue != "":
		start_dialogue(choice.next_dialogue)
	else:
		end_dialogue()


func end_dialogue() -> void:
	var dialogue_id = current_dialogue.id
	is_dialogue_active = false
	current_dialogue = null
	current_line_index = 0
	pending_choices.clear()
	dialogue_ended.emit(dialogue_id)


## ==================== RADIO SYSTEM ====================

func receive_radio_transmission(transmission_id: String) -> bool:
	if not radio_database.has(transmission_id):
		return false
	
	var transmission = radio_database[transmission_id]
	radio_transmission_received.emit(transmission)
	return true


func get_radio_transmission(transmission_id: String) -> RadioTransmission:
	return radio_database.get(transmission_id)


func get_available_radio_signals() -> Array:
	var current_chapter = 1
	var story_manager = get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story_manager:
		current_chapter = story_manager.current_chapter
	
	var available: Array = []
	for id in radio_database:
		if radio_database[id].chapter <= current_chapter:
			available.append(radio_database[id])
	return available


func tune_to_frequency(frequency: String) -> RadioTransmission:
	for id in radio_database:
		if radio_database[id].frequency == frequency:
			var transmission = radio_database[id]
			radio_transmission_received.emit(transmission)
			return transmission
	return null


## ==================== LORE SYSTEM ====================

func collect_lore_note(note_id: String) -> bool:
	for note in lore_note_database:
		if note.id == note_id and not note.is_collected:
			note.is_collected = true
			lore_note_found.emit(note)
			StoryManager.collect_lore(note_id)
			return true
	return false


func get_lore_note(note_id: String) -> LoreNote:
	for note in lore_note_database:
		if note.id == note_id:
			return note
	return null


func get_lore_notes_for_chapter(chapter: int) -> Array:
	var result: Array = []
	for note in lore_note_database:
		if note.chapter == chapter:
			result.append(note)
	return result


func get_collected_lore_notes() -> Array:
	var result: Array = []
	for note in lore_note_database:
		if note.is_collected:
			result.append(note)
	return result


## ==================== QUERY METHODS ====================

func get_current_line() -> DialogueLine:
	if current_dialogue == null or current_line_index >= current_dialogue.lines.size():
		return null
	return current_dialogue.lines[current_line_index - 1]


func has_choices() -> bool:
	return pending_choices.size() > 0


func get_current_choices() -> Array:
	return pending_choices


func is_active() -> bool:
	return is_dialogue_active


## ==================== RANDOM EVENTS ====================

func play_random_encounter() -> void:
	var encounters: Array = ["rescue_survivor", "trader", "strange_signal"]
	encounters.shuffle()
	start_dialogue(encounters[0])
