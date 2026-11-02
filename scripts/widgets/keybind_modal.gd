## keybind_modal.gd
## Ventana modal de CONTROLES del jugador 1: cada carril tiene una tecla y un botón de
## control, que funcionan a la vez. Se elige un carril y se presiona lo que se quiera
## asignar: si es una tecla cambia la tecla, si es un botón del control cambia el botón.
## Al final ACEPTAR guarda los cambios o CANCELAR los descarta.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

signal closed(applied: bool)

var _staged: Array[int] = []        # tecla de cada carril
var _staged_pad: Array[int] = []    # botón de control de cada carril
var _capturing: int = -1
var _tween: Tween = null

# Nodos de la escena keybind_modal.tscn
@onready var _panel: Panel = %Panel
@onready var _list: Control = %List
@onready var _hint: Label = %Hint


func _ready() -> void:
	RB.localize(self)
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_on_cancel)


func open() -> void:
	_staged.clear()
	_staged_pad.clear()
	for i in GameState.LANE_COUNT:
		_staged.append(GameState.get_lane_key(i))
		_staged_pad.append(GameState.get_lane_pad(i))
	_capturing = -1
	_rebuild_items(0)
	_hint.text = _idle_hint()
	visible = true
	_list.keyboard_enabled = true
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.92, 0.92)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _idle_hint() -> String:
	return RB.t("Elige un carril y presiona la tecla o el botón nuevo.", "Pick a lane and press the new key or button.")


func _item_text(lane: int) -> String:
	return "%s %d:   %s   ·   %s" % [RB.t("CARRIL", "LANE"), lane + 1, GameState.key_name(_staged[lane]), GameState.pad_name(_staged_pad[lane])]


func _show_row_message(msg: String) -> void:
	_list.set_item_text(_capturing, "%s %d:   %s" % [RB.t("CARRIL", "LANE"), _capturing + 1, msg])


func _rebuild_items(start_index: int) -> void:
	var rows: Array = []
	for i in GameState.LANE_COUNT:
		rows.append({"id": "lane_%d" % i, "text": _item_text(i)})
	rows.append({"id": "ok", "text": RB.t("ACEPTAR", "ACCEPT")})
	rows.append({"id": "cancel", "text": RB.t("CANCELAR", "CANCEL")})
	_list.set_items(rows, start_index, true)


func _on_activated(id: String) -> void:
	if _capturing >= 0:
		return
	if id == "ok":
		_apply()
	elif id == "cancel":
		_on_cancel()
	elif id.begins_with("lane_"):
		_capturing = int(id.substr(5))
		_list.keyboard_enabled = false
		_show_row_message(RB.t("¡PRESIONA UNA TECLA O BOTÓN!", "PRESS A KEY OR BUTTON!"))
		_hint.text = RB.t("Esc cancela el cambio de este carril.", "Esc cancels changing this lane.")


func _input(event: InputEvent) -> void:
	if not visible or _capturing < 0:
		return
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return
		get_viewport().set_input_as_handled()
		var btn: int = int(jb.button_index)
		for i in GameState.LANE_COUNT:
			if i != _capturing and _staged_pad[i] == btn:
				_show_row_message(RB.t("¡BOTÓN YA USADO!", "BUTTON ALREADY USED!"))
				_shake()
				return
		_staged_pad[_capturing] = btn
		_finish_capture(true)
		return
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = int(k.physical_keycode) if int(k.physical_keycode) != 0 else int(k.keycode)
	if code == KEY_ESCAPE:
		_finish_capture(false)
		return
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		return
	if GameState.is_p2_key(code):
		_show_row_message(RB.t("¡TECLA DEL JUGADOR 2!", "PLAYER 2 KEY!"))
		_shake()
		return
	for i in GameState.LANE_COUNT:
		if i != _capturing and _staged[i] == code:
			_show_row_message(RB.t("¡TECLA YA USADA!", "KEY ALREADY USED!"))
			_shake()
			return
	_staged[_capturing] = code
	_finish_capture(true)


func _finish_capture(_assigned: bool) -> void:
	var lane: int = _capturing
	_capturing = -1
	_list.set_item_text(lane, _item_text(lane))
	_list.keyboard_enabled = true
	_hint.text = _idle_hint()


func _shake() -> void:
	var base: Vector2 = (get_viewport_rect().size - _panel.size) * 0.5
	var tw := create_tween()
	for i in 4:
		var off := Vector2(8.0 if i % 2 == 0 else -8.0, 0.0)
		tw.tween_property(_panel, "position", base + off, 0.04)
	tw.tween_property(_panel, "position", base, 0.04)


func _apply() -> void:
	for i in GameState.LANE_COUNT:
		GameState.set_lane_binding(i, _staged[i], _staged_pad[i])
	GameState.save_settings()
	_close(true)


func _on_cancel() -> void:
	if _capturing >= 0:
		return
	_close(false)


func _close(applied: bool) -> void:
	_list.keyboard_enabled = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await _tween.finished
	visible = false
	closed.emit(applied)
