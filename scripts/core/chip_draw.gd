@tool
## chip_draw.gd
## Dibuja "pastillas" (chips) con relieve apoyadas sobre el plano del carril, con la
## MISMA perspectiva que highway.gd: el carril es un plano visto desde arriba, así que
## cada pastilla se proyecta punto por punto (los lados convergen hacia el horizonte y
## el largo se acorta con la distancia) en vez de escalarse como un dibujo plano.
##
## Se usa para las notas, los receptores y la barra de golpe.
##
## Coordenadas de la forma (en píxeles a la altura de la línea de golpe):
##   x = a lo ancho del carril, y = profundidad (positivo = más lejos del jugador).
## Proyección (igual que highway.project_pos):
##   z   = distancia relativa (1 = línea de golpe, far_z = fondo)
##   pantalla.x = centro + lateral / z
##   pantalla.y = horizonte + k / z      con k = hit_y - horizon_y
extends RefCounted

const SEGS := 4


## Rectángulo redondeado (puntos en el plano). `cb` desplaza el centro en profundidad.
static func rrect(hw: float, hd: float, r: float, cb: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr: float = maxf(minf(r, minf(hw, hd)), 0.01)
	var centers: Array = [
		Vector2(hw - rr, hd - rr + cb),
		Vector2(-hw + rr, hd - rr + cb),
		Vector2(-hw + rr, -hd + rr + cb),
		Vector2(hw - rr, -hd + rr + cb),
	]
	for c in 4:
		for i in SEGS + 1:
			var ang: float = deg_to_rad(90.0 * float(c) + 90.0 * float(i) / float(SEGS))
			pts.append((centers[c] as Vector2) + Vector2(cos(ang), sin(ang)) * rr)
	return pts


## Lleva la forma del plano a la pantalla, relativa al punto proyectado del centro
## (lateral L, distancia zc). `elev` la levanta del piso (píxeles a la altura de la línea).
static func to_screen(shape: PackedVector2Array, k: float, lateral: float, zc: float, elev: float, shift: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	var x0: float = lateral / zc
	var y0: float = k / zc
	for p in shape:
		var zz: float = maxf(zc + (p.y + shift.y) / k, 0.05)
		var s: float = 1.0 / zz
		out.append(Vector2((lateral + p.x + shift.x) * s - x0, k * s - y0 - elev * s))
	return out


## Color por vértice: `far_c` en el borde lejano y `near_c` en el cercano.
static func gradient(shape: PackedVector2Array, hd: float, far_c: Color, near_c: Color, cb: float = 0.0) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in shape:
		var t: float = clampf((hd + cb - p.y) / (2.0 * hd), 0.0, 1.0)
		cols.append(far_c.lerp(near_c, t))
	return cols


## Pastilla biselada. El nodo `ci` debe estar en el punto proyectado del centro de la pastilla.
##   k      = hit_y - horizon_y
##   lateral = distancia del centro al eje del carril (píxeles a la altura de la línea)
##   zc     = distancia relativa del centro
##   hw, hd = medio ancho y media profundidad
##   elev   = altura del relieve
##   glow   = 0..1 aclara el color (destello al acertar)
##   gloss  = opacidad del brillo superior
static func draw_chip(ci: CanvasItem, k: float, lateral: float, zc: float, base: Color, hw: float, hd: float, elev: float, glow: float = 0.0, gloss: float = 0.22, far_light: float = 0.30, near_dark: float = 0.22) -> void:
	var c: Color = base.lerp(Color.WHITE, glow * 0.55)
	var outer: PackedVector2Array = rrect(hw, hd, minf(hd * 0.5, 9.0))

	# Sombra proyectada en el piso
	ci.draw_colored_polygon(to_screen(outer, k, lateral, zc, 0.0, Vector2(3.0, -5.0)), Color(0.0, 0.0, 0.0, 0.45))

	# Paredes: capas apiladas del piso hasta la tapa, un poco más claras hacia arriba
	var wall: Color = c.darkened(0.55)
	var layers: int = 3
	for i in layers:
		var h: float = elev * float(i) / float(layers)
		ci.draw_colored_polygon(to_screen(outer, k, lateral, zc, h), wall.lightened(0.05 * float(i)))

	# Tapa: bisel (borde inclinado) con luz arriba y sombra abajo
	var top: PackedVector2Array = to_screen(outer, k, lateral, zc, elev)
	ci.draw_polygon(top, gradient(outer, hd, c.lightened(far_light), c.darkened(near_dark)))
	var rim: PackedVector2Array = top.duplicate()
	rim.append(top[0])
	ci.draw_polyline(rim, c.darkened(0.45), 1.0, true)

	# Meseta interior (parte plana de la tapa)
	var ih: float = maxf(hd - 6.5, 1.0)
	var iw: float = maxf(hw - 6.0, 1.0)
	var inner: PackedVector2Array = rrect(iw, ih, minf(ih * 0.5, 6.0))
	ci.draw_polygon(to_screen(inner, k, lateral, zc, elev), gradient(inner, ih, c.lightened(0.14), c.darkened(0.08)))

	# Brillo suave hacia el borde lejano
	if gloss > 0.0:
		var gh: float = maxf(ih * 0.30, 1.0)
		var strip: PackedVector2Array = rrect(maxf(iw - 8.0, 1.0), gh, gh * 0.8, ih * 0.42)
		ci.draw_colored_polygon(to_screen(strip, k, lateral, zc, elev), Color(c.lightened(0.7), gloss))
