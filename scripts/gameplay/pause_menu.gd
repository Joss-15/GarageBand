## pause_menu.gd
## Pausa de la partida: CONTINUAR (con cuenta regresiva 3-2-1), REINICIAR y
## SALIR AL MENÚ. Funciona con el árbol en pausa (process_mode = ALWAYS).
extends CanvasLayer

const RB = preload("res://scripts/core/rb_theme.gd")
const MENU_LIST = preload("res://scripts/widgets/rb_menu_list.gd")

signal resume_finished
signal restart_requested
signal quit_requested

var _dim: ColorRect = null
var _title: Label = null
var _list: Control = null
var _count: Label = null
var _counting: bool = false
var _bar: ColorRect = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.04, 0.68)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_bar = ColorRect.new()
	_bar.color = Color(0.10, 0.12, 0.22, 0.92)
	_bar.position = Vector2(0.0, 190.0)
	_bar.size = Vector2(1152.0, 270.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	var edge_top := ColorRect.new()
	edge_top.color = RB.GOLD
	edge_top.size = Vector2(1152.0, 3.0)
	_bar.add_child(edge_top)
	var edge_bottom := ColorRect.new()
	edge_bottom.color = RB.GOLD
	edge_bottom.position = Vector2(0.0, 267.0)
	edge_bottom.size = Vector2(1152.0, 3.0)
	_bar.add_child(edge_bottom)

	_title = RB.label(RB.t("PAUSA", "PAUSED"), 64, Color.WHITE)
	_title.position = Vector2(120.0, 214.0)
	add_child(_title)

	_list = MENU_LIST.new()
	_list.font_size = 44
	_list.row_height = 54.0
	_list.position = Vector2(130.0, 296.0)
	_list.size = Vector2(600.0, 170.0)
	add_child(_list)
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_start_countdown)
	_list.keyboard_enabled = false

	_count = RB.label("3", 160, Color.WHITE)
	_count.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_count.add_theme_constant_override("outline_size", 14)
	_count.size = Vector2(300.0, 200.0)
	_count.position = Vector2((1152.0 - 300.0) * 0.5, 224.0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.pivot_offset = _count.size * 0.5
	_count.visible = false
	add_child(_count)


func open() -> void:
	_counting = false
	_count.visible = false
	_title.visible = true
	_bar.visible = true
	_list.visible = true
	_dim.modulate.a = 0.0
	visible = true
	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.2)
	RB.slide_in(_bar, Vector2(0.0, 30.0), 0.0, 0.3)
	_list.set_items([
		{"id": "resume", "text": RB.t("CONTINUAR", "RESUME")},
		{"id": "restart", "text": RB.t("REINICIAR", "RESTART")},
		{"id": "quit", "text": RB.t("SALIR AL MENÚ", "QUIT TO MENU")},
	], 0, true)
	_list.keyboard_enabled = true


func _on_activated(id: String) -> void:
	if _counting:
		return
	match id:
		"resume":
			_start_countdown()
		"restart":
			_list.keyboard_enabled = false
			restart_requested.emit()
		"quit":
			_list.keyboard_enabled = false
			quit_requested.emit()


func _start_countdown() -> void:
	if _counting:
		return
	_counting = true
	_list.keyboard_enabled = false
	_title.visible = false
	_bar.visible = false
	_list.visible = false
	_count.visible = true
	_dim.color = Color(0.0, 0.0, 0.04, 0.45)
	var tw := create_tween()
	for n in [3, 2, 1]:
		tw.tween_callback(_show_number.bind(n))
		tw.tween_interval(0.7)
	tw.tween_callback(_finish_countdown)


func _show_number(n: int) -> void:
	_count.text = str(n)
	_count.scale = Vector2(1.5, 1.5)
	_count.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_count, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_count, "modulate:a", 0.35, 0.6)


func _finish_countdown() -> void:
	visible = false
	_dim.color = Color(0.0, 0.0, 0.04, 0.68)
	_counting = false
	resume_finished.emit()
