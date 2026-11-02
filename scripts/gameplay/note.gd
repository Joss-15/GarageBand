## note.gd
## Una nota (pastilla con relieve) que viaja por el carril en perspectiva. Su posición
## se calcula a partir del tiempo de la canción y se dibuja apoyada sobre el plano del
## carril (chip_draw.gd), con el mismo ángulo que el carril; el acierto/fallo usa las
## mismas ventanas de tiempo de siempre.
extends Node2D

const ChipDraw = preload("res://scripts/core/chip_draw.gd")

signal note_hit(lane: int, accuracy: float)
signal note_missed(lane: int)

# Ventanas de tiempo (segundos)
const HIT_WINDOW_PERFECT := 0.060
const HIT_WINDOW_GOOD := 0.100
const HIT_WINDOW_BAD := 0.20

# Tamaño de la pastilla a la altura de la línea de golpe (px): medio ancho, media profundidad, relieve
const GEM_HW := 33.0
const GEM_HD := 19.0
const GEM_ELEV := 8.0

var lane: int = 0
var beat_time: float = 0.0
var color: Color = Color.WHITE
var highway: Node2D = null
var fall_time: float = 2.0

var _judged: bool = false
var _k: float = 547.0         # hit_y - horizon_y
var _lateral: float = 0.0     # distancia de su carril al centro del highway
var _zc: float = 1.0          # distancia relativa actual (1 = línea de golpe)


func setup(p_lane: int, p_time: float, p_color: Color, p_highway: Node2D, p_fall_time: float) -> void:
	lane = p_lane
	beat_time = p_time
	color = p_color
	highway = p_highway
	fall_time = p_fall_time
	_k = highway.hit_y - highway.horizon_y
	_lateral = highway.lane_offset(lane)
	visible = false
	queue_redraw()


func _draw() -> void:
	if highway == null:
		return
	ChipDraw.draw_chip(self, _k, _lateral, _zc, color, GEM_HW, GEM_HD, GEM_ELEV)


## Posiciona la nota según el tiempo actual de la canción y detecta el fallo.
func update_for_time(song_time: float) -> void:
	var dt: float = beat_time - song_time
	if not _judged and dt < -HIT_WINDOW_BAD:
		_judged = true
		note_missed.emit(lane)
		queue_free()
		return
	var shown: float = clampf(dt, -0.3, fall_time)
	position = highway.project_pos(lane, shown)
	_zc = 1.0 / highway.project_scale(shown)
	visible = true
	queue_redraw()
	# aparece suavemente al entrar por el fondo
	modulate.a = clampf((fall_time - dt) / 0.35, 0.0, 1.0)


## Intenta registrar un golpe. Devuelve true si fue válido.
func try_hit(song_time: float) -> bool:
	if _judged:
		return false
	var diff: float = absf(song_time - beat_time)
	if diff > HIT_WINDOW_BAD:
		return false
	_judged = true
	var accuracy: float = 0.3
	if diff <= HIT_WINDOW_PERFECT:
		accuracy = 1.0
	elif diff <= HIT_WINDOW_GOOD:
		accuracy = 0.6
	note_hit.emit(lane, accuracy)
	queue_free()
	return true


## ¿Está esta nota dentro de la ventana de golpe?
func is_hittable(song_time: float) -> bool:
	return not _judged and absf(song_time - beat_time) <= HIT_WINDOW_BAD
