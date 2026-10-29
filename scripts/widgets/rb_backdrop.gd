## rb_backdrop.gd
## Fondo animado de los menús (escena rb_backdrop.tscn): foto oscurecida con zoom
## lento, resplandores a la deriva, haces de luz, luciérnagas y viñeta.
## Los nodos viven en la escena; aquí solo se anima y se aplican los exports.
extends Control

@export var tint: Color = Color(0.30, 0.42, 0.90)
@export var photo_brightness: float = 0.55
@export var with_beams: bool = true
@export var with_fireflies: bool = true

@onready var _photo: TextureRect = $Photo
@onready var _glow_a: TextureRect = $GlowA
@onready var _glow_b: TextureRect = $GlowB
@onready var _beams: Node2D = $StageFx
@onready var _fireflies: CPUParticles2D = $Fireflies


func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_photo.modulate = Color(tint.r * photo_brightness, tint.g * photo_brightness, tint.b * photo_brightness, 1.0)
	_photo.pivot_offset = vp * 0.5
	_photo.scale = Vector2(1.04, 1.04)
	var kb := create_tween().set_loops()
	kb.tween_property(_photo, "scale", Vector2(1.12, 1.12), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	kb.tween_property(_photo, "scale", Vector2(1.04, 1.04), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_drift(_glow_a, Vector2(140.0, 20.0), 14.0)
	_drift(_glow_b, Vector2(-120.0, -30.0), 17.0)

	_beams.visible = with_beams
	_beams.set_process(with_beams)
	_fireflies.visible = with_fireflies
	_fireflies.emitting = with_fireflies


func _drift(glow: Control, drift: Vector2, duration: float) -> void:
	var start: Vector2 = glow.position
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "position", start + drift, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "position", start, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
