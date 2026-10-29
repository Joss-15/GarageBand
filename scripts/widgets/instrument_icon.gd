## instrument_icon.gd
## Insignia circular con el ícono de un instrumento, dibujada por código
## (no necesita imágenes). instrument: guitarra | bajo | batería | microfono
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

@export var instrument: String = "guitarra":
	set(value):
		instrument = value
		queue_redraw()

@export var ring_color: Color = Color(0.93, 0.94, 0.97):
	set(value):
		ring_color = value
		queue_redraw()

@export var glyph_color: Color = Color(0.95, 0.96, 0.98)


func _init() -> void:
	custom_minimum_size = Vector2(48.0, 48.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, r, Color(0.04, 0.04, 0.06))
	draw_arc(c, r - 1.5, 0.0, TAU, 48, ring_color, maxf(2.0, r * 0.09), true)
	match instrument:
		"bajo":
			_draw_guitar(c, r, true)
		"batería":
			_draw_drums(c, r)
		"microfono":
			_draw_mic(c, r)
		_:
			_draw_guitar(c, r, false)


func _draw_guitar(c: Vector2, r: float, bass: bool) -> void:
	var gc: Color = glyph_color
	var dark := Color(0.04, 0.04, 0.06)
	draw_set_transform(c, -0.75, Vector2.ONE)
	var body_r: float = r * (0.28 if bass else 0.34)
	draw_circle(Vector2(0.0, r * 0.34), body_r, gc)
	draw_circle(Vector2(0.0, r * 0.02), body_r * 0.78, gc)
	draw_circle(Vector2(0.0, r * 0.22), r * 0.09, dark)
	var neck_top: float = -r * (0.88 if bass else 0.74)
	draw_line(Vector2(0.0, -r * 0.1), Vector2(0.0, neck_top), gc, r * 0.13)
	draw_rect(Rect2(-r * 0.10, neck_top - r * 0.18, r * 0.20, r * 0.20), gc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_drums(c: Vector2, r: float) -> void:
	var gc: Color = glyph_color
	var rim := Color(0.80, 0.82, 0.90)
	var rx: float = r * 0.58
	var ry: float = r * 0.24
	var top_c: Vector2 = c + Vector2(0.0, -r * 0.10)
	draw_rect(Rect2(c.x - rx, top_c.y, rx * 2.0, r * 0.50), gc)
	draw_colored_polygon(RB.ellipse_points(top_c + Vector2(0.0, r * 0.50), rx, ry), gc)
	draw_colored_polygon(RB.ellipse_points(top_c, rx, ry), rim)
	# baquetas cruzadas
	draw_line(c + Vector2(-r * 0.62, -r * 0.62), c + Vector2(r * 0.14, -r * 0.04), gc, r * 0.09, true)
	draw_line(c + Vector2(r * 0.62, -r * 0.62), c + Vector2(-r * 0.14, -r * 0.04), gc, r * 0.09, true)


func _draw_mic(c: Vector2, r: float) -> void:
	var gc: Color = glyph_color
	var dark := Color(0.04, 0.04, 0.06)
	draw_set_transform(c, 0.5, Vector2.ONE)
	draw_circle(Vector2(0.0, -r * 0.30), r * 0.30, gc)
	for i in range(-1, 2):
		draw_line(Vector2(float(i) * r * 0.1, -r * 0.54), Vector2(float(i) * r * 0.1, -r * 0.06), dark, 1.5)
	var handle := PackedVector2Array([
		Vector2(-r * 0.13, -r * 0.02), Vector2(r * 0.13, -r * 0.02),
		Vector2(r * 0.07, r * 0.66), Vector2(-r * 0.07, r * 0.66),
	])
	draw_colored_polygon(handle, gc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
