@tool
## diamond_pattern.gd
## Rombos tenues para los banners (resultados). Cubre todo su rectángulo.
## Es @tool: se ve también en el editor.
extends Control

@export var line_color: Color = Color(0.5, 0.7, 1.0, 0.07):
	set(v):
		line_color = v
		queue_redraw()
@export var step: float = 36.0:
	set(v):
		step = maxf(v, 8.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cols: int = int(size.x / step) + 2
	var rows: int = int(size.y / step) + 2
	for ix in cols:
		for iy in rows:
			var p := Vector2(float(ix) * step, float(iy) * step)
			draw_line(p + Vector2(0.0, step * 0.5), p + Vector2(step * 0.5, 0.0), line_color, 1.0)
			draw_line(p + Vector2(step * 0.5, 0.0), p + Vector2(step, step * 0.5), line_color, 1.0)
			draw_line(p + Vector2(step, step * 0.5), p + Vector2(step * 0.5, step), line_color, 1.0)
			draw_line(p + Vector2(step * 0.5, step), p + Vector2(0.0, step * 0.5), line_color, 1.0)
