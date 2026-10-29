## cover_art.gd
## Marco con la portada de una canción. Si la carpeta de la canción tiene
## cover.png/jpg se usa esa imagen; si no, se genera una portada de color
## a partir del nombre con la inicial del título.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

var _frame: Panel = null
var _tex: TextureRect = null
var _bg: TextureRect = null
var _letter: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", RB.box(Color(0.05, 0.06, 0.09), 3, Color(0.82, 0.84, 0.90), 3))
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)

	_letter = Label.new()
	_letter.add_theme_font_override("font", RB.brand_font())
	_letter.add_theme_font_size_override("font_size", int(size.y * 0.46))
	_letter.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	_letter.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	_letter.add_theme_constant_override("outline_size", 8)
	_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letter)
	_letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	_tex.visible = false


## song: diccionario de song_library.gd (usa "cover", "name", "title").
func set_song(song: Dictionary) -> void:
	if _frame == null:
		return
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
