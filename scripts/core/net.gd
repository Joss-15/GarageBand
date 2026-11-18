## net.gd
## Autoload "Net": multijugador en línea de 2 jugadores por IP directa (ENet).
##
## Modelo "carrera de puntajes": cada jugador juega en su propia máquina y juzga sus
## aciertos con su reloj de audio, así que la latencia NO afecta la precisión. Por la
## red solo viaja: los datos de la sala (nombre, instrumento, listo), la canción que
## eligió el host, la señal de empezar con cuenta regresiva, el estado en vivo del
## jugador (puntos, combo, precisión) unas 10 veces por segundo y el resultado final.
##
## El host es quien crea la sala (peer 1). El invitado se conecta con su IP.
## Para la versión web: los navegadores no pueden abrir servidores ni usar UDP, así
## que allí habría que cambiar ENetMultiplayerPeer por WebSocketMultiplayerPeer contra
## un servidor intermedio. Los RPC de este archivo no cambian.
extends Node

signal peer_joined                          # hay un rival conectado
signal peer_left(reason: String)            # el rival se fue (o se perdió la conexión)
signal join_failed                          # no se pudo conectar al host
signal rival_changed                        # cambió nombre / instrumento / listo del rival
signal song_changed                         # el host eligió otra canción
signal countdown_started(seconds: float)    # empieza la cuenta regresiva de la partida
signal rival_state(data: Dictionary)        # estado en vivo del rival
signal rival_finished(data: Dictionary)     # resultado final del rival

const DEFAULT_PORT := 24680
const COUNTDOWN := 3.0                      # segundos de cuenta regresiva antes de empezar
const STATE_INTERVAL := 0.1                 # cada cuánto se manda el estado en vivo
const PING_INTERVAL := 1.0
const JOIN_TIMEOUT := 6.0                   # Godot no avisa si la IP no responde, así que hay tiempo límite propio

var active: bool = false        # hay una sesión abierta (creada o unida)
var is_host: bool = false
var connected: bool = false     # hay un rival conectado
var local: Dictionary = {"name": "Jugador", "instrument": "guitarra", "ready": false}
var rival: Dictionary = {"name": "", "instrument": "guitarra", "ready": false}
var song: Dictionary = {}       # canción elegida por el host: {name, title, artist, md5}
var rtt_ms: float = 0.0         # latencia de ida y vuelta medida

var _ping_timer: float = 0.0
var _join_left: float = 0.0     # cuenta atrás mientras el invitado intenta conectarse


func _ready() -> void:
	# La red debe seguir viva aunque el juego esté en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Crear / unirse / salir ───────────────────────────────────────────────────

## Crea la sala y se queda esperando al invitado.
func host_game(port: int = DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	active = true
	is_host = true
	return OK


## Se conecta a la sala de un host. La conexión se confirma con peer_joined.
func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	active = true
	is_host = false
	_join_left = JOIN_TIMEOUT
	return OK


## Cierra la sesión y limpia el estado.
func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	connected = false
	_join_left = 0.0
	song = {}
	rtt_ms = 0.0
	local["ready"] = false
	rival = {"name": "", "instrument": "guitarra", "ready": false}


## IPs de esta máquina que sirven para que el otro jugador se conecte (LAN o VPN).
static func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var addr: String = str(a)
		if addr.count(".") == 3 and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			out.append(addr)
	return out


func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(_id: int) -> void:
	# Solo el host usa esto: llegó el invitado
	if not is_host:
		return
	connected = true
	_send_info()
	if not song.is_empty():
		_rpc_song.rpc(song)
	peer_joined.emit()


func _on_connected_to_server() -> void:
	_join_left = 0.0
	connected = true
	_send_info()
	peer_joined.emit()


func _on_peer_disconnected(_id: int) -> void:
	if not is_host:
		return
	_rival_gone("El otro jugador se desconectó.")


func _on_server_disconnected() -> void:
	_rival_gone("Se perdió la conexión con el host.")
	active = false


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _rival_gone(reason: String) -> void:
	connected = false
	rival = {"name": "", "instrument": "guitarra", "ready": false}
	local["ready"] = false
	peer_left.emit(reason)


# ── Datos de la sala ─────────────────────────────────────────────────────────

## Cambia un dato propio (name / instrument / ready) y se lo avisa al rival.
func set_local(key: String, value: Variant) -> void:
	local[key] = value
	_send_info()


func _send_info() -> void:
	if connected:
		_rpc_info.rpc(local)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_info(info: Dictionary) -> void:
	rival = info
	rival_changed.emit()


## El host elige la canción. song = {name, title, artist, md5}.
func select_song(new_song: Dictionary) -> void:
	if not is_host:
		return
	song = new_song
	local["ready"] = false
	if connected:
		_rpc_song.rpc(song)
		_send_info()


@rpc("authority", "call_remote", "reliable")
func _rpc_song(new_song: Dictionary) -> void:
	song = new_song
	local["ready"] = false     # al cambiar la canción hay que volver a darle a listo
	_send_info()
	song_changed.emit()


## El host arranca la partida. Descuenta media latencia al invitado para que
## los dos terminen la cuenta regresiva casi a la vez.
func start_match() -> void:
	if not is_host or not connected:
		return
	var guest_secs: float = maxf(COUNTDOWN - rtt_ms * 0.5 / 1000.0, 0.5)
	_rpc_start.rpc(guest_secs)
	countdown_started.emit(COUNTDOWN)


@rpc("authority", "call_remote", "reliable")
func _rpc_start(seconds: float) -> void:
	countdown_started.emit(seconds)


# ── Durante la partida ───────────────────────────────────────────────────────

## Estado en vivo (puntos, combo, precisión...). Se pierde algún paquete sin problema.
func send_state(data: Dictionary) -> void:
	if connected:
		_rpc_state.rpc(data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_state(data: Dictionary) -> void:
	rival_state.emit(data)


## Resultado final de la partida (llega siempre).
func send_finished(data: Dictionary) -> void:
	if connected:
		_rpc_finished.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_finished(data: Dictionary) -> void:
	rival_finished.emit(data)


# ── Latencia ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Tiempo límite al intentar unirse a una IP que no responde
	if _join_left > 0.0 and not connected:
		_join_left -= delta
		if _join_left <= 0.0:
			leave()
			join_failed.emit()
			return
	if not connected:
		return
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = PING_INTERVAL
		_rpc_ping.rpc(Time.get_ticks_usec())


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping(sent_usec: int) -> void:
	_rpc_pong.rpc_id(multiplayer.get_remote_sender_id(), sent_usec)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_pong(sent_usec: int) -> void:
	rtt_ms = float(Time.get_ticks_usec() - sent_usec) / 1000.0
