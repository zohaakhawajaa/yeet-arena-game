extends Node
## Persistent user settings. Stored in user://settings.cfg (never in the install dir).

const SETTINGS_PATH := "user://settings.cfg"

var master_volume: float = 1.0        ## 0..1
var music_volume: float = 0.7         ## 0..1
var sfx_volume: float = 0.9           ## 0..1
var muted: bool = false
var fullscreen: bool = false
var difficulty: String = "normal"     ## easy | normal | hard
var reduced_effects: bool = false     ## accessibility: fewer particles / less shake
var api_url: String = "http://127.0.0.1:8000"
var display_name: String = "PLAYER"
var volume_tested: bool = false

## Runtime-only: raised when any volume setting changes.
signal volume_changed

func _ready() -> void:
	load_settings()
	var env_url := OS.get_environment("YEET_API_URL")
	if env_url != "":
		api_url = env_url

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cf.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(cf.get_value("audio", "muted", muted))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	reduced_effects = bool(cf.get_value("video", "reduced_effects", reduced_effects))
	difficulty = String(cf.get_value("game", "difficulty", difficulty))
	api_url = String(cf.get_value("network", "api_url", api_url))
	display_name = String(cf.get_value("game", "display_name", display_name))

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "muted", muted)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "reduced_effects", reduced_effects)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("network", "api_url", api_url)
	cf.set_value("game", "display_name", display_name)
	var err := cf.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % err)

func set_master(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	volume_changed.emit()
	save_settings()

func set_music(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	volume_changed.emit()
	save_settings()

func set_sfx(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	volume_changed.emit()
	save_settings()

func set_muted(v: bool) -> void:
	muted = v
	volume_changed.emit()
	save_settings()

func set_fullscreen(v: bool) -> void:
	fullscreen = v
	_apply_window_mode()
	save_settings()

func set_reduced_effects(v: bool) -> void:
	reduced_effects = v
	save_settings()

func set_difficulty(d: String) -> void:
	if d in ["easy", "normal", "hard"]:
		difficulty = d
		save_settings()

func set_api_url(url: String) -> void:
	api_url = url.strip_edges()
	save_settings()

func set_display_name(n: String) -> void:
	display_name = n
	save_settings()

func apply_on_startup() -> void:
	_apply_window_mode()

func _apply_window_mode() -> void:
	var mode := DisplayServer.window_get_mode()
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if mode != want:
		DisplayServer.window_set_mode(want)
