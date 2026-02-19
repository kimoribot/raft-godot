## Weather System
## Dynamic weather with clear, rain, and storm states

class_name WeatherSystem
extends Node

## Weather states
enum WeatherState {
	CLEAR,
	RAIN,
	STORM,
	FOG
}

## Current weather state
var current_state: WeatherState = WeatherState.CLEAR
var previous_state: WeatherState = WeatherState.CLEAR

## Weather parameters
var transition_duration: float = 5.0
var transition_progress: float = 1.0

## Timing
var state_timer: float = 0.0
var min_state_duration: float = 60.0
var max_state_duration: float = 180.0
var time_until_change: float = 0.0

## Weather parameters (0.0 - 1.0)
var rain_intensity: float = 0.0
var wind_strength: float = 0.0
var fog_density: float = 0.0
var wave_intensity: float = 0.0

## Target values for transitions
var target_rain: float = 0.0
var target_wind: float = 0.0
var target_fog: float = 0.0
var target_wave: float = 0.0

## Audio
var audio_rain: AudioStreamPlayer
var audio_wind: AudioStreamPlayer
var audio_thunder: AudioStreamPlayer

## Particle systems (references)
var rain_particles: GPUParticles3D
var wave_mesh: MeshInstance3D
var fog_volume: WorldEnvironment

## Storm tracking
var storm_intensity: float = 0.0
var lightning_timer: float = 0.0
var lightning_enabled: bool = true


func _ready():
	_initialize_weather()
	_initialize_audio()
	_set_state(WeatherState.CLEAR)


func _initialize_weather():
	# Set initial time until weather change
	_set_next_weather_time()


func _initialize_audio():
	# Create audio players
	audio_rain = AudioStreamPlayer.new()
	audio_rain.bus = "Weather"
	audio_rain.volume_db = -80.0
	add_child(audio_rain)
	
	audio_wind = AudioStreamPlayer.new()
	audio_wind.bus = "Weather"
	audio_wind.volume_db = -80.0
	add_child(audio_wind)
	
	audio_thunder = AudioStreamPlayer.new()
	audio_thunder.bus = "Weather"
	audio_thunder.volume_db = -80.0
	add_child(audio_thunder)


func _process(delta):
	# Update state timer
	state_timer += delta
	if state_timer >= time_until_change:
		_change_weather()
	
	# Update transition
	if transition_progress < 1.0:
		transition_progress = min(transition_progress + delta / transition_duration, 1.0)
		_update_weather_transition()
	
	# Update storm effects
	if current_state == WeatherState.STORM:
		_update_storm(delta)
	
	# Apply weather effects to environment
	_apply_weather_effects(delta)


## Set weather state
func _set_state(new_state: WeatherState):
	previous_state = current_state
	current_state = new_state
	transition_progress = 0.0
	state_timer = 0.0
	_set_next_weather_time()
	
	# Set target parameters based on state
	match new_state:
		WeatherState.CLEAR:
			target_rain = 0.0
			target_wind = 0.1
			target_fog = 0.0
			target_wave = 0.1
			transition_duration = 5.0
		
		WeatherState.RAIN:
			target_rain = 0.5
			target_wind = 0.3
			target_fog = 0.2
			target_wave = 0.3
			transition_duration = 3.0
		
		WeatherState.STORM:
			target_rain = 1.0
			target_wind = 1.0
			target_fog = 0.5
			target_wave = 1.0
			transition_duration = 2.0
		
		WeatherState.FOG:
			target_rain = 0.1
			target_wind = 0.05
			target_fog = 0.8
			target_wave = 0.2
			transition_duration = 8.0
	
	# Trigger audio changes
	_update_audio_volume()


## Change to next weather state
func _change_weather():
	var states = WeatherState.keys()
	var new_state
	
	# Weighted random for weather progression
	match current_state:
		WeatherState.CLEAR:
			# Most likely to stay clear or go to rain
			new_state = _weighted_pick([
				WeatherState.CLEAR,
				WeatherState.RAIN,
				WeatherState.FOG
			], [0.5, 0.4, 0.1])
		
		WeatherState.RAIN:
			# Can go to clear, storm, or stay raining
			new_state = _weighted_pick([
				WeatherState.CLEAR,
				WeatherState.RAIN,
				WeatherState.STORM
			], [0.3, 0.5, 0.2])
		
		WeatherState.STORM:
			# Usually calms to rain or clear
			new_state = _weighted_pick([
				WeatherState.CLEAR,
				WeatherState.RAIN,
				WeatherState.STORM
			], [0.2, 0.6, 0.2])
		
		WeatherState.FOG:
			# Usually lifts to clear
			new_state = _weighted_pick([
				WeatherState.CLEAR,
				WeatherState.RAIN,
				WeatherState.FOG
			], [0.6, 0.2, 0.2])
	
	_set_state(new_state)


func _set_next_weather_time():
	time_until_change = randf_range(min_state_duration, max_state_duration)


## Update weather transition interpolation
func _update_weather_transition():
	var t = _ease_in_out_cubic(transition_progress)
	
	rain_intensity = lerp(_get_state_rain(previous_state), target_rain, t)
	wind_strength = lerp(_get_state_wind(previous_state), target_wind, t)
	fog_density = lerp(_get_state_fog(previous_state), target_fog, t)
	wave_intensity = lerp(_get_state_wave(previous_state), target_wave, t)


## Get base values for states
func _get_state_rain(state: WeatherState) -> float:
	match state:
		WeatherState.CLEAR: return 0.0
		WeatherState.RAIN: return 0.5
		WeatherState.STORM: return 1.0
		WeatherState.FOG: return 0.1
	return 0.0


func _get_state_wind(state: WeatherState) -> float:
	match state:
		WeatherState.CLEAR: return 0.1
		WeatherState.RAIN: return 0.3
		WeatherState.STORM: return 1.0
		WeatherState.FOG: return 0.05
	return 0.1


func _get_state_fog(state: WeatherState) -> float:
	match state:
		WeatherState.CLEAR: return 0.0
		WeatherState.RAIN: return 0.2
		WeatherState.STORM: return 0.5
		WeatherState.FOG: return 0.8
	return 0.0


func _get_state_wave(state: WeatherState) -> float:
	match state:
		WeatherState.CLEAR: return 0.1
		WeatherState.RAIN: return 0.3
		WeatherState.STORM: return 1.0
		WeatherState.FOG: return 0.2
	return 0.1


## Update storm-specific effects
func _update_storm(delta: float):
	storm_intensity = (rain_intensity + wind_strength + wave_intensity) / 3.0
	
	# Lightning
	if lightning_enabled:
	 += delta
		lightning_timer	if lightning_timer >= randf_range(3.0, 10.0) / storm_intensity:
			_trigger_lightning()
			lightning_timer = 0.0


## Trigger lightning effect
func _trigger_lightning():
	# Flash effect
	_create_lightning_flash()
	
	# Thunder sound
	_play_thunder()
	
	# Notify nearby players
	emit_signal("lightning_strike", _get_lightning_position())


## Create visual lightning flash
func _create_lightning_flash():
	# Create a temporary light or flash effect
	var flash = DirectionalLight3D.new()
	flash.light_energy = 5.0
	flash.light_color = Color.WHITE
	flash.rotation_degrees = Vector3(-90, 0, 0)
	add_child(flash)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)


## Get random lightning position
func _get_lightning_position() -> Vector3:
	var angle = randf() * TAU
	var dist = randf_range(50, 200)
	return Vector3(cos(angle) * dist, 50, sin(angle) * dist)


## Play thunder sound
func _play_thunder():
	if audio_thunder.playing:
		return
	
	# Random pitch for variety
	audio_thunder.pitch_scale = randf_range(0.8, 1.2)
	audio_thunder.volume_db = -20.0 + (storm_intensity * 10.0)
	audio_thunder.play()


## Apply weather effects to environment
func _apply_weather_effects(delta: float):
	# Update environment fog
	var env = get_tree().get_first_node_in_group("world_environment") as WorldEnvironment
	if env:
		_apply_fog_to_environment(env)
	
	# Update wave mesh if exists
	if wave_mesh:
		_apply_waves_to_mesh(delta)
	
	# Update rain particles
	if rain_particles:
		_apply_rain_particles()


## Apply fog to environment
func _apply_fog_to_environment(env: WorldEnvironment):
	var environment = env.environment
	if environment:
		environment.fog_light_color = _get_fog_color()
		environment.fog_density = 0.001 + (fog_density * 0.01)
		environment.fog_sky_affect = fog_density


## Get fog color based on weather
func _get_fog_color() -> Color:
	match current_state:
		WeatherState.CLEAR:
			return Color(0.7, 0.8, 0.9)
		WeatherState.RAIN:
			return Color(0.5, 0.55, 0.6)
		WeatherState.STORM:
			return Color(0.3, 0.35, 0.4)
		WeatherState.FOG:
			return Color(0.85, 0.88, 0.9)
		_:
			return Color.WHITE


## Apply waves to ocean mesh
func _apply_waves_to_mesh(delta: float):
	# Wave animation parameters
	var time = Time.get_ticks_msec() / 1000.0
	var wave_height = wave_intensity * 2.0
	var wave_speed = 1.0 + wind_strength * 2.0
	var wave_frequency = 0.5
	
	# Update shader parameters if using custom shader
	if wave_mesh and wave_mesh.mesh:
		var material = wave_mesh.get_surface_override_material(0)
		if material:
			material.set_shader_parameter("wave_height", wave_height)
			material.set_shader_parameter("wave_speed", wave_speed)
			material.set_shader_parameter("wave_frequency", wave_frequency)


## Apply rain particles
func _apply_rain_particles():
	if rain_particles:
		rain_particles.emitting = rain_intensity > 0.1
		rain_particles.amount_ratio = rain_intensity
		
		# Adjust particle speed based on wind
		if rain_particles.process_material:
			var mat = rain_particles.process_material as ParticleProcessMaterial
			mat.direction = Vector3(-wind_strength, -1, 0).normalized()
			mat.initial_velocity_min = 20.0 + wind_strength * 20.0
			mat.initial_velocity_max = 30.0 + wind_strength * 30.0


## Update audio volumes
func _update_audio_volume():
	# Rain volume
	if audio_rain:
		audio_rain.volume_db = -80.0 + (rain_intensity * 60.0)
	
	# Wind volume
	if audio_wind:
		audio_wind.volume_db = -80.0 + (wind_strength * 60.0)


## Ease in-out cubic
func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


## Weighted pick
func _weighted_pick(options: Array, weights: Array) -> var:
	var total = 0.0
	for w in weights:
		total += w
	
	var roll = randf() * total
	var current = 0.0
	
	for i in range(options.size()):
		current += weights[i]
		if roll <= current:
			return options[i]
	
	return options.back()


## Force weather to specific state
func force_weather(state_name: String):
	var state = WeatherState.get(state_name.to_upper(), -1)
	if state >= 0:
		_set_state(state)


## Get current weather info
func get_weather_info() -> Dictionary:
	return {
		"state": WeatherState.keys()[current_state],
		"rain_intensity": rain_intensity,
		"wind_strength": wind_strength,
		"fog_density": fog_density,
		"wave_intensity": wave_intensity,
		"storm_intensity": storm_intensity,
		"time_until_change": time_until_change - state_timer,
		"is_transitioning": transition_progress < 1.0
	}


## Check if it's safe to sail
func is_safe_to_sail() -> bool:
	return current_state != WeatherState.STORM and wave_intensity < 0.7


## Get visibility range
func get_visibility_range() -> float:
	var base_visibility = 500.0
	var fog_penalty = fog_density * 400.0
	var storm_penalty = (1.0 - rain_intensity) * 100.0 if current_state == WeatherState.STORM else 0.0
	return max(50.0, base_visibility - fog_penalty - storm_penalty)


## Get wave height multiplier
func get_wave_multiplier() -> float:
	return 0.5 + wave_intensity * 1.5


## Get wind direction and strength
func get_wind_vector() -> Vector2:
	var angle = randf() * TAU  # Slightly variable wind direction
	var strength = wind_strength
	return Vector2(cos(angle), sin(angle)) * strength


## Set audio streams (called from external setup)
func set_audio_streams(rain_stream: AudioStream, wind_stream: AudioStream, thunder_stream: AudioStream):
	if audio_rain and rain_stream:
		audio_rain.stream = rain_stream
		audio_rain.play()
	
	if audio_wind and wind_stream:
		audio_wind.stream = wind_stream
		audio_wind.play()
	
	if audio_thunder and thunder_stream:
		audio_thunder.stream = thunder_stream


## Set particle system reference
func set_rain_particles(particles: GPUParticles3D):
	rain_particles = particles


## Set wave mesh reference
func set_wave_mesh(mesh: MeshInstance3D):
	wave_mesh = mesh


## Connect to signal for lightning strikes
signal lightning_strike(position: Vector3)


## Serialize weather state
func get_weather_data() -> Dictionary:
	return {
		"current_state": current_state,
		"previous_state": previous_state,
		"state_timer": state_timer,
		"time_until_change": time_until_change,
		"transition_progress": transition_progress,
		"rain_intensity": rain_intensity,
		"wind_strength": wind_strength,
		"fog_density": fog_density,
		"wave_intensity": wave_intensity,
		"storm_intensity": storm_intensity
	}


## Deserialize and restore weather state
func restore_weather_data(data: Dictionary):
	if data.has("current_state"):
		current_state = data["current_state"]
	if data.has("state_timer"):
		state_timer = data["state_timer"]
	if data.has("time_until_change"):
		time_until_change = data["time_until_change"]
	
	# Apply restored values
	rain_intensity = data.get("rain_intensity", 0.0)
	wind_strength = data.get("wind_strength", 0.1)
	fog_density = data.get("fog_density", 0.0)
	wave_intensity = data.get("wave_intensity", 0.1)
