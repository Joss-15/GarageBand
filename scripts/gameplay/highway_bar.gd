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

## Teclas de símbolo: Godot las nombra con palabra ("Semicolon"), que no cabe en la barra.
const SYMBOLS := {
	KEY_SEMICOLON: "Ñ",
	KEY_COMMA: ",",
	KEY_PERIOD: ".",
	KEY_SLASH: "/",
	KEY_APOSTROPHE: "'",
}

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
## Prefijo de las acciones de entrada de este carril: "lane_" para el jugador 1 y
## "p2_lane_" para el jugador 2 (la letra de cada carril sale de esa acción).
@export var action_prefix: String = "lane_":
	set(v):
		action_prefix = v
		queue_redraw()


## Nombre de lo que se presiona en el carril i: el botón del control si hay un control
## conectado y la acción tiene botón; si no, la tecla. "?" si no tiene ninguno.
func key_label(i: int) -> String:
	var action: String = "%s%d" % [action_prefix, i]

	if not InputMap.has_action(action):
		return "?"

	var evs: Array[InputEvent] = InputMap.action_get_events(action)
	if evs.is_empty():
		return "?"

	# 1. Con un control conectado se muestra el botón (en el editor nunca hay control)
	var pad_connected: bool = not Engine.is_editor_hint() and not Input.get_connected_joypads().is_empty()
	for ev in evs:
		if pad_connected and ev is InputEventJoypadButton:
			var btn := (ev as InputEventJoypadButton).button_index
			match btn:
				JOY_BUTTON_A: return "A"
				JOY_BUTTON_B: return "B"
				JOY_BUTTON_X: return "X"
				JOY_BUTTON_Y: return "Y"
				JOY_BUTTON_LEFT_SHOULDER: return "LB"
				JOY_BUTTON_RIGHT_SHOULDER: return "RB"
				JOY_BUTTON_DPAD_LEFT: return "←"
				JOY_BUTTON_DPAD_RIGHT: return "→"
				JOY_BUTTON_DPAD_UP: return "↑"
				JOY_BUTTON_DPAD_DOWN: return "↓"
				_: return "PAD"

	# 2. Tecla del teclado (la Ñ del jugador 2 sale de SYMBOLS)
	var key_ev: InputEventKey = null
	for ev in evs:
		if ev is InputEventKey:
			key_ev = ev as InputEventKey
			break

	if key_ev != null:
		var code: int = int(key_ev.physical_keycode)
		if code != 0:
			if DisplayServer.get_name() != "headless":
				var mapped: int = int(DisplayServer.keyboard_get_keycode_from_physical(key_ev.physical_keycode))
				if mapped != 0:
					code = mapped
		else:
			code = int(key_ev.keycode)

		if SYMBOLS.has(code):
			return str(SYMBOLS[code])
		return OS.get_keycode_string(code as Key)

	return "?"
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
		var key_name: String = key_label(i)
		var cx: float = center_x + (float(i) - (float(lane_count) - 1.0) * 0.5) * lane_w
		var col: Color = LANE_COLORS[i % LANE_COLORS.size()]
		draw_string_outline(f, Vector2(cx - 30.0, y + 54.0), key_name, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 24, 6, Color(0.0, 0.0, 0.0, 0.9))
		draw_string(f, Vector2(cx - 30.0, y + 54.0), key_name, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 24, col)
