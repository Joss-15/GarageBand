@tool
## combo_dial.gd
## Dial circular que muestra el combo actual y su avance hacia el siguiente múltiplo de 10.
## Es @tool: se ve también en el editor.
extends Control

@export var font: Font
@export var combo: int = 0:
	set(v):
		combo = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(76.0, 76.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Cambia el combo; cada múltiplo de 10 hace un pequeño rebote.
func set_combo(c: int) -> void:
	var grew: bool = c > combo
	combo = c
	if grew and c > 0 and c % 10 == 0:
		pivot_offset = size * 0.5
		scale = Vector2(1.25, 1.25)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(c, r, Color(0.06, 0.07, 0.10, 0.92))
	draw_arc(c, r, 0.0, TAU, 48, Color(0.33, 0.34, 0.40), 4.0, true)
	var frac: float = float(combo % 10) / 10.0
	if combo > 0 and combo % 10 == 0:
		frac = 1.0
	if frac > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(0.88, 0.82, 0.10), 5.0, true)
	var f: Font = font if font != null else ThemeDB.fallback_font
	var fs: int = 28 if combo < 100 else 22
	draw_string(f, Vector2(0.0, c.y + float(fs) * 0.36), str(combo), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
