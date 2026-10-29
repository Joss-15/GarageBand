## cover_art.gd
## Marco con la portada de una canción (escena cover_art.tscn). Si la carpeta de
## la canción tiene cover.png/jpg se usa esa imagen; si no, se genera una portada
## de color a partir del nombre con la inicial del título.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

@onready var _bg: TextureRect = $Bg
@onready var _letter: Label = $Letter
@onready var _tex: TextureRect = $Cover


func _ready() -> void:
	_letter.add_theme_font_size_override("font_size", int(size.y * 0.46))


## song: diccionario de song_library.gd (usa "cover", "name", "title").
func set_song(song: Dictionary) -> void:
	var cover_path: String = str(song.get("cover", ""))
	var cover: Texture2D = null
	if cover_path != "":
		cover = load(cover_path) as Texture2D
	if cover != null:
		_tex.texture = cover
		_tex.visible = true
		_bg.visible = false
		_letter.visible = false
	else:
		var seed_name: String = str(song.get("name", "?"))
		var hue: float = float(absi(hash(seed_name)) % 360) / 360.0
		var c0: Color = Color.from_hsv(hue, 0.62, 0.62)
		var c1: Color = Color.from_hsv(fmod(hue + 0.12, 1.0), 0.80, 0.22)
		_bg.texture = RB.v_gradient(c0, c1)
		_bg.visible = true
		_tex.visible = false
		var title: String = str(song.get("title", "?"))
		_letter.text = title.substr(0, 1).to_upper()
		_letter.visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.28)
