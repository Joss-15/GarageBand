## results.gd
## Fin de canción: arriba el título y los puntos totales con estrellas; a la
## izquierda la tarjeta del jugador (precisión, instrumento, rango y puntos);
## a la derecha la tabla de posiciones local (SQLite) con guardado de nombre.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const BACKDROP = preload("res://scripts/widgets/rb_backdrop.gd")
const ICON = preload("res://scripts/widgets/instrument_icon.gd")
const RATING = preload("res://scripts/widgets/rating_row.gd")

const BOARD_POS := Vector2(410.0, 176.0)
const BOARD_SIZE := Vector2(700.0, 350.0)


## Rombos tenues para el banner superior.
class Pattern extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var step: float = 36.0
		var cols: int = int(size.x / step) + 2
		var rows: int = int(size.y / step) + 2
		var col := Color(0.5, 0.7, 1.0, 0.07)
		for ix in cols:
			for iy in rows:
				var p := Vector2(float(ix) * step, float(iy) * step)
				draw_line(p + Vector2(0.0, step * 0.5), p + Vector2(step * 0.5, 0.0), col, 1.0)
				draw_line(p + Vector2(step * 0.5, 0.0), p + Vector2(step, step * 0.5), col, 1.0)
				draw_line(p + Vector2(step, step * 0.5), p + Vector2(step * 0.5, step), col, 1.0)
				draw_line(p + Vector2(step * 0.5, step), p + Vector2(0.0, step * 0.5), col, 1.0)


## Medallón decorativo que gira lentamente.
class Medallion extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(88.0, 88.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r, Color(0.04, 0.10, 0.35))
		draw_arc(c, r, 0.0, TAU, 48, Color(0.75, 0.88, 1.0), 3.0, true)
		draw_arc(c, r * 0.72, 0.0, TAU, 40, Color(0.40, 0.70, 1.0), 2.0, true)
		for i in 16:
			var a: float = TAU * float(i) / 16.0
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.86, 2.6, Color(0.85, 0.93, 1.0))
		draw_circle(c, r * 0.42, Color(0.10, 0.55, 0.95))
		draw_circle(c, r * 0.22, Color(0.80, 0.90, 1.0))


var _score_lbl: Label = null
var _acc_lbl: Label = null
var _stars_top: Control = null
var _stars_card: Control = null
var _rank_bar: Control = null
var _score_card_lbl: Label = null
var _board_rows: Control = null
var _name_edit: LineEdit = null
var _save_btn: Button = null
var _saved: bool = false
var _leaving: bool = false


func _ready() -> void:
	var backdrop := BACKDROP.new()
	backdrop.tint = Color(0.12, 0.22, 0.70)
	backdrop.photo_brightness = 0.32
	backdrop.with_fireflies = false
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_banner()
	_build_card()
	_build_board()
	_build_bottom_bar()
	_load_leaderboard()
	_animate_in()


# ── Construcción ─────────────────────────────────────────────────────────────

func _build_banner() -> void:
	var banner := TextureRect.new()
	banner.texture = RB.v_gradient(Color(0.02, 0.07, 0.34, 0.97), Color(0.01, 0.03, 0.17, 0.97))
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	banner.size = Vector2(1152.0, 150.0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	var pat := Pattern.new()
	pat.size = banner.size
	banner.add_child(pat)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.90, 1.0, 0.9)
	line.position = Vector2(0.0, 148.0)
	line.size = Vector2(1152.0, 2.0)
	banner.add_child(line)

	var title_text: String = GameState.selected_song_title
	if title_text == "":
		title_text = GameState.selected_song_name
	var title := RB.label(title_text.to_upper(), 44, Color(0.94, 0.95, 0.98))
	title.position = Vector2(0.0, 14.0)
	title.size = Vector2(1152.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var row := HBoxContainer.new()
	row.position = Vector2(0.0, 84.0)
	row.size = Vector2(1152.0, 56.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var badge := Panel.new()
	badge.add_theme_stylebox_override("panel", RB.box(Color(0.05, 0.05, 0.08), 3, Color(0.92, 0.92, 0.97), 2))
	badge.custom_minimum_size = Vector2(48.0, 48.0)
	var bl := RB.label("GB", 20, Color.WHITE)
	bl.position = Vector2(8.0, 10.0)
	badge.add_child(bl)
	row.add_child(badge)
	_score_lbl = RB.label("0", 54, Color.WHITE)
	row.add_child(_score_lbl)
	_stars_top = RATING.new()
	_stars_top.count = 5
	_stars_top.item_size = 30.0
	row.add_child(_stars_top)

	var med := Medallion.new()
	med.position = Vector2(1030.0, 28.0)
	med.size = Vector2(88.0, 88.0)
	add_child(med)
	med.pivot_offset = med.size * 0.5
	create_tween().set_loops().tween_property(med, "rotation", TAU, 16.0).from(0.0)

	RB.slide_in(title, Vector2(0.0, -30.0), 0.0, 0.5)
	RB.slide_in(row, Vector2(0.0, -20.0), 0.12, 0.5)


func _build_card() -> void:
	var acc: float = GameState.last_accuracy
	var inst: String = GameState.last_instrument

	var block := Panel.new()
	block.add_theme_stylebox_override("panel", RB.box(Color(0.08, 0.26, 0.36, 0.92), 0, Color(0.50, 0.75, 0.85), 2))
	block.position = Vector2(50.0, 176.0)
	block.size = Vector2(330.0, 152.0)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(block)
	_acc_lbl = RB.label("0%", 84, Color.WHITE)
	_acc_lbl.position = Vector2(22.0, -2.0)
	block.add_child(_acc_lbl)
	var inst_lbl := RB.label(RB.instrument_name(inst), 28, Color(0.88, 0.92, 0.98))
	inst_lbl.position = Vector2(24.0, 86.0)
	block.add_child(inst_lbl)
	_rank_bar = Panel.new()
	_rank_bar.add_theme_stylebox_override("panel", RB.box(RB.rank_color(acc), 0))
	_rank_bar.position = Vector2(0.0, 118.0)
	_rank_bar.size = Vector2(330.0, 34.0)
	_rank_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rank_lbl := RB.label(RB.rank_text(acc), 22, Color.WHITE)
	rank_lbl.size = Vector2(330.0, 34.0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rank_bar.add_child(rank_lbl)
	block.add_child(_rank_bar)

	var combo := RB.label("%s  x%d" % [RB.t("COMBO MÁXIMO", "MAX COMBO"), GameState.last_max_combo], 20, RB.WHITE_SOFT)
	combo.position = Vector2(54.0, 338.0)
	add_child(combo)
	var notes := RB.label("%s  %d / %d" % [RB.t("NOTAS", "NOTES"), GameState.last_hit_notes, GameState.last_total_notes], 20, RB.WHITE_SOFT)
	notes.position = Vector2(54.0, 368.0)
	add_child(notes)

	var solo := Panel.new()
	solo.add_theme_stylebox_override("panel", RB.box(Color(0.03, 0.05, 0.10, 0.92), 0, RB.GOLD, 3))
	solo.position = Vector2(50.0, 406.0)
	solo.size = Vector2(330.0, 124.0)
	solo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(solo)
	var cap := RB.label(RB.t("PUNTOS", "SCORE"), 18, RB.GRAY_TXT)
	cap.position = Vector2(0.0, 8.0)
	cap.size = Vector2(330.0, 24.0)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	solo.add_child(cap)
	var icon := ICON.new()
	icon.instrument = inst
	icon.size = Vector2(46.0, 46.0)
	icon.position = Vector2(34.0, 40.0)
	solo.add_child(icon)
	_score_card_lbl = RB.label("0", 44, Color(0.55, 0.85, 0.95))
	_score_card_lbl.position = Vector2(92.0, 38.0)
	_score_card_lbl.size = Vector2(222.0, 52.0)
	solo.add_child(_score_card_lbl)
	_stars_card = RATING.new()
	_stars_card.count = 5
	_stars_card.item_size = 24.0
	_stars_card.position = Vector2(88.0, 92.0)
	solo.add_child(_stars_card)

	RB.slide_in(block, Vector2(-60.0, 0.0), 0.15, 0.5)
	RB.slide_in(combo, Vector2(-60.0, 0.0), 0.22, 0.5)
	RB.slide_in(notes, Vector2(-60.0, 0.0), 0.26, 0.5)
	RB.slide_in(solo, Vector2(-60.0, 0.0), 0.30, 0.5)


func _build_board() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", RB.box(Color(0.02, 0.03, 0.08, 0.80), 0, Color(0.42, 0.46, 0.60), 2))
	panel.position = BOARD_POS
	panel.size = BOARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var title := RB.label(RB.t("TABLA DE POSICIONES", "LEADERBOARD"), 24, Color.WHITE)
	title.position = Vector2(18.0, 10.0)
	panel.add_child(title)

	var heads: Array = [
		["#", 14.0, 36.0, HORIZONTAL_ALIGNMENT_LEFT],
		[RB.t("JUGADOR", "PLAYER"), 56.0, 210.0, HORIZONTAL_ALIGNMENT_LEFT],
		[RB.t("PUNTOS", "SCORE"), 270.0, 130.0, HORIZONTAL_ALIGNMENT_RIGHT],
		["%", 410.0, 80.0, HORIZONTAL_ALIGNMENT_RIGHT],
		["COMBO", 500.0, 80.0, HORIZONTAL_ALIGNMENT_RIGHT],
		[RB.t("FECHA", "DATE"), 596.0, 100.0, HORIZONTAL_ALIGNMENT_LEFT],
	]
	for h in heads:
		var ha: Array = h
		var hl := RB.label(str(ha[0]), 14, RB.GRAY_TXT)
		hl.position = Vector2(float(ha[1]), 48.0)
		hl.size = Vector2(float(ha[2]), 20.0)
		hl.horizontal_alignment = int(ha[3]) as HorizontalAlignment
		panel.add_child(hl)
	var sep := ColorRect.new()
	sep.color = Color(0.42, 0.46, 0.60, 0.8)
	sep.position = Vector2(12.0, 70.0)
	sep.size = Vector2(BOARD_SIZE.x - 24.0, 1.0)
	panel.add_child(sep)

	_board_rows = Control.new()
	_board_rows.position = Vector2(0.0, 76.0)
	_board_rows.size = Vector2(BOARD_SIZE.x, 270.0)
	_board_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_board_rows)

	# Nombre y guardado
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = RB.t("Tu nombre", "Your name")
	_name_edit.max_length = 16
	_name_edit.position = Vector2(BOARD_POS.x, 536.0)
	_name_edit.size = Vector2(340.0, 40.0)
	_name_edit.add_theme_font_override("font", RB.font(true))
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_stylebox_override("normal", RB.box(Color(0.04, 0.05, 0.09, 0.95), 4, Color(0.5, 0.52, 0.6), 2))
	_name_edit.add_theme_stylebox_override("focus", RB.box(Color(0.06, 0.07, 0.12, 0.98), 4, RB.GOLD, 2))
	if GameState.player1_name != "P1":
		_name_edit.text = GameState.player1_name
	_name_edit.text_submitted.connect(_on_name_submitted)
	add_child(_name_edit)

	_save_btn = Button.new()
	_save_btn.text = RB.t("GUARDAR PUNTAJE", "SAVE SCORE")
	_save_btn.position = Vector2(BOARD_POS.x + 354.0, 536.0)
	_save_btn.size = Vector2(230.0, 40.0)
	_save_btn.focus_mode = Control.FOCUS_NONE
	_save_btn.add_theme_font_override("font", RB.font(true))
	_save_btn.add_theme_font_size_override("font_size", 20)
	_save_btn.add_theme_color_override("font_color", RB.INK)
	_save_btn.add_theme_color_override("font_hover_color", RB.INK)
	_save_btn.add_theme_color_override("font_pressed_color", RB.INK)
	_save_btn.add_theme_color_override("font_disabled_color", Color(0.75, 0.76, 0.8))
	_save_btn.add_theme_stylebox_override("normal", RB.box(RB.GOLD, 5, RB.GOLD_BRIGHT, 2))
	_save_btn.add_theme_stylebox_override("hover", RB.box(RB.GOLD_BRIGHT, 5, Color.WHITE, 2))
	_save_btn.add_theme_stylebox_override("pressed", RB.box(Color(0.70, 0.65, 0.05), 5))
	_save_btn.add_theme_stylebox_override("disabled", RB.box(Color(0.30, 0.31, 0.36), 5))
	_save_btn.pressed.connect(_on_save_pressed)
	add_child(_save_btn)

	RB.slide_in(panel, Vector2(60.0, 0.0), 0.2, 0.55)
	RB.slide_in(_name_edit, Vector2(0.0, 30.0), 0.4, 0.45)
	RB.slide_in(_save_btn, Vector2(0.0, 30.0), 0.45, 0.45)


func _build_bottom_bar() -> void:
	var bar := TextureRect.new()
	bar.texture = RB.h_gradient(Color(0.0, 0.14, 0.62), Color(0.04, 0.05, 0.30))
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.position = Vector2(0.0, 588.0)
	bar.size = Vector2(1152.0, 60.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var pat := Pattern.new()
	pat.size = bar.size
	bar.add_child(pat)
	var hx: float = 40.0
	hx += RB.add_hint(bar, Vector2(hx, 14.0), Color(0.15, 0.80, 0.25), "ENTER", RB.t("CONTINUAR", "CONTINUE"), 22) + 60.0
	RB.add_hint(bar, Vector2(hx, 14.0), Color(0.95, 0.85, 0.10), "R", RB.t("REINICIAR", "RESTART"), 22)
	RB.slide_in(bar, Vector2(0.0, 60.0), 0.35, 0.5)


# ── Animación de entrada ─────────────────────────────────────────────────────

func _animate_in() -> void:
	var acc: float = GameState.last_accuracy
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(_show_score, 0.0, float(GameState.last_score), 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_show_accuracy, 0.0, acc * 100.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_reveal_stars)


func _show_score(v: float) -> void:
	var text: String = RB.fmt_int(int(roundf(v)))
	_score_lbl.text = text
	_score_card_lbl.text = text


func _show_accuracy(v: float) -> void:
	_acc_lbl.text = "%d%%" % int(roundf(v))


func _reveal_stars() -> void:
	var n: int = RB.stars_for(GameState.last_accuracy)
	_stars_top.reveal(n, 0.16)
	_stars_card.reveal(n, 0.16)
	_acc_lbl.text = "%.1f%%" % (GameState.last_accuracy * 100.0)
	RB.pop(_acc_lbl, 1.10, 0.3)
	_rank_bar.modulate = Color(1.7, 1.7, 1.7, 1.0)
	create_tween().tween_property(_rank_bar, "modulate", Color.WHITE, 0.5)


# ── Guardado y tabla de posiciones ───────────────────────────────────────────

func _db_ready() -> bool:
	return Database != null and Database.db != null


func _on_name_submitted(_text: String) -> void:
	_on_save_pressed()


func _on_save_pressed() -> void:
	if _saved:
		return
	var player_name: String = _name_edit.text.strip_edges()
	if player_name.is_empty():
		player_name = RB.t("Anónimo", "Anonymous")
	GameState.player1_name = player_name
	if not _db_ready():
		_save_btn.text = RB.t("SIN BASE DE DATOS", "NO DATABASE")
		return
	Database.save_score(
		player_name,
		GameState.selected_song_name,
		GameState.last_score,
		GameState.last_accuracy,
		GameState.last_max_combo,
		GameState.last_hit_notes,
		GameState.last_total_notes,
		GameState.two_player_mode
	)
	_saved = true
	_save_btn.text = RB.t("¡GUARDADO!", "SAVED!")
	_save_btn.disabled = true
	_name_edit.release_focus()
	_name_edit.editable = false
	_load_leaderboard()


func _load_leaderboard() -> void:
	for c in _board_rows.get_children():
		c.queue_free()
	if not _db_ready():
		var msg := RB.label(RB.t("La base de datos no está disponible.", "The database is not available."), 18, RB.GRAY_TXT, false)
		msg.position = Vector2(18.0, 12.0)
		_board_rows.add_child(msg)
		return
	var rows: Array = Database.get_top10(GameState.selected_song_name)
	if rows.is_empty():
		var empty := RB.label(RB.t("Sin registros aún. ¡Sé el primero!", "No records yet. Be the first!"), 18, RB.GRAY_TXT, false)
		empty.position = Vector2(18.0, 12.0)
		_board_rows.add_child(empty)
		return
	for i in rows.size():
		var data: Dictionary = rows[i]
		var row := Control.new()
		row.position = Vector2(0.0, float(i) * 27.0)
		row.size = Vector2(BOARD_SIZE.x, 26.0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mine: bool = str(data["player_name"]) == GameState.player1_name and int(data["score"]) == GameState.last_score and _saved
		if mine:
			var hl := ColorRect.new()
			hl.color = Color(0.20, 0.85, 0.45, 0.22)
			hl.position = Vector2(8.0, 0.0)
			hl.size = Vector2(BOARD_SIZE.x - 16.0, 26.0)
			hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(hl)
		var tc: Color = Color(0.55, 1.0, 0.70) if mine else RB.WHITE_SOFT
		_cell(row, "%d" % (i + 1), 14.0, 36.0, HORIZONTAL_ALIGNMENT_LEFT, tc)
		_cell(row, str(data["player_name"]), 56.0, 210.0, HORIZONTAL_ALIGNMENT_LEFT, tc)
		_cell(row, RB.fmt_int(int(data["score"])), 270.0, 130.0, HORIZONTAL_ALIGNMENT_RIGHT, tc)
		_cell(row, "%.1f%%" % (float(data["accuracy"]) * 100.0), 410.0, 80.0, HORIZONTAL_ALIGNMENT_RIGHT, tc)
		_cell(row, "x%d" % int(data["max_combo"]), 500.0, 80.0, HORIZONTAL_ALIGNMENT_RIGHT, tc)
		_cell(row, str(data["date"]), 596.0, 100.0, HORIZONTAL_ALIGNMENT_LEFT, RB.GRAY_TXT)
		_board_rows.add_child(row)
		RB.slide_in(row, Vector2(30.0, 0.0), 0.04 * float(i) + 0.3, 0.3)


func _cell(parent: Control, text: String, x: float, w: float, align: int, color: Color) -> void:
	var l := RB.label(text, 17, color)
	l.position = Vector2(x, 1.0)
	l.size = Vector2(w, 24.0)
	l.horizontal_alignment = align as HorizontalAlignment
	l.clip_text = true
	parent.add_child(l)


# ── Salida ───────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_leaving = true
		SceneFade.go("res://scenes/screens/song_select.tscn")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_R:
			_leaving = true
			SceneFade.go("res://scenes/gameplay/gameplay.tscn")
			get_viewport().set_input_as_handled()
