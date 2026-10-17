## song_select.gd
## Lee canciones desde res://songs/ de forma local.
## Cada canción requiere dos archivos con el mismo nombre:
##   - nombre.wav   (audio)
##   - nombre.json  (beatmap)

extends Control

@onready var bgm_player:          AudioStreamPlayer = $BGMPlayer
@onready var song_list:           ItemList          = $CyberPanel/VBox/SongList
@onready var play_button:         Button            = $CyberPanel/VBox/PlayButton
@onready var song_name_label:     Label             = $CyberPanel/VBox/SongNameLabel
@onready var settings_panel:      Panel             = $SettingsPanel
@onready var settings_close:      Button            = $SettingsCerrar
@onready var title:               Label             = $CyberPanel/VBox/SubtitleLabel
@onready var download_music_button: Button          = $CyberPanel/VBox/DownloadButton
@onready var volume_label:        Label             = $SettingsPanel/LabelVolumen
@onready var close_settings:      Button            = $SettingsCerrar
@onready var volume_slider:       HSlider           = $SettingsPanel/HSlider
@onready var two_player_button:   Button            = $CyberPanel/VBox/TwoPlayerButton
@onready var instructions_label:  Label             = $CyberPanel/VBox/InstructionsLabel
@onready var english_switch:      CheckButton       = $SettingsPanel/EnglishSwitch
@onready var tecla_label:         Label             = $SettingsPanel/LabelTeclas
@onready var tecla_one:           Button            = $SettingsPanel/BtnCarril1
@onready var tecla_two:           Button            = $SettingsPanel/BtnCarril2
@onready var tecla_three:         Button            = $SettingsPanel/BtnCarril3
@onready var tecla_four:          Button            = $SettingsPanel/BtnCarril4
@onready var tecla_five:          Button            = $SettingsPanel/BtnCarril5

# Carpeta local donde viven los .wav y .json de las canciones
const SONGS_PATH := "res://songs/"
const DatabaseScript = preload("res://scrpts/database.gd")

# Cada entrada: { "name": String, "wav": String, "json": String }
var song_files:   Array = []
var loaded_songs: int   = 0

var default_volume_level: float = 0.1
var english_mode:         bool  = false

# Para la animación del botón Play
var _play_tween:       Tween = null
var _play_scale_tween: Tween = null


func _ready() -> void:
	play_button.disabled = true
	song_name_label.text = "Cargando canciones..."

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(default_volume_level)
	)
	volume_slider.value = default_volume_level

	song_list.item_selected.connect(_on_song_selected)
	play_button.pressed.connect(_on_play_pressed)

	if download_music_button:
		download_music_button.pressed.connect(_on_download_pressed)
	if two_player_button:
		two_player_button.pressed.connect(_on_two_player_toggled)

	# Restaurar idioma guardado
	english_mode = (GameState.current_language == "en")
	if english_switch != null:
		english_switch.set_block_signals(true)
		english_switch.button_pressed = english_mode
		english_switch.set_block_signals(false)

	_apply_language()
	_update_two_player_button()
	_scan_songs()


# ── ESCANEO LOCAL ─────────────────────────────────────────────────────────────

func _scan_songs() -> void:
	var en := (GameState.current_language == "en")
	song_files.clear()
	song_list.clear()

	var dir := DirAccess.open(SONGS_PATH)
	if dir == null:
		song_name_label.text = "Error: songs/ folder not found." if en \
			else "Error: no se encontró la carpeta songs/."
		return

	# Recopilar todos los .wav que tengan su .json par
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension().to_lower() == "wav":
			var stem      := fname.get_basename()
			var wav_path  := SONGS_PATH + fname
			var json_path := SONGS_PATH + stem + ".json"

			if FileAccess.file_exists(ProjectSettings.globalize_path(json_path)) \
				or ResourceLoader.exists(json_path):
				song_files.append({
					"name": stem,
					"wav":  wav_path,
					"json": json_path,
				})
		fname = dir.get_next()
	dir.list_dir_end()

	# Ordenar alfabéticamente
	song_files.sort_custom(func(a, b): return a["name"] < b["name"])

	if song_files.is_empty():
		song_name_label.text = "No songs found in songs/." if en \
			else "No se encontraron canciones en songs/."
		return

	for song in song_files:
		var display: String = song["name"].replace("_", " ").replace("-", " ").capitalize()
		song_list.add_item(display)

	loaded_songs         = song_files.size()
	song_name_label.text = "%d song(s) found" % loaded_songs if en \
		else "%d cancion(es) encontrada(s)" % loaded_songs


# ── SELECCIÓN ─────────────────────────────────────────────────────────────────

func _on_song_selected(index: int) -> void:
	play_button.disabled = false
	var display: String = song_files[index]["name"].replace("_", " ").replace("-", " ").capitalize()
	song_name_label.text = "♪ " + display
	_animate_active_play_button()


# ── PLAY ──────────────────────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	bgm_player.stop()

	var sel := song_list.get_selected_items()
	if sel.is_empty():
		return

	var en   := (GameState.current_language == "en")
	var song := song_files[sel[0]] as Dictionary

	play_button.disabled = true
	song_name_label.text = "Loading..." if en else "Cargando..."

	# ── 1. Cargar beatmap (JSON local) ────────────────────────────────────────
	var json_global := ProjectSettings.globalize_path(song["json"])
	var file        := FileAccess.open(json_global, FileAccess.READ)
	if file == null:
		file = FileAccess.open(song["json"], FileAccess.READ)

	if file == null:
		song_name_label.text = "Error: beatmap not found." if en \
			else "Error: no se encontró el beatmap."
		play_button.disabled = false
		return

	var json_text := file.get_as_text()
	file.close()

	var beatmap = JSON.parse_string(json_text)
	if beatmap == null or typeof(beatmap) != TYPE_DICTIONARY:
		song_name_label.text = "Error: invalid beatmap JSON." if en \
			else "Error: el JSON del beatmap es inválido."
		play_button.disabled = false
		return

	# ── 2. Cargar audio (WAV local) ───────────────────────────────────────────
	var stream := load(song["wav"]) as AudioStream
	if stream == null:
		song_name_label.text = "Error: could not load audio." if en \
			else "Error: no se pudo cargar el audio."
		play_button.disabled = false
		return

	# ── 3. Guardar en GameState y cambiar escena ──────────────────────────────
	GameState.current_beatmap    = beatmap
	GameState.selected_stream    = stream
	GameState.selected_song_name = song["name"]
	GameState.selected_song_path = song["wav"]

	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


# ── ANIMACIÓN BOTÓN PLAY ──────────────────────────────────────────────────────

func _animate_active_play_button() -> void:
	if _play_tween and _play_tween.is_valid():
		_play_tween.kill()
	if _play_scale_tween and _play_scale_tween.is_valid():
		_play_scale_tween.kill()

	play_button.pivot_offset = play_button.size / 2.0

	_play_tween = create_tween().set_loops()
	_play_tween.tween_property(play_button, "self_modulate", Color(2.0, 2.0, 2.0, 1.0), 0.8)
	_play_tween.tween_property(play_button, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)

	_play_scale_tween = create_tween().set_loops()
	_play_scale_tween.tween_property(play_button, "scale", Vector2(1.008, 1.008), 0.4).set_trans(Tween.TRANS_SINE)
	_play_scale_tween.tween_property(play_button, "scale", Vector2(1.0,   1.0  ), 0.4).set_trans(Tween.TRANS_SINE)


# ── BOTÓN DESCARGA ────────────────────────────────────────────────────────────

func _on_download_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/download_screen.tscn")


# ── 2 JUGADORES ───────────────────────────────────────────────────────────────

func _on_two_player_toggled() -> void:
	GameState.two_player_mode = not GameState.two_player_mode
	_update_two_player_button()


func _update_two_player_button() -> void:
	if two_player_button == null:
		return
	var en := (GameState.current_language == "en")
	if GameState.two_player_mode:
		two_player_button.text     = "👥 2 Players: ON"  if en else "👥 2 Jugadores: ON"
		two_player_button.modulate = Color(0.3, 1.0, 0.3)
	else:
		two_player_button.text     = "👤 2 Players: OFF" if en else "👤 2 Jugadores: OFF"
		two_player_button.modulate = Color(1.0, 1.0, 1.0)


# ── IDIOMA ────────────────────────────────────────────────────────────────────

func _apply_language() -> void:
	var en := (GameState.current_language == "en")

	title.text                  = "Select Song"                         if en else "Seleccionar Cancion"
	play_button.text            = "Play"                                if en else "Jugar"
	download_music_button.text  = "Download Music"                      if en else "Descargar Musica"
	# colorblind_label.text       = "Colorblind Mode"                     if en else "Modo Daltonismo"
	volume_label.text           = "Volume"                              if en else "Volumen"
	close_settings.text         = "Close"                               if en else "Cerrar"
	instructions_label.text     = "Default Controls: D  F  J  K  L" if en \
		else "Teclas Predeterminadas: D  F  J  K  L"
	tecla_label.text            = "Keybinds"                            if en else "Teclas"

	for lane in ["lane_0","lane_1","lane_2","lane_3","lane_4","lane_5"]:
		_actualizar_texto_boton(lane)

	if loaded_songs > 0:
		song_name_label.text = "%d song(s) found" % loaded_songs if en \
			else "%d cancion(es) encontrada(s)" % loaded_songs

	_update_two_player_button()


func _on_button_pressed() -> void:
	GameState.current_language = "en" if GameState.current_language == "es" else "es"
	english_mode = (GameState.current_language == "en")
	_apply_language()


func _on_english_switch_toggled(toggled_on: bool) -> void:
	english_mode               = toggled_on
	GameState.current_language = "en" if toggled_on else "es"
	_apply_language()


# ── SETTINGS ──────────────────────────────────────────────────────────────────

func _on_settings_button_pressed() -> void:
	settings_panel.visible = not settings_panel.visible
	settings_close.visible = not settings_close.visible


func _on_settings_cerrar_pressed() -> void:
	settings_panel.visible = false
	settings_close.visible = false


func _on_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))


func _on_check_button_toggled(toggled_on: bool) -> void:
	GameState.colorblind_mode = toggled_on
	var color_rect = ScreenFilter.get_node("ColorRect")
	color_rect.material.set_shader_parameter("is_active", toggled_on)


# ── REASIGNACIÓN DE TECLAS ────────────────────────────────────────────────────

var accion_a_cambiar:    String       = ""
var todos_los_carriles: Array[String] = ["lane_0","lane_1","lane_2","lane_3","lane_4","lane_5"]


func _on_btn_carril_1_pressed() -> void: _iniciar_reasignacion("lane_0", $SettingsPanel/BtnCarril1)
func _on_btn_carril_2_pressed() -> void: _iniciar_reasignacion("lane_1", $SettingsPanel/BtnCarril2)
func _on_btn_carril_3_pressed() -> void: _iniciar_reasignacion("lane_2", $SettingsPanel/BtnCarril3)
func _on_btn_carril_4_pressed() -> void: _iniciar_reasignacion("lane_3", $SettingsPanel/BtnCarril4)
func _on_btn_carril_5_pressed() -> void: _iniciar_reasignacion("lane_4", $SettingsPanel/BtnCarril5)


func _iniciar_reasignacion(accion: String, btn: Button) -> void:
	accion_a_cambiar = accion
	var en := (GameState.current_language == "en")
	btn.text = "Press a key..." if en else "Presiona una tecla..."


func _input(event: InputEvent) -> void:
	if accion_a_cambiar == "" or not (event is InputEventKey) or not event.pressed:
		return

	# Verificar duplicado
	for carril in todos_los_carriles:
		if carril != accion_a_cambiar and InputMap.action_has_event(carril, event):
			_actualizar_texto_boton(accion_a_cambiar, "¡Tecla ya usada!")
			return

	InputMap.action_erase_events(accion_a_cambiar)
	InputMap.action_add_event(accion_a_cambiar, event)
	_actualizar_texto_boton(accion_a_cambiar)
	accion_a_cambiar = ""


func _actualizar_texto_boton(accion: String, texto_especial: String = "") -> void:
	var en    := (GameState.current_language == "en")
	var btns  := [$SettingsPanel/BtnCarril1, $SettingsPanel/BtnCarril2,
				  $SettingsPanel/BtnCarril3, $SettingsPanel/BtnCarril4,
				  $SettingsPanel/BtnCarril5]
	var lanes := ["lane_0","lane_1","lane_2","lane_3","lane_4"]
	var idx   := lanes.find(accion)
	if idx == -1:
		return
	var btn: Button = btns[idx]

	if texto_especial != "":
		if texto_especial == "Presiona una tecla...":
			btn.text = "Press a key..." if en else "Presiona una tecla..."
		elif texto_especial == "¡Tecla ya usada!":
			btn.text = "Key already used!" if en else "¡Tecla ya usada!"
		else:
			btn.text = texto_especial
		return

	var tecla := _obtener_tecla_actual(accion)
	var num   := str(idx + 1)
	btn.text   = ("Lane %s: %s" % [num, tecla]) if en else ("Carril %s: %s" % [num, tecla])


func _obtener_tecla_actual(accion: String) -> String:
	var eventos := InputMap.action_get_events(accion)
	if eventos.size() > 0 and eventos[0] is InputEventKey:
		return OS.get_keycode_string(eventos[0].physical_keycode)
	return "???"
