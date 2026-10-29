@tool
## player_tab.gd
## Tarjeta metálica de jugador con ícono, nombre y franja amarilla inferior
## (como las pestañas de la parte baja de los menús de Rock Band). Escena player_tab.tscn.
## Es @tool: el ancho, el nombre y el jugador (ícono) se ven al cambiarlos en el editor.
extends Control

const PLAYER_ICONS: Array[Texture2D] = [
	preload("res://assets/images/player1_icon.png"),
	preload("res://assets/images/player2_icon.png"),
	preload("res://assets/images/player3_icon.png"),
	preload("res://assets/images/player4_icon.png"),
]

@export var tab_width: float = 340.0:
	set(v):
		tab_width = v
		_apply_width()

@export var player_name: String = "Jugador 1":
	set(v):
		player_name = v
		if is_node_ready():
			$Body/NameLabel.text = v

## Número de jugador (1-4): decide cuál ícono playerN_icon se muestra.
@export_range(1, 4) var player_number: int = 1:
	set(v):
		player_number = clampi(v, 1, PLAYER_ICONS.size())
		_apply_icon()


func _ready() -> void:
	$Body/NameLabel.text = player_name
	_apply_icon()
	_apply_width()


func _apply_icon() -> void:
	if not is_node_ready():
		return
	($Body/Icon as TextureRect).texture = PLAYER_ICONS[player_number - 1]


func _apply_width() -> void:
	if not is_node_ready():
		return
	var body := $Body as Control
	var shine := $Body/Shine as Control
	var strip := $Body/Strip as Control
	body.size = Vector2(tab_width, body.size.y)
	shine.position.x = 1.0  # dentro del borde de 1 px del Body
	shine.size = Vector2(tab_width - 2.0, shine.size.y)
	strip.size = Vector2(tab_width, strip.size.y)
	if not Engine.is_editor_hint():
		custom_minimum_size.x = tab_width


## Atajo para fijar nombre y jugador de una vez. El segundo parámetro (instrumento)
## se ignora: se conserva para no romper las llamadas existentes.
func setup(p_name: String, _p_instrument: String = "", p_number: int = 1) -> void:
	player_name = p_name
	player_number = p_number
