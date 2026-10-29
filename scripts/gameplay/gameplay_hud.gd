## gameplay_hud.gd
## Interfaz de la partida:
##  - izquierda: barra de rendimiento (el ícono del instrumento sube con la buena
##    precisión y baja con los fallos), título de la canción y dial de combo.
##  - derecha: puntos totales y barra de progreso con 00:00 y la duración.
##  - centro: juicios (PERFECTO / BIEN / REGULAR / FALLO) sobre el carril.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const ICON = preload("res://scripts/widgets/instrument_icon.gd")

const PERF_X := 40.0
const PERF_TOP := 262.0
const PERF_H := 264.0
const RIGHT_X := 830.0
const RIGHT_W := 288.0


## Dial circular que muestra el combo actual y su avance hacia el siguiente múltiplo de 10.
class ComboDial extends Control:
	const RB = preload("res://scripts/core/rb_theme.gd")
	var combo: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(76.0, 76.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_combo(c: int) -> void:
		var grew: bool = c > combo
		combo = c
		if grew and c > 0 and c % 10 == 0:
			pivot_offset = size * 0.5
			scale = Vector2(1.25, 1.25)
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 4.0
		draw_circle(c, r, Color(0.06, 0.07, 0.10, 0.92))
		draw_arc(c, r, 0.0, TAU, 48, Color(0.33, 0.34, 0.40), 4.0, true)
		var frac: float = float(combo % 10) / 10.0
		if combo > 0 and combo % 10 == 0:
			frac = 1.0
		if frac > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, RB.GOLD, 5.0, true)
		var txt: String = str(combo)
		var fs: int = 28 if combo < 100 else 22
		draw_string(RB.font(true), Vector2(0.0, c.y + float(fs) * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)


var _score_lbl: Label = null
var _acc_lbl: Label = null
var _prog_fill: Panel = null
var _dur_lbl: Label = null
var _perf_icon: Control = null
var _perf_clip: Control = null
var _perf_grad: TextureRect = null
var _dial: Control = null

var _duration: float = 1.0
var _perf: float = 0.5
var _perf_tween: Tween = null
var _score_shown: float = 0.0
var _score_target: int = 0
var _score_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(song_title: String, artist: String, instrument: String, duration: float) -> void:
	_duration = maxf(duration, 1.0)
	_build_performance_bar(instrument)
	_build_song_info(song_title, artist, instrument)
	_build_dial()
	_build_score_and_progress()
	var hint := RB.label(RB.t("ESC  PAUSA", "ESC  PAUSE"), 14, Color(0.5, 0.52, 0.58, 0.9))
	hint.position = Vector2(24.0, 618.0)
	add_child(hint)
	_apply_perf(_perf)


# ── Construcción ─────────────────────────────────────────────────────────────

func _build_performance_bar(instrument: String) -> void:
	var track := Panel.new()
	track.add_theme_stylebox_override("panel", RB.box(Color(0.05, 0.06, 0.09, 0.9), 6, Color(0.55, 0.57, 0.63), 2))
	track.position = Vector2(PERF_X, PERF_TOP)
	track.size = Vector2(12.0, PERF_H)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)

	_perf_clip = Control.new()
	_perf_clip.clip_contents = true
	_perf_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_perf_clip)
	var g := Gradient.new()
	g.set_color(0, Color(0.20, 0.90, 0.30))
	g.set_color(1, Color(0.90, 0.15, 0.15))
	g.add_point(0.5, Color(0.95, 0.85, 0.12))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	gt.width = 4
	gt.height = int(PERF_H)
	_perf_grad = TextureRect.new()
	_perf_grad.texture = gt
	_perf_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_perf_grad.stretch_mode = TextureRect.STRETCH_SCALE
	_perf_grad.size = Vector2(12.0, PERF_H)
	_perf_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_clip.add_child(_perf_grad)

	_perf_icon = ICON.new()
	_perf_icon.instrument = instrument
	_perf_icon.size = Vector2(46.0, 46.0)
	add_child(_perf_icon)


func _build_song_info(song_title: String, artist: String, instrument: String) -> void:
	var title := RB.label(song_title, 26, Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(92.0, 258.0)
	title.size = Vector2(240.0, 70.0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	var y: float = 258.0 + minf(title.get_minimum_size().y, 70.0) + 4.0
	if artist != "":
		var at := RB.label(artist, 19, Color(0.80, 0.82, 0.88), false, true)
		at.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		at.add_theme_constant_override("outline_size", 5)
		at.position = Vector2(92.0, y)
		add_child(at)
		y += 26.0
	var inst := RB.label(RB.instrument_name(instrument), 16, RB.GOLD)
	inst.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	inst.add_theme_constant_override("outline_size", 5)
	inst.position = Vector2(92.0, y)
	add_child(inst)


func _build_dial() -> void:
	_dial = ComboDial.new()
	_dial.position = Vector2(300.0, 420.0)
	_dial.size = Vector2(76.0, 76.0)
	add_child(_dial)
	var cl := RB.label("COMBO", 13, RB.GRAY_TXT)
	cl.position = Vector2(300.0, 498.0)
	cl.size = Vector2(76.0, 18.0)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(cl)


func _build_score_and_progress() -> void:
	var box := Panel.new()
	var sb := RB.box(Color(0.10, 0.11, 0.16, 0.92), 8, Color(0.78, 0.80, 0.86), 2)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 6
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(RIGHT_X, 262.0)
	box.size = Vector2(RIGHT_W, 58.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var cap := RB.label(RB.t("PUNTOS", "SCORE"), 13, RB.GRAY_TXT)
	cap.position = Vector2(RIGHT_X + 14.0, 268.0)
	add_child(cap)
	_score_lbl = RB.label("0", 38, Color.WHITE)
	_score_lbl.position = Vector2(RIGHT_X + 8.0, 272.0)
	_score_lbl.size = Vector2(RIGHT_W - 22.0, 44.0)
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score_lbl)

	_acc_lbl = RB.label("%s 100.0%%" % RB.t("PRECISIÓN", "ACCURACY"), 16, RB.GRAY_TXT)
	_acc_lbl.position = Vector2(RIGHT_X + 4.0, 326.0)
	add_child(_acc_lbl)

	var track := Panel.new()
	track.add_theme_stylebox_override("panel", RB.box(Color(0.06, 0.07, 0.10, 0.92), 5, Color(0.55, 0.57, 0.63), 2))
	track.position = Vector2(RIGHT_X, 356.0)
	track.size = Vector2(RIGHT_W, 12.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	_prog_fill = Panel.new()
	_prog_fill.add_theme_stylebox_override("panel", RB.box(RB.GOLD, 4))
	_prog_fill.position = Vector2(RIGHT_X + 2.0, 358.0)
	_prog_fill.size = Vector2(0.0, 8.0)
	_prog_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prog_fill)

	var t0 := RB.label("00:00", 15, RB.GRAY_TXT)
	t0.position = Vector2(RIGHT_X, 372.0)
	add_child(t0)
	_dur_lbl = RB.label(RB.fmt_time(_duration), 15, RB.GRAY_TXT)
	_dur_lbl.position = Vector2(RIGHT_X + RIGHT_W - 100.0, 372.0)
	_dur_lbl.size = Vector2(100.0, 20.0)
	_dur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_dur_lbl)


# ── API ──────────────────────────────────────────────────────────────────────

func set_score(value: int) -> void:
	_score_target = value
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_show_score, _score_shown, float(value), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	RB.pop(_score_lbl, 1.06, 0.18)


func _show_score(v: float) -> void:
	_score_shown = v
	_score_lbl.text = RB.fmt_int(int(roundf(v)))


func set_accuracy(percent: float) -> void:
	_acc_lbl.text = "%s %.1f%%" % [RB.t("PRECISIÓN", "ACCURACY"), percent]


func set_combo(c: int) -> void:
	_dial.set_combo(c)


func set_progress(song_time: float) -> void:
	var ratio: float = clampf(song_time / _duration, 0.0, 1.0)
	_prog_fill.size.x = (RIGHT_W - 4.0) * ratio


## Rendimiento 0..1: sube el ícono con los aciertos y lo baja con los fallos.
func set_performance(v: float) -> void:
	if _perf_tween != null and _perf_tween.is_valid():
		_perf_tween.kill()
	_perf_tween = create_tween()
	_perf_tween.tween_method(_apply_perf, _perf, clampf(v, 0.0, 1.0), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_perf(v: float) -> void:
	_perf = v
	var fill_h: float = PERF_H * v
	_perf_clip.position = Vector2(PERF_X, PERF_TOP + PERF_H - fill_h)
	_perf_clip.size = Vector2(12.0, fill_h)
	_perf_grad.position = Vector2(0.0, -(PERF_H - fill_h))
	var cy: float = PERF_TOP + PERF_H * (1.0 - v)
	_perf_icon.position = Vector2(PERF_X + 6.0 - 23.0, cy - 23.0)
	_perf_icon.ring_color = Color(0.95, 0.30, 0.30).lerp(Color(0.35, 0.95, 0.45), v)


func show_judge(text: String, color: Color) -> void:
	var lbl := RB.label(text, 40, color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.size = Vector2(320.0, 52.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vp: Vector2 = get_viewport_rect().size
	lbl.position = Vector2(vp.x * 0.5 - 160.0, 470.0)
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(0.6, 0.6)
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", 430.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.25).set_delay(0.38)
	tw.chain().tween_callback(lbl.queue_free)
