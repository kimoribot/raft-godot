extends Node
## Main audio manager for Raft game.
## Central hub for all audio systems with volume controls, bus management,
## ducking, and 3D audio positioning.

class_name AudioManager

# Singleton instance
static var instance: AudioManager

# Audio subsystem managers
var ambience: AmbienceManager
var music: MusicManager
var sfx: SFXManager

# Bus indices
var master_bus_idx: int = 0
var music_bus_idx: int = -1
var sfx_bus_idx: int = -1
var ambience_bus_idx: int = -1

# Volume settings (0.0 - 1.0)
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var ambience_volume: float = 0.6

# Ducking
var is_ducking: bool = false
var ducking_tween: Tween
var ducking_reduce_db: float = -12.0  # How much to reduce (in dB)
var ducking_restore_delay: float = 1.5

# 3D Audio settings
var listener_3d: AudioListener3D

# Player reference for 3D positioning
var player_node: Node3D = null


func _ready() -> void:
	# Singleton setup
	if instance == null:
		instance = self
	else:
		push_warning("AudioManager: Multiple instances detected, ignoring.")
		queue_free()
		return
	
	_setup_audio_buses()
	_create_audio_managers()
	_setup_3d_listener()


func _setup_audio_buses() -> void:
	# Ensure Master bus exists
	master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx == -1:
		push_error("AudioManager: Master audio bus not found!")
		return
	
	# Create custom buses
	_create_audio_bus("Music", 0.4)
	_create_audio_bus("SFX", 0.6)
	_create_audio_bus("Ambience", 0.5)
	
	# Get bus indices
	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")
	ambience_bus_idx = AudioServer.get_bus_index("Ambience")
	
	# Apply initial volumes
	_update_all_bus_volumes()


func _create_audio_bus(bus_name: String, default_volume: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, bus_name)
	
	# Set default volume
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(default_volume))
	
	# Connect to Master
	AudioServer.set_bus_send(bus_idx, master_bus_idx)
	
	# Add effect slots (compressor for ducking)
	_add_compressor_to_bus(bus_idx)


func _add_compressor_to_bus(bus_idx: int) -> void:
	# Add a dynamics compressor effect for better audio quality
	var compressor: Effect = Compressor.new()
	compressor.threshold_db = -24.0
	compressor.ratio = 4.0
	compressor.attack_us = 50
	compressor.release_ms = 250
	
	# Insert at position 0
	AudioServer.add_bus_effect(bus_idx, compressor, 0)


func _create_audio_managers() -> void:
	# Create ambience manager
	ambience = AmbienceManager.new()
	ambience.name = "AmbienceManager"
	add_child(ambience)
	
	# Create music manager
	music = MusicManager.new()
	music.name = "MusicManager"
	add_child(music)
	
	# Create SFX manager
	sfx = SFXManager.new()
	sfx.name = "SFXManager"
	add_child(sfx)


func _setup_3d_listener() -> void:
	# Create 3D listener
	listener_3d = AudioListener3D.new()
	listener_3d.name = "AudioListener3D"
	listener_3d.make_current()
	add_child(listener_3d)


# ==================== VOLUME CONTROLS ====================

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_update_bus_volume(master_bus_idx, master_volume)


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_update_bus_volume(music_bus_idx, music_volume)
	if music:
		music.set_music_volume(music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_update_bus_volume(sfx_bus_idx, sfx_volume)
	if sfx:
		sfx.set_sfx_volume(sfx_volume)


func set_ambience_volume(value: float) -> void:
	ambience_volume = clamp(value, 0.0, 1.0)
	_update_bus_volume(ambience_bus_idx, ambience_volume)
	if ambience:
		ambience.set_ambience_volume(ambience_volume)


func _update_bus_volume(bus_idx: int, volume: float) -> void:
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))


func _update_all_bus_volumes() -> void:
	_update_bus_volume(master_bus_idx, master_volume)
	_update_bus_volume(music_bus_idx, music_volume)
	_update_bus_volume(sfx_bus_idx, sfx_volume)
	_update_bus_volume(ambience_bus_idx, ambience_volume)


func get_master_volume() -> float:
	return master_volume


func get_music_volume() -> float:
	return music_volume


func get_sfx_volume() -> float:
	return sfx_volume


func get_ambience_volume() -> float:
	return ambience_volume


# ==================== DUCKING SYSTEM ====================

func duck(duration: float = 0.3, reduce_db: float = -12.0) -> void:
	"""Reduce music/ambience volume for important sounds."""
	if is_ducking:
		# Already ducking, just extend the timer
		if ducking_tween:
			ducking_tween.kill()
		_schedule_duck_restore(duration)
		return
	
	is_ducking = true
	ducking_reduce_db = reduce_db
	
	if ducking_tween:
		ducking_tween.kill()
	
	ducking_tween = create_tween()
	ducking_tween.set_parallel(true)
	
	# Duck music
	if music_bus_idx >= 0:
		var current_music_vol: float = AudioServer.get_bus_volume_db(music_bus_idx)
		ducking_tween.tween_property(AudioServer, "bus_volumes_db", 
			{music_bus_idx: current_music_vol + reduce_db}, duration)
	
	# Duck ambience
	if ambience_bus_idx >= 0:
		var current_amb_vol: float = AudioServer.get_bus_volume_db(ambience_bus_idx)
		ducking_tween.parallel().tween_property(AudioServer, "bus_volumes_db",
			{ambience_bus_idx: current_amb_vol + reduce_db * 0.7}, duration)
	
	# Schedule restore
	_schedule_duck_restore(duration + ducking_restore_delay)


func _schedule_duck_restore(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_restore_from_duck()


func _restore_from_duck() -> void:
	if not is_ducking:
		return
	
	if ducking_tween:
		ducking_tween.kill()
	
	ducking_tween = create_tween()
	ducking_tween.set_parallel(true)
	
	# Restore music volume
	if music_bus_idx >= 0:
		ducking_tween.tween_property(AudioServer, "bus_volumes_db",
			{music_bus_idx: linear_to_db(music_volume)}, 0.5)
	
	# Restore ambience
	if ambience_bus_idx >= 0:
		ducking_tween.parallel().tween_property(AudioServer, "bus_volumes_db",
			{ambience_bus_idx: linear_to_db(ambience_volume)}, 0.5)
	
	await ducking_tween.finished
	is_ducking = false


func is_ducking_active() -> bool:
	return is_ducking


# ==================== 3D AUDIO POSITIONING ====================

func set_listener_position(position: Vector3) -> void:
	if listener_3d:
		listener_3d.global_position = position


func set_player_node(node: Node3D) -> void:
	"""Set the player node for relative 3D positioning."""
	player_node = node


func get_3d_world_position() -> Vector3:
	if player_node:
		return player_node.global_position
	return Vector3.ZERO


# ==================== CONVENIENCE METHODS ====================

func play_ambience() -> void:
	if ambience:
		ambience.play()


func stop_ambience() -> void:
	if ambience:
		ambience.stop()


func set_weather(state: AmbienceManager.WeatherState, intensity: float = 0.5) -> void:
	if ambience:
		ambience.set_weather(state, intensity)


func play_music() -> void:
	if music:
		music.play()


func stop_music() -> void:
	if music:
		music.stop()


func set_music_state(state: MusicManager.MusicState) -> void:
	if music:
		music.set_state(state)


func play_music_calm() -> void:
	if music:
		music.play_calm()


func play_music_intense() -> void:
	if music:
		music.play_intense()


func play_music_storm() -> void:
	if music:
		music.play_storm()


# ==================== SFX CONVENIENCE ====================

func play_footstep() -> void:
	if sfx:
		sfx.play_footstep()


func play_splash(position: Vector3 = Vector3.ZERO, intensity: float = 0.5) -> void:
	if sfx:
		sfx.play_splash(position, intensity)


func play_hook_throw() -> void:
	if sfx:
		sfx.play_hook_throw()


func play_item_pickup() -> void:
	if sfx:
		sfx.play_item_pickup()


func play_craft_complete() -> void:
	if sfx:
		sfx.play_craft_complete()


func play_shark_attack() -> void:
	if sfx:
		sfx.play_shark_attack()


func play_ui_click() -> void:
	if sfx:
		sfx.play_ui_click()


# ==================== DUCKING WRAPPERS FOR SFX ====================

func play_important_sfx(sfx_method: Callable) -> void:
	"""Play an important SFX with automatic ducking."""
	duck(0.2, -8.0)
	sfx_method.call()


func play_critical_sfx(sfx_method: Callable) -> void:
	"""Play a critical SFX with strong ducking."""
	duck(0.15, -15.0)
	sfx_method.call()


# ==================== GAME EVENT HANDLERS ====================

func on_player_jump() -> void:
	duck(0.1, -6.0)
	play_splash(Vector3.ZERO, 0.3)


func on_item_collected() -> void:
	play_item_pickup()


func on_crafting_complete() -> void:
	play_craft_complete()


func on_shark_attack() -> void:
	duck(0.3, -10.0)
	play_music_intense()


func on_storm_start() -> void:
	play_music_storm()
	set_weather(AmbienceManager.WeatherState.STORMY, 1.0)


func on_storm_end() -> void:
	play_music_calm()
	set_weather(AmbienceManager.WeatherState.CALM)


# ==================== SAVE/LOAD ====================

func get_audio_settings() -> Dictionary:
	return {
		"master": master_volume,
		"music": music_volume,
		"sfx": sfx_volume,
		"ambience": ambience_volume
	}


func apply_audio_settings(settings: Dictionary) -> void:
	if settings.has("master"):
		set_master_volume(settings["master"])
	if settings.has("music"):
		set_music_volume(settings["music"])
	if settings.has("sfx"):
		set_sfx_volume(settings["sfx"])
	if settings.has("ambience"):
		set_ambience_volume(settings["ambience"])


# ==================== CLEANUP ====================

func _exit_tree() -> void:
	if instance == self:
		instance = null


# ==================== STATIC ACCESS ====================

static func get_instance() -> AudioManager:
	return instance


# Example usage function (call from game code)
static func play_sound(sound_name: String, position: Vector3 = Vector3.ZERO) -> void:
	if instance:
		match sound_name:
			"footstep":
				instance.play_footstep()
			"splash":
				instance.play_splash(position)
			"hook_throw":
				instance.play_hook_throw()
			"pickup":
				instance.play_item_pickup()
			"craft":
				instance.play_craft_complete()
			"shark":
				instance.play_shark_attack()
			"ui_click":
				instance.play_ui_click()
