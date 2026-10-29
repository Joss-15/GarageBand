## rb_menu_list.gd
## Lista vertical de opciones estilo menú de Rock Band: texto grande en negrita y
## una "losa" amarilla que se desliza suavemente hacia la opción seleccionada.
## Teclado (↑ ↓ Enter Esc) y mouse (hover + clic). `indent_step` produce la
## sangría escalonada de los submenús en cascada.
##
## Con `carousel = true` la lista funciona como carrusel: la opción seleccionada
## queda fija en el centro y las demás giran alrededor (más pequeñas y tenues),
## así que nunca se sale del espacio asignado sin importar cuántas opciones haya.
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
## Margen izquierdo del texto dentro de la fila (para dejar espacio a un ícono propio).
## Solo aplica al modo lista; la losa no se mueve.
@export var text_padding_left: float = 0.0
@export var text_color: Color = Color(0.80, 0.81, 0.84)
@export var text_color_selected: Color = Color(0.06, 0.06, 0.06)

## ── Modo carrusel ──
@export var carousel: bool = false
## Ancho de la columna donde se centran las opciones.
@export var carousel_width: float = 620.0
## Altura (coordenada local) del centro, donde se detiene la opción seleccionada.
@export var carousel_center_y: float = 120.0
## Separación entre la opción central y sus vecinas inmediatas.
@export var carousel_spacing: float = 58.0
## Cuántas opciones se muestran a cada lado del centro.
@export var carousel_range: int = 2
## Alineación del texto en el carrusel (true = a la izquierda, false = centrado).
@export var carousel_align_left: bool = true
@export var carousel_margin_left: float = 18.0
## Si es false la selección no da la vuelta: la lista tiene inicio y fin.
@export var wrap_around: bool = true

## Cada elemento: { "id": String, "text": String }
var items: Array = []
var selected: int = 0

var _labels: Array[Label] = []
var _prev_d: Array[int] = []
var _lbl_tweens: Array = []
var _slab: Panel = null   # la losa amarilla es el nodo "Slab" de la escena rb_menu_list.tscn
var _slab_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_slab()


func _ensure_slab() -> void:
	if _slab == null:
		_slab = $Slab as Panel


func set_items(new_items: Array, start_index: int = 0, animate: bool = true) -> void:
	_ensure_slab()
	items = new_items
	selected = clampi(start_index, 0, maxi(items.size() - 1, 0))
	for l in _labels:
		l.queue_free()
	for old in _lbl_tweens:
		var old_tw: Tween = old as Tween
		if old_tw != null and old_tw.is_valid():
			old_tw.kill()
	_labels.clear()
	_prev_d.clear()
	_lbl_tweens.clear()
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
		lbl.position = Vector2(indent_step * float(i) + text_padding_left, row_height * float(i) + (row_height - lbl.size.y) * 0.5)
		lbl.mouse_entered.connect(_on_hover.bind(i))
		lbl.gui_input.connect(_on_label_input.bind(i))
		_labels.append(lbl)
		_prev_d.append(0)
		_lbl_tweens.append(null)
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
	if index == selected or carousel:
		_apply_selection(false)


func label_at(index: int) -> Label:
	if index < 0 or index >= _labels.size():
		return null
	return _labels[index]


func move_selection(dir: int) -> void:
	if items.is_empty():
		return
	var next: int = posmod(selected + dir, items.size()) if wrap_around else clampi(selected + dir, 0, items.size() - 1)
	if next == selected:
		_bump(dir)
		return
	selected = next
	_apply_selection(true)
	selection_changed.emit(selected)


## Pequeño empujón de la losa cuando se intenta pasar del inicio o del final.
func _bump(dir: int) -> void:
	if _slab == null or not _slab.visible:
		return
	if _slab_tween != null and _slab_tween.is_valid():
		return
	var base: Vector2 = _slab.position
	var nudge := Vector2(0.0, 5.0 * float(signi(dir)))
	_slab_tween = create_tween()
	_slab_tween.tween_property(_slab, "position", base + nudge, 0.06).set_trans(Tween.TRANS_SINE)
	_slab_tween.tween_property(_slab, "position", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_selection(animate: bool) -> void:
	for i in _labels.size():
		var col: Color = text_color_selected if i == selected else text_color
		_labels[i].add_theme_color_override("font_color", col)
	if _labels.is_empty():
		_slab.visible = false
		return
	_slab.visible = true
	var lbl: Label = _labels[selected]
	var target_pos: Vector2
	var target_size: Vector2
	if carousel:
		_layout_carousel(animate)
		var cw: float = slab_width if slab_width > 0.0 else lbl.size.x + slab_pad * 2.0
		var sx0: float = carousel_margin_left - slab_pad if carousel_align_left else (carousel_width - cw) * 0.5
		target_pos = Vector2(sx0, carousel_center_y - row_height * 0.5)
		target_size = Vector2(cw, row_height)
	else:
		var sx: float = 0.0 if slab_width > 0.0 else lbl.position.x - text_padding_left - slab_pad
		var sw: float = slab_width if slab_width > 0.0 else lbl.size.x + text_padding_left + slab_pad * 2.0
		target_pos = Vector2(sx, row_height * float(selected))
		target_size = Vector2(sw, row_height)
	if _slab_tween != null and _slab_tween.is_valid():
		_slab_tween.kill()
	if animate:
		_slab_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slab_tween.tween_property(_slab, "position", target_pos, 0.2)
		_slab_tween.tween_property(_slab, "size", target_size, 0.2)
	else:
		_slab.position = target_pos
		_slab.size = target_size


# ── Carrusel ─────────────────────────────────────────────────────────────────

## Distancia de la opción i a la seleccionada (negativa = arriba).
func _carousel_offset(i: int) -> int:
	return i - selected


func _carousel_scale(a: int) -> float:
	if a == 0:
		return 1.0
	if a == 1:
		return 0.82
	return 0.62


func _carousel_alpha(a: int) -> float:
	if a == 0:
		return 1.0
	if a == 1:
		return 0.75
	return 0.32


func _carousel_y_offset(d: int) -> float:
	var a: int = absi(d)
	var off: float = 0.0
	if a >= 1:
		off += carousel_spacing
	if a >= 2:
		off += carousel_spacing * 0.8
	return off if d >= 0 else -off


## Coloca (o anima) cada opción según su distancia al centro. Las que quedan
## fuera del rango visible se desvanecen. Si un salto largo (lista con wrap)
## mueve una opción de un extremo al otro, se desvanece en vez de cruzar la columna.
func _layout_carousel(animate: bool) -> void:
	for i in _labels.size():
		var lbl: Label = _labels[i]
		var d: int = _carousel_offset(i)
		var a: int = absi(d)
		var in_range: bool = a <= carousel_range
		var sc: float = _carousel_scale(a)
		var alpha: float = _carousel_alpha(a) if in_range else 0.0
		var tx: float = carousel_margin_left if carousel_align_left else (carousel_width - lbl.size.x) * 0.5
		var target_pos := Vector2(tx, carousel_center_y + _carousel_y_offset(d) - lbl.size.y * 0.5)
		var target_scale := Vector2(sc, sc)
		lbl.pivot_offset = Vector2(0.0, lbl.size.y * 0.5) if carousel_align_left else lbl.size * 0.5
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP if in_range else Control.MOUSE_FILTER_IGNORE
		var old_tw: Tween = _lbl_tweens[i] as Tween
		if old_tw != null and old_tw.is_valid():
			old_tw.kill()
		var jump: bool = absi(d - _prev_d[i]) > 2
		_prev_d[i] = d
		if not animate:
			lbl.position = target_pos
			lbl.scale = target_scale
			lbl.modulate.a = alpha
		elif jump:
			lbl.position = target_pos
			lbl.scale = target_scale
			lbl.modulate.a = 0.0
			var fade := create_tween()
			fade.tween_property(lbl, "modulate:a", alpha, 0.25)
			_lbl_tweens[i] = fade
		else:
			var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(lbl, "position", target_pos, 0.24)
			tw.tween_property(lbl, "scale", target_scale, 0.24)
			tw.tween_property(lbl, "modulate:a", alpha, 0.24)
			_lbl_tweens[i] = tw


func _play_intro() -> void:
	if carousel:
		for i in _labels.size():
			var cl: Label = _labels[i]
			var target_a: float = cl.modulate.a
			cl.modulate.a = 0.0
			var ctw := create_tween()
			ctw.tween_property(cl, "modulate:a", target_a, 0.3).set_delay(0.06 * float(i))
			_lbl_tweens[i] = ctw
		_slab.modulate.a = 0.0
		create_tween().tween_property(_slab, "modulate:a", 1.0, 0.35)
		return
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
	# En el carrusel las opciones se mueven bajo el cursor: no se selecciona al pasar.
	if carousel or i == selected:
		return
	selected = i
	_apply_selection(true)
	selection_changed.emit(selected)


func _on_label_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if carousel and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		move_selection(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if i != selected:
		selected = i
		_apply_selection(true)
		selection_changed.emit(selected)
		if carousel:
			return   # en el carrusel el primer clic solo centra la opción
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
