extends Node

## Audio Manager - handles all game audio (music, SFX, ambience)

signal music_changed(track_name)
signal sfx_volume_changed(value)
signal music_volume_changed(value)

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

var sfx_volume: float = 0.8
var music_volume: float = 0.6
var ambience_volume: float = 0.5

# Audio buses
var master_bus: int = 0
var music_bus: int = 1
var sfx_bus: int = 2
var ambience_bus: int = 3

func _ready() -> void:
	_setup_audio_players()
	_load_settings()

func _setup_audio_players() -> void:
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	music_player.volume_db = linear_to_db(music_volume)
	music_player.connect("finished", _on_music_finished)
	add_child(music_player)
	
	# SFX player
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "SFX"
	sfx_player.volume_db = linear_to_db(sfx_volume)
	add_child(sfx_player)
	
	# Ambience player
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "AmbiencePlayer"
	ambience_player.bus = "Ambience"
	ambience_player.volume_db = linear_to_db(ambience_volume)
	add_child(ambience_player)
	
	# Create audio buses if needed
	_setup_audio_buses()

func _setup_audio_buses() -> void:
	# Master is always bus 0
	# Add additional buses
	var bus_count = AudioServer.get_bus_count()
	while bus_count < 4:
		AudioServer.add_bus(bus_count)
		bus_count += 1
	
	# Name the buses
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_name(3, "Ambience")

func _load_settings() -> void:
	if FileAccess.file_exists("user://audio_settings.cfg"):
		var config = ConfigFile.new()
		config.load("user://audio_settings.cfg")
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		music_volume = config.get_value("audio", "music_volume", 0.6)
		ambience_volume = config.get_value("audio", "ambience_volume", 0.5)
		_apply_volume()

func _apply_volume() -> void:
	if music_player:
		music_player.volume_db = linear_to_db(music_volume)
	if sfx_player:
		sfx_player.volume_db = linear_to_db(sfx_volume)
	if ambience_player:
		ambience_player.volume_db = linear_to_db(ambience_volume)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "ambience_volume", ambience_volume)
	config.save("user://audio_settings.cfg")

# Music functions
func play_music(track: AudioStream, fade_time: float = 1.0) -> void:
	if not music_player:
		return
	
	if music_player.playing:
		_fade_out_music(fade_time)
	
	music_player.stream = track
	music_player.play()

func stop_music(fade_time: float = 1.0) -> void:
	if music_player and music_player.playing:
		_fade_out_music(fade_time)

func _fade_out_music(time: float) -> void:
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, time)
	tween.tween_callback(music_player.stop)
	tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), 0.1)

func _on_music_finished() -> void:
	# Auto-play next in playlist or loop
	pass

# SFX functions
func play_sfx(sound: AudioStream, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not sfx_player:
		return
	
	var player = sfx_player.duplicate()
	player.name = "SFX_" + str(Time.get_ticks_msec())
	player.bus = "SFX"
	player.volume_db = linear_to_db(sfx_volume * volume)
	player.pitch_scale = pitch
	player.stream = sound
	player.connect("finished", player.queue_free)
	add_child(player)
	player.play()

func play_ui_click() -> void:
	# Placeholder for UI click sound
	pass

func play_collect_item() -> void:
	# Placeholder for item pickup sound
	pass

func play_damage() -> void:
	# Placeholder for damage sound
	pass

# Ambience functions
func play_ambience(track: AudioStream) -> void:
	if ambience_player:
		ambience_player.stream = track
		ambience_player.play()

func stop_ambience() -> void:
	if ambience_player:
		ambience_player.stop()

# Volume control
func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_volume()
	emit_signal("sfx_volume_changed", sfx_volume)
	save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_volume()
	emit_signal("music_volume_changed", music_volume)
	save_settings()

func set_ambience_volume(value: float) -> void:
	ambience_volume = clamp(value, 0.0, 1.0)
	_apply_volume()
	save_settings()
