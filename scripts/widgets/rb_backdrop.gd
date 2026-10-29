## rb_backdrop.gd
## Fondo animado de los menús: foto oscurecida con zoom lento, haces de luz,
## resplandores a la deriva, luciérnagas y viñeta.
extends Control

const RB = preload("res://scripts/core/rb_theme.gd")
const STAGE_FX = preload("res://scripts/gameplay/stage_fx.gd")

@export var tint: Color = Color(0.30, 0.42, 0.90)
@export var photo_brightness: float = 0.55
@export var with_beams: bool = true
@export var with_fireflies: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var vp: Vector2 = get_viewport_rect().size

	var base := ColorRect.new()
	base.color = Color(0.01, 0.015, 0.05)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tex := load("res://assets/images/fondito.jpg") as Texture2D
	if tex != null:
		var photo := TextureRect.new()
		photo.texture = tex
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.modulate = Color(tint.r * photo_brightness, tint.g * photo_brightness, tint.b * photo_brightness, 1.0)
		add_child(photo)
		photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		photo.pivot_offset = vp * 0.5
		photo.scale = Vector2(1.04, 1.04)
		var kb := create_tween().set_loops()
		kb.tween_property(photo, "scale", Vector2(1.12, 1.12), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		kb.tween_property(photo, "scale", Vector2(1.04, 1.04), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Degradado azul profundo
	var wash := TextureRect.new()
	wash.texture = RB.v_gradient(Color(0.0, 0.02, 0.12, 0.50), Color(0.0, 0.0, 0.03, 0.88))
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Resplandores a la deriva
	_add_glow(Color(0.25, 0.40, 1.00), Vector2(-120.0, 40.0), Vector2(140.0, 20.0), 14.0)
	_add_glow(Color(0.65, 0.25, 0.95), Vector2(vp.x - 520.0, vp.y - 480.0), Vector2(-120.0, -30.0), 17.0)

	if with_beams:
		var fx := STAGE_FX.new()
		fx.origin_y = -40.0
		fx.length = vp.y + 160.0
		fx.beam_spread = 300.0
		fx.base_alpha = 0.085
		add_child(fx)

	if with_fireflies:
		_add_fireflies(vp)

	# Viñeta
	var vig := TextureRect.new()
	vig.texture = _vignette()
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _vignette() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.92))
	g.set_offset(0, 0.40)
	g.set_offset(1, 1.0)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.85)
	t.width = 512
	t.height = 512
	return t


func _add_glow(color: Color, start: Vector2, drift: Vector2, duration: float) -> void:
	var glow := TextureRect.new()
	glow.texture = RB.radial_gradient(Color(color.r, color.g, color.b, 0.40), Color(color.r, color.g, color.b, 0.0), 256)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.size = Vector2(640.0, 640.0)
	glow.position = start
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "position", start + drift, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "position", start, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_fireflies(vp: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = vp * 0.5
	p.amount = 38
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = vp * 0.5
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.texture = RB.soft_dot(24)
	p.color = Color(1.0, 0.95, 0.45, 0.9)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.5, Color(1.0, 1.0, 1.0, 1.0))
	p.color_ramp = ramp
	add_child(p)
