## gameplay.gd
## Partida de un jugador: carril en perspectiva (highway.gd), notas, enemigos,
## HUD y pausa. La puntuación, las ventanas de golpe y la lógica de enemigos son
## las de siempre; solo cambió la presentación.
extends Node2D

const RB = preload("res://scripts/core/rb_theme.gd")
const HUD_SCRIPT = preload("res://scripts/gameplay/gameplay_hud.gd")
const PAUSE_SCRIPT = preload("res://scripts/gameplay/pause_menu.gd")
const STAGE_FX = preload("res://scripts/gameplay/stage_fx.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")

const LANE_COUNT := 5
const NOTE_FALL_TIME := 2.0
const NOTE_SCENE := preload("res://scenes/gameplay/note.tscn")
const RECEPTOR_SCENE := preload("res://scenes/gameplay/lane_receptor.tscn")
const ENEMY_SCENE := preload("res://scenes/characters/enemy.tscn")
const LANE_ACTIONS := ["lane_0", "lane_1", "lane_2", "lane_3", "lane_4"]

# Geometría del carril (la parte de arriba de la pantalla es el escenario con Nat)
const HIGHWAY_TOP_Y := 238.0
const HIGHWAY_BOTTOM_MARGIN := 82.0
const LANE_W := 88.0
const FAR_Z := 2.5

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var notes_root: Node2D = $Notes
@onready var highway: Node2D = $HighwayRoot
@onready var fighter: Node2D = $Nat
@onready var actors: Node2D = $Actors
@onready var back_fx: Node2D = $BackFX

var pending_notes: Array = []
var active_notes: Array = []

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var hit_count: int = 0
var miss_count: int = 0
var total_notes: int = 0
var performance: float = 0.5

var game_started: bool = false
var game_ended: bool = false
var _paused: bool = false

var _last_time: float = 0.0
var _beat_period: float = 0.5
var _duration: float = 1.0
var _receptors: Array = []
var _hud: Control = null
var _pause: CanvasLayer = null
var _stage_fx: Node2D = null


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
	var vp: Vector2 = get_viewport_rect().size
	var hit_y: float = vp.y - HIGHWAY_BOTTOM_MARGIN
	highway.setup(vp, hit_y, HIGHWAY_TOP_Y, LANE_W, FAR_Z, NOTE_FALL_TIME)

	active_notes.resize(LANE_COUNT)
	for i in LANE_COUNT:
		active_notes[i] = []

	_build_back_fx(vp)
	_build_receptors()

	var beatmap: Dictionary = GameState.current_beatmap
	if beatmap.is_empty():
		push_error("gameplay.gd: No hay beatmap en GameState.")
		return

	pending_notes = (beatmap.get("notes", []) as Array).duplicate(true)
	pending_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	total_notes = int(beatmap.get("note_count", pending_notes.size()))
	if total_notes <= 0:
		total_notes = pending_notes.size()
	_duration = float(beatmap.get("duration", 0.0))
	if _duration <= 1.0 and GameState.selected_stream != null:
		_duration = GameState.selected_stream.get_length()
	var bpm: float = float(beatmap.get("bpm_estimado", 120.0))
	_beat_period = 60.0 / maxf(bpm, 40.0)

	_build_hud()
	_build_pause()

	audio_player.stream = GameState.selected_stream
	audio_player.play()
	game_started = true


# ── Construcción ─────────────────────────────────────────────────────────────

func _build_back_fx(vp: Vector2) -> void:
	var floor_tex := TextureRect.new()
	floor_tex.texture = RB.v_gradient(Color(0.03, 0.05, 0.14), Color(0.0, 0.0, 0.02))
	floor_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_tex.stretch_mode = TextureRect.STRETCH_SCALE
	floor_tex.position = Vector2(0.0, 228.0)
	floor_tex.size = Vector2(vp.x, vp.y - 228.0)
	back_fx.add_child(floor_tex)
	var fx := STAGE_FX.new()
	fx.origin_y = 226.0
	fx.length = vp.y - 200.0
	fx.beam_spread = 260.0
	fx.beam_count = 5
	fx.base_alpha = 0.09
	back_fx.add_child(fx)
	_stage_fx = fx


func _build_receptors() -> void:
	_receptors.clear()
	for i in LANE_COUNT:
		var r: Node2D = RECEPTOR_SCENE.instantiate()
		var col: Color = RB.LANE_COLORS[i]
		r.lane_color = col
		r.lane_index = i
		r.position = Vector2(highway.lane_center_x(i), highway.hit_y)
		highway.add_child(r)
		_receptors.append(r)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = HUD_SCRIPT.new()
	layer.add_child(_hud)
	var title: String = GameState.selected_song_title
	if title == "":
		title = GameState.selected_song_name
	_hud.setup(title, GameState.selected_song_artist, GameState.selected_instrument, _duration)


func _build_pause() -> void:
	_pause = PAUSE_SCRIPT.new()
	add_child(_pause)
	_pause.resume_finished.connect(_on_resume_finished)
	_pause.restart_requested.connect(_on_restart)
	_pause.quit_requested.connect(_on_quit)


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
	_hud.set_progress(t)
	highway.set_clock(t, _beat_period)

	_spawn_pending(t)
	for lane in LANE_COUNT:
		for n in active_notes[lane]:
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				n.update_for_time(t)

	_process_input(t)

	if not audio_player.playing and pending_notes.is_empty():
		_end_game()


func _spawn_pending(song_time: float) -> void:
	while not pending_notes.is_empty():
		var next: Dictionary = pending_notes[0]
		if song_time >= float(next["time"]) - NOTE_FALL_TIME:
			pending_notes.pop_front()
			_spawn_note(float(next["time"]), int(next["lane"]))
		else:
			break


func _spawn_note(beat_time: float, lane: int) -> void:
	# Ignorar notas de carriles fuera de rango (por si el JSON tiene carriles viejos)
	if lane < 0 or lane >= LANE_COUNT:
		return

	var note: Node2D = NOTE_SCENE.instantiate()
	notes_root.add_child(note)
	var col: Color = RB.LANE_COLORS[lane]
	note.setup(lane, beat_time, col, highway, NOTE_FALL_TIME)
	note.note_hit.connect(_on_note_hit)
	note.note_missed.connect(_on_note_missed)

	var enemy: Node2D = ENEMY_SCENE.instantiate()
	actors.add_child(enemy)
	var is_flying: bool = lane >= 2     # carriles 2,3,4 vuelan; 0,1 caminan
	var start_x: float = get_viewport_rect().size.x + 100.0
	var target_pos: Vector2 = fighter.global_position
	target_pos.y += 15.0
	target_pos.x += 30.0
	if is_flying:
		target_pos.y -= 70.0
	enemy.global_position = Vector2(start_x, target_pos.y)
	enemy.setup(is_flying, NOTE_FALL_TIME, target_pos, fighter)
	note.set_meta("enemy_node", enemy)

	active_notes[lane].append(note)


func _process_input(t: float) -> void:
	for lane in LANE_COUNT:
		if not Input.is_action_just_pressed(LANE_ACTIONS[lane]):
			continue
		_receptors[lane].animate_press()
		highway.press_lane(lane, 1.0)

		var has_hittable: bool = false
		for n in active_notes[lane]:
			if is_instance_valid(n) and n.is_hittable(t):
				has_hittable = true
				break

		if has_hittable:
			_hit_lane(lane, t)
		else:
			# Presionar al aire también es fallo y rompe el combo
			_register_miss()


func _hit_lane(lane: int, song_time: float) -> void:
	var best_note: Node2D = null
	var best_diff: float = INF
	for n in active_notes[lane]:
		if is_instance_valid(n) and n.is_hittable(song_time):
			var d: float = absf(song_time - float(n.beat_time))
			if d < best_diff:
				best_diff = d
				best_note = n

	if best_note != null:
		if best_note.has_meta("enemy_node"):
			var enemy: Variant = best_note.get_meta("enemy_node")
			if is_instance_valid(enemy):
				enemy.defeat()
		# Carriles 0,1 -> patada | carriles 2,3,4 -> puñetazo
		if lane < 2:
			fighter.play_kick()
		else:
			fighter.play_punch()
		best_note.try_hit(song_time)


# ── Resultados de cada nota ──────────────────────────────────────────────────

func _prune(lane: int) -> void:
	active_notes[lane] = active_notes[lane].filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())


func _on_note_hit(lane: int, accuracy: float) -> void:
	_prune(lane)
	if lane < _receptors.size():
		_receptors[lane].animate_hit(accuracy)

	hit_count += 1
	combo += 1
	if combo > max_combo:
		max_combo = combo
	score += int(100.0 * accuracy * (1.0 + combo * 0.01))

	var text: String = RB.t("REGULAR", "BAD")
	var perf_value: float = 0.4
	if accuracy >= 0.95:
		text = RB.t("¡PERFECTO!", "PERFECT!")
		perf_value = 1.0
	elif accuracy >= 0.55:
		text = RB.t("BIEN", "GOOD")
		perf_value = 0.75
	var col: Color = RB.LANE_COLORS[lane]
	_hud.show_judge(text, col.lightened(0.25) if accuracy >= 0.55 else Color(0.75, 0.75, 0.8))
	_hud.set_score(score)
	_hud.set_combo(combo)
	_hud.set_accuracy(_live_accuracy())
	_update_performance(perf_value)
	highway.pulse(0.6 if accuracy >= 0.95 else 0.3)
	_stage_fx.pulse(0.55 if accuracy >= 0.95 else 0.25)


func _on_note_missed(lane: int) -> void:
	_prune(lane)
	_register_miss()


func _register_miss() -> void:
	miss_count += 1
	combo = 0
	_hud.set_combo(0)
	_hud.set_accuracy(_live_accuracy())
	_hud.show_judge(RB.t("FALLO", "MISS"), Color(1.0, 0.25, 0.25))
	_update_performance(0.0)
	fighter.play_hurt()


func _live_accuracy() -> float:
	var total: int = hit_count + miss_count
	if total <= 0:
		return 100.0
	return float(hit_count) / float(total) * 100.0


func _update_performance(value: float) -> void:
	performance = lerpf(performance, value, 0.12)
	_hud.set_performance(performance)


# ── Fin de partida, pausa ────────────────────────────────────────────────────

func _end_game() -> void:
	if game_ended:
		return
	game_ended = true
	game_started = false

	var accuracy: float = float(hit_count) / float(total_notes) if total_notes > 0 else 0.0
	GameState.last_score = score
	GameState.last_max_combo = max_combo
	GameState.last_accuracy = accuracy
	GameState.last_hit_notes = hit_count
	GameState.last_miss_notes = miss_count
	GameState.last_total_notes = total_notes
	GameState.last_duration = _duration
	GameState.last_instrument = GameState.selected_instrument
	GameState.last_score_p2 = 0
	GameState.last_max_combo_p2 = 0
	GameState.last_accuracy_p2 = 0.0
	GameState.last_hit_notes_p2 = 0

	await get_tree().create_timer(1.0).timeout
	SceneFade.go("res://scenes/screens/results.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and game_started and not game_ended and not _paused:
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
