## gameplay.gd
## Partida de 1 o 2 jugadores con carriles en perspectiva (highway.gd).
## Cada jugador tiene su propia "pista" (Track): su carril, sus 5 receptores,
## sus teclas, su mapa de notas (según su instrumento), sus puntos y su combo.
## En 1 jugador se usa el HUD de siempre (%Hud). En 2 jugadores ese HUD se oculta
## y se dibuja uno compacto sobre cada carril.
extends Node2D

const RB = preload("res://scripts/core/rb_theme.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")

const LANE_COUNT := 5
const NOTE_FALL_TIME := 2.0
const NOTE_SCENE := preload("res://scenes/gameplay/note.tscn")

# Controles: el jugador 1 (solo o en pareja) usa lane_*, que se configuran en Opciones →
# Controles (teclado y control a la vez). El jugador 2 usa p2_lane_* (teclas fijas, ver
# GameState.P2_KEYS).
const P1_ACTIONS := ["lane_0", "lane_1", "lane_2", "lane_3", "lane_4"]
const P2_ACTIONS := ["p2_lane_0", "p2_lane_1", "p2_lane_2", "p2_lane_3", "p2_lane_4"]

# Geometría del carril
const HIGHWAY_TOP_Y := 238.0
const HIGHWAY_BOTTOM_MARGIN := 82.0
const LANE_W := 88.0
const FAR_Z := 2.5

# HUD compacto (solo 2 jugadores)
const JUDGE_Y := 450.0
const PROG_W := 320.0
const HUD_W := 440.0                                  # ancho del HUD de cada jugador (= ancho del carril)
const BOX_BG := Color(0.04, 0.05, 0.09, 0.92)         # fondo de las cajas (como el HUD de 1 jugador)
const BOX_BORDER := Color(0.78, 0.80, 0.88)
const TRACK_BG := Color(0.05, 0.06, 0.10)
const TRACK_BORDER := Color(0.45, 0.47, 0.55)
const PERF_LOW := Color(0.95, 0.30, 0.30)
const PERF_HIGH := Color(0.35, 0.95, 0.45)


## Estado de un jugador durante la partida.
class Track:
	var index: int = 0
	var actions: Array = []
	var highway: Node2D = null
	var receptors: Array = []
	var instrument: String = "guitarra"
	var pending: Array = []
	var active: Array = []          # active[lane] = Array de notas en pantalla
	var total_notes: int = 0
	var score: int = 0
	var combo: int = 0
	var max_combo: int = 0
	var hit_count: int = 0
	var miss_count: int = 0
	var performance: float = 0.5
	# Elementos del HUD compacto (2 jugadores)
	var score_lbl: Label = null
	var combo_lbl: Label = null          # número dentro del dial de combo
	var dial_style: StyleBoxFlat = null  # borde del dial (se pone dorado con buen combo)
	var acc_lbl: Label = null
	var perf_fill: Panel = null          # relleno del medidor de rendimiento
	var perf_w: float = 0.0
	var judge_lbl: Label = null
	var judge_tween: Tween = null


@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var notes_root: Node2D = $Notes
@onready var highway: Node2D = $HighwayRoot
@onready var _hud: Control = %Hud
@onready var _pause: CanvasLayer = %PauseMenu
@onready var _stage_fx: Node2D = %StageFx

var tracks: Array = []
var two_player: bool = false

var game_started: bool = false
var game_ended: bool = false
var _paused: bool = false

var _last_time: float = 0.0
var _beat_period: float = 0.5
var _duration: float = 1.0

var _hud_layer: CanvasLayer = null
var _prog_fill: Panel = null
var _elapsed_lbl: Label = null
var _last_sec: int = -1


## Si se abre esta escena directamente (F6) sin haber elegido canción, usa la primera de la biblioteca.
func _ensure_session() -> void:
	if not GameState.current_beatmap.is_empty() and GameState.selected_stream != null:
		return
	var songs: Array = SONG_LIB.scan()
	if songs.is_empty():
		return
	var song: Dictionary = songs[0]
	GameState.selected_song_name = str(song["name"])
	GameState.selected_song_title = str(song["title"])
	GameState.selected_song_artist = str(song["artist"])
	GameState.selected_song_path = str(song["wav"])
	GameState.selected_stream = load(str(song["wav"])) as AudioStream
	GameState.current_beatmap = SONG_LIB.load_beatmap(song, GameState.selected_instrument)


func _ready() -> void:
	_ensure_session()
	GameState.stop_bgm()
	two_player = GameState.two_player_mode

	var beatmap: Dictionary = GameState.current_beatmap
	if beatmap.is_empty():
		push_error("gameplay.gd: No hay beatmap en GameState.")
		return

	# La duración se calcula antes de armar la pantalla (el HUD de 2 jugadores la muestra)
	_duration = float(beatmap.get("duration", 0.0))
	if _duration <= 1.0 and GameState.selected_stream != null:
		_duration = GameState.selected_stream.get_length()
	var bpm: float = float(beatmap.get("bpm_estimado", 120.0))
	_beat_period = 60.0 / maxf(bpm, 40.0)

	var vp: Vector2 = get_viewport_rect().size
	var hit_y: float = vp.y - HIGHWAY_BOTTOM_MARGIN
	if two_player:
		_build_two_player(vp, hit_y, beatmap)
	else:
		_build_solo(vp, hit_y, beatmap)

	if not two_player:
		_setup_hud()
	_connect_pause()

	audio_player.stream = GameState.selected_stream
	audio_player.play()
	game_started = true


# ── Construcción ─────────────────────────────────────────────────────────────

func _build_solo(vp: Vector2, hit_y: float, beatmap: Dictionary) -> void:
	highway.setup(vp, hit_y, HIGHWAY_TOP_Y, LANE_W, FAR_Z, NOTE_FALL_TIME)
	tracks.append(_make_track(0, P1_ACTIONS, highway, GameState.selected_instrument, beatmap))


func _build_two_player(vp: Vector2, hit_y: float, beatmap_p1: Dictionary) -> void:
	var beatmap_p2: Dictionary = _load_beatmap_for(GameState.selected_instrument_p2, beatmap_p1)
	var cx1: float = vp.x * 0.25
	var cx2: float = vp.x * 0.75

	# El carril del jugador 2 es una copia del original
	var highway_p2: Node2D = _duplicate_highway()
	add_child(highway_p2)
	move_child(highway_p2, highway.get_index() + 1)

	# La barra de cada carril muestra las teclas de su jugador (lane_* / p2_lane_*)
	highway.get_node("Bar").action_prefix = "lane_"
	highway_p2.get_node("Bar").action_prefix = "p2_lane_"

	highway.setup(vp, hit_y, HIGHWAY_TOP_Y, LANE_W, FAR_Z, NOTE_FALL_TIME, cx1)
	highway_p2.setup(vp, hit_y, HIGHWAY_TOP_Y, LANE_W, FAR_Z, NOTE_FALL_TIME, cx2)
	_place_receptors(highway)
	_place_receptors(highway_p2)

	var trk1: Track = _make_track(0, P1_ACTIONS, highway, GameState.selected_instrument, beatmap_p1)
	var trk2: Track = _make_track(1, P2_ACTIONS, highway_p2, GameState.selected_instrument_p2, beatmap_p2)
	tracks.append(trk1)
	tracks.append(trk2)

	_hud.visible = false
	_ensure_hud_layer()
	_build_center_header(vp)
	_build_compact_hud(trk1, cx1)
	_build_compact_hud(trk2, cx2)


func _duplicate_highway() -> Node2D:
	var copy: Node2D = highway.duplicate() as Node2D
	copy.name = "HighwayRootP2"
	# Los nombres únicos (%) de la copia chocarían con los del original
	copy.unique_name_in_owner = false
	for child in copy.get_children():
		child.unique_name_in_owner = false
	return copy


## Centra los 5 receptores del carril en sus columnas (la escena los trae para un carril central).
func _place_receptors(hw: Node2D) -> void:
	for i in LANE_COUNT:
		var rec: Node2D = hw.get_node("Receptor%d" % i) as Node2D
		rec.position.x = hw.lane_center_x(i)


## Mapa de notas del instrumento de un jugador; si no existe usa el de respaldo.
func _load_beatmap_for(instrument: String, fallback: Dictionary) -> Dictionary:
	var song: Dictionary = SONG_LIB.find_by_name(GameState.selected_song_name)
	if song.is_empty():
		return fallback
	var bm: Dictionary = SONG_LIB.load_beatmap(song, instrument)
	if bm.is_empty():
		return fallback
	return bm


func _make_track(index: int, actions: Array, hw: Node2D, instrument: String, beatmap: Dictionary) -> Track:
	var trk := Track.new()
	trk.index = index
	trk.actions = actions
	trk.highway = hw
	trk.instrument = instrument
	for i in LANE_COUNT:
		trk.receptors.append(hw.get_node("Receptor%d" % i))
		trk.active.append([])
	trk.pending = (beatmap.get("notes", []) as Array).duplicate(true)
	trk.pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	trk.total_notes = int(beatmap.get("note_count", trk.pending.size()))
	if trk.total_notes <= 0:
		trk.total_notes = trk.pending.size()
	return trk


func _setup_hud() -> void:
	var title: String = GameState.selected_song_title
	if title == "":
		title = GameState.selected_song_name
	_hud.setup(title, GameState.selected_song_artist, GameState.selected_instrument, _duration)


func _connect_pause() -> void:
	_pause.resume_finished.connect(_on_resume_finished)
	_pause.restart_requested.connect(_on_restart)
	_pause.quit_requested.connect(_on_quit)


# ── HUD compacto (2 jugadores) ───────────────────────────────────────────────

func _ensure_hud_layer() -> void:
	if _hud_layer != null:
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 2
	add_child(_hud_layer)


## Texto con la tipografía del juego (RB.label) colocado en un rectángulo.
func _text(text: String, font_size: int, color: Color, pos: Vector2, width: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = true) -> Label:
	var lbl: Label = RB.label(text, font_size, color, bold)
	lbl.position = pos
	lbl.size = Vector2(width, float(font_size) + 12.0)
	lbl.horizontal_alignment = align
	lbl.clip_text = true
	_hud_layer.add_child(lbl)
	return lbl


## Caja redondeada con borde (misma apariencia que la caja de PUNTOS de 1 jugador).
func _box(pos: Vector2, box_size: Vector2, bg: Color, border: Color, border_w: int, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = box_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", sb)
	_hud_layer.add_child(panel)
	return panel


## Parte común arriba al centro: título, artista y barra de progreso con 00:00 y la duración.
func _build_center_header(vp: Vector2) -> void:
	var cx: float = vp.x * 0.5
	var title: String = GameState.selected_song_title
	if title == "":
		title = GameState.selected_song_name
	_text(title, 28, Color.WHITE, Vector2(cx - 300.0, 4.0), 600.0, HORIZONTAL_ALIGNMENT_CENTER)
	var artist: String = GameState.selected_song_artist
	if artist != "":
		_text(artist, 16, RB.GRAY_TXT, Vector2(cx - 300.0, 38.0), 600.0, HORIZONTAL_ALIGNMENT_CENTER, false)

	var bx: float = cx - PROG_W * 0.5
	var by: float = 64.0
	_box(Vector2(bx, by), Vector2(PROG_W, 10.0), TRACK_BG, TRACK_BORDER, 2, 5)
	_prog_fill = _box(Vector2(bx + 2.0, by + 2.0), Vector2(0.0, 6.0), RB.GOLD_BRIGHT, RB.GOLD_BRIGHT, 0, 3)
	_elapsed_lbl = _text("00:00", 13, RB.GRAY_TXT, Vector2(bx, by + 12.0), 100.0, HORIZONTAL_ALIGNMENT_LEFT, false)
	_text(RB.fmt_time(_duration), 13, RB.GRAY_TXT, Vector2(bx + PROG_W - 100.0, by + 12.0), 100.0, HORIZONTAL_ALIGNMENT_RIGHT, false)


## HUD de un jugador sobre su carril: dial de combo, jugador · instrumento,
## caja de puntos, precisión y medidor de rendimiento.
func _build_compact_hud(trk: Track, center_x: float) -> void:
	var accent: Color = RB.GOLD_BRIGHT
	if trk.index == 1:
		accent = Color(0.35, 0.80, 1.0)
	var x0: float = center_x - HUD_W * 0.5
	var xr: float = x0 + 100.0           # columna derecha, junto al dial
	var wr: float = HUD_W - 100.0

	# Dial de combo: anillo con el número y "COMBO" debajo
	var dial: Panel = _box(Vector2(x0 + 8.0, 108.0), Vector2(76.0, 76.0), BOX_BG, BOX_BORDER, 4, 38)
	trk.dial_style = dial.get_theme_stylebox("panel") as StyleBoxFlat
	trk.combo_lbl = _text("0", 30, Color.WHITE, Vector2(x0 + 8.0, 125.0), 76.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(RB.t("COMBO", "COMBO"), 13, RB.GRAY_TXT, Vector2(x0 + 8.0, 188.0), 76.0, HORIZONTAL_ALIGNMENT_CENTER)

	# Jugador · instrumento
	var player_text: String = RB.t("JUGADOR %d", "PLAYER %d") % (trk.index + 1)
	var header: String = "%s · %s" % [player_text, RB.instrument_name(trk.instrument)]
	_text(header.to_upper(), 20, accent, Vector2(xr, 90.0), wr)

	# Caja de puntos
	_box(Vector2(xr, 120.0), Vector2(wr, 66.0), BOX_BG, BOX_BORDER, 2, 10)
	_text(RB.t("PUNTOS", "SCORE"), 13, RB.GRAY_TXT, Vector2(xr + 12.0, 124.0), 120.0)
	trk.score_lbl = _text("0", 40, Color.WHITE, Vector2(xr, 136.0), wr - 14.0, HORIZONTAL_ALIGNMENT_RIGHT)

	# Precisión y medidor de rendimiento (en 1 jugador es el ícono que sube y baja)
	trk.acc_lbl = _text("%s 100.0%%" % RB.t("PRECISIÓN", "ACCURACY"), 16, RB.GRAY_TXT, Vector2(xr, 188.0), wr, HORIZONTAL_ALIGNMENT_LEFT, false)
	_box(Vector2(xr, 216.0), Vector2(wr, 10.0), TRACK_BG, TRACK_BORDER, 2, 5)
	trk.perf_w = wr - 4.0
	trk.perf_fill = _box(Vector2(xr + 2.0, 218.0), Vector2(trk.perf_w * trk.performance, 6.0), PERF_LOW, PERF_LOW, 0, 3)
	_set_perf_bar(trk)

	# Aviso de juicio (PERFECTO / BIEN / FALLO) sobre el carril
	trk.judge_lbl = _text("", 38, Color.WHITE, Vector2(x0, JUDGE_Y), HUD_W, HORIZONTAL_ALIGNMENT_CENTER)
	trk.judge_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	trk.judge_lbl.add_theme_constant_override("outline_size", 8)
	trk.judge_lbl.modulate.a = 0.0


func _set_perf_bar(trk: Track) -> void:
	var v: float = clampf(trk.performance, 0.0, 1.0)
	trk.perf_fill.size.x = trk.perf_w * v
	var sb: StyleBoxFlat = trk.perf_fill.get_theme_stylebox("panel") as StyleBoxFlat
	sb.bg_color = PERF_LOW.lerp(PERF_HIGH, v)


func _compact_combo(trk: Track) -> void:
	trk.combo_lbl.text = str(trk.combo)
	trk.dial_style.border_color = RB.GOLD_BRIGHT if trk.combo >= 10 else BOX_BORDER
	if trk.combo > 0:
		RB.pop(trk.combo_lbl, 1.25, 0.15)


func _compact_accuracy(trk: Track) -> void:
	trk.acc_lbl.text = "%s %.1f%%" % [RB.t("PRECISIÓN", "ACCURACY"), _live_accuracy(trk)]


func _show_compact_judge(trk: Track, text: String, color: Color) -> void:
	var lbl: Label = trk.judge_lbl
	lbl.text = text
	lbl.modulate = Color(color.r, color.g, color.b, 1.0)
	lbl.position.y = JUDGE_Y
	if trk.judge_tween != null and trk.judge_tween.is_valid():
		trk.judge_tween.kill()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", JUDGE_Y - 28.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.25).set_delay(0.35)
	trk.judge_tween = tw


# ── Bucle principal ──────────────────────────────────────────────────────────

## Tiempo de la canción suavizado y compensado por la latencia de salida.
func _song_time() -> float:
	if not audio_player.playing:
		return _last_time
	var t: float = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	t = maxf(t, _last_time)
	_last_time = t
	return t


func _process(_delta: float) -> void:
	if not game_started or game_ended or _paused:
		return

	var t: float = _song_time()
	_update_progress(t)
	for trk: Track in tracks:
		_update_track(trk, t)

	if not audio_player.playing and _all_pending_empty():
		_end_game()


func _update_progress(t: float) -> void:
	if two_player:
		if _prog_fill != null:
			_prog_fill.size.x = (PROG_W - 4.0) * clampf(t / maxf(_duration, 1.0), 0.0, 1.0)
		var sec: int = int(t)
		if sec != _last_sec and _elapsed_lbl != null:
			_last_sec = sec
			_elapsed_lbl.text = RB.fmt_time(float(sec))
	else:
		_hud.set_progress(t)


func _all_pending_empty() -> bool:
	for trk: Track in tracks:
		if not trk.pending.is_empty():
			return false
	return true


func _update_track(trk: Track, t: float) -> void:
	trk.highway.set_clock(t, _beat_period)
	_spawn_pending(trk, t)
	for lane in LANE_COUNT:
		for n in trk.active[lane]:
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				n.update_for_time(t)
	_process_input(trk, t)


func _spawn_pending(trk: Track, song_time: float) -> void:
	while not trk.pending.is_empty():
		var next: Dictionary = trk.pending[0]
		if song_time >= float(next["time"]) - NOTE_FALL_TIME:
			trk.pending.pop_front()
			_spawn_note(trk, float(next["time"]), int(next["lane"]))
		else:
			break


func _spawn_note(trk: Track, beat_time: float, lane: int) -> void:
	# Ignorar notas de carriles fuera de rango (por si el JSON tiene carriles viejos)
	if lane < 0 or lane >= LANE_COUNT:
		return

	var note: Node2D = NOTE_SCENE.instantiate()
	notes_root.add_child(note)
	var col: Color = RB.LANE_COLORS[lane]
	note.setup(lane, beat_time, col, trk.highway, NOTE_FALL_TIME)
	note.note_hit.connect(_on_note_hit.bind(trk))
	note.note_missed.connect(_on_note_missed.bind(trk))
	trk.active[lane].append(note)


func _process_input(trk: Track, t: float) -> void:
	for lane in LANE_COUNT:
		if not Input.is_action_just_pressed(trk.actions[lane]):
			continue
		trk.receptors[lane].animate_press()
		trk.highway.press_lane(lane, 1.0)

		var has_hittable: bool = false
		for n in trk.active[lane]:
			if is_instance_valid(n) and n.is_hittable(t):
				has_hittable = true
				break

		if has_hittable:
			_hit_lane(trk, lane, t)
		else:
			# Presionar al aire también es fallo y rompe el combo
			_register_miss(trk)


func _hit_lane(trk: Track, lane: int, song_time: float) -> void:
	var best_note: Node2D = null
	var best_diff: float = INF
	for n in trk.active[lane]:
		if is_instance_valid(n) and n.is_hittable(song_time):
			var d: float = absf(song_time - float(n.beat_time))
			if d < best_diff:
				best_diff = d
				best_note = n

	if best_note != null:
		best_note.try_hit(song_time)


# ── Resultados de cada nota ──────────────────────────────────────────────────

func _prune(trk: Track, lane: int) -> void:
	trk.active[lane] = trk.active[lane].filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())


func _on_note_hit(lane: int, accuracy: float, trk: Track) -> void:
	_prune(trk, lane)
	if lane < trk.receptors.size():
		trk.receptors[lane].animate_hit(accuracy)

	trk.hit_count += 1
	trk.combo += 1
	if trk.combo > trk.max_combo:
		trk.max_combo = trk.combo
	trk.score += int(100.0 * accuracy * (1.0 + trk.combo * 0.01))

	var text: String = RB.t("REGULAR", "BAD")
	var perf_value: float = 0.4
	if accuracy >= 0.95:
		text = RB.t("¡PERFECTO!", "PERFECT!")
		perf_value = 1.0
	elif accuracy >= 0.55:
		text = RB.t("BIEN", "GOOD")
		perf_value = 0.75
	var col: Color = RB.LANE_COLORS[lane]
	var judge_col: Color = Color(0.75, 0.75, 0.8)
	if accuracy >= 0.55:
		judge_col = col.lightened(0.25)

	if two_player:
		trk.score_lbl.text = RB.fmt_int(trk.score)
		RB.pop(trk.score_lbl, 1.06, 0.18)
		_compact_combo(trk)
		_compact_accuracy(trk)
		_show_compact_judge(trk, text, judge_col)
	else:
		_hud.show_judge(text, judge_col)
		_hud.set_score(trk.score)
		_hud.set_combo(trk.combo)
		_hud.set_accuracy(_live_accuracy(trk))

	_update_performance(trk, perf_value)
	trk.highway.pulse(0.6 if accuracy >= 0.95 else 0.3)
	_stage_fx.pulse(0.55 if accuracy >= 0.95 else 0.25)


func _on_note_missed(lane: int, trk: Track) -> void:
	_prune(trk, lane)
	_register_miss(trk)


func _register_miss(trk: Track) -> void:
	trk.miss_count += 1
	trk.combo = 0
	if two_player:
		_compact_combo(trk)
		_compact_accuracy(trk)
		_show_compact_judge(trk, RB.t("FALLO", "MISS"), Color(1.0, 0.25, 0.25))
	else:
		_hud.set_combo(0)
		_hud.set_accuracy(_live_accuracy(trk))
		_hud.show_judge(RB.t("FALLO", "MISS"), Color(1.0, 0.25, 0.25))
	_update_performance(trk, 0.0)


func _live_accuracy(trk: Track) -> float:
	var total: int = trk.hit_count + trk.miss_count
	if total <= 0:
		return 100.0
	return float(trk.hit_count) / float(total) * 100.0


func _update_performance(trk: Track, value: float) -> void:
	trk.performance = lerpf(trk.performance, value, 0.12)
	if two_player:
		_set_perf_bar(trk)
	else:
		_hud.set_performance(trk.performance)


# ── Fin de partida, pausa ────────────────────────────────────────────────────

func _end_game() -> void:
	if game_ended:
		return
	game_ended = true
	game_started = false

	var t1: Track = tracks[0]
	GameState.last_score = t1.score
	GameState.last_max_combo = t1.max_combo
	GameState.last_accuracy = float(t1.hit_count) / float(t1.total_notes) if t1.total_notes > 0 else 0.0
	GameState.last_hit_notes = t1.hit_count
	GameState.last_miss_notes = t1.miss_count
	GameState.last_total_notes = t1.total_notes
	GameState.last_duration = _duration
	GameState.last_instrument = t1.instrument

	if two_player:
		var t2: Track = tracks[1]
		GameState.last_score_p2 = t2.score
		GameState.last_max_combo_p2 = t2.max_combo
		GameState.last_accuracy_p2 = float(t2.hit_count) / float(t2.total_notes) if t2.total_notes > 0 else 0.0
		GameState.last_hit_notes_p2 = t2.hit_count
		GameState.last_total_notes_p2 = t2.total_notes
		GameState.last_instrument_p2 = t2.instrument
	else:
		GameState.last_score_p2 = 0
		GameState.last_max_combo_p2 = 0
		GameState.last_accuracy_p2 = 0.0
		GameState.last_hit_notes_p2 = 0
		GameState.last_total_notes_p2 = 0

	await get_tree().create_timer(1.0).timeout
	SceneFade.go("res://scenes/screens/results.tscn")


## La pausa es Esc o Start. No se usa ui_cancel porque incluye el botón B del control,
## que también es un carril del jugador 1.
func _unhandled_input(event: InputEvent) -> void:
	if not game_started or game_ended or _paused:
		return
	var wants_pause: bool = false
	if event is InputEventKey:
		var k := event as InputEventKey
		wants_pause = k.pressed and not k.echo and k.keycode == KEY_ESCAPE
	elif event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		wants_pause = jb.pressed and jb.button_index == JOY_BUTTON_START
	if wants_pause:
		_open_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and game_started and not game_ended and not _paused:
		_open_pause()


func _open_pause() -> void:
	_paused = true
	get_tree().paused = true
	_pause.open()


func _on_resume_finished() -> void:
	_paused = false
	get_tree().paused = false


func _on_restart() -> void:
	SceneFade.go("res://scenes/gameplay/gameplay.tscn")


func _on_quit() -> void:
	SceneFade.go("res://scenes/screens/song_select.tscn")
