## rb_menu_list.gd
## Lista vertical de opciones estilo menú de Rock Band: texto grande en negrita y
## una "losa" amarilla que se desliza suavemente hacia la opción seleccionada.
## Teclado (↑ ↓ Enter Esc) y mouse (hover + clic). `indent_step` produce la
## sangría escalonada de los submenús en cascada.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

signal activated(id: String)
signal selection_changed(index: int)
signal cancelled

@export var font_size: int = 60
@export var row_height: float = 66.0
@export var indent_step: float = 0.0
@export var keyboard_enabled: bool = true
## Si es mayor que 0, la losa ocupa siempre este ancho (listas con columnas).
@export var slab_width: float = 0.0
@export var slab_pad: float = 18.0
@export var text_color: Color = Color(0.80, 0.81, 0.84)
@export var text_color_selected: Color = Color(0.06, 0.06, 0.06)

## Cada elemento: { "id": String, "text": String }
var items: Array = []
var selected: int = 0

var _labels: Array[Label] = []
var _slab: Panel = null
var _slab_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_slab()


func _ensure_slab() -> void:
	if _slab != null:
		return
	_slab = Panel.new()
	_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slab.add_theme_stylebox_override("panel", RB.box(RB.GOLD, 5, RB.GOLD_BRIGHT, 2))
	add_child(_slab)
	move_child(_slab, 0)


func set_items(new_items: Array, start_index: int = 0, animate: bool = true) -> void:
	_ensure_slab()
	items = new_items
	selected = clampi(start_index, 0, maxi(items.size() - 1, 0))
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for i in items.size():
		var it: Dictionary = items[i]
		var lbl := Label.new()
		lbl.text = str(it.get("text", ""))
		lbl.add_theme_font_override("font", RB.font(true))
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", text_color)
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(lbl)
		lbl.size = lbl.get_minimum_size()
		lbl.position = Vector2(indent_step * float(i), row_height * float(i) + (row_height - lbl.size.y) * 0.5)
		lbl.mouse_entered.connect(_on_hover.bind(i))
		lbl.gui_input.connect(_on_label_input.bind(i))
		_labels.append(lbl)
	_apply_selection(false)
	if animate:
		_play_intro()


func selected_id() -> String:
	if selected < 0 or selected >= items.size():
		return ""
	return str((items[selected] as Dictionary).get("id", ""))


func set_item_text(index: int, text: String) -> void:
	if index < 0 or index >= _labels.size():
		return
	var it: Dictionary = items[index]
	it["text"] = text
	_labels[index].text = text
	_labels[index].size = _labels[index].get_minimum_size()
	if index == selected:
		_apply_selection(false)


func label_at(index: int) -> Label:
	if index < 0 or index >= _labels.size():
		return null
	return _labels[index]


func move_selection(dir: int) -> void:
	if items.is_empty():
		return
	selected = posmod(selected + dir, items.size())
	_apply_selection(true)
	selection_changed.emit(selected)


func _apply_selection(animate: bool) -> void:
	for i in _labels.size():
		var col: Color = text_color_selected if i == selected else text_color
		_labels[i].add_theme_color_override("font_color", col)
	if _labels.is_empty():
		_slab.visible = false
		return
	_slab.visible = true
	var lbl: Label = _labels[selected]
	var sx: float = 0.0 if slab_width > 0.0 else lbl.position.x - slab_pad
	var sw: float = slab_width if slab_width > 0.0 else lbl.size.x + slab_pad * 2.0
	var target_pos := Vector2(sx, row_height * float(selected))
	var target_size := Vector2(sw, row_height)
	if _slab_tween != null and _slab_tween.is_valid():
		_slab_tween.kill()
	if animate:
		_slab_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slab_tween.tween_property(_slab, "position", target_pos, 0.2)
		_slab_tween.tween_property(_slab, "size", target_size, 0.2)
	else:
		_slab.position = target_pos
		_slab.size = target_size


func _play_intro() -> void:
	for i in _labels.size():
		var lbl: Label = _labels[i]
		var base: Vector2 = lbl.position
		lbl.position = base + Vector2(-70.0, 0.0)
		lbl.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(lbl, "position", base, 0.45).set_delay(0.07 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.3).set_delay(0.07 * float(i))
	_slab.modulate.a = 0.0
	create_tween().tween_property(_slab, "modulate:a", 1.0, 0.35).set_delay(0.07 * float(selected))


func _flash() -> void:
	_slab.modulate = Color(1.8, 1.8, 1.3, 1.0)
	create_tween().tween_property(_slab, "modulate", Color.WHITE, 0.28)


func _activate() -> void:
	if items.is_empty():
		return
	_flash()
	activated.emit(selected_id())


func _on_hover(i: int) -> void:
	if i == selected:
		return
	selected = i
	_apply_selection(true)
	selection_changed.emit(selected)


func _on_label_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if i != selected:
				selected = i
				_apply_selection(true)
				selection_changed.emit(selected)
			_activate()


func _unhandled_input(event: InputEvent) -> void:
	if not keyboard_enabled or not is_visible_in_tree() or items.is_empty():
		return
	if event.is_action_pressed("ui_down"):
		move_selection(1)
	elif event.is_action_pressed("ui_up"):
		move_selection(-1)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		cancelled.emit()
	else:
		return
	get_viewport().set_input_as_handled()
