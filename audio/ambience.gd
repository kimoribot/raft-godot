extends Node
## Ocean ambience system for Raft game.
## Manages wave, wind, and seagull sounds that vary with weather conditions.

class_name AmbienceManager

# Weather states
enum WeatherState { CALM, MODERATE, STORMY }

# Audio stream players
var wave_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var seagull_player: AudioStreamPlayer

# Volume controls
var wave_volume: float = 0.0
var wind_volume: float = 0.0
var seagull_volume: float = 0.0

# Current weather state
var current_weather: WeatherState = WeatherState.CALM

# Storm intensity (0.0 - 1.0)
var storm_intensity: float = 0.0

# Tween for smooth transitions
var volume_tween: Tween

# Bus indices
var master_bus_idx: int = 0
var ambience_bus_idx: int = -1


func _ready() -> void:
	_setup_audio_players()
	_setup_audio_bus()
	_connect_weather_system()


func _setup_audio_players() -> void:
	# Wave sounds player
	wave_player = AudioStreamPlayer.new()
	wave_player.name = "WavePlayer"
	wave_player.bus = "Ambience"
	wave_player.volume_db = -80.0  # Start silent
	add_child(wave_player)
	
	# Wind sounds player
	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindPlayer"
	wind_player.bus = "Ambience"
	wind_player.volume_db = -80.0
	add_child(wind_player)
	
	# Seagull sounds player (for distance, make it quieter)
	seagull_player = AudioStreamPlayer.new()
	seagull_player.name = "SeagullPlayer"
	seagull_player.bus = "Ambience"
	seagull_player.volume_db = -80.0
	seagull_player.max_distance = 500.0
	seagull_player.unit_size = 2.0
	add_child(seagull_player)
	
	# Note: In production, load actual audio streams
	# wave_player.stream = load("res://audio/ambience/waves.ogg")
	# wind_player.stream = load("res://audio/ambience/wind.ogg")
	# seagull_player.stream = load("res://audio/ambience/seagulls.ogg")


func _setup_audio_bus() -> void:
	# Find or create Ambience bus
	ambience_bus_idx = AudioServer.get_bus_index("Ambience")
	if ambience_bus_idx == -1:
		# Create new bus
		ambience_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(ambience_bus_idx)
		AudioServer.set_bus_name(ambience_bus_idx, "Ambience")
		# Connect to Master
		AudioServer.set_bus_send(ambience_bus_idx, master_bus_idx)
	
	# Set default volumes
	_update_volumes_for_weather()


func _connect_weather_system() -> void:
	# In production, connect to your game's weather system
	# Example: Events.weather_changed.connect(_on_weather_changed)
	pass


func _on_weather_changed(new_weather: WeatherState, intensity: float = 0.0) -> void:
	current_weather = new_weather
	storm_intensity = clamp(intensity, 0.0, 1.0)
	_animate_volume_transition()


func _animate_volume_transition() -> void:
	if volume_tween:
		volume_tween.kill()
	
	volume_tween = create_tween()
	volume_tween.set_trans(Tween.TRANS_SINE)
	volume_tween.set_ease(Tween.EASE_IN_OUT)
	
	var duration: float = 2.0
	
	match current_weather:
		WeatherState.CALM:
			# Gentle waves, light wind, distant seagulls
			volume_tween.tween_property(wave_player, "volume_db", -6.0, duration)
			volume_tween.parallel().tween_property(wind_player, "volume_db", -12.0, duration)
			volume_tween.parallel().tween_property(seagull_player, "volume_db", -18.0, duration)
			_set_playback_speed(1.0)
			
		WeatherState.MODERATE:
			# Increased waves, stronger wind, fewer seagulls
			volume_tween.tween_property(wave_player, "volume_db", 0.0, duration)
			volume_tween.parallel().tween_property(wind_player, "volume_db", -6.0, duration)
			volume_tween.parallel().tween_property(seagull_player, "volume_db", -24.0, duration)
			_set_playback_speed(1.1)
			
		WeatherState.STORMY:
			# Intense waves, strong wind, no seagulls
			var storm_wave_vol: float = lerp(0.0, 6.0, storm_intensity)
			var storm_wind_vol: float = lerp(-3.0, 3.0, storm_intensity)
			
			volume_tween.tween_property(wave_player, "volume_db", storm_wave_vol, duration)
			volume_tween.parallel().tween_property(wind_player, "volume_db", storm_wind_vol, duration)
			volume_tween.parallel().tween_property(seagull_player, "volume_db", -80.0, duration * 0.5)
			_set_playback_speed(1.0 + storm_intensity * 0.3)


func _set_playback_speed(speed: float) -> void:
	# Modulate playback for variety
	if wave_player.stream:
		wave_player.pitch_scale = speed
	if wind_player.stream:
		wind_player.pitch_scale = speed * 0.9


func _update_volumes_for_weather() -> void:
	match current_weather:
		WeatherState.CALM:
			wave_volume = 0.5
			wind_volume = 0.3
			seagull_volume = 0.2
		WeatherState.MODERATE:
			wave_volume = 0.7
			wind_volume = 0.5
			seagull_volume = 0.1
		WeatherState.STORMY:
			wave_volume = 0.9
			wind_volume = 0.8
			seagull_volume = 0.0


func play() -> void:
	if not wave_player.playing:
		wave_player.play()
	if not wind_player.playing:
		wind_player.play()
	# Seagulls play intermittently
	if not seagull_player.playing:
		_schedule_seagull_calls()


func stop() -> void:
	wave_player.stop()
	wind_player.stop()
	seagull_player.stop()


func _schedule_seagull_calls() -> void:
	if seagull_volume <= 0.0:
		return
	
	# Random delay between seagull calls (10-30 seconds)
	var delay: float = randf_range(10.0, 30.0)
	await get_tree().create_timer(delay).timeout
	
	if seagull_volume > 0.0 and current_weather != WeatherState.STORMY:
		seagull_player.play()
		_schedule_seagull_calls()


func set_ambience_volume(value: float) -> void:
	# Global ambience volume (0.0 - 1.0)
	value = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(ambience_bus_idx, linear_to_db(value))


func get_weather_state() -> WeatherState:
	return current_weather


func set_weather(state: WeatherState, intensity: float = 0.5) -> void:
	_on_weather_changed(state, intensity)
