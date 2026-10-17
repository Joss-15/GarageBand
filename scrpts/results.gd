## results.gd
## Muestra resultados y maneja guardado/consulta de scores via el singleton Database.

extends Control

@onready var song_label:        Label    = $VBox/SongLabel
@onready var name_field_p1:     LineEdit = $VBox/NamesBox/NameFieldP1
@onready var name_field_p2:     LineEdit = $VBox/NamesBox/NameFieldP2
@onready var label_p2:          Label    = $VBox/NamesBox/LabelP2
@onready var save_button:       Button   = $VBox/SaveButton
@onready var leaderboard:       ItemList = $VBox/Leaderboard
@onready var back_button:       Button   = $VBox/BackButton
@onready var score_label_p1:    Label    = $VBox/ResultsBox/P1/ScoreLabel
@onready var accuracy_label_p1: Label    = $VBox/ResultsBox/P1/AccuracyLabel
@onready var combo_label_p1:    Label    = $VBox/ResultsBox/P1/ComboLabel
@onready var results_box_p2:    Control  = $VBox/ResultsBox/P2
@onready var score_label_p2:    Label    = $VBox/ResultsBox/P2/ScoreLabel
@onready var accuracy_label_p2: Label    = $VBox/ResultsBox/P2/AccuracyLabel
@onready var combo_label_p2:    Label    = $VBox/ResultsBox/P2/ComboLabel
@onready var regresar_button:   Button   = $VBox/BackButton
@onready var p1_label:          Label    = $VBox/ResultsBox/P1/Label
@onready var p2_label:          Label    = $VBox/ResultsBox/P2/Label

var _saved := false


func _ready() -> void:
	var two_p := GameState.two_player_mode
	var en    := (GameState.current_language == "en")

	_apply_language(en)

	song_label.text = "♪ %s" % GameState.selected_song_name

	# Resultados P1
	score_label_p1.text    = "Score: %d"    % GameState.last_score
	accuracy_label_p1.text = "Accuracy: %s" % _fmt_accuracy(GameState.last_accuracy)
	combo_label_p1.text    = "Max Combo: %d" % GameState.last_max_combo

	# P2 — solo visible en modo 2 jugadores
	results_box_p2.visible = two_p
	label_p2.visible       = two_p
	name_field_p2.visible  = two_p

	if two_p:
		score_label_p2.text    = "Score: %d"    % GameState.last_score_p2
		accuracy_label_p2.text = "Accuracy: %s" % _fmt_accuracy(GameState.last_accuracy_p2)
		combo_label_p2.text    = "Max Combo: %d" % GameState.last_max_combo_p2

	# Rellenar nombres previos si los hay
	name_field_p1.text = GameState.player1_name if GameState.player1_name != "P1" else ""
	name_field_p2.text = GameState.player2_name if GameState.player2_name != "P2" else ""

	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_load_leaderboard()


# ── IDIOMA ────────────────────────────────────────────────────────────────────

func _apply_language(en: bool) -> void:
	p1_label.text      = "--- Player 1 ---" if en else "--- Jugador 1 ---"
	p2_label.text      = "--- Player 2 ---" if en else "--- Jugador 2 ---"
	save_button.text   = "Save Score"       if en else "Guardar Puntuacion"
	regresar_button.text = "Back"           if en else "Regresar"
	name_field_p1.placeholder_text = "Player 1 name" if en else "Nombre Jugador 1"
	name_field_p2.placeholder_text = "Player 2 name" if en else "Nombre Jugador 2"


# ── GUARDAR ───────────────────────────────────────────────────────────────────

func _on_save_pressed() -> void:
	if _saved:
		return

	var en := (GameState.current_language == "en")

	# Nombre P1
	var name_p1 := name_field_p1.text.strip_edges()
	if name_p1.is_empty():
		name_p1 = "Anonymous" if en else "Anonimo"
	GameState.player1_name = name_p1

	# Guardar P1 via singleton Database
	Database.save_score(
		name_p1,
		GameState.selected_song_name,
		GameState.last_score,
		GameState.last_accuracy,
		GameState.last_max_combo,
		GameState.last_hit_notes,
		GameState.last_total_notes,
		GameState.two_player_mode
	)

	# Guardar P2 si aplica
	if GameState.two_player_mode:
		var name_p2 := name_field_p2.text.strip_edges()
		if name_p2.is_empty():
			name_p2 = "Anonymous 2" if en else "Anonimo 2"
		GameState.player2_name = name_p2

		Database.save_score(
			name_p2,
			GameState.selected_song_name,
			GameState.last_score_p2,
			GameState.last_accuracy_p2,
			GameState.last_max_combo_p2,
			GameState.last_hit_notes_p2,
			GameState.last_total_notes,
			GameState.two_player_mode
		)

	_saved           = true
	save_button.text = "Saved!" if en else "Guardado!"
	save_button.disabled = true

	# Recargar el leaderboard para mostrar el nuevo score
	_load_leaderboard()


# ── LEADERBOARD ───────────────────────────────────────────────────────────────

func _load_leaderboard() -> void:
	var en   := (GameState.current_language == "en")
	var rows := Database.get_top10(GameState.selected_song_name)

	leaderboard.clear()

	if rows.is_empty():
		leaderboard.add_item(
			"No records yet. Be the first!" if en
			else "Sin registros aun. Se el primero!"
		)
		return

	for i in rows.size():
		var row: Dictionary = rows[i]
		var acc   := "%.1f%%" % (float(row["accuracy"]) * 100.0)
		var entry := "#%d  %-15s  %7d pts  %s  combo:%d  %s" % [
			i + 1,
			row["player_name"],
			row["score"],
			acc,
			row["max_combo"],
			row["date"],
		]
		leaderboard.add_item(entry)

		# Resaltar las entradas del jugador actual
		if row["player_name"] == GameState.player1_name or \
		   row["player_name"] == GameState.player2_name:
			leaderboard.set_item_custom_fg_color(i, Color(0.3, 1.0, 0.5))


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _fmt_accuracy(val: float) -> String:
	return "%.1f%%" % (val * 100.0)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/song_select.tscn")
