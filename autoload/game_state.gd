extends Node

## Game State - global game data and state management

# Game info
var game_name: String = "Raft: Ocean Survival"
var version: String = "0.1.0"

# Player state
var player_name: String = "Survivor"
var player_health: float = 100.0
var player_hunger: float = 100.0
var player_thirst: float = 100.0
var player_stamina: float = 100.0

# World state
var current_day: int = 1
var time_of_day: float = 12.0  # 0-24 hours
var is_paused: bool = false
var game_over: bool = false

# Progression
var player_level: int = 1
var player_xp: float = 0.0
var skills_unlocked: Array = []

# Location
var raft_position: Vector3 = Vector3.ZERO
var current_biome: String = "ocean"

# Game settings
var difficulty: String = "normal"  # easy, normal, hard, survival
var is_tutorial_completed: bool = false
var auto_save_enabled: bool = true

# Story progress
var story_flags: Dictionary = {}
var quests_completed: Array = []
var current_quest_id: String = ""

# World events
var weather: String = "clear"
var storm_intensity: float = 0.0
var is_night: bool = false

func _ready() -> void:
	_load_game()

func _process(delta: float) -> void:
	if not is_paused and not game_over:
		_update_time(delta)
		_update_stats(delta)

func _update_time(delta: float) -> void:
	# Day/night cycle (5 minutes = 1 day)
	time_of_day += delta * (24.0 / 300.0)  # 5 min = 300 sec
	if time_of_day >= 24.0:
		time_of_day = 0.0
		current_day += 1
		_on_new_day()
	
	is_night = time_of_day < 6.0 or time_of_day > 20.0

func _update_stats(delta: float) -> void:
	# Hunger decay (faster when hungry)
	var hunger_rate = 0.5 * delta  # 0.5 per second
	player_hunger = max(0.0, player_hunger - hunger_rate)
	
	# Thirst decay (faster than hunger)
	var thirst_rate = 0.8 * delta
	player_thirst = max(0.0, player_thirst - thirst_rate)
	
	# Health decay when starving or dehydrated
	if player_hunger <= 0.0 or player_thirst <= 0.0:
		player_health -= delta * 2.0
	
	player_health = clamp(player_health, 0.0, 100.0)
	
	# Check game over
	if player_health <= 0.0:
		_trigger_game_over()

func _on_new_day() -> void:
	# Daily quest refresh, weather change, etc.
	pass

func _trigger_game_over() -> void:
	game_over = true
	is_paused = true
	print("Game Over!")

# Save/Load
func save_game(slot: int = 0) -> bool:
	var save_data = {
		"version": version,
		"player_name": player_name,
		"player_health": player_health,
		"player_hunger": player_hunger,
		"player_thirst": player_thirst,
		"current_day": current_day,
		"time_of_day": time_of_day,
		"player_level": player_level,
		"player_xp": player_xp,
		"raft_position": {"x": raft_position.x, "y": raft_position.y, "z": raft_position.z},
		"current_biome": current_biome,
		"difficulty": difficulty,
		"is_tutorial_completed": is_tutorial_completed,
		"story_flags": story_flags,
		"quests_completed": quests_completed,
		"current_quest_id": current_quest_id,
		"weather": weather
	}
	
	var file = FileAccess.open("user://save_game_" + str(slot) + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		return true
	return false

func load_game(slot: int = 0) -> bool:
	var file = FileAccess.open("user://save_game_" + str(slot) + ".json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var data = json.get_data()
			_apply_save_data(data)
			file.close()
			return true
	return false

func _apply_save_data(data: Dictionary) -> void:
	player_name = data.get("player_name", "Survivor")
	player_health = data.get("player_health", 100.0)
	player_hunger = data.get("player_hunger", 100.0)
	player_thirst = data.get("player_thirst", 100.0)
	current_day = data.get("current_day", 1)
	time_of_day = data.get("time_of_day", 12.0)
	player_level = data.get("player_level", 1)
	player_xp = data.get("player_xp", 0.0)
	
	var pos = data.get("raft_position", {})
	raft_position = Vector3(pos.get("x", 0), pos.get("y", 0), pos.get("z", 0))
	
	current_biome = data.get("current_biome", "ocean")
	difficulty = data.get("difficulty", "normal")
	is_tutorial_completed = data.get("is_tutorial_completed", false)
	story_flags = data.get("story_flags", {})
	quests_completed = data.get("quests_completed", [])
	current_quest_id = data.get("current_quest_id", "")
	weather = data.get("weather", "clear")
	
	game_over = false
	is_paused = false

func _load_game() -> void:
	# Try to load auto-save if exists
	if auto_save_enabled:
		load_game(0)

# Player actions
func add_xp(amount: float) -> void:
	player_xp += amount
	_check_level_up()

func _check_level_up() -> void:
	var xp_needed = player_level * 100.0
	while player_xp >= xp_needed:
		player_xp -= xp_needed
		player_level += 1
		_on_level_up()

func _on_level_up() -> void:
	player_health = 100.0
	# Could trigger level up effects here

func consume_food(hunger_restore: float) -> void:
	player_hunger = min(100.0, player_hunger + hunger_restore)

func consume_drink(thirst_restore: float) -> void:
	player_thirst = min(100.0, player_thirst + thirst_restore)

func heal(amount: float) -> void:
	player_health = min(100.0, player_health + amount)

# Story flags
func set_story_flag(flag: String, value: bool) -> void:
	story_flags[flag] = value

func get_story_flag(flag: String) -> bool:
	return story_flags.get(flag, false)

# Pause
func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false

func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()

# Reset
func new_game() -> void:
	player_health = 100.0
	player_hunger = 100.0
	player_thirst = 100.0
	player_stamina = 100.0
	current_day = 1
	time_of_day = 12.0
	player_level = 1
	player_xp = 0.0
	raft_position = Vector3.ZERO
	current_biome = "ocean"
	story_flags = {}
	quests_completed = []
	current_quest_id = ""
	weather = "clear"
	storm_intensity = 0.0
	game_over = false
	is_paused = false
