## keybind_modal.gd
## Ventana modal para reasignar las 5 teclas de los carriles.
## Se elige un carril, se presiona la tecla nueva y al final ACEPTAR guarda
## los cambios o CANCELAR los descarta.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const MENU_LIST = preload("res://scripts/widgets/rb_menu_list.gd")

signal closed(applied: bool)

var _staged: Array[int] = []
var _capturing: int = -1
var _panel: Panel = null
var _list: Control = null
var _hint: Label = null
var _tween: Tween = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vp: Vector2 = get_viewport_rect().size
	_panel = Panel.new()
	_panel.size = Vector2(620.0, 470.0)
	_panel.position = (vp - _panel.size) * 0.5
	var sb := RB.box(Color(0.05, 0.06, 0.11, 0.97), 14, RB.GOLD, 3)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var title := RB.label(RB.t("TECLAS", "KEY BINDINGS"), 38, Color.WHITE)
	title.position = Vector2(34.0, 18.0)
	_panel.add_child(title)

	var bar := ColorRect.new()
	bar.color = Color(0.78, 0.08, 0.08)
	bar.position = Vector2(34.0, 72.0)
	bar.size = Vector2(552.0, 3.0)
	_panel.add_child(bar)

	_list = MENU_LIST.new()
	_list.font_size = 30
	_list.row_height = 44.0
	_list.slab_width = 552.0
	_list.slab_pad = 0.0
	_list.position = Vector2(34.0, 88.0)
	_list.size = Vector2(552.0, 320.0)
	_panel.add_child(_list)
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_on_cancel)

	_hint = RB.label("", 16, RB.GRAY_TXT, false, true)
	_hint.position = Vector2(34.0, 428.0)
	_panel.add_child(_hint)


func open() -> void:
	_staged.clear()
	for i in GameState.LANE_COUNT:
		_staged.append(GameState.get_lane_key(i))
	_capturing = -1
	_rebuild_items(0)
	_hint.text = RB.t("Elige un carril y presiona la tecla nueva.", "Pick a lane and press the new key.")
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


func _key_name(code: int) -> String:
	if code <= 0:
		return "?"
	return OS.get_keycode_string(code as Key)


func _item_text(lane: int) -> String:
	return "%s %d:    %s" % [RB.t("CARRIL", "LANE"), lane + 1, _key_name(_staged[lane])]


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
		_list.set_item_text(_capturing, "%s %d:    %s" % [RB.t("CARRIL", "LANE"), _capturing + 1, RB.t("¡PRESIONA UNA TECLA!", "PRESS A KEY!")])
		_hint.text = RB.t("Esc cancela el cambio de esta tecla.", "Esc cancels changing this key.")


func _input(event: InputEvent) -> void:
	if not visible or _capturing < 0:
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
	for i in GameState.LANE_COUNT:
		if i != _capturing and _staged[i] == code:
			_list.set_item_text(_capturing, "%s %d:    %s" % [RB.t("CARRIL", "LANE"), _capturing + 1, RB.t("¡TECLA YA USADA!", "KEY ALREADY USED!")])
			_shake()
			return
	_staged[_capturing] = code
	_finish_capture(true)


func _finish_capture(_assigned: bool) -> void:
	var lane: int = _capturing
	_capturing = -1
	_list.set_item_text(lane, _item_text(lane))
	_list.keyboard_enabled = true
	_hint.text = RB.t("Elige un carril y presiona la tecla nueva.", "Pick a lane and press the new key.")


func _shake() -> void:
	var base: Vector2 = (get_viewport_rect().size - _panel.size) * 0.5
	var tw := create_tween()
	for i in 4:
		var off := Vector2(8.0 if i % 2 == 0 else -8.0, 0.0)
		tw.tween_property(_panel, "position", base + off, 0.04)
	tw.tween_property(_panel, "position", base, 0.04)


func _apply() -> void:
	for i in GameState.LANE_COUNT:
		GameState.set_lane_key(i, _staged[i])
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
