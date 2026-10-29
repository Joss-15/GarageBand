## note.gd
## Una nota (gema) que viaja por el carril en perspectiva. Su posición y tamaño se
## calculan a partir del tiempo de la canción; el acierto/fallo usa las mismas
## ventanas de tiempo de siempre.
extends Node2D

const RB = preload("res://scripts/core/rb_theme.gd")

signal note_hit(lane: int, accuracy: float)
signal note_missed(lane: int)

# Ventanas de tiempo (segundos)
const HIT_WINDOW_PERFECT := 0.060
const HIT_WINDOW_GOOD := 0.100
const HIT_WINDOW_BAD := 0.20

const GEM_W := 78.0
const GEM_H := 28.0

var lane: int = 0
var beat_time: float = 0.0
var color: Color = Color.WHITE
var highway: Node2D = null
var fall_time: float = 2.0

var _judged: bool = false
var _shadow_pts := PackedVector2Array()
var _outer_pts := PackedVector2Array()
var _body_pts := PackedVector2Array()
var _body_cols := PackedColorArray()
var _gloss_pts := PackedVector2Array()


func setup(p_lane: int, p_time: float, p_color: Color, p_highway: Node2D, p_fall_time: float) -> void:
	lane = p_lane
	beat_time = p_time
	color = p_color
	highway = p_highway
	fall_time = p_fall_time
	_build_gem()
	visible = false
	queue_redraw()


func _build_gem() -> void:
	var hw: float = GEM_W * 0.5
	var hh: float = GEM_H * 0.5
	_outer_pts = RB.rounded_rect(Rect2(-hw, -hh, GEM_W, GEM_H), 10.0)
	_shadow_pts = RB.rounded_rect(Rect2(-hw + 2.0, -hh + 4.0, GEM_W, GEM_H), 10.0)
	_body_pts = RB.rounded_rect(Rect2(-hw + 3.0, -hh + 3.0, GEM_W - 6.0, GEM_H - 6.0), 8.0)
	_gloss_pts = RB.rounded_rect(Rect2(-hw + 8.0, -hh + 4.5, GEM_W - 16.0, GEM_H * 0.34), 5.0)
	_body_cols = PackedColorArray()
	for v in _body_pts:
		var t: float = clampf((v.y + hh - 3.0) / (GEM_H - 6.0), 0.0, 1.0)
		_body_cols.append(color.lightened(0.38 * (1.0 - t)).darkened(0.30 * t))


func _draw() -> void:
	if _outer_pts.is_empty():
		return
	draw_colored_polygon(_shadow_pts, Color(0.0, 0.0, 0.0, 0.45))
	draw_colored_polygon(_outer_pts, Color(0.96, 0.96, 0.99))
	draw_polygon(_body_pts, _body_cols)
	draw_colored_polygon(_gloss_pts, Color(1.0, 1.0, 1.0, 0.30))


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
	var sc: float = highway.project_scale(shown)
	scale = Vector2(sc, sc)
	visible = true
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
