## song_select.gd
## Biblioteca musical: lista alfabética seccionada por letra, portada y dificultad
## por instrumento a la derecha, y preescucha (mitad de la canción, volumen bajo)
## de la canción resaltada. Las canciones se leen de res://songs/ (ver song_library.gd).
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const BACKDROP = preload("res://scripts/widgets/rb_backdrop.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")
const PLAYER_TAB = preload("res://scripts/widgets/player_tab.gd")
const ICON = preload("res://scripts/widgets/instrument_icon.gd")
const RATING = preload("res://scripts/widgets/rating_row.gd")
const COVER = preload("res://scripts/widgets/cover_art.gd")

const LIST_POS := Vector2(30.0, 132.0)
const LIST_SIZE := Vector2(800.0, 404.0)
const HEADER_H := 46.0
const SONG_H := 42.0
const ROW_GAP := 2.0
const ROW_W := 790.0
const PREVIEW_DB := -9.0

var _songs: Array = []
var _entries: Array = []
var _selected: int = 0
var _content_h: float = 0.0
var _best_cache: Dictionary = {}

var _holder: Control = null
var _rows_root: Control = null
var _cursor: Control = null
var _scroll_tween: Tween = null
var _cursor_tween: Tween = null

var _sub_label: Label = null
var _stars_total_label: Label = null
var _cover: Control = null
var _best_label: Label = null
var _best_stars: Control = null
var _inst_dots: Array = []
var _hint_bar: Control = null
var _tab: Control = null
var _title: Label = null
var _band_box: Control = null
var _right_panel: Control = null

var _preview_player: AudioStreamPlayer = null
var _preview_timer: Timer = null
var _preview_tween: Tween = null
var _preview_path: String = ""
var _loading_path: String = ""
var _stream_cache: Dictionary = {}
var _starting: bool = false


func _ready() -> void:
	GameState.play_menu_music()
	_songs = SONG_LIB.scan(true)
	_build_static_ui()
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


# ── Construcción ─────────────────────────────────────────────────────────────

func _build_static_ui() -> void:
	var backdrop := BACKDROP.new()
	backdrop.tint = Color(0.22, 0.30, 0.55)
	backdrop.photo_brightness = 0.40
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Velo oscuro para dar contraste a la lista
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.02, 0.42)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_title = RB.label(RB.t("BIBLIOTECA MUSICAL", "MUSIC LIBRARY"), 62, Color(0.88, 0.89, 0.92))
	_title.position = Vector2(42.0, 12.0)
	add_child(_title)

	# Insignia de banda + nombre del jugador
	_band_box = Control.new()
	_band_box.position = Vector2(840.0, 26.0)
	_band_box.size = Vector2(290.0, 56.0)
	add_child(_band_box)
	var badge := Panel.new()
	badge.add_theme_stylebox_override("panel", RB.box(Color(0.05, 0.05, 0.07), 3, Color(0.9, 0.9, 0.95), 2))
	badge.size = Vector2(48.0, 48.0)
	badge.position = Vector2(0.0, 4.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := RB.label("GB", 20, Color.WHITE)
	bl.position = Vector2(8.0, 10.0)
	badge.add_child(bl)
	_band_box.add_child(badge)
	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	var pn := RB.label(player, 34, Color.WHITE)
	pn.position = Vector2(60.0, 6.0)
	_band_box.add_child(pn)

	# Barra de subtítulo gris
	var sub_bar := Panel.new()
	sub_bar.add_theme_stylebox_override("panel", RB.box(Color(0.52, 0.53, 0.56, 0.96), 0))
	sub_bar.position = Vector2(30.0, 90.0)
	sub_bar.size = Vector2(1092.0, 34.0)
	sub_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub_bar)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", RB.box(Color(0.03, 0.03, 0.04), 5))
	pill.position = Vector2(40.0, 94.0)
	pill.size = Vector2(70.0, 26.0)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pl := RB.label("ENTER", 14, Color.WHITE)
	pl.position = Vector2(9.0, 3.0)
	pill.add_child(pl)
	add_child(pill)
	_sub_label = RB.label("", 18, Color.WHITE)
	_sub_label.position = Vector2(120.0, 97.0)
	add_child(_sub_label)
	_stars_total_label = RB.label("", 28, Color.WHITE)
	_stars_total_label.position = Vector2(1010.0, 90.0)
	add_child(_stars_total_label)
	var total_star := RATING.new()
	total_star.count = 1
	total_star.value = 1
	total_star.item_size = 26.0
	total_star.position = Vector2(1080.0, 90.0)
	add_child(total_star)

	_build_right_panel()

	# Barra de ayuda inferior
	_hint_bar = Control.new()
	_hint_bar.position = Vector2(30.0, 544.0)
	_hint_bar.size = Vector2(1092.0, 32.0)
	add_child(_hint_bar)
	var bar_bg := Panel.new()
	bar_bg.add_theme_stylebox_override("panel", RB.box(Color(0.13, 0.13, 0.15, 0.95), 0))
	bar_bg.size = _hint_bar.size
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_bar.add_child(bar_bg)
	var hx: float = 16.0
	hx += RB.add_hint(_hint_bar, Vector2(hx, 1.0), Color(0.15, 0.80, 0.25), "ENTER", RB.t("JUGAR CANCIÓN", "PLAY SONG"), 18) + 44.0
	hx += RB.add_hint(_hint_bar, Vector2(hx, 1.0), Color(0.95, 0.85, 0.10), "← →", RB.t("SIGUIENTE LETRA", "NEXT HEADING"), 18) + 44.0
	RB.add_hint(_hint_bar, Vector2(hx, 1.0), Color(1.0, 0.55, 0.10), "ESC", RB.t("ATRÁS", "BACK"), 18)

	_tab = PLAYER_TAB.new()
	_tab.position = Vector2(50.0, 574.0)
	add_child(_tab)
	_tab.setup(player, GameState.selected_instrument, "ESC", RB.t("ATRÁS", "BACK"), 340.0)

	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = "Master"
	_preview_player.finished.connect(_on_preview_finished)
	add_child(_preview_player)

	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.wait_time = 0.45
	_preview_timer.timeout.connect(_start_preview)
	add_child(_preview_timer)


func _build_right_panel() -> void:
	_right_panel = Control.new()
	_right_panel.position = Vector2(856.0, 98.0)
	_right_panel.size = Vector2(266.0, 440.0)
	add_child(_right_panel)

	_cover = COVER.new()
	_cover.position = Vector2(14.0, 34.0)
	_cover.size = Vector2(236.0, 236.0)
	_right_panel.add_child(_cover)

	var best_bg := Panel.new()
	best_bg.add_theme_stylebox_override("panel", RB.box(Color(0.02, 0.03, 0.06, 0.78), 0, Color(0.4, 0.42, 0.5), 1))
	best_bg.position = Vector2(14.0, 280.0)
	best_bg.size = Vector2(236.0, 36.0)
	best_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_panel.add_child(best_bg)
	_best_label = RB.label("", 18, Color.WHITE)
	_best_label.position = Vector2(24.0, 285.0)
	_right_panel.add_child(_best_label)
	_best_stars = RATING.new()
	_best_stars.count = 5
	_best_stars.item_size = 13.0
	_best_stars.position = Vector2(150.0, 284.0)
	_right_panel.add_child(_best_stars)

	var rows_bg := Panel.new()
	rows_bg.add_theme_stylebox_override("panel", RB.box(Color(0.02, 0.03, 0.06, 0.70), 0))
	rows_bg.position = Vector2(14.0, 324.0)
	rows_bg.size = Vector2(236.0, 172.0)
	rows_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_panel.add_child(rows_bg)
	_inst_dots.clear()
	for i in RB.INSTRUMENT_IDS.size():
		var id: String = str(RB.INSTRUMENT_IDS[i])
		var icon := ICON.new()
		icon.instrument = id
		icon.size = Vector2(32.0, 32.0)
		icon.position = Vector2(26.0, 330.0 + float(i) * 41.0)
		_right_panel.add_child(icon)
		var nm := RB.label(RB.instrument_name(id), 13, RB.GRAY_TXT)
		nm.position = Vector2(66.0, 337.0 + float(i) * 41.0)
		_right_panel.add_child(nm)
		var dots := RATING.new()
		dots.count = 5
		dots.dots = true
		dots.item_size = 14.0
		dots.position = Vector2(150.0, 334.0 + float(i) * 41.0)
		_right_panel.add_child(dots)
		_inst_dots.append(dots)


func _build_list() -> void:
	_holder = Control.new()
	_holder.position = LIST_POS
	_holder.size = LIST_SIZE
	_holder.clip_contents = true
	_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_holder.gui_input.connect(_on_holder_input)
	add_child(_holder)

	_rows_root = Control.new()
	_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_rows_root)

	_cursor = _make_cursor()
	_rows_root.add_child(_cursor)

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


func _make_cursor() -> Control:
	var c := Control.new()
	c.size = Vector2(ROW_W, SONG_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := TextureRect.new()
	fill.texture = RB.h_gradient(Color(0.90, 0.84, 0.10, 0.96), Color(0.16, 0.14, 0.03, 0.88))
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := ColorRect.new()
	top.color = Color(1.0, 1.0, 1.0, 0.9)
	top.size = Vector2(ROW_W, 2.0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = Color(1.0, 1.0, 1.0, 0.9)
	bottom.position = Vector2(0.0, SONG_H - 2.0)
	bottom.size = Vector2(ROW_W, 2.0)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bottom)
	return c


func _song_stars(song: Dictionary) -> int:
	var key: String = str(song["name"])
	if not _best_cache.has(key):
		_best_cache[key] = SONG_LIB.best_stars(key)
	return int(_best_cache[key])


func _add_header(letter: String, count: int, y: float) -> void:
	var row := Control.new()
	row.position = Vector2(0.0, y)
	row.size = Vector2(ROW_W, HEADER_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = RB.TEAL_BAR
	bg.size = row.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var edge := ColorRect.new()
	edge.color = Color(0.45, 0.75, 0.90, 0.9)
	edge.size = Vector2(5.0, HEADER_H)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(edge)
	var l := RB.label(letter, 32, Color.WHITE)
	l.position = Vector2(24.0, 2.0)
	row.add_child(l)
	var cl := RB.label("%d %s" % [count, RB.t("CANCIONES" if count != 1 else "CANCIÓN", "SONGS" if count != 1 else "SONG")], 22, Color(0.80, 0.84, 0.90))
	cl.position = Vector2(470.0, 8.0)
	row.add_child(cl)
	var earned: int = 0
	for s in _songs:
		var song: Dictionary = s
		if str(song["letter"]) == letter:
			earned += _song_stars(song)
	var sl := RB.label("%d/%d" % [earned, count * 5], 22, Color.WHITE)
	sl.position = Vector2(ROW_W - 150.0, 8.0)
	sl.size = Vector2(90.0, 30.0)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(sl)
	var star := RATING.new()
	star.count = 1
	star.value = 1
	star.item_size = 24.0
	star.position = Vector2(ROW_W - 52.0, 8.0)
	row.add_child(star)
	_rows_root.add_child(row)


func _add_song_row(index: int, y: float) -> void:
	var song: Dictionary = _songs[index]
	var row := Control.new()
	row.position = Vector2(0.0, y)
	row.size = Vector2(ROW_W, SONG_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(index))
	var title := RB.label(str(song["title"]), 25, Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	title.add_theme_constant_override("outline_size", 5)
	title.position = Vector2(70.0, 4.0)
	row.add_child(title)
	var artist_text: String = str(song["artist"])
	if artist_text != "":
		var at := RB.label(artist_text, 20, Color(0.78, 0.80, 0.86), false, true)
		at.position = Vector2(70.0 + RB.text_width(str(song["title"]), 25) + 16.0, 8.0)
		row.add_child(at)
	var stars := RATING.new()
	stars.count = 5
	stars.item_size = 14.0
	stars.value = _song_stars(song)
	stars.position = Vector2(ROW_W - 140.0, 11.0)
	row.add_child(stars)
	_rows_root.add_child(row)


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


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if index == _selected and mb.double_click:
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
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", RB.box(Color(0.03, 0.04, 0.08, 0.9), 8, RB.GOLD, 2))
	box.size = Vector2(700.0, 200.0)
	box.position = (get_viewport_rect().size - box.size) * 0.5
	add_child(box)
	var msg := RB.label(RB.t("No se encontraron canciones.", "No songs were found."), 32, Color.WHITE)
	msg.position = Vector2(30.0, 28.0)
	box.add_child(msg)
	var help := RB.label(RB.t(
		"Crea una carpeta en songs/ con nombre.wav y nombre.json\ny vuelve a abrir esta pantalla.",
		"Create a folder in songs/ with name.wav and name.json\nand open this screen again."), 20, RB.GRAY_TXT, false)
	help.position = Vector2(30.0, 90.0)
	box.add_child(help)
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
