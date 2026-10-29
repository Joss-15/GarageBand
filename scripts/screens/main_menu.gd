## main_menu.gd
## Menú principal: JUGAR / OPCIONES / SALIR.
## "Opciones" despliega un submenú en cascada (volumen, teclas, idioma,
## daltonismo). Las teclas se reasignan en una ventana modal con ACEPTAR/CANCELAR.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const BACKDROP = preload("res://scripts/widgets/rb_backdrop.gd")
const MENU_LIST = preload("res://scripts/widgets/rb_menu_list.gd")
const PLAYER_TAB = preload("res://scripts/widgets/player_tab.gd")
const SONG_LIB = preload("res://scripts/core/song_library.gd")
const KEYBIND_MODAL = preload("res://scripts/widgets/keybind_modal.gd")

const MAIN_POS := Vector2(86.0, 250.0)

var _list: Control = null
var _sub_header: Label = null
var _logo: Control = null
var _profile: Control = null
var _ticker: Control = null
var _tab: Control = null
var _modal: Control = null
var _volume_slider: HSlider = null
var _volume_label: Label = null
var _tip_label: Label = null
var _tip_title: Control = null
var _tips: Array[String] = []
var _tip_idx: int = 0
var _in_options: bool = false


func _ready() -> void:
	GameState.apply_settings()
	GameState.play_menu_music()

	var backdrop := BACKDROP.new()
	backdrop.tint = Color(0.28, 0.40, 0.95)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_logo()

	_sub_header = RB.label("", 58, Color(0.60, 0.62, 0.68, 0.75))
	_sub_header.position = MAIN_POS
	_sub_header.visible = false
	add_child(_sub_header)

	_list = MENU_LIST.new()
	_list.size = Vector2(760.0, 420.0)
	add_child(_list)
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_on_cancelled)

	_build_volume_controls()
	_build_profile()
	#_build_ticker()
	_build_tab()

	_modal = KEYBIND_MODAL.new()
	add_child(_modal)
	_modal.closed.connect(_on_modal_closed)

	_show_main_menu(true)

	RB.slide_in(_logo, Vector2(-80.0, 0.0), 0.0, 0.6)
	RB.slide_in(_profile, Vector2(80.0, 0.0), 0.15, 0.6)
	RB.slide_in(_tab, Vector2(0.0, 90.0), 0.3, 0.6)
	RB.slide_in(_ticker, Vector2(0.0, 30.0), 0.45, 0.6)


func _exit_tree() -> void:
	GameState.save_settings()


# ── Construcción de la interfaz ──────────────────────────────────────────────

func _build_logo() -> void:
	_logo = Control.new()
	_logo.position = Vector2(84.0, 40.0)
	_logo.size = Vector2(520.0, 90.0)
	add_child(_logo)
	var brand: Font = RB.brand_font()
	var garage := Label.new()
	garage.text = "GARAGE"
	garage.add_theme_font_override("font", brand)
	garage.add_theme_font_size_override("font_size", 58)
	garage.add_theme_color_override("font_color", Color.WHITE)
	garage.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	garage.add_theme_constant_override("outline_size", 10)
	_logo.add_child(garage)
	var band := Label.new()
	band.text = "BAND"
	band.add_theme_font_override("font", brand)
	band.add_theme_font_size_override("font_size", 58)
	band.add_theme_color_override("font_color", RB.GOLD)
	band.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	band.add_theme_constant_override("outline_size", 10)
	band.position = Vector2(garage.get_minimum_size().x + 18.0, 0.0)
	_logo.add_child(band)
	# Brillo suave que respira
	for lbl in [garage, band]:
		var shimmer := create_tween().set_loops()
		shimmer.tween_property(lbl, "modulate", Color(1.25, 1.2, 1.05, 1.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shimmer.tween_property(lbl, "modulate", Color.WHITE, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_profile() -> void:
	if _profile != null:
		_profile.queue_free()
	_profile = Control.new()
	_profile.position = Vector2(760.0, 26.0)
	_profile.size = Vector2(370.0, 94.0)
	add_child(_profile)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", RB.box(Color(0.03, 0.04, 0.08, 0.90), 3, Color(0.80, 0.82, 0.90), 2))
	bg.size = _profile.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile.add_child(bg)

	var crest := Panel.new()
	crest.add_theme_stylebox_override("panel", RB.box(Color(0.10, 0.06, 0.06), 3, RB.GOLD, 3))
	crest.position = Vector2(9.0, 9.0)
	crest.size = Vector2(76.0, 76.0)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gb := Label.new()
	gb.text = "GB"
	gb.add_theme_font_override("font", RB.brand_font())
	gb.add_theme_font_size_override("font_size", 38)
	gb.add_theme_color_override("font_color", RB.GOLD)
	gb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gb.size = crest.size
	crest.add_child(gb)
	_profile.add_child(crest)

	var stars: int = SONG_LIB.total_stars()
	var rank: Dictionary = RB.fan_rank(stars)
	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	var name_lbl := RB.label(player, 28, Color.WHITE)
	name_lbl.position = Vector2(98.0, 4.0)
	_profile.add_child(name_lbl)
	var stars_lbl := RB.label("%s %s" % [RB.fmt_int(stars), RB.t("ESTRELLAS", "STARS")], 21, Color.WHITE)
	stars_lbl.position = Vector2(98.0, 36.0)
	_profile.add_child(stars_lbl)

	var track := Panel.new()
	track.add_theme_stylebox_override("panel", RB.box(Color(0.20, 0.21, 0.26), 3))
	track.position = Vector2(98.0, 66.0)
	track.size = Vector2(190.0, 6.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile.add_child(track)
	var span: int = maxi(int(rank["next"]) - int(rank["cur"]), 1)
	var frac: float = 1.0 if int(rank["next"]) == int(rank["cur"]) else clampf(float(stars - int(rank["cur"])) / float(span), 0.0, 1.0)
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", RB.box(Color(0.92, 0.94, 1.0), 3))
	fill.position = Vector2(98.0, 66.0)
	fill.size = Vector2(0.0, 6.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile.add_child(fill)
	create_tween().tween_property(fill, "size:x", 190.0 * frac, 0.9).set_delay(0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var rank_lbl := RB.label("%s %s" % [RB.t("RANGO:", "RANK:"), str(rank["name"])], 14, RB.GRAY_TXT)
	rank_lbl.position = Vector2(98.0, 72.0)
	_profile.add_child(rank_lbl)

	var note_box := Panel.new()
	note_box.add_theme_stylebox_override("panel", RB.box(Color(0.12, 0.13, 0.18), 3, Color(0.8, 0.82, 0.9), 2))
	note_box.position = Vector2(304.0, 22.0)
	note_box.size = Vector2(52.0, 52.0)
	note_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note := RB.label("♪", 36, Color(0.9, 0.92, 1.0))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.size = note_box.size
	note_box.add_child(note)
	_profile.add_child(note_box)


func _build_ticker() -> void:
	if _ticker != null:
		_ticker.queue_free()
	_tips = [
		RB.t("Agrega tus propias canciones: una carpeta en songs/ con el .wav y su .json de notas.",
			"Add your own songs: a folder in songs/ with the .wav and its notes .json."),
		RB.t("Cada instrumento puede tener su propio mapa: nombre_guitarra.json, nombre_bajo.json...",
			"Each instrument can have its own chart: name_guitarra.json, name_bajo.json..."),
		RB.t("Mantén el combo: cada acierto seguido suma un bonus a tu puntuación.",
			"Keep your combo going: every hit in a row adds a bonus to your score."),
	]
	_tip_idx = clampi(_tip_idx, 0, _tips.size() - 1)
	_ticker = Control.new()
	_ticker.position = Vector2(60.0, 506.0)
	_ticker.size = Vector2(1000.0, 56.0)
	add_child(_ticker)
	var chip := ColorRect.new()
	chip.color = Color(0.95, 0.85, 0.10)
	chip.position = Vector2(0.0, 2.0)
	chip.size = Vector2(12.0, 22.0)
	_ticker.add_child(chip)
	var title := RB.label("%s (%d/%d)" % [RB.t("SIGUIENTE MENSAJE", "NEXT MESSAGE"), _tip_idx + 1, _tips.size()], 20, Color.WHITE)
	title.position = Vector2(24.0, 0.0)
	_ticker.add_child(title)
	_tip_title = title
	_tip_label = RB.label(_tips[_tip_idx], 19, RB.GRAY_TXT, false)
	_tip_label.position = Vector2(0.0, 28.0)
	_ticker.add_child(_tip_label)
	var timer := Timer.new()
	timer.wait_time = 7.0
	timer.autostart = true
	timer.timeout.connect(_next_tip)
	_ticker.add_child(timer)


func _next_tip() -> void:
	if _tips.is_empty() or _tip_label == null:
		return
	_tip_idx = (_tip_idx + 1) % _tips.size()
	var tw := create_tween()
	tw.tween_property(_tip_label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_swap_tip)
	tw.tween_property(_tip_label, "modulate:a", 1.0, 0.35)


func _swap_tip() -> void:
	_tip_label.text = _tips[_tip_idx]
	(_tip_title as Label).text = "%s (%d/%d)" % [RB.t("SIGUIENTE MENSAJE", "NEXT MESSAGE"), _tip_idx + 1, _tips.size()]


func _build_tab() -> void:
	if _tab != null:
		_tab.queue_free()
	_tab = PLAYER_TAB.new()
	_tab.position = Vector2(50.0, 570.0)
	add_child(_tab)
	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	_tab.setup(player, GameState.selected_instrument, "ENTER", RB.t("SELECCIONAR", "SELECT"), 340.0)


func _build_volume_controls() -> void:
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = GameState.master_volume
	_volume_slider.size = Vector2(260.0, 28.0)
	_volume_slider.focus_mode = Control.FOCUS_NONE
	_volume_slider.visible = false
	var track := RB.box(Color(0.10, 0.11, 0.16), 5, Color(0.5, 0.52, 0.6), 1)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	_volume_slider.add_theme_stylebox_override("slider", track)
	_volume_slider.add_theme_stylebox_override("grabber_area", RB.box(RB.GOLD, 5))
	_volume_slider.add_theme_stylebox_override("grabber_area_highlight", RB.box(RB.GOLD_BRIGHT, 5))
	var knob: Texture2D = RB.disc_texture(28, Color(0.97, 0.97, 1.0))
	_volume_slider.add_theme_icon_override("grabber", knob)
	_volume_slider.add_theme_icon_override("grabber_highlight", knob)
	_volume_slider.value_changed.connect(_on_volume_changed)
	add_child(_volume_slider)

	_volume_label = RB.label("", 30, Color.WHITE)
	_volume_label.visible = false
	add_child(_volume_label)
	_update_volume_label()


func _update_volume_label() -> void:
	_volume_label.text = "%d%%" % int(roundf(_volume_slider.value * 100.0))


func _on_volume_changed(v: float) -> void:
	GameState.master_volume = maxf(v, 0.001)
	GameState.apply_audio()
	_update_volume_label()


# ── Navegación ───────────────────────────────────────────────────────────────

func _show_main_menu(first: bool) -> void:
	_in_options = false
	_volume_slider.visible = false
	_volume_label.visible = false
	if _sub_header.visible:
		var tw := create_tween()
		tw.tween_property(_sub_header, "modulate:a", 0.0, 0.15)
		tw.tween_callback(_sub_header.hide)
	_list.font_size = 64
	_list.row_height = 70.0
	_list.indent_step = 0.0
	_list.position = MAIN_POS
	_list.set_items([
		{"id": "play", "text": RB.t("JUGAR", "PLAY")},
		{"id": "options", "text": RB.t("OPCIONES", "OPTIONS")},
		{"id": "quit", "text": RB.t("SALIR", "QUIT")},
	], 0 if first else 1, true)


func _options_items() -> Array:
	var en: bool = GameState.current_language == "en"
	return [
		{"id": "volume", "text": RB.t("VOLUMEN", "VOLUME")},
		{"id": "keys", "text": RB.t("TECLAS", "KEY BINDINGS")},
		{"id": "language", "text": RB.t("IDIOMA: ", "LANGUAGE: ") + ("ENGLISH" if en else "ESPAÑOL")},
		{"id": "colorblind", "text": RB.t("DALTONISMO: ", "COLORBLIND: ") + (RB.t("SÍ", "ON") if GameState.colorblind_mode else RB.t("NO", "OFF"))},
		{"id": "back", "text": RB.t("ATRÁS", "BACK")},
	]


func _show_options(keep_index: int = 0, animate: bool = true) -> void:
	_in_options = true
	_sub_header.text = RB.t("OPCIONES", "OPTIONS")
	_sub_header.modulate.a = 0.0
	_sub_header.visible = true
	create_tween().tween_property(_sub_header, "modulate:a", 1.0, 0.3)
	_list.font_size = 50
	_list.row_height = 60.0
	_list.indent_step = 36.0
	_list.position = MAIN_POS + Vector2(34.0, 76.0)
	_list.set_items(_options_items(), keep_index, animate)
	_place_volume_controls()


func _place_volume_controls() -> void:
	var width: float = RB.text_width(RB.t("VOLUMEN", "VOLUME"), 50)
	_volume_slider.position = _list.position + Vector2(width + 56.0, 16.0)
	_volume_label.position = _volume_slider.position + Vector2(_volume_slider.size.x + 18.0, -6.0)
	_volume_slider.value = GameState.master_volume
	_update_volume_label()
	_volume_slider.visible = true
	_volume_label.visible = true
	_volume_slider.modulate.a = 0.0
	_volume_label.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_volume_slider, "modulate:a", 1.0, 0.4).set_delay(0.25)
	tw.tween_property(_volume_label, "modulate:a", 1.0, 0.4).set_delay(0.25)


func _on_activated(id: String) -> void:
	match id:
		"play":
			SceneFade.go("res://scenes/screens/song_select.tscn")
		"options":
			_show_options(0, true)
		"quit":
			GameState.save_settings()
			get_tree().quit()
		"keys":
			_list.keyboard_enabled = false
			_modal.open()
		"language":
			GameState.current_language = "es" if GameState.current_language == "en" else "en"
			GameState.save_settings()
			_refresh_texts()
		"colorblind":
			GameState.colorblind_mode = not GameState.colorblind_mode
			GameState.apply_colorblind()
			GameState.save_settings()
			_list.set_items(_options_items(), _list.selected, false)
			_place_volume_controls_keep()
		"back":
			GameState.save_settings()
			_show_main_menu(false)


func _place_volume_controls_keep() -> void:
	_volume_slider.visible = true
	_volume_label.visible = true


func _on_cancelled() -> void:
	if _in_options:
		GameState.save_settings()
		_show_main_menu(false)


func _on_modal_closed(_applied: bool) -> void:
	_list.keyboard_enabled = true


## Reconstruye los textos tras cambiar de idioma.
func _refresh_texts() -> void:
	_build_profile()
	#_build_ticker()
	_build_tab()
	_sub_header.text = RB.t("OPCIONES", "OPTIONS")
	_list.set_items(_options_items(), _list.selected, false)
	_place_volume_controls_keep()
	var width: float = RB.text_width(RB.t("VOLUMEN", "VOLUME"), 50)
	_volume_slider.position = _list.position + Vector2(width + 56.0, 16.0)
	_volume_label.position = _volume_slider.position + Vector2(_volume_slider.size.x + 18.0, -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_TAB and not (event as InputEventKey).echo:
		_next_tip()
		get_viewport().set_input_as_handled()
		return
	if not _in_options or not _list.keyboard_enabled:
		return
	if _list.selected_id() != "volume":
		return
	if event.is_action_pressed("ui_left"):
		_volume_slider.value = clampf(_volume_slider.value - 0.05, 0.0, 1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_volume_slider.value = clampf(_volume_slider.value + 0.05, 0.0, 1.0)
		get_viewport().set_input_as_handled()
