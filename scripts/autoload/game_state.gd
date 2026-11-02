## game_state.gd
## Autoload — persiste datos entre escenas, guarda los ajustes del jugador
## (volumen, idioma, daltonismo, teclas) y controla la música de menús.
extends Node

## Controles del jugador 1 (acciones lane_0 … lane_4): una tecla y un botón de control por
## carril. Estos son los valores de fábrica; el jugador los cambia en Opciones → Controles
## y se guardan en settings.cfg.
const DEFAULT_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G]
const DEFAULT_PADS := [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_X, JOY_BUTTON_A, JOY_BUTTON_B]

## Teclas fijas del jugador 2 (acciones p2_lane_*). El jugador 1 no puede usarlas para que
## nunca se pisen en el modo de dos jugadores.
const P2_KEYS := [KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON]  # SEMICOLON es la Ñ en teclado español

## Teclas de símbolo: Godot las nombra con palabra ("Semicolon"), que no cabe en pantalla.
const KEY_SYMBOLS := {
	KEY_SEMICOLON: "Ñ",
	KEY_COMMA: ",",
	KEY_PERIOD: ".",
	KEY_SLASH: "/",
	KEY_APOSTROPHE: "'",
}
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

var last_total_notes_p2: int = 0
var last_instrument_p2: String = "guitarra"

var player1_name: String = "P1"
var player2_name: String = "P2"
var two_player_mode: bool = true
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
	_apply_default_bindings()
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
	var keys: Array[int] = []
	var pads: Array[int] = []
	for i in LANE_COUNT:
		keys.append(int(cfg.get_value("keys", "lane_%d" % i, 0)))
		pads.append(int(cfg.get_value("keys", "pad_%d" % i, -1)))
	# Si lo guardado es inválido (teclas repetidas, o del jugador 2 como en versiones
	# anteriores) se descarta y quedan las de fábrica.
	var keys_ok: bool = _bindings_valid(keys, true)
	var pads_ok: bool = _bindings_valid(pads, false)
	for i in LANE_COUNT:
		set_lane_binding(i, keys[i] if keys_ok else get_lane_key(i), pads[i] if pads_ok else get_lane_pad(i))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("ui", "language", current_language)
	cfg.set_value("ui", "colorblind", colorblind_mode)
	for i in LANE_COUNT:
		cfg.set_value("keys", "lane_%d" % i, get_lane_key(i))
		cfg.set_value("keys", "pad_%d" % i, get_lane_pad(i))
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


## Tecla (código físico) del jugador 1 para el carril `lane`, o 0 si no tiene.
func get_lane_key(lane: int) -> int:
	var events: Array[InputEvent] = InputMap.action_get_events("lane_%d" % lane)
	for ev in events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return int(k.physical_keycode) if int(k.physical_keycode) != 0 else int(k.keycode)
	return 0


## Botón del control del jugador 1 para el carril `lane`, o -1 si no tiene.
func get_lane_pad(lane: int) -> int:
	var events: Array[InputEvent] = InputMap.action_get_events("lane_%d" % lane)
	for ev in events:
		if ev is InputEventJoypadButton:
			return int((ev as InputEventJoypadButton).button_index)
	return -1


func set_lane_key(lane: int, physical_keycode: int) -> void:
	set_lane_binding(lane, physical_keycode, get_lane_pad(lane))


## Deja en el carril `lane` del jugador 1 una tecla (0 = ninguna) y un botón (-1 = ninguno).
func set_lane_binding(lane: int, physical_keycode: int, pad_button: int) -> void:
	var action: String = "lane_%d" % lane
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	if physical_keycode > 0:
		var kev := InputEventKey.new()
		kev.physical_keycode = physical_keycode as Key
		InputMap.action_add_event(action, kev)
	if pad_button >= 0:
		var jev := InputEventJoypadButton.new()
		jev.button_index = pad_button as JoyButton
		InputMap.action_add_event(action, jev)


## Controles de fábrica del jugador 1 y teclas fijas del jugador 2. Así no dependen de lo
## que haya en Proyecto → Configuración → Mapa de entradas.
func _apply_default_bindings() -> void:
	for i in LANE_COUNT:
		set_lane_binding(i, int(DEFAULT_KEYS[i]), int(DEFAULT_PADS[i]))
	for i in P2_KEYS.size():
		var action: String = "p2_lane_%d" % i
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = int(P2_KEYS[i]) as Key
		InputMap.action_add_event(action, ev)


## Una lista guardada vale si trae los 5 carriles, sin repetidos y (teclas) sin usar las del jugador 2.
func _bindings_valid(values: Array[int], are_keys: bool) -> bool:
	var seen: Array[int] = []
	for v in values:
		if (are_keys and v <= 0) or (not are_keys and v < 0):
			return false
		if v in seen:
			return false
		if are_keys and is_p2_key(v):
			return false
		seen.append(v)
	return true


func is_p2_key(code: int) -> bool:
	return code in P2_KEYS


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


# ── Nombres para mostrar ─────────────────────────────────────────────────────

## Nombre corto de una tecla (código físico), como se ve en el teclado del jugador.
func key_name(code: int) -> String:
	if code <= 0:
		return "?"
	var shown: int = code
	if DisplayServer.get_name() != "headless":
		var mapped: int = int(DisplayServer.keyboard_get_keycode_from_physical(code as Key))
		if mapped != 0:
			shown = mapped
	if KEY_SYMBOLS.has(shown):
		return str(KEY_SYMBOLS[shown])
	return OS.get_keycode_string(shown as Key)


## Nombre corto de un botón de control (-1 = sin botón).
func pad_name(button: int) -> String:
	if button < 0:
		return "—"
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_LEFT:
			return "←"
		JOY_BUTTON_DPAD_RIGHT:
			return "→"
		JOY_BUTTON_DPAD_UP:
			return "↑"
		JOY_BUTTON_DPAD_DOWN:
			return "↓"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_START:
			return "START"
		JOY_BUTTON_BACK:
			return "BACK"
	return "BTN %d" % button
