## online_lobby.gd
## Pantalla "Multijugador en línea" (escena online_lobby.tscn): solo la conexión por IP directa.
## Toda la interfaz vive en la escena; aquí solo hay lógica.
##
## Flujo completo del modo en línea:
##   1. Esta pantalla: el host crea la sala o el invitado se une con la IP.
##   2. Al conectarse, el host manda a los dos a la selección de canción (Net.go_stage):
##      solo el host la maneja; el invitado la ve con un overlay "está seleccionando…".
##   3. Elegida la canción, los dos pasan a la selección de instrumento con sistema LISTO;
##      el host inicia la partida cuando los dos están listos.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

const BACK_SCENE := "res://scenes/screens/main_menu.tscn"
const COL_ERR := Color(1.0, 0.45, 0.45)

var _leaving: bool = false

@onready var _msg: Label = %Msg
@onready var _name_edit: LineEdit = %NameEdit
@onready var _port_edit: LineEdit = %PortEdit
@onready var _ip_edit: LineEdit = %IpEdit
@onready var _connect_list: Control = %ConnectList
@onready var _ips_lbl: Label = %IpsLabel
@onready var _status_lbl: Label = %StatusLabel
@onready var _status_card: Control = $ConnectView/StatusCard


func _ready() -> void:
	RB.localize(self)
	_name_edit.placeholder_text = RB.t("Jugador", "Player")
	_port_edit.text = str(Net.DEFAULT_PORT)
	if GameState.player1_name != "P1":
		_name_edit.text = GameState.player1_name
	_msg.text = RB.t("Por IP directa: misma red local, o con una VPN (Radmin, ZeroTier, Hamachi).",
		"Direct IP: same local network, or over a VPN (Radmin, ZeroTier, Hamachi).")

	_connect_list.activated.connect(_on_connect_activated)
	_connect_list.cancelled.connect(_on_back_pressed)

	# Mientras se escribe en un campo, la lista no recibe teclas
	for edit: LineEdit in [_name_edit, _port_edit, _ip_edit]:
		edit.focus_entered.connect(_on_field_focus.bind(true))
		edit.focus_exited.connect(_on_field_focus.bind(false))
		edit.gui_input.connect(_on_field_gui_input.bind(edit))
		edit.text_submitted.connect(_on_field_submitted.bind(edit))

	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.join_failed.connect(_on_join_failed)

	# Aquí no hay partida: se llega desde el menú o al perderse la conexión. Si el host
	# sigue con la sala abierta (el invitado se fue) se queda esperando a otro rival.
	GameState.online_mode = false
	if Net.active and Net.is_host and not Net.connected:
		pass
	else:
		Net.leave()

	_connect_list.set_items([
		{"id": "host", "text": _host_text()},
		{"id": "join", "text": _join_text()},
		{"id": "back", "text": RB.t("VOLVER", "BACK")},
	], 0, true)
	_update_connect_state()
	if Net.notice != "":
		_set_status(Net.notice, COL_ERR)
		Net.notice = ""


# ── Campos de texto ──────────────────────────────────────────────────────────

func _on_field_focus(entered: bool) -> void:
	_connect_list.keyboard_enabled = not entered


func _on_field_gui_input(event: InputEvent, edit: LineEdit) -> void:
	if event.is_action_pressed("ui_cancel"):
		edit.release_focus()
		edit.accept_event()


func _on_field_submitted(_text: String, edit: LineEdit) -> void:
	edit.release_focus()
	if edit == _ip_edit:
		_on_join_pressed()


func _release_fields() -> void:
	for edit: LineEdit in [_name_edit, _port_edit, _ip_edit]:
		edit.release_focus()


func _clean_name() -> String:
	var n: String = _name_edit.text.strip_edges()
	if n.is_empty():
		n = RB.t("Jugador", "Player")
	return n


func _port() -> int:
	var p: int = int(_port_edit.text.strip_edges())
	return p if p >= 1024 and p <= 65535 else Net.DEFAULT_PORT


# ── Estado de la conexión ────────────────────────────────────────────────────

func _hosting() -> bool:
	return Net.active and Net.is_host and not Net.connected


func _joining() -> bool:
	return Net.active and not Net.is_host and not Net.connected


func _host_text() -> String:
	return RB.t("CANCELAR SALA", "CANCEL ROOM") if _hosting() else RB.t("CREAR SALA", "CREATE ROOM")


func _join_text() -> String:
	return RB.t("CANCELAR", "CANCEL") if _joining() else RB.t("UNIRSE A LA SALA", "JOIN ROOM")


func _set_status(text: String, color: Color = RB.GRAY_TXT) -> void:
	_status_lbl.text = text
	_status_lbl.add_theme_color_override("font_color", color)
	_sync_status_card()


func _sync_status_card() -> void:
	_status_card.visible = _ips_lbl.text != "" or _status_lbl.text != ""


## Deja la pantalla según lo que esté haciendo Net.
func _update_connect_state() -> void:
	_connect_list.set_item_text(0, _host_text())
	_connect_list.set_item_text(1, _join_text())
	var locked: bool = _hosting() or _joining()
	_name_edit.editable = not locked
	_port_edit.editable = not locked
	_ip_edit.editable = not locked
	if _hosting():
		var ips: Array = Net.call("local_ips")
		var shown: String = ", ".join(PackedStringArray(ips)) if not ips.is_empty() else RB.t("(no se encontró IP)", "(no IP found)")
		_ips_lbl.text = RB.t("Dile a tu rival que escriba esta IP: %s   (puerto %d)", "Tell your rival to type this IP: %s   (port %d)") % [shown, _port()]
		_set_status(RB.t("Esperando al rival…", "Waiting for your rival…"))
	else:
		_ips_lbl.text = ""
	if _joining():
		_set_status(RB.t("Conectando…", "Connecting…"))
	_sync_status_card()


func _on_connect_activated(id: String) -> void:
	_release_fields()
	match id:
		"host":
			_on_host_pressed()
		"join":
			_on_join_pressed()
		"back":
			_on_back_pressed()


func _on_host_pressed() -> void:
	if _joining():
		return
	if _hosting():
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
	if _hosting():
		return
	if _joining():
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


## Ya hay rival. El host manda a los dos a elegir canción; el invitado espera esa orden.
func _on_peer_joined() -> void:
	_leaving = true
	_connect_list.keyboard_enabled = false
	if Net.is_host:
		Net.go_stage("song")
	else:
		_set_status(RB.t("Conectado. Esperando al anfitrión…", "Connected. Waiting for the host…"))


func _on_peer_left(reason: String) -> void:
	_leaving = false
	_connect_list.keyboard_enabled = true
	_update_connect_state()
	_set_status(reason, COL_ERR)


# ── Salida y teclado ─────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	Net.leave()
	GameState.online_mode = false
	SceneFade.go(BACK_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	# TAB: empezar a escribir en los campos
	if event.is_action_pressed("ui_focus_next") and _name_edit.editable:
		_name_edit.grab_focus()
		get_viewport().set_input_as_handled()
		return
	# Clic fuera de un campo: deja de escribir
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus is LineEdit:
			focus.release_focus()
