## player_tab.gd
## Tarjeta metálica de jugador con ícono, nombre y franja amarilla inferior
## (como las pestañas de la parte baja de los menús de Rock Band).
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const ICON = preload("res://scripts/widgets/instrument_icon.gd")

var _icon: Control = null
var _name_lbl: Label = null
var _strip_lbl: Label = null
var _tab_width: float = 340.0


func setup(player_name: String, instrument: String, pill: String, strip_text: String, tab_width: float = 340.0) -> void:
	_tab_width = tab_width
	custom_minimum_size = Vector2(tab_width, 78.0)
	size = Vector2(tab_width, 78.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := Panel.new()
	body.position = Vector2(0.0, 10.0)
	body.size = Vector2(tab_width, 68.0)
	var sb := RB.box(Color(0.40, 0.41, 0.45), 0, Color(0.80, 0.82, 0.88), 0)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.border_width_top = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 8
	body.add_theme_stylebox_override("panel", sb)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	var shine := ColorRect.new()
	shine.color = Color(1.0, 1.0, 1.0, 0.10)
	shine.position = Vector2(8.0, 14.0)
	shine.size = Vector2(tab_width - 16.0, 14.0)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shine)

	_icon = ICON.new()
	_icon.instrument = instrument
	_icon.size = Vector2(54.0, 54.0)
	_icon.position = Vector2(8.0, 0.0)
	add_child(_icon)

	_name_lbl = RB.label(player_name, 26, Color.WHITE)
	_name_lbl.position = Vector2(72.0, 12.0)
	add_child(_name_lbl)

	var strip := Panel.new()
	strip.position = Vector2(0.0, 46.0)
	strip.size = Vector2(tab_width, 30.0)
	var ssb := RB.box(RB.GOLD, 0, RB.GOLD_BRIGHT, 0)
	ssb.border_width_top = 2
	strip.add_theme_stylebox_override("panel", ssb)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	var px: float = 74.0
	if pill != "":
		var pw: float = RB.text_width(pill, 13) + 16.0
		var pp := Panel.new()
		pp.add_theme_stylebox_override("panel", RB.box(Color(0.04, 0.04, 0.05), 6))
		pp.position = Vector2(px, 49.0)
		pp.size = Vector2(pw, 22.0)
		pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pl := RB.label(pill, 13, Color.WHITE)
		pl.position = Vector2(8.0, 2.0)
		pp.add_child(pl)
		add_child(pp)
		px += pw + 10.0
	_strip_lbl = RB.label(strip_text, 20, RB.INK)
	_strip_lbl.position = Vector2(px, 46.0)
	add_child(_strip_lbl)


func set_instrument(id: String) -> void:
	if _icon != null:
		_icon.instrument = id


func set_strip_text(text: String) -> void:
	if _strip_lbl != null:
		_strip_lbl.text = text
