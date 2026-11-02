## seleccion_instrumento.gd
## Pantalla "elige instrumento" de la canción seleccionada (escena
## seleccion_instrumento.tscn). La tarjeta del jugador sube desde abajo con la
## lista de instrumentos y su dificultad.
##
## A la derecha de la pestaña del jugador 1 hay una pestaña "+" para sumar al
## jugador 2 (clic, o la tecla 2). Se crea una copia completa de la tarjeta, cada
## jugador elige con sus propias teclas y la partida empieza cuando los dos confirman.
##   Un jugador : ↑ ↓ Enter Esc (como siempre)
##   Dos jugadores: J1 = W S E (o control: cruceta ↑ ↓ y A) · J2 = ↑ ↓ Enter · Esc vuelve a la biblioteca
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")

const PLUS_W := 250.0               # ancho de la pestaña "+"
const SLIDE_FROM_BELOW := 340.0     # desde cuánto más abajo sube una tarjeta
const READY_TINT := Color(0.78, 1.0, 0.78)

var _song: Dictionary = {}
var _icons: Array = []
var _dots: Array = []
var _starting: bool = false

# Jugador 2: se prepara al abrir la pantalla pero solo aparece al pulsar "+"
var _two_player: bool = false
var _panel_home: Vector2 = Vector2.ZERO
var _panel_w: float = 440.0
var _intro_tween: Tween = null
var _panel2: Control = null
var _tab2: Control = null
var _list2: Control = null
var _icons2: Array = []
var _dots2: Array = []
var _plus_tab: Control = null
var _chosen: Array = ["", ""]       # instrumento confirmado por cada jugador ("" = aún no)

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
	GameState.two_player_mode = false    # el jugador 2 se vuelve a sumar cada vez
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
	_panel_home = _panel.position
	_panel_w = float(_tab.tab_width)

	_fill_header()
	# La copia del jugador 2 se hace ANTES de llenar la tarjeta 1, para que salga limpia
	_prepare_player2()
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


func _instrument_rows() -> Array:
	var rows: Array = []
	for i in RB.INSTRUMENT_IDS.size():
		var id: String = str(RB.INSTRUMENT_IDS[i])
		rows.append({"id": id, "text": RB.instrument_name(id)})
	return rows


func _index_of(id: String) -> int:
	for i in RB.INSTRUMENT_IDS.size():
		if str(RB.INSTRUMENT_IDS[i]) == id:
			return i
	return 0


func _fill_panel() -> void:
	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	_tab.setup(player, GameState.selected_instrument)

	_list.set_items(_instrument_rows(), _index_of(GameState.selected_instrument), true)
	_list.activated.connect(_on_activated.bind(0))
	_list.cancelled.connect(_back)
	_list.selection_changed.connect(_on_selection_changed)

	_reveal_dots(_dots)
	_refresh_icons()


func _reveal_dots(dots: Array) -> void:
	for i in RB.INSTRUMENT_IDS.size():
		var d: Control = dots[i]
		d.reveal(SONG_LIB.difficulty(_song, str(RB.INSTRUMENT_IDS[i])), 0.08)


func _play_intro() -> void:
	_panel.position = _panel_home + Vector2(0.0, SLIDE_FROM_BELOW)
	_intro_tween = create_tween()
	_intro_tween.tween_property(_panel, "position", _panel_home, 0.6).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ── Jugador 2 ────────────────────────────────────────────────────────────────

func _prepare_player2() -> void:
	# Copia de la tarjeta completa (pestaña, lista, íconos y puntos)
	_panel2 = _panel.duplicate() as Control
	_panel2.name = "PanelP2"
	_panel2.unique_name_in_owner = false
	for c in _panel2.get_children():
		c.unique_name_in_owner = false   # los nombres únicos (%) de la copia chocarían con los originales
	_tab2 = _panel2.get_node("PlayerTab") as Control
	_list2 = _panel2.get_node("List") as Control
	for i in RB.INSTRUMENT_IDS.size():
		_icons2.append(_panel2.get_node("Icon%d" % i))
		_dots2.append(_panel2.get_node("Dots%d" % i))
	_build_plus_tab()


## Pestaña "+": copia de la pestaña del jugador 1, a su derecha, clicable.
func _build_plus_tab() -> void:
	_plus_tab = _tab.duplicate() as Control
	_plus_tab.name = "PlusTab"
	_plus_tab.unique_name_in_owner = false
	_panel.add_child(_plus_tab)
	_plus_tab.position = Vector2(_tab.position.x + _panel_w + 14.0, _tab.position.y)
	_plus_tab.tab_width = PLUS_W
	_plus_tab.setup(RB.t("+  Jugador 2", "+  Player 2"), "", 2)
	_plus_tab.modulate = Color(1.0, 1.0, 1.0, 0.65)

	var body: Control = _plus_tab.get_node("Body") as Control
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size = Vector2(PLUS_W, body.size.y)
	btn.pressed.connect(_add_player2)
	btn.mouse_entered.connect(_set_plus_alpha.bind(1.0))
	btn.mouse_exited.connect(_set_plus_alpha.bind(0.65))
	_plus_tab.add_child(btn)

	var hint: Label = RB.label(RB.t("o pulsa la tecla 2 / Y", "or press the 2 key / Y"), 16, RB.GRAY_TXT, false)
	hint.position = Vector2(8.0, body.size.y + 6.0)
	_plus_tab.add_child(hint)


func _set_plus_alpha(a: float) -> void:
	if _plus_tab != null and is_instance_valid(_plus_tab) and not _two_player:
		_plus_tab.modulate.a = a


func _add_player2() -> void:
	if _two_player or _starting:
		return
	_two_player = true
	GameState.two_player_mode = true
	_list.keyboard_enabled = false      # desde ahora las teclas de ambos las maneja _unhandled_input
	_msg.text = RB.t("J1: W S E / control   ·   J2: ↑ ↓ Enter   ·   Esc: volver", "P1: W S E / gamepad   ·   P2: ↑ ↓ Enter   ·   Esc: back")

	var vp_w: float = get_viewport_rect().size.x
	var x1: float = vp_w * 0.25 - _panel_w * 0.5
	var x2: float = vp_w * 0.75 - _panel_w * 0.5

	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_panel.position = _panel_home

	# El "+" se desvanece y la tarjeta 1 se corre a la izquierda
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_plus_tab, "modulate:a", 0.0, 0.2)
	tw.tween_property(_panel, "position:x", x1, 0.4)
	tw.finished.connect(_plus_tab.queue_free)

	# La tarjeta 2 sube desde abajo hasta su lugar
	add_child(_panel2)
	_panel2.position = Vector2(x2, _panel_home.y + SLIDE_FROM_BELOW)
	_fill_player2()
	create_tween().tween_property(_panel2, "position", Vector2(x2, _panel_home.y), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fill_player2() -> void:
	var player: String = GameState.player2_name
	if player == "P2":
		player = RB.t("Jugador 2", "Player 2")
	_tab2.setup(player, "", 2)

	# Que el jugador 2 empiece en un instrumento distinto al del jugador 1
	var start1: int = _list.selected
	var start2: int = _index_of(GameState.selected_instrument_p2)
	if start2 == start1:
		start2 = (start1 + 1) % RB.INSTRUMENT_IDS.size()
	_list2.set_items(_instrument_rows(), start2, true)
	_list2.keyboard_enabled = false
	_list2.activated.connect(_on_activated.bind(1))
	_list2.selection_changed.connect(_on_selection_changed)

	_reveal_dots(_dots2)
	_refresh_icons()


# ── Selección ────────────────────────────────────────────────────────────────

func _on_selection_changed(_index: int) -> void:
	_refresh_icons()


func _refresh_icons() -> void:
	_paint_icons(_icons, _list.selected)
	if _two_player and _list2 != null:
		_paint_icons(_icons2, _list2.selected)


func _paint_icons(icons: Array, selected: int) -> void:
	for i in icons.size():
		var ic: Control = icons[i]
		ic.ring_color = RB.GOLD_BRIGHT if i == selected else Color(0.55, 0.57, 0.63)


func _list_of(player: int) -> Control:
	return _list if player == 0 else _list2


func _on_activated(id: String, player: int) -> void:
	if _starting or str(_chosen[player]) != "":
		return
	var bm: Dictionary = SONG_LIB.load_beatmap(_song, id)
	if bm.is_empty():
		_msg.text = RB.t("No se encontró el mapa de notas de esta canción.", "Could not find the note chart for this song.")
		_msg.modulate = Color(1.0, 0.45, 0.45)
		return

	_chosen[player] = id
	if not _two_player:
		_start(bm)
		return

	# Dos jugadores: marca a este como listo y espera al otro
	var panel: Control = _panel if player == 0 else _panel2
	panel.modulate = READY_TINT
	if str(_chosen[0]) != "" and str(_chosen[1]) != "":
		_start(SONG_LIB.load_beatmap(_song, str(_chosen[0])))
	else:
		var waiting: String = RB.t("Jugador 2", "Player 2") if player == 0 else RB.t("Jugador 1", "Player 1")
		_msg.text = RB.t("Esperando a %s…", "Waiting for %s…") % waiting


func _start(bm_p1: Dictionary) -> void:
	_starting = true
	_list.keyboard_enabled = false
	GameState.selected_instrument = str(_chosen[0])
	if _two_player:
		GameState.selected_instrument_p2 = str(_chosen[1])
	GameState.two_player_mode = _two_player
	GameState.current_beatmap = bm_p1
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


# ── Teclado ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return

	# Un jugador: la lista ya maneja ↑ ↓ Enter Esc. Aquí solo se escucha la tecla 2.
	if not _two_player:
		if event is InputEventKey:
			var k0 := event as InputEventKey
			if k0.pressed and not k0.echo and (k0.keycode == KEY_2 or k0.keycode == KEY_KP_2):
				_add_player2()
				get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton:
			var jb0 := event as InputEventJoypadButton
			if jb0.pressed and jb0.button_index == JOY_BUTTON_Y:
				_add_player2()
				get_viewport().set_input_as_handled()
		return

	# Dos jugadores: J1 con W S E o con el control, J2 con ↑ ↓ Enter, Esc vuelve
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.pressed:
			match jb.button_index:
				JOY_BUTTON_DPAD_UP:
					_move(0, -1)
				JOY_BUTTON_DPAD_DOWN:
					_move(0, 1)
				JOY_BUTTON_A:
					_confirm(0)
				JOY_BUTTON_B:
					_back()
				_:
					return
		else:
			return
	elif event is InputEventJoypadMotion:
		return    # el stick no mueve al jugador 2 por accidente
	elif event.is_action_pressed("ui_cancel"):
		_back()
	elif event.is_action_pressed("ui_up"):
		_move(1, -1)
	elif event.is_action_pressed("ui_down"):
		_move(1, 1)
	elif event.is_action_pressed("ui_accept"):
		_confirm(1)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_W:
				_move(0, -1)
			KEY_S:
				_move(0, 1)
			KEY_E:
				_confirm(0)
			_:
				return
	else:
		return
	get_viewport().set_input_as_handled()


func _move(player: int, dir: int) -> void:
	if str(_chosen[player]) != "":
		return
	_list_of(player).move_selection(dir)


func _confirm(player: int) -> void:
	if str(_chosen[player]) != "":
		return
	var lst: Control = _list_of(player)
	lst.activated.emit(lst.selected_id())
