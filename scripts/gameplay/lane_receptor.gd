@tool
## lane_receptor.gd
## Indicador de carril: una pastilla con relieve apoyada sobre el carril, con la misma
## perspectiva que el highway (se dibuja con chip_draw.gd; las partículas son el nodo
## "Particles" de lane_receptor.tscn). Es @tool: se ve en el editor con el color que
## tenga `lane_color`.

extends Node2D

const ChipDraw = preload("res://scripts/core/chip_draw.gd")

@export var lane_color: Color = Color.WHITE:
	set(v):
		lane_color = v
		_apply_particle_color()
		queue_redraw()
@export var lane_index: int = 0

@onready var _particles: CPUParticles2D = $Particles

# ── Dimensiones de la pastilla (px a la altura de la línea de golpe) ─────────
const HALF_W      := 33.0    # Medio ancho
const HALF_D      := 15.0    # Media profundidad
const ELEV        := 3.0     # Relieve (más bajo que las notas, que pasan por encima)

const PRESS_SCALE := Vector2(1.12, 1.2)
const BASE_SCALE  := Vector2(1.0,  1.0)

# Estado de animación de brillo (0.0 = normal, 1.0 = flash completo)
var _flash: float = 0.0


func _ready() -> void:
	_apply_particle_color()
	queue_redraw()


## Pinta las partículas con el color del carril (el degradado es local a cada instancia).
func _apply_particle_color() -> void:
	if not is_node_ready():
		return
	_particles.color = lane_color
	var grad: Gradient = _particles.color_ramp
	if grad != null:
		grad.set_color(0, Color(lane_color.r, lane_color.g, lane_color.b, 1.0))
		grad.set_color(1, Color(lane_color.r, lane_color.g, lane_color.b, 0.0))


func _draw() -> void:
	# Geometría del carril: la da el highway en el juego; en el editor se usan valores típicos
	var k: float = 547.0
	var lateral: float = (float(lane_index) - 2.0) * 88.0
	var p: Node = get_parent()
	if not Engine.is_editor_hint() and p != null and "horizon_y" in p:
		k = float(p.hit_y) - float(p.horizon_y)
		lateral = float(p.lane_offset(lane_index))
	ChipDraw.draw_chip(self, k, lateral, 1.0, lane_color, HALF_W, HALF_D, ELEV, _flash, 0.18)


# ── Animaciones ───────────────────────────────────────────────────────────────

func animate_press() -> void:
	# Efecto de flash: se vuelve blanco HDR por un instante
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 1. Escala explosiva
	tw.parallel().tween_property(self, "scale", PRESS_SCALE, 0.05)

	# 2. Flash de color blanco puro (sobrepasa el 0.85 del Glow)
	self_modulate = Color(2, 2, 2, 1)
	tw.parallel().tween_property(self, "self_modulate", Color(1, 1, 1, 1), 0.15)

	# Regreso a normal
	tw.chain().tween_property(self, "scale", BASE_SCALE, 0.1)


func animate_hit(accuracy: float) -> void:
	_particles.amount = 12 if accuracy < 0.55 else (16 if accuracy < 0.95 else 22)

	var bright := lane_color.lightened(0.3 if accuracy >= 0.95 else 0.0)
	_particles.color = bright
	if _particles.color_ramp:
		_particles.color_ramp.set_color(0, Color(bright.r, bright.g, bright.b, 1.0))
		_particles.color_ramp.set_color(1, Color(bright.r, bright.g, bright.b, 0.0))
	_particles.restart()

	# Animar el flash interno (redibuja la pastilla más brillante)
	var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_flash, 0.0, 1.0, 0.05)
	tw.tween_method(_set_flash, 1.0, 0.0, 0.30)


func _set_flash(val: float) -> void:
	_flash = val
	queue_redraw()
