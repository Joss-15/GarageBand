@tool
## highway_bar.gd
## Barra cromada de la línea de golpe con la tecla de cada carril.
## Es @tool: se ve también en el editor. highway.gd le pasa la geometría al empezar.
extends Node2D

const LANE_COLORS := [
	Color(0.14, 0.86, 0.28),
	Color(0.95, 0.16, 0.16),
	Color(0.98, 0.86, 0.10),
	Color(0.18, 0.44, 0.98),
	Color(1.00, 0.56, 0.10),
]

@export var font: Font
@export var center_x: float = 576.0:
	set(v):
		center_x = v
		queue_redraw()
@export var hit_y: float = 566.0:
	set(v):
		hit_y = v
		queue_redraw()
@export var lane_w: float = 88.0:
	set(v):
		lane_w = v
		queue_redraw()
@export var lane_count: int = 5:
	set(v):
		lane_count = v
		queue_redraw()


func _draw() -> void:
	var total_w: float = lane_w * float(lane_count)
	var x0: float = center_x - total_w * 0.5 - 12.0
	var x1: float = center_x + total_w * 0.5 + 12.0
	var y: float = hit_y
	draw_rect(Rect2(x0, y - 22.0, x1 - x0, 44.0), Color(0.07, 0.075, 0.09))
	draw_rect(Rect2(x0, y - 22.0, x1 - x0, 4.0), Color(0.80, 0.83, 0.90))
	draw_rect(Rect2(x0, y + 18.0, x1 - x0, 4.0), Color(0.55, 0.58, 0.66))
	draw_rect(Rect2(x0, y - 18.0, x1 - x0, 3.0), Color(1.0, 1.0, 1.0, 0.07))
	draw_rect(Rect2(x0 - 6.0, y - 24.0, 8.0, 48.0), Color(1.0, 0.55, 0.12))
	draw_rect(Rect2(x1 - 2.0, y - 24.0, 8.0, 48.0), Color(1.0, 0.55, 0.12))
	var f: Font = font if font != null else ThemeDB.fallback_font
	for i in lane_count:
		var key_name: String = "?"
		var action: String = "lane_%d" % i
		if InputMap.has_action(action):
			var evs: Array[InputEvent] = InputMap.action_get_events(action)
			if evs.size() > 0 and evs[0] is InputEventKey:
				var k := evs[0] as InputEventKey
				var code: int = int(k.physical_keycode) if int(k.physical_keycode) != 0 else int(k.keycode)
				key_name = OS.get_keycode_string(code as Key)
		var cx: float = center_x + (float(i) - (float(lane_count) - 1.0) * 0.5) * lane_w
		var col: Color = LANE_COLORS[i % LANE_COLORS.size()]
		draw_string_outline(f, Vector2(cx - 30.0, y + 54.0), key_name, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 24, 6, Color(0.0, 0.0, 0.0, 0.9))
		draw_string(f, Vector2(cx - 30.0, y + 54.0), key_name, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 24, col)
