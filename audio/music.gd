extends Node
## Dynamic music system for Raft game.
## Manages transitions between calm, intense, and storm music states.

class_name MusicManager

# Music states
enum MusicState { CALM, INTENSE, STORM, SILENCE }

# Current music state
var current_state: MusicState = MusicState.CALM

# Audio stream players (crossfade setup)
var primary_player: AudioStreamPlayer
var secondary_player: AudioStreamPlayer
var active_player: AudioStreamPlayer

# Crossfade tween
var crossfade_tween: Tween

# Volume settings
var music_volume: float = 0.7
var master_volume: float = 1.0

# Bus indices
var master_bus_idx: int = 0
var music_bus_idx: int = -1

# Track timers
var track_timer: float = 0.0
var current_track_duration: float = 0.0

# State transition flags
var is_transitioning: bool = false
var transition_duration: float = 3.0

# Storm intensity for layering
var storm_intensity: float = 0.0


func _ready() -> void:
	_setup_audio_players()
	_setup_audio_bus()
	_initialize_music()


func _setup_audio_players() -> void:
	# Primary player for current track
	primary_player = AudioStreamPlayer.new()
	primary_player.name = "MusicPrimary"
	primary_player.bus = "Music"
	primary_player.volume_db = -80.0
	add_child(primary_player)
	
	# Secondary player for crossfading
	secondary_player = AudioStreamPlayer.new()
	secondary_player.name = "MusicSecondary"
	secondary_player.bus = "Music"
	secondary_player.volume_db = -80.0
	add_child(secondary_player)
	
	active_player = primary_player
	
	# Note: In production, load actual audio streams
	# _load_music_streams()


func _setup_audio_bus() -> void:
	# Find or create Music bus
	music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		music_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(music_bus_idx)
		AudioServer.set_bus_name(music_bus_idx, "Music")
		AudioServer.set_bus_send(music_bus_idx, master_bus_idx)
	
	# Apply initial volume
	_update_bus_volume()


func _initialize_music() -> void:
	# Start with calm music
	_play_track(MusicState.CALM)


func _process(delta: float) -> void:
	# Handle track timing
	track_timer += delta
	if track_timer >= current_track_duration and current_track_duration > 0:
		_on_track_finished()


func _on_track_finished() -> void:
	# Loop or play next track based on state
	match current_state:
		MusicState.CALM:
			_play_calm_track()
		MusicState.INTENSE:
			_play_intense_track()
		MusicState.STORM:
			_play_storm_track()


func _play_track(state: MusicState, force: bool = false) -> void:
	if not force and current_state == state and active_player.playing:
		return
	
	current_state = state
	track_timer = 0.0
	
	# In production, select appropriate track based on state
	match state:
		MusicState.CALM:
			_play_calm_track()
		MusicState.INTENSE:
			_play_intense_track()
		MusicState.STORM:
			_play_storm_track()
		MusicState.SILENCE:
			_fade_to_silence()


func _play_calm_track() -> void:
	# Calm exploration music - peaceful, ambient
	current_track_duration = 180.0  # 3 minutes
	
	if crossfade_tween:
		crossfade_tween.kill()
	
	# Crossfade from current to calm
	var target_player: AudioStreamPlayer = secondary_player if active_player == primary_player else primary_player
	
	# In production: target_player.stream = load("res://audio/music/calm_exploration.ogg")
	
	# Crossfade
	crossfade_tween = create_tween()
	crossfade_tween.set_parallel(true)
	
	# Fade out current
	crossfade_tween.tween_property(active_player, "volume_db", -80.0, transition_duration)
	
	# Fade in new
	crossfade_tween.tween_property(target_player, "volume_db", _get_volume_for_state(MusicState.CALM), transition_duration)
	
	await crossfade_tween.finished
	
	active_player.stop()
	active_player = target_player
	active_player.play()


func _play_intense_track() -> void:
	# Intense shark attack music - urgent, dramatic
	current_track_duration = 60.0  # 1 minute loops
	
	if crossfade_tween:
		crossfade_tween.kill()
	
	var target_player: AudioStreamPlayer = secondary_player if active_player == primary_player else primary_player
	
	# In production: target_player.stream = load("res://audio/music/shark_attack.ogg")
	
	crossfade_tween = create_tween()
	crossfade_tween.set_parallel(true)
	
	# Quick crossfade for intense music (faster transition)
	var intense_transition: float = 1.5
	
	crossfade_tween.tween_property(active_player, "volume_db", -80.0, intense_transition)
	crossfade_tween.tween_property(target_player, "volume_db", _get_volume_for_state(MusicState.INTENSE), intense_transition)
	
	await crossfade_tween.finished
	
	active_player.stop()
	active_player = target_player
	active_player.play()


func _play_storm_track() -> void:
	# Storm music - dramatic, building tension
	current_track_duration = 240.0  # 4 minutes
	
	if crossfade_tween:
		crossfade_tween.kill()
	
	var target_player: AudioStreamPlayer = secondary_player if active_player == primary_player else primary_player
	
	# In production: target_player.stream = load("res://audio/music/storm.ogg")
	
	crossfade_tween = create_tween()
	crossfade_tween.set_parallel(true)
	
	# Slower crossfade for storm (builds tension)
	var storm_transition: float = transition_duration * 1.5
	
	crossfade_tween.tween_property(active_player, "volume_db", -80.0, storm_transition)
	crossfade_tween.tween_property(target_player, "volume_db", _get_volume_for_state(MusicState.STORM), storm_transition)
	
	await crossfade_tween.finished
	
	active_player.stop()
	active_player = target_player
	active_player.play()
	
	# Start storm intensity modulation
	_start_storm_modulation()


func _fade_to_silence() -> void:
	if crossfade_tween:
		crossfade_tween.kill()
	
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(active_player, "volume_db", -80.0, transition_duration)
	
	await crossfade_tween.finished
	active_player.stop()


func _start_storm_modulation() -> void:
	# Modulate storm intensity over time
	var tween: Tween = create_tween()
	tween.set_loops()
	
	# Oscillate storm intensity
	tween.tween_property(self, "storm_intensity", 1.0, 15.0)
	tween.tween_property(self, "storm_intensity", 0.3, 15.0)
	
	# Update volume based on intensity
	tween.set_parallel(true)
	tween.tween_method(_on_storm_intensity_changed, 0.0, 1.0, 1.0)


func _on_storm_intensity_changed(value: float) -> void:
	storm_intensity = value
	# Modulate volume slightly with storm intensity
	var base_vol: float = _get_volume_for_state(MusicState.STORM)
	var modulated_vol: float = base_vol + (value * 3.0 - 1.5)  # ±1.5dB
	active_player.volume_db = modulated_vol


func _get_volume_for_state(state: MusicState) -> float:
	match state:
		MusicState.CALM:
			return linear_to_db(music_volume * 0.8)
		MusicState.INTENSE:
			return linear_to_db(music_volume)
		MusicState.STORM:
			return linear_to_db(music_volume * 0.9)
		MusicState.SILENCE:
			return -80.0
	return -80.0


func _update_bus_volume() -> void:
	if music_bus_idx >= 0:
		AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(music_volume * master_volume))


# Public API

func set_state(new_state: MusicState) -> void:
	if is_transitioning:
		return
	_play_track(new_state)


func play_calm() -> void:
	set_state(MusicState.CALM)


func play_intense() -> void:
	set_state(MusicState.INTENSE)


func play_storm() -> void:
	set_state(MusicState.STORM)


func fade_out(duration: float = 2.0) -> void:
	is_transitioning = true
	if crossfade_tween:
		crossfade_tween.kill()
	
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(active_player, "volume_db", -80.0, duration)
	
	await crossfade_tween.finished
	active_player.stop()
	is_transitioning = false


func fade_in(duration: float = 2.0) -> void:
	is_transitioning = true
	
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(active_player, "volume_db", _get_volume_for_state(current_state), duration)
	
	await crossfade_tween.finished
	is_transitioning = false


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_update_bus_volume()


func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_update_bus_volume()


func get_current_state() -> MusicState:
	return current_state


func is_playing() -> bool:
	return active_player.playing


func stop() -> void:
	active_player.stop()


func play() -> void:
	if not active_player.playing:
		active_player.play()
