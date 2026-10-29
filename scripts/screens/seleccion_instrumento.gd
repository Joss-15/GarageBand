## seleccion_instrumento.gd
## Pantalla "elige instrumento" de la canción seleccionada (escena
## seleccion_instrumento.tscn). De momento solo hay un jugador: la tarjeta del
## jugador sube desde abajo con la lista de instrumentos y su dificultad. Al
## confirmar se carga el mapa de notas de ese instrumento.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")

var _song: Dictionary = {}
var _icons: Array = []
var _dots: Array = []
var _starting: bool = false

# Nodos de la escena seleccion_instrumento.tscn
@onready var _cover: Control = %Cover
@onready var _title: Label = %Title
@onready var _artist_lbl: Label = %ArtistLabel
@onready var _msg: Label = %Msg
@onready var _panel: Control = %Panel
@onready var _tab: Control = %PlayerTab
@onready var _list: Control = %List


func _ready() -> void:
	RB.localize(self)
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
	_icons = [%Icon0, %Icon1, %Icon2, %Icon3]
	_dots = [%Dots0, %Dots1, %Dots2, %Dots3]

	_fill_header()
	_fill_panel()
	_play_intro()


func _fill_header() -> void:
	_cover.set_song(_song)
	_title.text = str(_song["title"]).to_upper()
	var artist: String = str(_song.get("artist", ""))
	_artist_lbl.visible = artist != ""
	_artist_lbl.text = artist.to_upper()

	RB.slide_in(_cover, Vector2(-50.0, 0.0), 0.0, 0.5)
	RB.slide_in(_title, Vector2(-40.0, 0.0), 0.08, 0.5)
	if artist != "":
		RB.slide_in(_artist_lbl, Vector2(-40.0, 0.0), 0.12, 0.5)
	RB.slide_in(_msg, Vector2(0.0, 20.0), 0.25, 0.5)


func _fill_panel() -> void:
	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	_tab.setup(player, GameState.selected_instrument)

	var rows: Array = []
	var start_idx: int = 0
	for i in RB.INSTRUMENT_IDS.size():
		var id: String = str(RB.INSTRUMENT_IDS[i])
		rows.append({"id": id, "text": RB.instrument_name(id)})
		if id == GameState.selected_instrument:
			start_idx = i
	_list.set_items(rows, start_idx, true)
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_back)
	_list.selection_changed.connect(_on_selection_changed)

	for i in RB.INSTRUMENT_IDS.size():
		var dots: Control = _dots[i]
		dots.reveal(SONG_LIB.difficulty(_song, str(RB.INSTRUMENT_IDS[i])), 0.08)
	_refresh_icons()


func _play_intro() -> void:
	var target: Vector2 = _panel.position
	_panel.position = target + Vector2(0.0, 340.0)
	var tw := create_tween()
	tw.tween_property(_panel, "position", target, 0.6).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_selection_changed(_index: int) -> void:
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
