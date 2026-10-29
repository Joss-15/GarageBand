## song_row.gd
## Fila de una canción en la biblioteca (escena song_row.tscn): título, artista y
## estrellas obtenidas. Emite `pressed` al hacer clic con el mouse.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

signal pressed(double_click: bool)

@onready var _title: Label = $Title
@onready var _artist: Label = $Artist
@onready var _stars: Control = $Stars


## song: diccionario de song_library.gd (usa "title" y "artist").
func setup(song: Dictionary, stars: int) -> void:
	var title_text: String = str(song["title"])
	_title.text = title_text
	var artist_text: String = str(song["artist"])
	_artist.visible = artist_text != ""
	_artist.text = artist_text
	_artist.position.x = 70.0 + RB.text_width(title_text, 25) + 16.0
	_stars.value = stars


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(mb.double_click)
