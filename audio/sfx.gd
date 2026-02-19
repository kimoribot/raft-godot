extends Node
## Sound effects system for Raft game.
## Manages all gameplay SFX: footsteps, splashes, hooks, crafting, sharks, UI.

class_name SFXManager

# SFX Categories
enum SFXCategory { FOOTSTEP, SPLASH, HOOK, ITEM, CRAFTING, SHARK, UI }

# Audio stream players pool for overlapping sounds
var player_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 16

# Dedicated players for important sounds (no pooling)
var shark_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer

# 3D audio players for spatial sounds
var splash_3d: AudioStreamPlayer3D
var hook_3d: AudioStreamPlayer3D

# Bus indices
var sfx_bus_idx: int = -1

# Volume settings
var sfx_volume: float = 0.8
var footstep_volume: float = 0.6
var splash_volume: float = 0.7
var hook_volume: float = 0.8
var item_volume: float = 0.7
var crafting_volume: float = 0.6
var shark_volume: float = 1.0
var ui_volume: float = 0.5

# Footstep timing
var footstep_timer: float = 0.0
var footstep_interval: float = 0.4
var is_walking: bool = false

# Random pitch variation
var pitch_variation: float = 0.1


func _ready() -> void:
	_setup_player_pool()
	_setup_dedicated_players()
	_setup_audio_bus()


func _setup_player_pool() -> void:
	for i in pool_size:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFXPool_%d" % i
		player.bus = "SFX"
		player.volume_db = -80.0
		add_child(player)
		player_pool.append(player)


func _setup_dedicated_players() -> void:
	# Shark player (important, needs reliable playback)
	shark_player = AudioStreamPlayer.new()
	shark_player.name = "SharkPlayer"
	shark_player.bus = "SFX"
	add_child(shark_player)
	
	# UI player (needs to be responsive)
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = "SFX"
	add_child(ui_player)
	
	# 3D players for spatial audio
	splash_3d = AudioStreamPlayer3D.new()
	splash_3d.name = "Splash3D"
	splash_3d.bus = "SFX"
	splash_3d.unit_size = 10.0
	splash_3d.max_distance = 50.0
	add_child(splash_3d)
	
	hook_3d = AudioStreamPlayer3D.new()
	hook_3d.name = "Hook3D"
	hook_3d.bus = "SFX"
	hook_3d.unit_size = 8.0
	hook_3d.max_distance = 40.0
	add_child(hook_3d)
	
	# Note: In production, load actual audio streams
	# _load_sfx_streams()


func _setup_audio_bus() -> void:
	sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx == -1:
		sfx_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(sfx_bus_idx)
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		# Connect to Master
		AudioServer.set_bus_send(sfx_bus_idx, AudioServer.get_bus_index("Master"))


func _process(delta: float) -> void:
	# Handle footstep timing
	if is_walking:
		footstep_timer += delta
		if footstep_timer >= footstep_interval:
			footstep_timer = 0.0
			play_footstep()


# ==================== FOOTSTEPS ====================

func play_footstep() -> void:
	_play_pool_sound("footstep", footstep_volume, SFXCategory.FOOTSTEP)


func start_walking() -> void:
	is_walking = true


func stop_walking() -> void:
	is_walking = false
	footstep_timer = 0.0


func set_footstep_interval(interval: float) -> void:
	footstep_interval = clamp(interval, 0.2, 1.0)


# ==================== SPLASH SOUNDS ====================

func play_splash(position: Vector3 = Vector3.ZERO, intensity: float = 0.5) -> void:
	# Use 3D player for spatial positioning
	splash_3d.global_position = position
	splash_3d.volume_db = linear_to_db(splash_volume * intensity)
	splash_3d.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	
	# In production: splash_3d.stream = load("res://audio/sfx/water/splash.ogg")
	splash_3d.play()


func play_small_splash() -> void:
	_play_pool_sound("splash_small", splash_volume * 0.5, SFXCategory.SPLASH)


func play_big_splash() -> void:
	_play_pool_sound("splash_big", splash_volume, SFXCategory.SPLASH)


# ==================== HOOK SOUNDS ====================

func play_hook_throw() -> void:
	hook_3d.pitch_scale = 1.2 + randf_range(-0.1, 0.1)
	hook_3d.volume_db = linear_to_db(hook_volume)
	# In production: hook_3d.stream = load("res://audio/sfx/hook/throw.ogg")
	hook_3d.play()


func play_hook_release() -> void:
	_play_pool_sound("hook_release", hook_volume, SFXCategory.HOOK)


func play_hook_hit() -> void:
	_play_pool_sound("hook_hit", hook_volume * 1.2, SFXCategory.HOOK)


func play_hook_reel() -> void:
	# Continuous reeling sound
	_play_pool_sound("hook_reel", hook_volume * 0.5, SFXCategory.HOOK)


# ==================== ITEM SOUNDS ====================

func play_item_pickup() -> void:
	_play_pool_sound("item_pickup", item_volume, SFXCategory.ITEM)


func play_item_drop() -> void:
	_play_pool_sound("item_drop", item_volume * 0.7, SFXCategory.ITEM)


func play_item_place() -> void:
	_play_pool_sound("item_place", item_volume, SFXCategory.ITEM)


func play_item_collect() -> void:
	# Satisfying collection sound
	_play_pool_sound("item_collect", item_volume * 1.1, SFXCategory.ITEM)


# ==================== CRAFTING SOUNDS ====================

func play_craft_start() -> void:
	_play_pool_sound("craft_start", crafting_volume, SFXCategory.CRAFTING)


func play_craft_complete() -> void:
	# Satisfying completion sound
	_play_pool_sound("craft_complete", crafting_volume * 1.2, SFXCategory.CRAFTING)


func play_craft_fail() -> void:
	_play_pool_sound("craft_fail", crafting_volume, SFXCategory.CRAFTING)


func play_crafting_tick() -> void:
	# Progress tick sound
	_play_pool_sound("craft_tick", crafting_volume * 0.4, SFXCategory.CRAFTING)


# ==================== SHARK SOUNDS ====================

func play_shark_growl() -> void:
	# Shark growl - uses dedicated player for reliability
	shark_player.volume_db = linear_to_db(shark_volume)
	shark_player.pitch_scale = 1.0 + randf_range(-0.15, 0.15)
	# In production: shark_player.stream = load("res://audio/sfx/shark/growl.ogg")
	shark_player.play()


func play_shark_attack() -> void:
	shark_player.volume_db = linear_to_db(shark_volume * 1.2)
	shark_player.pitch_scale = 1.1 + randf_range(-0.1, 0.1)
	# In production: shark_player.stream = load("res://audio/sfx/shark/attack.ogg")
	shark_player.play()


func play_shark_bite() -> void:
	shark_player.volume_db = linear_to_db(shark_volume * 1.3)
	# In production: shark_player.stream = load("res://audio/sfx/shark/bite.ogg")
	shark_player.play()


func play_shark_warning() -> void:
	# Warning growl before attack
	shark_player.volume_db = linear_to_db(shark_volume * 0.8)
	# In production: shark_player.stream = load("res://audio/sfx/shark/warning.ogg")
	shark_player.play()


# ==================== UI SOUNDS ====================

func play_ui_click() -> void:
	ui_player.volume_db = linear_to_db(ui_volume)
	ui_player.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
	# In production: ui_player.stream = load("res://audio/sfx/ui/click.ogg")
	ui_player.play()


func play_ui_hover() -> void:
	ui_player.volume_db = linear_to_db(ui_volume * 0.3)
	ui_player.pitch_scale = 1.2 + randf_range(-0.1, 0.1)
	# In production: ui_player.stream = load("res://audio/sfx/ui/hover.ogg")
	ui_player.play()


func play_ui_open() -> void:
	ui_player.volume_db = linear_to_db(ui_volume)
	# In production: ui_player.stream = load("res://audio/sfx/ui/open.ogg")
	ui_player.play()


func play_ui_close() -> void:
	ui_player.volume_db = linear_to_db(ui_volume * 0.8)
	# In production: ui_player.stream = load("res://audio/sfx/ui/close.ogg")
	ui_player.play()


func play_ui_error() -> void:
	ui_player.volume_db = linear_to_db(ui_volume * 1.1)
	ui_player.pitch_scale = 0.8
	# In production: ui_player.stream = load("res://audio/sfx/ui/error.ogg")
	ui_player.play()


func play_ui_success() -> void:
	ui_player.volume_db = linear_to_db(ui_volume * 1.0)
	ui_player.pitch_scale = 1.1
	# In production: ui_player.stream = load("res://audio/sfx/ui/success.ogg")
	ui_player.play()


# ==================== HELPER FUNCTIONS ====================

func _play_pool_sound(sound_name: String, volume: float, category: SFXCategory) -> void:
	# Find available player
	var player: AudioStreamPlayer = _get_available_player()
	if player == null:
		return
	
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	
	# In production, load actual sound
	# player.stream = load("res://audio/sfx/%s/%s.ogg" % [category.name.to_lower(), sound_name])
	
	player.play()


func _get_available_player() -> AudioStreamPlayer:
	# Find a player that's not currently playing
	for player in player_pool:
		if not player.playing:
			return player
	
	# All players busy - steal the oldest one
	var oldest_player: AudioStreamPlayer = player_pool[0]
	var oldest_time: float = 0.0
	
	for player in player_pool:
		if player.get_playback_position() > oldest_time:
			oldest_time = player.get_playback_position()
			oldest_player = player
	
	return oldest_player


# ==================== PUBLIC API ====================

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)


func set_category_volume(category: SFXCategory, value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	match category:
		SFXCategory.FOOTSTEP:
			footstep_volume = value
		SFXCategory.SPLASH:
			splash_volume = value
		SFXCategory.HOOK:
			hook_volume = value
		SFXCategory.ITEM:
			item_volume = value
		SFXCategory.CRAFTING:
			crafting_volume = value
		SFXCategory.SHARK:
			shark_volume = value
		SFXCategory.UI:
			ui_volume = value


func stop_all() -> void:
	for player in player_pool:
		player.stop()
	shark_player.stop()
	ui_player.stop()
	splash_3d.stop()
	hook_3d.stop()


func stop_category(category: SFXCategory) -> void:
	# Stop sounds of specific category
	match category:
		SFXCategory.SHARK:
			shark_player.stop()
		SFXCategory.UI:
			ui_player.stop()
		_:
			# Other categories use pool, harder to isolate
			pass
