extends Control

func _ready() -> void:
	# Connect button signals
	var new_game_btn = $MenuContainer/VBox/NewGameButton
	var continue_btn = $MenuContainer/VBox/ContinueButton
	var settings_btn = $MenuContainer/VBox/SettingsButton
	
	if new_game_btn:
		new_game_btn.pressed.connect(_on_new_game_pressed)
	
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)

func _on_new_game_pressed() -> void:
	# Start a new game
	GameState.new_game()
	get_tree().change_scene_to_file("res://world/game_world.tscn")

func _on_continue_pressed() -> void:
	# Try to load saved game
	if GameState.load_game(0):
		get_tree().change_scene_to_file("res://world/game_world.tscn")
	else:
		print("No saved game found")

func _on_settings_pressed() -> void:
	# For now, just print - settings menu can be added later
	print("Settings pressed")
