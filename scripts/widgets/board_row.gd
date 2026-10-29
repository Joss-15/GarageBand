## board_row.gd
## Fila de la tabla de posiciones (escena board_row.tscn): puesto, jugador, puntos,
## precisión, combo y fecha. `mine` resalta el récord recién guardado.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

@onready var _highlight: ColorRect = $Highlight
@onready var _cells: Array[Label] = [$Rank, $Player, $Score, $Accuracy, $Combo]
@onready var _date: Label = $Date


## data: fila de Database.get_top10 (player_name, score, accuracy, max_combo, date).
func setup(rank: int, data: Dictionary, mine: bool) -> void:
	_highlight.visible = mine
	var color: Color = Color(0.55, 1.0, 0.70) if mine else RB.WHITE_SOFT
	var texts: Array[String] = [
		"%d" % rank,
		str(data["player_name"]),
		RB.fmt_int(int(data["score"])),
		"%.1f%%" % (float(data["accuracy"]) * 100.0),
		"x%d" % int(data["max_combo"]),
	]
	for i in _cells.size():
		_cells[i].text = texts[i]
		_cells[i].add_theme_color_override("font_color", color)
	_date.text = str(data["date"])
