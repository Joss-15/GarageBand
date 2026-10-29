## rating_row.gd
## Fila de estrellas (dots = false) o de puntos de dificultad (dots = true).
## reveal(n) los rellena uno por uno con un pequeño rebote.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

@export var count: int = 5:
	set(v):
		count = v
		_update_min_size()
		queue_redraw()

@export var value: int = 0:
	set(v):
		value = v
		_shown = float(v)
		queue_redraw()

@export var item_size: float = 18.0:
	set(v):
		item_size = v
		_update_min_size()
		queue_redraw()

@export var dots: bool = false

var _shown: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_min_size()


func _update_min_size() -> void:
	custom_minimum_size = Vector2(item_size * 1.25 * float(count) + 4.0, item_size * 1.3)


## Rellena de 0 a `target` con animación.
func reveal(target: int, per_item: float = 0.16) -> void:
	value = target
	_shown = 0.0
	queue_redraw()
	if target <= 0:
		return
	var tw := create_tween()
	tw.tween_method(_set_shown, 0.0, float(target), per_item * float(target))


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _draw() -> void:
	for i in count:
		var center := Vector2(item_size * 0.65 + float(i) * item_size * 1.25, size.y * 0.5)
		var k: float = clampf(_shown - float(i), 0.0, 1.0)
		var r: float = item_size * 0.5
		if k > 0.0 and k < 1.0:
			r *= 1.0 + 0.4 * sin(k * PI)
		if dots:
			_draw_dot(center, r, k > 0.0)
		else:
			_draw_star(center, r, k > 0.0)


func _draw_star(center: Vector2, r: float, filled: bool) -> void:
	var pts: PackedVector2Array = RB.star_points(center, r)
	var fill: Color = Color(0.96, 0.78, 0.14) if filled else Color(0.13, 0.14, 0.18)
	var edge: Color = Color(0.45, 0.30, 0.02) if filled else Color(0.38, 0.40, 0.46)
	draw_colored_polygon(pts, fill)
	var line: PackedVector2Array = pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, edge, 1.6, true)


func _draw_dot(center: Vector2, r: float, filled: bool) -> void:
	if filled:
		draw_circle(center, r * 0.9, Color(0.96, 0.97, 1.0))
		draw_arc(center, r * 0.9, 0.0, TAU, 20, Color(0.55, 0.58, 0.65), 1.5, true)
	else:
		draw_circle(center, r * 0.9, Color(0.10, 0.11, 0.14))
		draw_arc(center, r * 0.9, 0.0, TAU, 20, Color(0.32, 0.34, 0.40), 1.5, true)
