## seleccion_instrumento.gd
## Pantalla "elige instrumento" de la canción seleccionada. De momento solo hay un
## jugador: la tarjeta del jugador sube desde abajo con la lista de instrumentos
## y su dificultad. Al confirmar se carga el mapa de notas de ese instrumento.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const BACKDROP = preload("res://scripts/widgets/rb_backdrop.gd")
const MENU_LIST = preload("res://scripts/widgets/rb_menu_list.gd")
const PLAYER_TAB = preload("res://scripts/widgets/player_tab.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")
const ICON = preload("res://scripts/widgets/instrument_icon.gd")
const RATING = preload("res://scripts/widgets/rating_row.gd")
const COVER = preload("res://scripts/widgets/cover_art.gd")

const PANEL_SIZE := Vector2(440.0, 318.0)
const ROW_H := 54.0

var _song: Dictionary = {}
var _panel: Control = null
var _tab: Control = null
var _list: Control = null
var _icons: Array = []
var _dots: Array = []
var _msg: Label = null
var _starting: bool = false


func _ready() -> void:
	_song = SONG_LIB.find_by_name(GameState.selected_song_name)
	if _song.is_empty():
		_song = {
			"name": GameState.selected_song_name,
			"title": GameState.selected_song_title if GameState.selected_song_title != "" else GameState.selected_song_name,
			"artist": GameState.selected_song_artist,
			"wav": GameState.selected_song_path,
			"cover": "",
			"letter": "#",
		}

	var backdrop := BACKDROP.new()
	backdrop.tint = Color(0.30, 0.22, 0.62)
	backdrop.photo_brightness = 0.45
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_header()
	_build_panel()
	_play_intro()


func _build_header() -> void:
	var cover := COVER.new()
	cover.position = Vector2(46.0, 40.0)
	cover.size = Vector2(124.0, 124.0)
	add_child(cover)
	cover.set_song(_song)

	var title := RB.label(str(_song["title"]).to_upper(), 54, Color(0.90, 0.91, 0.94))
	title.position = Vector2(196.0, 32.0)
	add_child(title)
	var artist: String = str(_song.get("artist", ""))
	var artist_lbl: Label = null
	if artist != "":
		artist_lbl = RB.label(artist.to_upper(), 30, Color(0.78, 0.80, 0.88), false, true)
		artist_lbl.position = Vector2(200.0, 100.0)
		add_child(artist_lbl)

	_msg = RB.label(RB.t(
		"Elige el instrumento con el que quieres tocar esta canción.",
		"Choose the instrument you want to play this song with."), 24, Color.WHITE, false)
	_msg.position = Vector2(200.0, 160.0)
	_msg.size = Vector2(760.0, 60.0)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_msg)

	RB.slide_in(cover, Vector2(-50.0, 0.0), 0.0, 0.5)
	RB.slide_in(title, Vector2(-40.0, 0.0), 0.08, 0.5)
	if artist_lbl != null:
		RB.slide_in(artist_lbl, Vector2(-40.0, 0.0), 0.12, 0.5)
	RB.slide_in(_msg, Vector2(0.0, 20.0), 0.25, 0.5)


func _build_panel() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_panel = Control.new()
	_panel.size = PANEL_SIZE
	_panel.position = Vector2((vp.x - PANEL_SIZE.x) * 0.5, vp.y - PANEL_SIZE.y)
	add_child(_panel)

	var body := Panel.new()
	var sb := RB.box(Color(0.13, 0.14, 0.17, 0.97), 0, Color(0.55, 0.57, 0.62), 0)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 3
	sb.border_color = Color(0.82, 0.10, 0.10)
	body.add_theme_stylebox_override("panel", sb)
	body.position = Vector2(0.0, 74.0)
	body.size = Vector2(PANEL_SIZE.x, PANEL_SIZE.y - 74.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(body)

	_tab = PLAYER_TAB.new()
	_panel.add_child(_tab)
	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	_tab.setup(player, GameState.selected_instrument, "↑ ↓", RB.t("ELIGE INSTRUMENTO", "CHOOSE INSTRUMENT"), PANEL_SIZE.x)

	_list = MENU_LIST.new()
	_list.font_size = 28
	_list.row_height = ROW_H
	_list.slab_width = PANEL_SIZE.x - 20.0
	_list.slab_pad = 0.0
	_list.position = Vector2(10.0, 90.0)
	_list.size = Vector2(PANEL_SIZE.x - 20.0, ROW_H * 4.0)
	_panel.add_child(_list)

	var rows: Array = []
	var start_idx: int = 0
	for i in RB.INSTRUMENT_IDS.size():
		var id: String = str(RB.INSTRUMENT_IDS[i])
		rows.append({"id": id, "text": "     " + RB.instrument_name(id)})
		if id == GameState.selected_instrument:
			start_idx = i
	_list.set_items(rows, start_idx, true)
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_back)
	_list.selection_changed.connect(_on_selection_changed)

	_icons.clear()
	_dots.clear()
	for i in RB.INSTRUMENT_IDS.size():
		var id2: String = str(RB.INSTRUMENT_IDS[i])
		var icon := ICON.new()
		icon.instrument = id2
		icon.size = Vector2(40.0, 40.0)
		icon.position = Vector2(24.0, 90.0 + ROW_H * float(i) + (ROW_H - 40.0) * 0.5)
		_panel.add_child(icon)
		_icons.append(icon)
		var dots := RATING.new()
		dots.count = 5
		dots.dots = true
		dots.item_size = 15.0
		dots.position = Vector2(PANEL_SIZE.x - 130.0, 90.0 + ROW_H * float(i) + (ROW_H - 20.0) * 0.5)
		_panel.add_child(dots)
		_dots.append(dots)
		dots.reveal(SONG_LIB.difficulty(_song, id2), 0.08)
	_refresh_icons()


func _play_intro() -> void:
	var target: Vector2 = _panel.position
	_panel.position = target + Vector2(0.0, 340.0)
	var tw := create_tween()
	tw.tween_property(_panel, "position", target, 0.6).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_selection_changed(index: int) -> void:
	_tab.set_instrument(str(RB.INSTRUMENT_IDS[index]))
	_refresh_icons()


func _refresh_icons() -> void:
	for i in _icons.size():
		var ic: Control = _icons[i]
		var active: bool = i == _list.selected
		ic.ring_color = RB.GOLD_BRIGHT if active else Color(0.55, 0.57, 0.63)


func _on_activated(id: String) -> void:
	if _starting:
		return
	var bm: Dictionary = SONG_LIB.load_beatmap(_song, id)
	if bm.is_empty():
		_msg.text = RB.t("No se encontró el mapa de notas de esta canción.", "Could not find the note chart for this song.")
		_msg.modulate = Color(1.0, 0.45, 0.45)
		return
	_starting = true
	_list.keyboard_enabled = false
	GameState.selected_instrument = id
	GameState.current_beatmap = bm
	if GameState.selected_stream == null and str(_song.get("wav", "")) != "":
		GameState.selected_stream = load(str(_song["wav"])) as AudioStream
	GameState.stop_bgm()
	SceneFade.go("res://scenes/gameplay/gameplay.tscn")


func _back() -> void:
	if _starting:
		return
	_starting = true
	_list.keyboard_enabled = false
	SceneFade.go("res://scenes/screens/song_select.tscn")
