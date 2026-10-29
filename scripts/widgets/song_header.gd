## song_header.gd
## Encabezado de letra de la biblioteca (escena song_header.tscn): la letra, cuántas
## canciones tiene y las estrellas ganadas sobre las posibles.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

@onready var _letter: Label = $Letter
@onready var _count: Label = $Count
@onready var _earned: Label = $Earned


func setup(letter: String, count: int, earned_stars: int) -> void:
	_letter.text = letter
	_count.text = "%d %s" % [count, RB.t("CANCIONES" if count != 1 else "CANCIÓN", "SONGS" if count != 1 else "SONG")]
	_earned.text = "%d/%d" % [earned_stars, count * 5]
