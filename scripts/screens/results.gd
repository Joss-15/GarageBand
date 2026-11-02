## results.gd
## Fin de canción (escena results.tscn): arriba el título y los puntos totales con
## estrellas; debajo, una columna de estadísticas por jugador (precisión, instrumento,
## rango, combo, notas y puntos).
##
## Un jugador: la columna del jugador a la izquierda y a la derecha la tabla de
## posiciones local (SQLite) con guardado de nombre, como siempre.
##
## Dos jugadores: la columna del jugador 2 es una copia de la del 1 y ocupa el lugar
## de la tabla. A la derecha quedan el ganador, los dos campos de nombre y un solo
## botón para guardar ambos puntajes. La tabla de posiciones no cabe en este modo.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const ROW_SCENE := preload("res://scenes/widgets/board_row.tscn")


## Nodos de la columna de estadísticas de un jugador.
class Col:
	var block: Control
	var acc_lbl: Label
	var inst_lbl: Label
	var rank_bar: Control
	var rank_label: Label
	var combo_lbl: Label
	var notes_lbl: Label
	var solo: Control
	var solo_icon: Control
	var score_lbl: Label
	var stars: Control
	var caption: Label


var _saved: bool = false
var _leaving: bool = false
var _born_ms: int = 0           # para ignorar botones del control justo al llegar (se venía tocando)
var _two: bool = false
var _cols: Array = []
var _name_edit2: LineEdit = null
var _right_nodes: Array = []     # nodos de la columna derecha en 2 jugadores (para la animación)

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
@onready var _score_caption: Label = %ScoreCaption
@onready var _score_card_lbl: Label = %ScoreCardLabel
@onready var _stars_card: Control = %StarsCard
@onready var _board: Control = %Board
@onready var _board_rows: Control = %BoardRows
@onready var _name_edit: LineEdit = %NameEdit
@onready var _save_btn: Button = %SaveBtn
@onready var _bottom_bar: Control = %BottomBar


func _ready() -> void:
	_born_ms = Time.get_ticks_msec()
	RB.localize(self)
	_two = GameState.two_player_mode

	# La columna del jugador 1 son los nodos de la escena
	var c1 := Col.new()
	c1.block = _block
	c1.acc_lbl = _acc_lbl
	c1.inst_lbl = _inst_lbl
	c1.rank_bar = _rank_bar
	c1.rank_label = _rank_label
	c1.combo_lbl = _combo_lbl
	c1.notes_lbl = _notes_lbl
	c1.solo = _solo
	c1.solo_icon = _solo_icon
	c1.score_lbl = _score_card_lbl
	c1.stars = _stars_card
	c1.caption = _score_caption
	_cols.append(c1)

	# Se duplica ANTES de llenar los textos, para que la copia salga limpia
	if _two:
		_build_player2()

	_fill_texts()
	_name_edit.text_submitted.connect(_on_name_submitted.bind(0))
	_save_btn.pressed.connect(_on_save_pressed)
	if _two:
		_name_edit2.text_submitted.connect(_on_name_submitted.bind(1))
	else:
		_load_leaderboard()
	_play_intro()
	_animate_in()


# ── Jugador 2 (solo en modo de 2 jugadores) ─────────────────────────────────

# ── Jugador 2 (solo en modo de 2 jugadores) ─────────────────────────────────

func _build_player2() -> void:
	# Un paso = ancho de una columna + el hueco entre la columna 1 y la tabla
	var dx: float = _board.position.x - _block.position.x

	var c2 := Col.new()
	c2.block = _dup_shifted(_block, dx)
	
	if c2.block != null:
		c2.acc_lbl = c2.block.get_node_or_null("AccLabel") as Label
		c2.inst_lbl = c2.block.get_node_or_null("InstLabel") as Label
		c2.rank_bar = c2.block.get_node_or_null("RankBar") as Control
		if c2.rank_bar != null:
			c2.rank_label = c2.rank_bar.get_node_or_null("RankLabel") as Label
	
	if c2.acc_lbl == null: c2.acc_lbl = _dup_shifted(_acc_lbl, dx) as Label
	if c2.inst_lbl == null: c2.inst_lbl = _dup_shifted(_inst_lbl, dx) as Label
	if c2.rank_bar == null: c2.rank_bar = _dup_shifted(_rank_bar, dx) as Control
	if c2.rank_label == null: c2.rank_label = _dup_shifted(_rank_label, dx) as Label

	c2.combo_lbl = _dup_shifted(_combo_lbl, dx) as Label
	c2.notes_lbl = _dup_shifted(_notes_lbl, dx) as Label
	c2.solo = _dup_shifted(_solo, dx)
	
	if c2.solo != null:
		c2.solo_icon = c2.solo.get_node_or_null("SoloIcon") as Control
		c2.score_lbl = c2.solo.get_node_or_null("ScoreCardLabel") as Label
		c2.stars = c2.solo.get_node_or_null("StarsCard") as Control
		c2.caption = c2.solo.get_node_or_null("ScoreCaption") as Label

	if c2.solo_icon == null: c2.solo_icon = _dup_shifted(_solo_icon, dx)
	if c2.score_lbl == null: c2.score_lbl = _dup_shifted(_score_card_lbl, dx) as Label
	if c2.stars == null: c2.stars = _dup_shifted(_stars_card, dx)
	if c2.caption == null: c2.caption = _dup_shifted(_score_caption, dx) as Label

	_cols.append(c2)
	_layout_right_column(dx)


## Copia un nodo de la escena de forma segura, la corre `dx` a la derecha y la deja justo encima del original.
func _dup_shifted(src: Control, dx: float) -> Control:
	if src == null:
		return null
		
	var copy: Control = src.duplicate() as Control
	_clear_unique(copy)
	var parent: Node = src.get_parent()
	if parent != null:
		parent.add_child(copy)
		parent.move_child(copy, src.get_index() + 1)
		copy.position = src.position + Vector2(dx, 0.0)
	return copy


## Quita los nombres únicos (%) de la copia para que no choquen con los originales.
func _clear_unique(n: Node) -> void:
	n.unique_name_in_owner = false
	if n.scene_file_path != "":
		return    # una escena instanciada tiene sus propios nombres únicos por dentro
	for c in n.get_children():
		_clear_unique(c)


## Donde iba la tabla: ganador, nombre de cada jugador y un solo botón de guardar.
func _layout_right_column(dx: float) -> void:
	_board.visible = false
	var x3: float = _board.position.x + dx
	var w3: float = _board.size.x - dx
	var y0: float = _block.position.y
	var parent: Node = _board.get_parent()

	var winner := RB.label("", 30, RB.GOLD_BRIGHT, true)
	winner.name = "WinnerLabel"
	winner.position = Vector2(x3, y0)
	winner.size = Vector2(w3, 44.0)
	winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner.text = _winner_text()
	parent.add_child(winner)

	_name_edit2 = _name_edit.duplicate() as LineEdit
	_clear_unique(_name_edit2)
	_name_edit2.name = "NameEdit2"
	parent.add_child(_name_edit2)

	var cap1 := RB.label(RB.t("JUGADOR 1", "PLAYER 1"), 16, RB.GRAY_TXT, false)
	cap1.position = Vector2(x3, y0 + 76.0)
	parent.add_child(cap1)
	var cap2 := RB.label(RB.t("JUGADOR 2", "PLAYER 2"), 16, RB.GRAY_TXT, false)
	cap2.position = Vector2(x3, y0 + 156.0)
	parent.add_child(cap2)

	_name_edit.position = Vector2(x3, y0 + 98.0)
	_name_edit.size = Vector2(w3, _name_edit.size.y)
	_name_edit2.position = Vector2(x3, y0 + 178.0)
	_name_edit2.size = Vector2(w3, _name_edit.size.y)
	_save_btn.position = Vector2(x3, y0 + 246.0)
	_save_btn.size = Vector2(w3, _save_btn.size.y)

	_right_nodes = [winner, cap1, _name_edit, cap2, _name_edit2, _save_btn]


func _winner_text() -> String:
	if GameState.last_score > GameState.last_score_p2:
		return RB.t("¡GANA EL JUGADOR 1!", "PLAYER 1 WINS!")
	if GameState.last_score_p2 > GameState.last_score:
		return RB.t("¡GANA EL JUGADOR 2!", "PLAYER 2 WINS!")
	return RB.t("¡EMPATE!", "IT'S A TIE!")


# ── Datos de cada jugador ────────────────────────────────────────────────────

func _stat(i: int) -> Dictionary:
	if i == 0:
		return {
			"acc": GameState.last_accuracy,
			"inst": GameState.last_instrument,
			"combo": GameState.last_max_combo,
			"hits": GameState.last_hit_notes,
			"total": GameState.last_total_notes,
			"score": GameState.last_score,
		}
	return {
		"acc": GameState.last_accuracy_p2,
		"inst": GameState.last_instrument_p2,
		"combo": GameState.last_max_combo_p2,
		"hits": GameState.last_hit_notes_p2,
		"total": GameState.last_total_notes_p2,
		"score": GameState.last_score_p2,
	}


func _total_score() -> int:
	var total: int = 0
	for i in _cols.size():
		total += int(_stat(i)["score"])
	return total


# ── Contenido ────────────────────────────────────────────────────────────────

func _fill_texts() -> void:
	var title_text: String = GameState.selected_song_title
	if title_text == "":
		title_text = GameState.selected_song_name
	if _title != null:
		_title.text = title_text.to_upper()

	for i in _cols.size():
		var c: Col = _cols[i]
		var st: Dictionary = _stat(i)
		var acc: float = float(st["acc"])
		var inst: String = str(st["inst"])

		if c.inst_lbl != null:
			c.inst_lbl.text = RB.instrument_name(inst)
		if c.rank_label != null:
			c.rank_label.text = RB.rank_text(acc)
		if c.rank_bar != null:
			c.rank_bar.add_theme_stylebox_override("panel", RB.box(RB.rank_color(acc), 0))
		if c.combo_lbl != null:
			c.combo_lbl.text = "%s  x%d" % [RB.t("COMBO MÁXIMO", "MAX COMBO"), int(st["combo"])]
		if c.notes_lbl != null:
			c.notes_lbl.text = "%s  %d / %d" % [RB.t("NOTAS", "NOTES"), int(st["hits"]), int(st["total"])]
		if c.solo_icon != null and "instrument" in c.solo_icon:
			c.solo_icon.instrument = inst
		if _two and c.caption != null:
			c.caption.text = RB.t("JUGADOR %d · PUNTOS", "PLAYER %d · SCORE") % (i + 1)

	if _name_edit != null:
		_name_edit.placeholder_text = RB.t("Tu nombre", "Your name")
		if GameState.player1_name != "P1":
			_name_edit.text = GameState.player1_name
			
	if _two and _name_edit2 != null:
		_name_edit2.placeholder_text = RB.t("Tu nombre", "Your name")
		if GameState.player2_name != "P2":
			_name_edit2.text = GameState.player2_name
func _play_intro() -> void:
	create_tween().set_loops().tween_property(_medallion, "rotation", TAU, 16.0).from(0.0)
	RB.slide_in(_title, Vector2(0.0, -30.0), 0.0, 0.5)
	RB.slide_in(_score_row, Vector2(0.0, -20.0), 0.12, 0.5)
	for i in _cols.size():
		var c: Col = _cols[i]
		var d: float = 0.06 * float(i)
		RB.slide_in(c.block, Vector2(-60.0, 0.0), 0.15 + d, 0.5)
		RB.slide_in(c.combo_lbl, Vector2(-60.0, 0.0), 0.22 + d, 0.5)
		RB.slide_in(c.notes_lbl, Vector2(-60.0, 0.0), 0.26 + d, 0.5)
		RB.slide_in(c.solo, Vector2(-60.0, 0.0), 0.30 + d, 0.5)
	if _two:
		for n in _right_nodes:
			RB.slide_in(n as Control, Vector2(60.0, 0.0), 0.3, 0.5)
	else:
		RB.slide_in(_board, Vector2(60.0, 0.0), 0.2, 0.55)
		RB.slide_in(_name_edit, Vector2(0.0, 30.0), 0.4, 0.45)
		RB.slide_in(_save_btn, Vector2(0.0, 30.0), 0.45, 0.45)
	RB.slide_in(_bottom_bar, Vector2(0.0, 60.0), 0.35, 0.5)


# ── Animación de entrada ─────────────────────────────────────────────────────

func _animate_in() -> void:
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(_show_progress, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_reveal_stars)


## p va de 0 a 1: sube los puntos y la precisión de cada jugador (y el total de arriba).
func _show_progress(p: float) -> void:
	_score_lbl.text = RB.fmt_int(int(roundf(float(_total_score()) * p)))
	for i in _cols.size():
		var c: Col = _cols[i]
		var st: Dictionary = _stat(i)
		c.score_lbl.text = RB.fmt_int(int(roundf(float(st["score"]) * p)))
		c.acc_lbl.text = "%d%%" % int(roundf(float(st["acc"]) * 100.0 * p))


func _reveal_stars() -> void:
	var avg: float = 0.0
	for i in _cols.size():
		var c: Col = _cols[i]
		var acc: float = float(_stat(i)["acc"])
		avg += acc
		c.stars.reveal(RB.stars_for(acc), 0.16)
		c.acc_lbl.text = "%.1f%%" % (acc * 100.0)
		RB.pop(c.acc_lbl, 1.10, 0.3)
		c.rank_bar.modulate = Color(1.7, 1.7, 1.7, 1.0)
		create_tween().tween_property(c.rank_bar, "modulate", Color.WHITE, 0.5)
	# Estrellas de arriba: según la precisión promedio de los jugadores
	_stars_top.reveal(RB.stars_for(avg / float(_cols.size())), 0.16)


# ── Guardado y tabla de posiciones ───────────────────────────────────────────

func _db_ready() -> bool:
	return Database != null and Database.db != null


func _on_name_submitted(_text: String, which: int) -> void:
	# En 2 jugadores, Enter en el nombre 1 pasa al nombre 2; Enter en el último guarda
	if _two and which == 0:
		_name_edit2.grab_focus()
		return
	_on_save_pressed()


func _on_save_pressed() -> void:
	if _saved:
		return
	var player_name: String = _name_edit.text.strip_edges()
	if player_name.is_empty():
		player_name = RB.t("Anónimo", "Anonymous")
	GameState.player1_name = player_name

	var player2_name: String = ""
	if _two:
		player2_name = _name_edit2.text.strip_edges()
		if player2_name.is_empty():
			player2_name = RB.t("Anónimo 2", "Anonymous 2")
		GameState.player2_name = player2_name

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
	if _two:
		Database.save_score(
			player2_name,
			GameState.selected_song_name,
			GameState.last_score_p2,
			GameState.last_accuracy_p2,
			GameState.last_max_combo_p2,
			GameState.last_hit_notes_p2,
			GameState.last_total_notes_p2,
			true
		)

	_saved = true
	_save_btn.text = RB.t("¡GUARDADO!", "SAVED!")
	_save_btn.disabled = true
	_name_edit.release_focus()
	_name_edit.editable = false
	if _two:
		_name_edit2.release_focus()
		_name_edit2.editable = false
	else:
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
	# Los botones del control son también los carriles: no salir por un golpe de la última nota
	if event is InputEventJoypadButton and Time.get_ticks_msec() - _born_ms < 1500:
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
