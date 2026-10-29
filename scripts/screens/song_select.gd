## song_select.gd
## Biblioteca musical (escena song_select.tscn): lista alfabética seccionada por
## letra, portada y dificultad por instrumento a la derecha, y preescucha (mitad
## de la canción, volumen bajo) de la canción resaltada. Las canciones se leen de
## res://songs/ (ver song_library.gd). La interfaz fija vive en la escena; aquí
## solo se crean las filas de canciones y se maneja la selección.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")
const ROW_SCENE := preload("res://scenes/widgets/song_row.tscn")
const HEADER_SCENE := preload("res://scenes/widgets/song_header.tscn")

const LIST_SIZE := Vector2(800.0, 404.0)
const HEADER_H := 46.0
const SONG_H := 42.0
const ROW_GAP := 2.0
const PREVIEW_DB := -9.0

var _songs: Array = []
var _entries: Array = []
var _selected: int = 0
var _content_h: float = 0.0
var _best_cache: Dictionary = {}

var _scroll_tween: Tween = null
var _cursor_tween: Tween = null

var _inst_dots: Array = []
var _preview_tween: Tween = null
var _preview_path: String = ""
var _loading_path: String = ""
var _stream_cache: Dictionary = {}
var _starting: bool = false

# Nodos de la escena song_select.tscn
@onready var _title: Label = %Title
@onready var _band_box: Control = %BandBox
@onready var _player_name: Label = %PlayerName
@onready var _sub_label: Label = %SubLabel
@onready var _stars_total_label: Label = %StarsTotal
@onready var _right_panel: Control = %RightPanel
@onready var _cover: Control = %Cover
@onready var _best_label: Label = %BestLabel
@onready var _best_stars: Control = %BestStars
@onready var _holder: Control = %Holder
@onready var _rows_root: Control = %RowsRoot
@onready var _cursor: Control = %Cursor
@onready var _hint_bar: Control = %HintBar
@onready var _tab: Control = %PlayerTab
@onready var _empty_box: Control = %EmptyBox
@onready var _preview_player: AudioStreamPlayer = %PreviewPlayer
@onready var _preview_timer: Timer = %PreviewTimer


func _ready() -> void:
	GameState.play_menu_music()
	RB.localize(self)
	_inst_dots = [%Dots0, %Dots1, %Dots2, %Dots3]

	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	_player_name.text = player
	_tab.setup(player, GameState.selected_instrument)

	_holder.gui_input.connect(_on_holder_input)
	_preview_player.finished.connect(_on_preview_finished)
	_preview_timer.timeout.connect(_start_preview)

	_songs = SONG_LIB.scan(true)
	if _songs.is_empty():
		_show_empty()
		return
	_build_list()
	var start: int = 0
	for i in _songs.size():
		if str((_songs[i] as Dictionary)["name"]) == GameState.last_song_name:
			start = i
	_select(start, false)
	_play_intro()
	set_process(false)


# ── Filas de la lista ────────────────────────────────────────────────────────

func _build_list() -> void:
	var counts: Dictionary = {}
	for s in _songs:
		var l: String = str((s as Dictionary)["letter"])
		counts[l] = int(counts.get(l, 0)) + 1

	var y: float = 0.0
	var current: String = ""
	for i in _songs.size():
		var song: Dictionary = _songs[i]
		var letter: String = str(song["letter"])
		if letter != current:
			current = letter
			_add_header(letter, int(counts[letter]), y)
			_entries.append({"type": "header", "y": y, "h": HEADER_H, "song_index": -1, "letter": letter})
			y += HEADER_H + ROW_GAP
		_add_song_row(i, y)
		_entries.append({"type": "song", "y": y, "h": SONG_H, "song_index": i, "letter": letter})
		y += SONG_H + ROW_GAP
	_content_h = y

	_sub_label.text = RB.t("MOSTRANDO %d DE %d CANCIONES, ORDENADAS POR NOMBRE", "VIEWING %d OF %d SONGS, SORTED BY SONG NAME") % [_songs.size(), _songs.size()]
	_stars_total_label.text = str(SONG_LIB.total_stars())


func _song_stars(song: Dictionary) -> int:
	var key: String = str(song["name"])
	if not _best_cache.has(key):
		_best_cache[key] = SONG_LIB.best_stars(key)
	return int(_best_cache[key])


func _add_header(letter: String, count: int, y: float) -> void:
	var earned: int = 0
	for s in _songs:
		var song: Dictionary = s
		if str(song["letter"]) == letter:
			earned += _song_stars(song)
	var row: Control = HEADER_SCENE.instantiate()
	row.position = Vector2(0.0, y)
	_rows_root.add_child(row)
	row.setup(letter, count, earned)


func _add_song_row(index: int, y: float) -> void:
	var song: Dictionary = _songs[index]
	var row: Control = ROW_SCENE.instantiate()
	row.position = Vector2(0.0, y)
	_rows_root.add_child(row)
	row.setup(song, _song_stars(song))
	row.pressed.connect(_on_row_pressed.bind(index))


# ── Selección y desplazamiento ───────────────────────────────────────────────

func _entry_for_song(song_index: int) -> Dictionary:
	for e in _entries:
		var entry: Dictionary = e
		if int(entry["song_index"]) == song_index:
			return entry
	return {}


func _select(index: int, animate: bool = true) -> void:
	_selected = clampi(index, 0, _songs.size() - 1)
	var entry: Dictionary = _entry_for_song(_selected)
	var target_y: float = float(entry["y"])
	if _cursor_tween != null and _cursor_tween.is_valid():
		_cursor_tween.kill()
	if animate:
		_cursor_tween = create_tween()
		_cursor_tween.tween_property(_cursor, "position:y", target_y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_cursor.position.y = target_y
	_scroll_to(target_y, animate)
	_update_info_panel()
	_schedule_preview()


func _scroll_to(song_y: float, animate: bool) -> void:
	var focus_y: float = song_y
	# Si es la primera canción de su letra, deja visible también el encabezado.
	if _selected == 0 or str((_songs[_selected] as Dictionary)["letter"]) != str((_songs[_selected - 1] as Dictionary)["letter"]):
		focus_y = song_y - HEADER_H - ROW_GAP
	var max_off: float = maxf(0.0, _content_h - LIST_SIZE.y)
	var wanted: float = clampf(focus_y - LIST_SIZE.y * 0.30, 0.0, max_off)
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	if animate:
		_scroll_tween = create_tween()
		_scroll_tween.tween_property(_rows_root, "position:y", -wanted, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_rows_root.position.y = -wanted


func _move(dir: int) -> void:
	var next: int = clampi(_selected + dir, 0, _songs.size() - 1)
	if next != _selected:
		_select(next)


func _jump_letter(dir: int) -> void:
	var cur_letter: String = str((_songs[_selected] as Dictionary)["letter"])
	if dir > 0:
		for i in range(_selected + 1, _songs.size()):
			if str((_songs[i] as Dictionary)["letter"]) != cur_letter:
				_select(i)
				return
	else:
		var i: int = _selected - 1
		while i >= 0 and str((_songs[i] as Dictionary)["letter"]) == cur_letter:
			i -= 1
		if i >= 0:
			var target_letter: String = str((_songs[i] as Dictionary)["letter"])
			while i > 0 and str((_songs[i - 1] as Dictionary)["letter"]) == target_letter:
				i -= 1
			_select(i)


func _update_info_panel() -> void:
	var song: Dictionary = _songs[_selected]
	_cover.set_song(song)
	var rec: Dictionary = SONG_LIB.best_record(str(song["name"]))
	if rec.is_empty():
		_best_label.text = RB.t("SIN PUNTAJE", "NO SCORE")
		_best_stars.value = 0
	else:
		_best_label.text = RB.fmt_int(int(rec.get("score", 0)))
		_best_stars.reveal(RB.stars_for(float(rec.get("accuracy", 0.0))), 0.1)
	for i in RB.INSTRUMENT_IDS.size():
		var dots: Control = _inst_dots[i]
		dots.reveal(SONG_LIB.difficulty(song, str(RB.INSTRUMENT_IDS[i])), 0.07)


func _on_row_pressed(double_click: bool, index: int) -> void:
	if index == _selected and double_click:
		_play()
	else:
		_select(index)


func _on_holder_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move(1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move(-1)


# ── Preescucha ───────────────────────────────────────────────────────────────

func _schedule_preview() -> void:
	_stop_preview_immediately()
	_preview_timer.start()


func _stop_preview_immediately() -> void:
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_player.stop()


func _start_preview() -> void:
	if _songs.is_empty():
		return
	var song: Dictionary = _songs[_selected]
	_preview_path = str(song["wav"])
	if _stream_cache.has(_preview_path):
		_play_preview(_stream_cache[_preview_path] as AudioStream)
		return
	if _loading_path == "":
		_loading_path = _preview_path
		ResourceLoader.load_threaded_request(_loading_path)
	set_process(true)


func _process(_delta: float) -> void:
	if _loading_path == "":
		set_process(false)
		return
	var status: int = ResourceLoader.load_threaded_get_status(_loading_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var res: AudioStream = ResourceLoader.load_threaded_get(_loading_path) as AudioStream
		if res != null:
			_stream_cache[_loading_path] = res
	_loading_path = ""
	# Si mientras cargaba se eligió otra canción, cargarla ahora.
	if _preview_path != "" and not _stream_cache.has(_preview_path):
		_loading_path = _preview_path
		ResourceLoader.load_threaded_request(_loading_path)
	elif _preview_path != "" and not _preview_player.playing and not _starting:
		_play_preview(_stream_cache[_preview_path] as AudioStream)


func _play_preview(stream: AudioStream) -> void:
	if stream == null or _starting:
		return
	GameState.fade_bgm(-60.0, 0.5)
	_preview_player.stream = stream
	_preview_player.volume_db = -45.0
	_preview_player.play(stream.get_length() * 0.5)
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_tween = create_tween()
	_preview_tween.tween_property(_preview_player, "volume_db", PREVIEW_DB, 0.9)


func _on_preview_finished() -> void:
	if _starting or _preview_player.stream == null:
		return
	_preview_player.play(_preview_player.stream.get_length() * 0.5)


# ── Acciones ─────────────────────────────────────────────────────────────────

func _play() -> void:
	if _starting or _songs.is_empty():
		return
	var song: Dictionary = _songs[_selected]
	var path: String = str(song["wav"])
	var stream: AudioStream = _stream_cache.get(path) as AudioStream
	if stream == null:
		stream = load(path) as AudioStream
	if stream == null:
		_sub_label.text = RB.t("ERROR: no se pudo cargar el audio.", "ERROR: could not load the audio.")
		return
	_starting = true
	GameState.selected_stream = stream
	GameState.selected_song_name = str(song["name"])
	GameState.selected_song_title = str(song["title"])
	GameState.selected_song_artist = str(song["artist"])
	GameState.selected_song_path = path
	GameState.last_song_name = str(song["name"])
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	create_tween().tween_property(_preview_player, "volume_db", -60.0, 0.3)
	_cursor.modulate = Color(1.8, 1.8, 1.3, 1.0)
	create_tween().tween_property(_cursor, "modulate", Color.WHITE, 0.3)
	SceneFade.go("res://scenes/screens/seleccion_instrumento.tscn")


func _back() -> void:
	if _starting:
		return
	_starting = true
	SceneFade.go("res://scenes/screens/main_menu.tscn")


func _show_empty() -> void:
	_empty_box.visible = true
	_sub_label.text = ""


func _play_intro() -> void:
	RB.slide_in(_title, Vector2(-60.0, 0.0), 0.0, 0.5)
	RB.slide_in(_band_box, Vector2(60.0, 0.0), 0.1, 0.5)
	RB.slide_in(_holder, Vector2(-40.0, 0.0), 0.15, 0.55)
	RB.slide_in(_right_panel, Vector2(60.0, 0.0), 0.2, 0.55)
	RB.slide_in(_hint_bar, Vector2(0.0, 40.0), 0.3, 0.5)
	RB.slide_in(_tab, Vector2(0.0, 90.0), 0.35, 0.55)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
		return
	if _starting or _songs.is_empty():
		return
	if event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_page_down"):
		_jump_letter(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_page_up"):
		_jump_letter(-1)
	elif event.is_action_pressed("ui_accept"):
		_play()
	else:
		return
	get_viewport().set_input_as_handled()
