## game_state.gd
## Autoload — persiste datos entre escenas, guarda los ajustes del jugador
## (volumen, idioma, daltonismo, teclas) y controla la música de menús.
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const MENU_MUSIC_PATH := "res://assets/audio/menumusic.wav"
const LANE_COUNT := 5

var selected_stream: AudioStream = null
var bgm_player: AudioStreamPlayer = null
var selected_song_name: String = ""
var selected_song_title: String = ""
var selected_song_artist: String = ""
var last_song_name: String = ""
var current_beatmap: Dictionary = {}
var selected_song_path: String = ""

# Resultados de la última partida (para la pantalla de resultados)
var last_score: int = 0
var last_max_combo: int = 0
var last_accuracy: float = 0.0
var last_hit_notes: int = 0
var last_miss_notes: int = 0
var last_total_notes: int = 0
var last_duration: float = 0.0
var last_instrument: String = "guitarra"

var player1_name: String = "P1"
var player2_name: String = "P2"
var two_player_mode: bool = false
var last_score_p2: int = 0
var last_max_combo_p2: int = 0
var last_accuracy_p2: float = 0.0
var last_hit_notes_p2: int = 0

var colorblind_mode: bool = false
var current_language: String = "es"
var selected_instrument: String = "guitarra"
var selected_instrument_p2: String = "guitarra"
var master_volume: float = 0.1

var _bgm_loop: bool = false
var _bgm_tween: Tween = null


func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "GlobalBGM"
	bgm_player.bus = "Master"
	add_child(bgm_player)
	load_settings()
	apply_audio()


# ── Ajustes ──────────────────────────────────────────────────────────────────

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "volume", master_volume)), 0.001, 1.0)
	current_language = str(cfg.get_value("ui", "language", current_language))
	colorblind_mode = bool(cfg.get_value("ui", "colorblind", colorblind_mode))
	for i in LANE_COUNT:
		var code: int = int(cfg.get_value("keys", "lane_%d" % i, 0))
		if code > 0:
			set_lane_key(i, code)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("ui", "language", current_language)
	cfg.set_value("ui", "colorblind", colorblind_mode)
	for i in LANE_COUNT:
		cfg.set_value("keys", "lane_%d" % i, get_lane_key(i))
	cfg.save(SETTINGS_PATH)


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))


## El filtro de daltonismo es otro autoload; se aplica cuando ya existe.
func apply_colorblind() -> void:
	var filter: Node = get_node_or_null("/root/ScreenFilter")
	if filter == null:
		return
	var rect: ColorRect = filter.get_node_or_null("ColorRect") as ColorRect
	if rect != null and rect.material is ShaderMaterial:
		(rect.material as ShaderMaterial).set_shader_parameter("is_active", colorblind_mode)


func apply_settings() -> void:
	apply_audio()
	apply_colorblind()


func get_lane_key(lane: int) -> int:
	var events: Array[InputEvent] = InputMap.action_get_events("lane_%d" % lane)
	for ev in events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return int(k.physical_keycode) if int(k.physical_keycode) != 0 else int(k.keycode)
	return 0


func set_lane_key(lane: int, physical_keycode: int) -> void:
	var action: String = "lane_%d" % lane
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, ev)


# ── Música de menús ──────────────────────────────────────────────────────────

func play_menu_music() -> void:
	if bgm_player == null:
		return
	_bgm_loop = true
	if bgm_player.playing and bgm_player.stream != null and bgm_player.stream.resource_path == MENU_MUSIC_PATH:
		fade_bgm(0.0, 0.6)
		return
	var stream := load(MENU_MUSIC_PATH) as AudioStream
	if stream == null:
		return
	bgm_player.stream = stream
	bgm_player.volume_db = -30.0
	if not bgm_player.finished.is_connected(_on_bgm_finished):
		bgm_player.finished.connect(_on_bgm_finished)
	bgm_player.play()
	fade_bgm(0.0, 1.2)


func _on_bgm_finished() -> void:
	if _bgm_loop and bgm_player != null:
		bgm_player.play()


func fade_bgm(to_db: float, duration: float) -> void:
	if bgm_player == null:
		return
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(bgm_player, "volume_db", to_db, duration)


func stop_bgm() -> void:
	_bgm_loop = false
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if bgm_player != null:
		bgm_player.stop()
