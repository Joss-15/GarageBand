## gameplay_hud.gd
## Interfaz de la partida (escena gameplay_hud.tscn):
##  - izquierda: barra de rendimiento (el ícono del instrumento sube con la buena
##    precisión y baja con los fallos), título de la canción y dial de combo.
##  - derecha: puntos totales y barra de progreso con 00:00 y la duración.
##  - centro: juicios (PERFECTO / BIEN / REGULAR / FALLO) sobre el carril.
## Los nodos viven en la escena; aquí solo se actualizan sus valores.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

const PERF_X := 40.0
const PERF_TOP := 262.0
const PERF_H := 264.0
const RIGHT_W := 288.0

@onready var _perf_clip: Control = %PerfClip
@onready var _perf_grad: TextureRect = %PerfGrad
@onready var _perf_icon: Control = %PerfIcon
@onready var _song_title: Label = %SongTitle
@onready var _artist_lbl: Label = %ArtistLabel
@onready var _instrument_lbl: Label = %InstrumentLabel
@onready var _dial: Control = %ComboDial
@onready var _score_lbl: Label = %ScoreLabel
@onready var _acc_lbl: Label = %AccLabel
@onready var _prog_fill: Panel = %ProgFill
@onready var _dur_lbl: Label = %DurationLabel

var _duration: float = 1.0
var _perf: float = 0.5
var _perf_tween: Tween = null
var _score_shown: float = 0.0
var _score_target: int = 0
var _score_tween: Tween = null


func _ready() -> void:
	RB.localize(self)


func setup(song_title: String, artist: String, instrument: String, duration: float) -> void:
	_duration = maxf(duration, 1.0)
	_perf_icon.instrument = instrument
	_song_title.text = song_title
	_artist_lbl.text = artist
	_artist_lbl.visible = artist != ""
	_instrument_lbl.text = RB.instrument_name(instrument)
	_dur_lbl.text = RB.fmt_time(_duration)
	_acc_lbl.text = "%s 100.0%%" % RB.t("PRECISIÓN", "ACCURACY")
	_apply_perf(_perf)


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
