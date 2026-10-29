## pause_menu.gd
## Pausa de la partida: CONTINUAR (con cuenta regresiva 3-2-1), REINICIAR y
## SALIR AL MENÚ. Funciona con el árbol en pausa (process_mode = ALWAYS).
extends CanvasLayer

const RB = preload("res://scripts/core/rb_theme.gd")

signal resume_finished
signal restart_requested
signal quit_requested

var _counting: bool = false

# Nodos de la escena pause_menu.tscn
@onready var _dim: ColorRect = %Dim
@onready var _bar: ColorRect = %Bar
@onready var _title: Label = %Title
@onready var _list: Control = %List
@onready var _count: Label = %Count


func _ready() -> void:
	RB.localize(self)
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_start_countdown)


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
