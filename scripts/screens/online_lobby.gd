## online_lobby.gd
## Pantalla "Multijugador en línea": conexión por IP directa y sala previa a la partida.
## Está construida entera en código (la escena online_lobby.tscn solo trae el nodo raíz).
##
## Flujo:  conectar (crear sala / unirse por IP)  ->  sala (el host elige la canción,
##         cada jugador su instrumento, los dos marcan LISTO)  ->  el host da EMPEZAR
##         ->  cuenta regresiva  ->  gameplay en modo en línea.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")

const BACK_SCENE := "res://scenes/screens/main_menu.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/gameplay.tscn"

const COL_BG := Color(0.03, 0.035, 0.08)
const COL_CARD := Color(0.07, 0.08, 0.14, 0.95)
const COL_ME := Color(1.0, 0.85, 0.15)
const COL_RIVAL := Color(0.35, 0.80, 1.0)
const COL_OK := Color(0.45, 0.95, 0.55)
const COL_ERR := Color(1.0, 0.45, 0.45)

var _songs: Array = []
var _starting: bool = false
var _local_md5: String = ""
var _ping_t: float = 0.0

var _center: CenterContainer
# Pantalla de conexión
var _connect_box: VBoxContainer
var _name_edit: LineEdit
var _port_edit: LineEdit
var _ip_edit: LineEdit
var _host_btn: Button
var _join_btn: Button
var _ips_lbl: Label
var _status_lbl: Label
# Sala
var _room_box: VBoxContainer
var _role_lbl: Label
var _ping_lbl: Label
var _me_name_lbl: Label
var _me_state_lbl: Label
var _inst_opt: OptionButton
var _rival_name_lbl: Label
var _rival_inst_lbl: Label
var _rival_state_lbl: Label
var _song_list: ItemList
var _song_lbl: Label
var _song_warn_lbl: Label
var _ready_btn: Button
var _start_btn: Button
var _countdown_lbl: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Desplazamos todo el bloque 100 píxeles hacia arriba para que quepan los botones
	_center.offset_top = -100.0 
	add_child(_center)

	_songs = SONG_LIB.scan()
	_build_connect()
	_build_room()
	_build_countdown()

	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.join_failed.connect(_on_join_failed)
	Net.rival_changed.connect(_refresh)
	Net.song_changed.connect(_on_song_changed)
	Net.countdown_started.connect(_begin_match)

	if Net.active and Net.connected:
		# Se vuelve de una partida con la sesión abierta
		GameState.online_mode = true
		Net.set_local("ready", false)
		_show_room()
	else:
		GameState.online_mode = false
		Net.leave()
		_show_connect()


# ── Construcción de la interfaz ──────────────────────────────────────────────

func _title(text: String, font_size: int = 38) -> Label:
	var lbl: Label = RB.label(text, font_size, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _small(text: String, color: Color = RB.GRAY_TXT) -> Label:
	var lbl: Label = RB.label(text, 16, color, false)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, 44.0)
	btn.pressed.connect(callback)
	return btn


func _card(accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", sb)
	return card


func _build_connect() -> void:
	_connect_box = VBoxContainer.new()
	_connect_box.custom_minimum_size = Vector2(540.0, 0.0)
	_connect_box.add_theme_constant_override("separation", 10)
	_center.add_child(_connect_box)

	_connect_box.add_child(_title(RB.t("MULTIJUGADOR EN LÍNEA", "ONLINE MULTIPLAYER")))
	_connect_box.add_child(_small(RB.t(
		"Por IP directa: misma red local, o con una VPN (Radmin, ZeroTier, Hamachi).",
		"Direct IP: same local network, or over a VPN (Radmin, ZeroTier, Hamachi).")))

	_connect_box.add_child(_small(RB.t("TU NOMBRE", "YOUR NAME")))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = RB.t("Jugador", "Player")
	if GameState.player1_name != "P1":
		_name_edit.text = GameState.player1_name
	_connect_box.add_child(_name_edit)

	_connect_box.add_child(_small(RB.t("PUERTO", "PORT")))
	_port_edit = LineEdit.new()
	_port_edit.text = str(Net.DEFAULT_PORT)
	_connect_box.add_child(_port_edit)

	_connect_box.add_child(HSeparator.new())
	_host_btn = _button(RB.t("CREAR SALA", "CREATE ROOM"), _on_host_pressed)
	_connect_box.add_child(_host_btn)
	_ips_lbl = _small("", COL_ME)
	_connect_box.add_child(_ips_lbl)

	_connect_box.add_child(HSeparator.new())
	_connect_box.add_child(_small(RB.t("IP DEL HOST", "HOST IP")))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.5"
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	_connect_box.add_child(_ip_edit)
	_join_btn = _button(RB.t("UNIRSE A LA SALA", "JOIN ROOM"), _on_join_pressed)
	_connect_box.add_child(_join_btn)

	_status_lbl = _small("")
	_connect_box.add_child(_status_lbl)
	_connect_box.add_child(_button(RB.t("VOLVER", "BACK"), _on_back_pressed))


func _build_room() -> void:
	_room_box = VBoxContainer.new()
	_room_box.custom_minimum_size = Vector2(880.0, 0.0)
	_room_box.add_theme_constant_override("separation", 6)
	_center.add_child(_room_box)

	_room_box.add_child(_title(RB.t("SALA", "ROOM")))
	var info := HBoxContainer.new()
	_role_lbl = _small("")
	_role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ping_lbl = _small("")
	_ping_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(_role_lbl)
	info.add_child(_ping_lbl)
	_room_box.add_child(info)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	_room_box.add_child(cards)

	# Tarjeta del jugador (yo)
	var me_card: PanelContainer = _card(COL_ME)
	var me_box := VBoxContainer.new()
	me_card.add_child(me_box)
	me_box.add_child(_small(RB.t("TÚ", "YOU"), COL_ME))
	_me_name_lbl = RB.label("", 26, Color.WHITE, true)
	me_box.add_child(_me_name_lbl)
	_inst_opt = OptionButton.new()
	for i in RB.INSTRUMENT_IDS.size():
		_inst_opt.add_item(RB.instrument_name(str(RB.INSTRUMENT_IDS[i])), i)
	_inst_opt.item_selected.connect(_on_instrument_selected)
	me_box.add_child(_inst_opt)
	_me_state_lbl = _small("")
	me_box.add_child(_me_state_lbl)
	cards.add_child(me_card)

	# Tarjeta del rival
	var rival_card: PanelContainer = _card(COL_RIVAL)
	var rival_box := VBoxContainer.new()
	rival_card.add_child(rival_box)
	rival_box.add_child(_small(RB.t("RIVAL", "RIVAL"), COL_RIVAL))
	_rival_name_lbl = RB.label("", 26, Color.WHITE, true)
	rival_box.add_child(_rival_name_lbl)
	_rival_inst_lbl = _small("")
	rival_box.add_child(_rival_inst_lbl)
	_rival_state_lbl = _small("")
	rival_box.add_child(_rival_state_lbl)
	cards.add_child(rival_card)

	# Canción
	_room_box.add_child(_small(RB.t("CANCIÓN", "SONG")))
	_song_list = ItemList.new()
	_song_list.custom_minimum_size = Vector2(0.0, 100.0)
	# --- AGREGA ESTO PARA QUE SE VEA EL CUADRO ---
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.5, 0.5, 0.5)
	_song_list.add_theme_stylebox_override("panel", sb)
	for s in _songs:
		var song: Dictionary = s
		var artist: String = str(song.get("artist", ""))
		var label: String = str(song["title"])
		if artist != "":
			label += "  —  " + artist
		_song_list.add_item(label)
	_song_list.item_selected.connect(_on_song_picked)
	_room_box.add_child(_song_list)
	_song_lbl = RB.label("", 20, Color.WHITE, true)
	_room_box.add_child(_song_lbl)
	_song_warn_lbl = _small("", COL_ERR)
	_room_box.add_child(_song_warn_lbl)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_room_box.add_child(buttons)
	_ready_btn = _button("", _on_ready_pressed)
	_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_ready_btn)
	_start_btn = _button(RB.t("EMPEZAR", "START"), _on_start_pressed)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_start_btn)
	var leave_btn: Button = _button(RB.t("SALIR", "LEAVE"), _on_back_pressed)
	buttons.add_child(leave_btn)


func _build_countdown() -> void:
	_countdown_lbl = RB.label("", 96, RB.GOLD_BRIGHT, true)
	_countdown_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_countdown_lbl.add_theme_constant_override("outline_size", 10)
	_countdown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_lbl.visible = false
	add_child(_countdown_lbl)


# ── Cambio entre pantallas ───────────────────────────────────────────────────

func _show_connect() -> void:
	_room_box.visible = false
	_connect_box.visible = true
	_update_connect_state()


func _show_room() -> void:
	_connect_box.visible = false
	_room_box.visible = true
	_role_lbl.text = RB.t("Eres el ANFITRIÓN: tú eliges la canción.", "You are the HOST: you pick the song.") if Net.is_host \
		else RB.t("Eres el INVITADO: el anfitrión elige la canción.", "You are the GUEST: the host picks the song.")
	_song_list.visible = Net.is_host
	_start_btn.visible = Net.is_host
	_inst_opt.select(maxi(_instrument_index(str(Net.local["instrument"])), 0))
	_recompute_song()
	_refresh()


func _instrument_index(id: String) -> int:
	for i in RB.INSTRUMENT_IDS.size():
		if str(RB.INSTRUMENT_IDS[i]) == id:
			return i
	return 0


# ── Conexión ─────────────────────────────────────────────────────────────────

func _clean_name() -> String:
	var n: String = _name_edit.text.strip_edges()
	if n.is_empty():
		n = RB.t("Jugador", "Player")
	return n


func _port() -> int:
	var p: int = int(_port_edit.text.strip_edges())
	return p if p >= 1024 and p <= 65535 else Net.DEFAULT_PORT


func _set_status(text: String, color: Color = RB.GRAY_TXT) -> void:
	_status_lbl.text = text
	_status_lbl.add_theme_color_override("font_color", color)


## Deja la pantalla de conexión según lo que esté haciendo Net.
func _update_connect_state() -> void:
	var hosting: bool = Net.active and Net.is_host and not Net.connected
	var joining: bool = Net.active and not Net.is_host and not Net.connected
	_host_btn.text = RB.t("CANCELAR SALA", "CANCEL ROOM") if hosting else RB.t("CREAR SALA", "CREATE ROOM")
	_join_btn.text = RB.t("CANCELAR", "CANCEL") if joining else RB.t("UNIRSE A LA SALA", "JOIN ROOM")
	_host_btn.disabled = joining
	_join_btn.disabled = hosting
	_name_edit.editable = not (hosting or joining)
	_port_edit.editable = not (hosting or joining)
	_ip_edit.editable = not (hosting or joining)
	if hosting:
		var ips: Array = Net.local_ips()
		var shown: String = ", ".join(PackedStringArray(ips)) if not ips.is_empty() else RB.t("(no se encontró IP)", "(no IP found)")
		_ips_lbl.text = RB.t("Dile a tu rival que escriba esta IP: %s   (puerto %d)", "Tell your rival to type this IP: %s   (port %d)") % [shown, _port()]
		_set_status(RB.t("Esperando al rival…", "Waiting for your rival…"))
	else:
		_ips_lbl.text = ""
	if joining:
		_set_status(RB.t("Conectando…", "Connecting…"))


func _on_host_pressed() -> void:
	if Net.active and Net.is_host and not Net.connected:
		Net.leave()
		_set_status("")
		_update_connect_state()
		return
	Net.local["name"] = _clean_name()
	var err: Error = Net.host_game(_port())
	if err != OK:
		_set_status(RB.t("No se pudo abrir el puerto %d. ¿Ya hay una sala abierta?", "Could not open port %d. Is a room already open?") % _port(), COL_ERR)
		return
	_update_connect_state()


func _on_join_pressed() -> void:
	if Net.active and not Net.is_host and not Net.connected:
		Net.leave()
		_set_status("")
		_update_connect_state()
		return
	var ip: String = _ip_edit.text.strip_edges()
	var port: int = _port()
	if ":" in ip:
		var parts: PackedStringArray = ip.split(":")
		ip = parts[0]
		port = int(parts[1])
	if ip.is_empty():
		_set_status(RB.t("Escribe la IP del anfitrión.", "Type the host IP."), COL_ERR)
		return
	Net.local["name"] = _clean_name()
	var err: Error = Net.join_game(ip, port)
	if err != OK:
		_set_status(RB.t("No se pudo iniciar la conexión (%s).", "Could not start the connection (%s).") % error_string(err), COL_ERR)
		return
	_update_connect_state()


func _on_join_failed() -> void:
	_update_connect_state()
	_set_status(RB.t("No se pudo conectar. Revisa la IP y que el anfitrión ya haya creado la sala.",
		"Could not connect. Check the IP and that the host has already created the room."), COL_ERR)


func _on_peer_joined() -> void:
	if _starting:
		return
	_show_room()


func _on_peer_left(reason: String) -> void:
	if _starting:
		return
	if not Net.is_host:
		Net.leave()
	_show_connect()
	_set_status(reason, COL_ERR)


# ── Sala ─────────────────────────────────────────────────────────────────────

func _md5_of(song: Dictionary) -> String:
	var path: String = str(song.get("wav", ""))
	if path != "" and FileAccess.file_exists(path):
		return FileAccess.get_md5(path)
	return ""


func _recompute_song() -> void:
	_local_md5 = ""
	if Net.song.is_empty():
		return
	var local_song: Dictionary = SONG_LIB.find_by_name(str(Net.song.get("name", "")))
	if not local_song.is_empty():
		_local_md5 = _md5_of(local_song)


## "ok" si se puede jugar; si no, el motivo: none / missing / different / nomap.
func _song_status() -> String:
	if Net.song.is_empty():
		return "none"
	var local_song: Dictionary = SONG_LIB.find_by_name(str(Net.song.get("name", "")))
	if local_song.is_empty():
		return "missing"
	var remote_md5: String = str(Net.song.get("md5", ""))
	if remote_md5 != "" and _local_md5 != "" and remote_md5 != _local_md5:
		return "different"
	if SONG_LIB.load_beatmap(local_song, str(Net.local["instrument"])).is_empty():
		return "nomap"
	return "ok"


func _set_state(lbl: Label, is_ready: bool) -> void:
	lbl.text = RB.t("✔ LISTO", "✔ READY") if is_ready else RB.t("Esperando…", "Waiting…")
	lbl.add_theme_color_override("font_color", COL_OK if is_ready else RB.GRAY_TXT)


func _refresh() -> void:
	if _room_box == null or not _room_box.visible:
		return
	_me_name_lbl.text = str(Net.local["name"])
	_rival_name_lbl.text = str(Net.rival.get("name", ""))
	_rival_inst_lbl.text = RB.instrument_name(str(Net.rival.get("instrument", "guitarra")))
	_set_state(_me_state_lbl, bool(Net.local["ready"]))
	_set_state(_rival_state_lbl, bool(Net.rival.get("ready", false)))

	var status: String = _song_status()
	if Net.song.is_empty():
		_song_lbl.text = RB.t("Elige una canción de la lista.", "Pick a song from the list.") if Net.is_host \
			else RB.t("Esperando a que el anfitrión elija la canción…", "Waiting for the host to pick the song…")
	else:
		var artist: String = str(Net.song.get("artist", ""))
		_song_lbl.text = str(Net.song.get("title", "")) + ("  —  " + artist if artist != "" else "")
	match status:
		"missing":
			_song_warn_lbl.text = RB.t("No tienes esta canción en tu juego.", "You do not have this song in your game.")
		"different":
			_song_warn_lbl.text = RB.t("Tu versión de esta canción es distinta a la del anfitrión.", "Your version of this song differs from the host's.")
		"nomap":
			_song_warn_lbl.text = RB.t("Esta canción no tiene mapa de notas para tu instrumento. Elige otro.", "This song has no note chart for your instrument. Pick another.")
		_:
			_song_warn_lbl.text = ""

	_ready_btn.disabled = status != "ok"
	_ready_btn.text = RB.t("CANCELAR LISTO", "UNREADY") if bool(Net.local["ready"]) else RB.t("LISTO", "READY")
	if Net.is_host:
		_start_btn.disabled = not (status == "ok" and bool(Net.local["ready"]) and bool(Net.rival.get("ready", false)))


func _on_song_picked(index: int) -> void:
	var song: Dictionary = _songs[index]
	Net.select_song({
		"name": str(song["name"]),
		"title": str(song["title"]),
		"artist": str(song.get("artist", "")),
		"md5": _md5_of(song),
	})
	_recompute_song()
	_refresh()


func _on_song_changed() -> void:
	_recompute_song()
	_refresh()


func _on_instrument_selected(index: int) -> void:
	Net.set_local("instrument", str(RB.INSTRUMENT_IDS[index]))
	_refresh()


func _on_ready_pressed() -> void:
	if _song_status() != "ok":
		return
	Net.set_local("ready", not bool(Net.local["ready"]))
	_refresh()


func _on_start_pressed() -> void:
	if not Net.is_host or not bool(Net.local["ready"]) or not bool(Net.rival.get("ready", false)):
		return
	Net.start_match()


# ── Inicio de la partida ─────────────────────────────────────────────────────

## Llega la señal de empezar (el host la manda a los dos con la cuenta regresiva).
## La pantalla de juego espera hasta online_start_at_msec para empezar a la vez.
func _begin_match(seconds: float) -> void:
	if _starting:
		return
	var song: Dictionary = SONG_LIB.find_by_name(str(Net.song.get("name", "")))
	if song.is_empty():
		_set_status(RB.t("No tienes la canción elegida.", "You do not have the selected song."), COL_ERR)
		return
	_starting = true
	var instrument: String = str(Net.local["instrument"])

	GameState.selected_song_name = str(song["name"])
	GameState.selected_song_title = str(song["title"])
	GameState.selected_song_artist = str(song.get("artist", ""))
	GameState.selected_song_path = str(song.get("wav", ""))
	GameState.selected_stream = load(str(song["wav"])) as AudioStream
	GameState.selected_instrument = instrument
	GameState.selected_instrument_p2 = str(Net.rival.get("instrument", "guitarra"))
	GameState.current_beatmap = SONG_LIB.load_beatmap(song, instrument)
	GameState.player1_name = str(Net.local["name"])
	GameState.player2_name = str(Net.rival.get("name", ""))
	GameState.online_mode = true
	GameState.two_player_mode = false
	GameState.online_start_at_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	GameState.stop_bgm()

	_countdown_lbl.text = RB.t("¡A JUGAR!", "GET READY!")
	_countdown_lbl.visible = true
	SceneFade.go(GAMEPLAY_SCENE)


# ── Salida y temporizador de ping ────────────────────────────────────────────

func _on_back_pressed() -> void:
	if _starting:
		return
	_starting = true
	Net.leave()
	GameState.online_mode = false
	SceneFade.go(BACK_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _room_box != null and _room_box.visible:
		_ping_t -= delta
		if _ping_t <= 0.0:
			_ping_t = 0.5
			_ping_lbl.text = "Ping: %d ms" % int(Net.rtt_ms)
