## results.gd
## Fin de canción (escena results.tscn): arriba el título y los puntos totales con
## estrellas; a la izquierda la tarjeta del jugador (precisión, instrumento, rango
## y puntos); a la derecha la tabla de posiciones local (SQLite) con guardado de
## nombre. La interfaz fija vive en la escena; aquí solo se rellenan los datos.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const ROW_SCENE := preload("res://scenes/widgets/board_row.tscn")

var _saved: bool = false
var _leaving: bool = false

# Nodos de la escena results.tscn
@onready var _title: Label = %Title
@onready var _score_row: Control = %ScoreRow
@onready var _score_lbl: Label = %ScoreLabel
@onready var _stars_top: Control = %StarsTop
@onready var _medallion: Control = %Medallion
@onready var _block: Control = %Block
@onready var _acc_lbl: Label = %AccLabel
@onready var _inst_lbl: Label = %InstLabel
@onready var _rank_bar: Control = %RankBar
@onready var _rank_label: Label = %RankLabel
@onready var _combo_lbl: Label = %ComboLabel
@onready var _notes_lbl: Label = %NotesLabel
@onready var _solo: Control = %Solo
@onready var _solo_icon: Control = %SoloIcon
@onready var _score_card_lbl: Label = %ScoreCardLabel
@onready var _stars_card: Control = %StarsCard
@onready var _board: Control = %Board
@onready var _board_rows: Control = %BoardRows
@onready var _name_edit: LineEdit = %NameEdit
@onready var _save_btn: Button = %SaveBtn
@onready var _bottom_bar: Control = %BottomBar


func _ready() -> void:
	RB.localize(self)
	_fill_texts()
	_name_edit.text_submitted.connect(_on_name_submitted)
	_save_btn.pressed.connect(_on_save_pressed)
	_load_leaderboard()
	_play_intro()
	_animate_in()


# ── Contenido ────────────────────────────────────────────────────────────────

func _fill_texts() -> void:
	var title_text: String = GameState.selected_song_title
	if title_text == "":
		title_text = GameState.selected_song_name
	_title.text = title_text.to_upper()

	var acc: float = GameState.last_accuracy
	var inst: String = GameState.last_instrument
	_inst_lbl.text = RB.instrument_name(inst)
	_rank_label.text = RB.rank_text(acc)
	_rank_bar.add_theme_stylebox_override("panel", RB.box(RB.rank_color(acc), 0))
	_combo_lbl.text = "%s  x%d" % [RB.t("COMBO MÁXIMO", "MAX COMBO"), GameState.last_max_combo]
	_notes_lbl.text = "%s  %d / %d" % [RB.t("NOTAS", "NOTES"), GameState.last_hit_notes, GameState.last_total_notes]
	_solo_icon.instrument = inst

	_name_edit.placeholder_text = RB.t("Tu nombre", "Your name")
	if GameState.player1_name != "P1":
		_name_edit.text = GameState.player1_name


func _play_intro() -> void:
	create_tween().set_loops().tween_property(_medallion, "rotation", TAU, 16.0).from(0.0)
	RB.slide_in(_title, Vector2(0.0, -30.0), 0.0, 0.5)
	RB.slide_in(_score_row, Vector2(0.0, -20.0), 0.12, 0.5)
	RB.slide_in(_block, Vector2(-60.0, 0.0), 0.15, 0.5)
	RB.slide_in(_combo_lbl, Vector2(-60.0, 0.0), 0.22, 0.5)
	RB.slide_in(_notes_lbl, Vector2(-60.0, 0.0), 0.26, 0.5)
	RB.slide_in(_solo, Vector2(-60.0, 0.0), 0.30, 0.5)
	RB.slide_in(_board, Vector2(60.0, 0.0), 0.2, 0.55)
	RB.slide_in(_name_edit, Vector2(0.0, 30.0), 0.4, 0.45)
	RB.slide_in(_save_btn, Vector2(0.0, 30.0), 0.45, 0.45)
	RB.slide_in(_bottom_bar, Vector2(0.0, 60.0), 0.35, 0.5)


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
		_board_message(RB.t("La base de datos no está disponible.", "The database is not available."))
		return
	var rows: Array = Database.get_top10(GameState.selected_song_name)
	if rows.is_empty():
		_board_message(RB.t("Sin registros aún. ¡Sé el primero!", "No records yet. Be the first!"))
		return
	for i in rows.size():
		var data: Dictionary = rows[i]
		var mine: bool = str(data["player_name"]) == GameState.player1_name and int(data["score"]) == GameState.last_score and _saved
		var row: Control = ROW_SCENE.instantiate()
		row.position = Vector2(0.0, float(i) * 27.0)
		_board_rows.add_child(row)
		row.setup(i + 1, data, mine)
		RB.slide_in(row, Vector2(30.0, 0.0), 0.04 * float(i) + 0.3, 0.3)


func _board_message(text: String) -> void:
	var msg := RB.label(text, 18, RB.GRAY_TXT, false)
	msg.position = Vector2(18.0, 12.0)
	_board_rows.add_child(msg)


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
