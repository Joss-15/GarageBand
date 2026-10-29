@tool
## medallion.gd
## Medallón decorativo (el banner de resultados lo hace girar lentamente).
## Es @tool: se ve también en el editor.
extends Control


func _init() -> void:
	custom_minimum_size = Vector2(88.0, 88.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(c, r, Color(0.04, 0.10, 0.35))
	draw_arc(c, r, 0.0, TAU, 48, Color(0.75, 0.88, 1.0), 3.0, true)
	draw_arc(c, r * 0.72, 0.0, TAU, 40, Color(0.40, 0.70, 1.0), 2.0, true)
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.86, 2.6, Color(0.85, 0.93, 1.0))
	draw_circle(c, r * 0.42, Color(0.10, 0.55, 0.95))
	draw_circle(c, r * 0.22, Color(0.80, 0.90, 1.0))
