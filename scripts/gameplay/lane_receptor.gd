@tool
## lane_receptor.gd
## Indicador de carril con forma de pastilla biselada, dibujada en código (escena
## lane_receptor.tscn; las partículas son el nodo "Particles"). Es @tool: se ve en
## el editor con el color que tenga `lane_color`.
## Capas del bisel (de abajo hacia arriba):
##   1. Sombra exterior (offset abajo-derecha, muy oscura)
##   2. Cuerpo base (color del carril)
##   3. Cara biselada inferior/lateral (sombra interna — color oscurecido)
##   4. Cara biselada superior (luz interna — color aclarado)
##   5. Reflejo especular (franja blanca semitransparente en la parte alta)

extends Node2D

@export var lane_color: Color = Color.WHITE:
	set(v):
		lane_color = v
		_apply_particle_color()
		queue_redraw()
@export var lane_index: int = 0

@onready var _particles: CPUParticles2D = $Particles

# ── Dimensiones de la pastilla ────────────────────────────────────────────────
const W           := 72.0    # Ancho total
const H           := 24.0    # Alto total
const CORNER      := 7.0     # Radio de esquinas (para simular con layering)
const BEVEL       := 4.0     # Grosor del bisel en píxeles

const PRESS_SCALE := Vector2(1.22, 1.45)
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
	var hw := W * 0.5
	var hh := H * 0.5
	# Rect centrado en el origen del nodo
	var r    := Rect2(-hw,        -hh,        W,        H)
	# ── 1. Sombra exterior ────────────────────────────────────────────────────
	var shadow_col := Color(0, 0, 0, 0.55)
	_draw_pill(Rect2(r.position + Vector2(2, 3), r.size), shadow_col, CORNER)

	# ── 2. Cuerpo base ────────────────────────────────────────────────────────
	# Mezclado con _flash para el efecto de brillo al atinar
	var base_col := lane_color.lerp(Color(1, 1, 1), _flash * 0.6)
	_draw_pill(r, base_col, CORNER)

	# ── 3. Cara biselada inferior + laterales (sombra interna) ────────────────
	var dark := lane_color.darkened(0.45)
	# Franja inferior
	_draw_pill(Rect2(-hw, hh - BEVEL, W, BEVEL), dark, minf(CORNER, BEVEL * 0.5))
	# Franja lateral izquierda
	draw_rect(Rect2(-hw, -hh + CORNER, BEVEL, H - CORNER * 2), dark)
	# Franja lateral derecha
	draw_rect(Rect2(hw - BEVEL, -hh + CORNER, BEVEL, H - CORNER * 2), dark)

	# ── 4. Cara biselada superior (luz interna) ───────────────────────────────
	var light := lane_color.lightened(0.30)
	_draw_pill(Rect2(-hw, -hh, W, BEVEL), light, minf(CORNER, BEVEL * 0.5))

	# ── 5. Reflejo especular (franja brillante en tercio superior) ─────────────
	var specular := Color(1, 1, 1, 0.28 + _flash * 0.35)
	var spec_h   := H * 0.38
	_draw_pill(Rect2(-hw + BEVEL, -hh + BEVEL * 0.5, W - BEVEL * 2, spec_h), specular, CORNER * 0.6)

	# ── 6. Borde exterior fino ────────────────────────────────────────────────
	var rim := lane_color.darkened(0.25)
	rim.a    = 0.6
	_draw_pill_outline(r, rim, CORNER)


## Dibuja un rectángulo con esquinas redondeadas simuladas con 3 rects + 4 círculos
func _draw_pill(rect: Rect2, color: Color, radius: float) -> void:
	var cr := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if cr <= 0.0 or rect.size.x <= 0 or rect.size.y <= 0:
		draw_rect(rect, color)
		return
	# Centro horizontal
	draw_rect(Rect2(rect.position.x + cr, rect.position.y, rect.size.x - cr * 2, rect.size.y), color)
	# Franjas laterales (sin esquinas)
	draw_rect(Rect2(rect.position.x, rect.position.y + cr, cr, rect.size.y - cr * 2), color)
	draw_rect(Rect2(rect.position.x + rect.size.x - cr, rect.position.y + cr, cr, rect.size.y - cr * 2), color)
	# 4 esquinas circulares
	var tl := rect.position + Vector2(cr, cr)
	var top_right := rect.position + Vector2(rect.size.x - cr, cr)
	var bl := rect.position + Vector2(cr, rect.size.y - cr)
	var br  := rect.position + Vector2(rect.size.x - cr, rect.size.y - cr)
	draw_circle(tl, cr, color)
	draw_circle(top_right, cr, color)
	draw_circle(bl, cr, color)
	draw_circle(br, cr, color)


## Dibuja solo el contorno (borde) de la píldora con líneas arco
func _draw_pill_outline(rect: Rect2, color: Color, radius: float) -> void:
	var cr := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var tl := rect.position + Vector2(cr, cr)
	var top_right := rect.position + Vector2(rect.size.x - cr, cr)
	var bl := rect.position + Vector2(cr, rect.size.y - cr)
	var br  := rect.position + Vector2(rect.size.x - cr, rect.size.y - cr)
	# Arcos en las 4 esquinas
	draw_arc(tl, cr, deg_to_rad(180), deg_to_rad(270), 8, color, 1.0)
	draw_arc(top_right, cr, deg_to_rad(270), deg_to_rad(360), 8, color, 1.0)
	draw_arc(bl, cr, deg_to_rad(90),  deg_to_rad(180), 8, color, 1.0)
	draw_arc(br, cr, deg_to_rad(0),   deg_to_rad(90),  8, color, 1.0)
	# Líneas rectas entre arcos
	draw_line(rect.position + Vector2(cr, 0),             rect.position + Vector2(rect.size.x - cr, 0),             color, 1.0)
	draw_line(rect.position + Vector2(cr, rect.size.y),   rect.position + Vector2(rect.size.x - cr, rect.size.y),   color, 1.0)
	draw_line(rect.position + Vector2(0, cr),             rect.position + Vector2(0, rect.size.y - cr),             color, 1.0)
	draw_line(rect.position + Vector2(rect.size.x, cr),   rect.position + Vector2(rect.size.x, rect.size.y - cr),   color, 1.0)


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

	# Animar el flash interno (redibuja el bisel más brillante)
	var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_flash, 0.0, 1.0, 0.05)
	tw.tween_method(_set_flash, 1.0, 0.0, 0.30)


func _set_flash(val: float) -> void:
	_flash = val
	queue_redraw()
