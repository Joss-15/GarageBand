## main_menu.gd
## Menú principal: JUGAR / OPCIONES / SALIR (escena main_menu.tscn).
## "Opciones" abre un carrusel (volumen, teclas, idioma, daltonismo) con inicio y
## fin. Las teclas se reasignan en una ventana modal con ACEPTAR/CANCELAR.
## La interfaz fija vive en la escena; aquí solo hay lógica y contenido dinámico.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")

const MAIN_POS := Vector2(86.0, 250.0)

# Zona del carrusel de opciones: debajo del título "OPCIONES" y encima de la tarjeta de jugador.
const CAROUSEL_MARGIN := 100.0   # separación del texto al borde izquierdo (= ancho extra de la losa)
const CAROUSEL_POS := Vector2(68.0, 280.0)   # x = MAIN_POS.x - CAROUSEL_MARGIN: el texto queda alineado con el título
const CAROUSEL_W := 620.0
const CAROUSEL_H := 236.0

var _in_options: bool = false
var _vol_tween: Tween = null

@onready var _list: Control = %List
@onready var _sub_header: Label = %SubHeader
@onready var _logo: Control = %Logo
@onready var _tab: Control = %PlayerTab
@onready var _modal: Control = %KeybindModal
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_label: Label = %VolumeValue


func _ready() -> void:
	GameState.apply_settings()
	GameState.play_menu_music()
	RB.localize(self)

	_list.activated.connect(_on_activated)
	_list.cancelled.connect(_on_cancelled)
	_list.selection_changed.connect(_on_list_selection_changed)
	_modal.closed.connect(_on_modal_closed)

	_volume_slider.value = GameState.master_volume
	_volume_slider.value_changed.connect(_on_volume_changed)
	_update_volume_label()

	_refresh_tab()
	_start_logo_shimmer()
	_show_main_menu(true)

	RB.slide_in(_logo, Vector2(-80.0, 0.0), 0.0, 0.6)
	RB.slide_in(_tab, Vector2(0.0, 90.0), 0.3, 0.6)


func _exit_tree() -> void:
	GameState.save_settings()


func _start_logo_shimmer() -> void:
	# Brillo suave que respira
	for lbl in _logo.get_children():
		var shimmer := create_tween().set_loops()
		shimmer.tween_property(lbl, "modulate", Color(1.25, 1.2, 1.05, 1.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shimmer.tween_property(lbl, "modulate", Color.WHITE, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _refresh_tab() -> void:
	var player: String = GameState.player1_name
	if player == "P1":
		player = RB.t("Jugador 1", "Player 1")
	_tab.setup(player, GameState.selected_instrument)


# ── Volumen ──────────────────────────────────────────────────────────────────

func _update_volume_label() -> void:
	_volume_label.text = "%d%%" % int(roundf(_volume_slider.value * 100.0))


func _on_volume_changed(v: float) -> void:
	GameState.master_volume = maxf(v, 0.001)
	GameState.apply_audio()
	_update_volume_label()


## El slider de volumen solo aparece (a la derecha de la opción central) cuando
## VOLUMEN es la opción seleccionada del carrusel.
func _update_volume_controls(animate: bool = true) -> void:
	var show_it: bool = _in_options and _list.selected_id() == "volume"
	if _vol_tween != null and _vol_tween.is_valid():
		_vol_tween.kill()
	if not show_it:
		if animate and _volume_slider.visible:
			_vol_tween = create_tween().set_parallel(true)
			_vol_tween.tween_property(_volume_slider, "modulate:a", 0.0, 0.12)
			_vol_tween.tween_property(_volume_label, "modulate:a", 0.0, 0.12)
			_vol_tween.chain().tween_callback(_hide_volume_controls)
		else:
			_hide_volume_controls()
		return
	var label_w: float = RB.text_width(RB.t("VOLUMEN", "VOLUME"), 46)
	var right_edge: float = CAROUSEL_POS.x + CAROUSEL_MARGIN + label_w
	var cy: float = CAROUSEL_POS.y + CAROUSEL_H * 0.5
	_volume_slider.position = Vector2(right_edge + 44.0, cy - _volume_slider.size.y * 0.5)
	_volume_label.position = Vector2(_volume_slider.position.x + _volume_slider.size.x + 18.0, cy - 22.0)
	_volume_slider.value = GameState.master_volume
	_update_volume_label()
	_volume_slider.visible = true
	_volume_label.visible = true
	if animate:
		_volume_slider.modulate.a = 0.0
		_volume_label.modulate.a = 0.0
		_vol_tween = create_tween().set_parallel(true)
		_vol_tween.tween_property(_volume_slider, "modulate:a", 1.0, 0.3).set_delay(0.15)
		_vol_tween.tween_property(_volume_label, "modulate:a", 1.0, 0.3).set_delay(0.15)
	else:
		_volume_slider.modulate.a = 1.0
		_volume_label.modulate.a = 1.0


func _hide_volume_controls() -> void:
	_volume_slider.visible = false
	_volume_label.visible = false


func _on_list_selection_changed(_index: int) -> void:
	if _in_options:
		_update_volume_controls(true)


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
	_list.carousel = false
	_list.wrap_around = true
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
	_list.font_size = 46
	_list.row_height = 56.0
	_list.indent_step = 0.0
	_list.carousel = true
	_list.wrap_around = false
	_list.carousel_align_left = true
	_list.carousel_margin_left = CAROUSEL_MARGIN
	_list.carousel_width = CAROUSEL_W
	_list.carousel_center_y = CAROUSEL_H * 0.5
	_list.carousel_spacing = 58.0
	_list.position = CAROUSEL_POS
	_list.size = Vector2(CAROUSEL_W, CAROUSEL_H)
	_list.set_items(_options_items(), keep_index, animate)
	_update_volume_controls(animate)


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
			_update_volume_controls(false)
		"back":
			GameState.save_settings()
			_show_main_menu(false)


func _on_cancelled() -> void:
	if _in_options:
		GameState.save_settings()
		_show_main_menu(false)


func _on_modal_closed(_applied: bool) -> void:
	_list.keyboard_enabled = true


## Vuelve a poner los textos de la escena y de las listas tras cambiar de idioma.
func _refresh_texts() -> void:
	RB.localize(self)
	_refresh_tab()
	_sub_header.text = RB.t("OPCIONES", "OPTIONS")
	_list.set_items(_options_items(), _list.selected, false)
	_update_volume_controls(false)


func _unhandled_input(event: InputEvent) -> void:
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
