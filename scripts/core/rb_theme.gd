## rb_theme.gd
## Utilidades de estilo compartidas por todas las pantallas: paleta, tipografía,
## cajas, gradientes, formato de números y textos bilingües (ES/EN).
## Uso en otros scripts:   const RB = preload("res://scripts/rb_theme.gd")
extends RefCounted

# ── Paleta ───────────────────────────────────────────────────────────────────
const GOLD := Color(0.88, 0.82, 0.10)
const GOLD_BRIGHT := Color(1.0, 0.95, 0.35)
const GOLD_DARK := Color(0.38, 0.33, 0.02)
const WHITE_SOFT := Color(0.93, 0.94, 0.96)
const GRAY_TXT := Color(0.74, 0.75, 0.79)
const INK := Color(0.05, 0.05, 0.06)
const PANEL_DARK := Color(0.035, 0.045, 0.075, 0.86)
const TEAL_BAR := Color(0.17, 0.38, 0.48, 0.92)
const CHROME := Color(0.72, 0.75, 0.82)

## Colores de los 5 carriles (verde, rojo, amarillo, azul, naranja)
const LANE_COLORS := [
	Color(0.14, 0.86, 0.28),
	Color(0.95, 0.16, 0.16),
	Color(0.98, 0.86, 0.10),
	Color(0.18, 0.44, 0.98),
	Color(1.00, 0.56, 0.10),
]

const INSTRUMENT_IDS := ["guitarra", "bajo", "batería", "microfono"]

static var _fonts: Dictionary = {}


# ── Tipografía ───────────────────────────────────────────────────────────────

## Fuente de sistema en negrita (o normal). Si el equipo no tiene ninguna de las
## familias, Godot usa la fuente por defecto.
static func font(bold: bool = true, italic: bool = false) -> Font:
	var key: String = "%s_%s" % [str(bold), str(italic)]
	if _fonts.has(key):
		return _fonts[key] as Font
	var f := SystemFont.new()
	if bold:
		f.font_names = PackedStringArray(["Gotham", "Montserrat", "Arial Black", "Segoe UI Black", "Segoe UI", "Arial"])
		f.font_weight = 800
	else:
		f.font_names = PackedStringArray(["Gotham", "Montserrat", "Segoe UI", "Arial"])
		f.font_weight = 500
	f.font_italic = italic
	_fonts[key] = f
	return f


## Fuente propia del juego (logo).
static func brand_font() -> Font:
	return load("res://assets/fonts/RhythmicHits.ttf") as Font


## Texto según el idioma elegido en opciones.
static func t(es: String, en: String) -> String:
	return en if GameState.current_language == "en" else es


static func text_width(text: String, size: int, bold: bool = true, italic: bool = false) -> float:
	return font(bold, italic).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


static func label(text: String, size: int = 24, color: Color = Color(0.93, 0.94, 0.96), bold: bool = true, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold, italic))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ── Cajas y gradientes ───────────────────────────────────────────────────────

static func box(bg: Color, radius: int = 0, border: Color = Color(0.0, 0.0, 0.0, 0.0), border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	return s


static func h_gradient(c0: Color, c1: Color, w: int = 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 0.0)
	tex.width = w
	tex.height = 4
	return tex


static func v_gradient(c0: Color, c1: Color, h: int = 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = h
	return tex


static func radial_gradient(inner: Color, outer: Color, px: int = 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = px
	tex.height = px
	return tex


## Punto suave y brillante (luciérnagas).
static func soft_dot(px: int = 24) -> GradientTexture2D:
	return radial_gradient(Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0), px)


## Disco liso de bordes nítidos (perilla de sliders).
static func disc_texture(px: int, color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.set_offset(0, 0.88)
	g.set_offset(1, 0.97)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = px
	tex.height = px
	return tex


# ── Geometría ────────────────────────────────────────────────────────────────

static func rounded_rect(rect: Rect2, r: float, steps: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr: float = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var centers: Array[Vector2] = [
		rect.position + Vector2(rr, rr),
		Vector2(rect.end.x - rr, rect.position.y + rr),
		rect.end - Vector2(rr, rr),
		Vector2(rect.position.x + rr, rect.end.y - rr),
	]
	var starts: Array[float] = [PI, PI * 1.5, 0.0, PI * 0.5]
	for i in 4:
		for s in range(steps + 1):
			var a: float = starts[i] + (PI * 0.5) * float(s) / float(steps)
			pts.append(centers[i] + Vector2(cos(a), sin(a)) * rr)
	return pts


static func ellipse_points(center: Vector2, rx: float, ry: float, steps: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func star_points(center: Vector2, r_out: float, r_in_ratio: float = 0.46) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + float(i) * PI / 5.0
		var rad: float = r_out if i % 2 == 0 else r_out * r_in_ratio
		pts.append(center + Vector2(cos(a), sin(a)) * rad)
	return pts


# ── Formato ──────────────────────────────────────────────────────────────────

static func fmt_int(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


static func fmt_time(sec: float) -> String:
	var total: int = int(maxf(sec, 0.0))
	var m: int = int(floorf(float(total) / 60.0))
	var s: int = total - m * 60
	return "%02d:%02d" % [m, s]


# ── Rendimiento ──────────────────────────────────────────────────────────────

static func stars_for(acc: float) -> int:
	if acc >= 0.90:
		return 5
	if acc >= 0.80:
		return 4
	if acc >= 0.60:
		return 3
	if acc >= 0.40:
		return 2
	if acc >= 0.20:
		return 1
	return 0


static func rank_text(acc: float) -> String:
	if acc >= 0.995:
		return t("IMPECABLE", "FLAWLESS")
	if acc >= 0.90:
		return t("¡INCREÍBLE!", "AWESOME!")
	if acc >= 0.75:
		return t("¡GENIAL!", "GREAT!")
	if acc >= 0.55:
		return t("BIEN HECHO", "NICE ONE")
	if acc >= 0.35:
		return t("PUEDE MEJORAR", "COULD BE BETTER")
	return t("SIGUE PRACTICANDO", "KEEP PRACTICING")


static func rank_color(acc: float) -> Color:
	if acc >= 0.995:
		return Color(0.10, 0.55, 0.16)
	if acc >= 0.90:
		return Color(0.12, 0.50, 0.55)
	if acc >= 0.75:
		return Color(0.16, 0.36, 0.78)
	if acc >= 0.55:
		return Color(0.62, 0.52, 0.08)
	if acc >= 0.35:
		return Color(0.72, 0.38, 0.08)
	return Color(0.70, 0.14, 0.14)


## Rango del jugador según sus estrellas totales.
static func fan_rank(stars: int) -> Dictionary:
	var tiers: Array = [
		[0, t("NOVATO", "ROOKIE")],
		[5, t("TELONERO", "OPENING ACT")],
		[15, t("BANDA DE GARAJE", "GARAGE BAND")],
		[30, t("ESTRELLA LOCAL", "LOCAL STAR")],
		[60, t("LEYENDA", "LEGEND")],
	]
	var idx: int = 0
	for i in tiers.size():
		if stars >= int((tiers[i] as Array)[0]):
			idx = i
	var cur: int = int((tiers[idx] as Array)[0])
	var nxt: int = cur
	if idx + 1 < tiers.size():
		nxt = int((tiers[idx + 1] as Array)[0])
	return {"name": str((tiers[idx] as Array)[1]), "cur": cur, "next": nxt}


# ── Instrumentos ─────────────────────────────────────────────────────────────

static func instrument_name(id: String) -> String:
	match id:
		"guitarra":
			return t("GUITARRA", "GUITAR")
		"bajo":
			return t("BAJO", "BASS")
		"batería":
			return t("BATERÍA", "DRUMS")
		"microfono":
			return t("MICRÓFONO", "VOCALS")
	return id.to_upper()


static func instrument_color(id: String) -> Color:
	match id:
		"guitarra":
			return Color(0.95, 0.85, 0.10)
		"bajo":
			return Color(0.20, 0.70, 1.00)
		"batería":
			return Color(1.00, 0.30, 0.30)
		"microfono":
			return Color(0.65, 0.35, 1.00)
	return Color(0.9, 0.9, 0.9)


# ── Componentes pequeños ─────────────────────────────────────────────────────

## Ayuda de teclas de la barra inferior: [chip de color] [TECLA] texto.
## Devuelve el ancho ocupado para poder encadenar varias.
static func add_hint(parent: Control, pos: Vector2, chip: Color, key: String, text: String, size: int = 18) -> float:
	var x: float = pos.x
	var chip_rect := ColorRect.new()
	chip_rect.color = chip
	chip_rect.position = Vector2(x, pos.y + 2.0)
	chip_rect.size = Vector2(12.0, float(size) + 6.0)
	chip_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(chip_rect)
	x += 20.0
	if key != "":
		var kw: float = text_width(key, size - 4) + 16.0
		var pill := Panel.new()
		pill.add_theme_stylebox_override("panel", box(Color(0.03, 0.03, 0.04), 6, Color(0.5, 0.5, 0.56), 1))
		pill.position = Vector2(x, pos.y)
		pill.size = Vector2(kw, float(size) + 10.0)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kl := label(key, size - 4, WHITE_SOFT)
		kl.position = Vector2(8.0, 3.0)
		pill.add_child(kl)
		parent.add_child(pill)
		x += kw + 10.0
	var tl := label(text, size, WHITE_SOFT)
	tl.position = Vector2(x, pos.y + 4.0)
	parent.add_child(tl)
	x += text_width(text, size)
	return x - pos.x


## Entrada suave: el nodo llega deslizándose desde `from_offset` mientras aparece.
## Debe llamarse con el nodo ya dentro del árbol.
static func slide_in(node: Control, from_offset: Vector2, delay: float = 0.0, duration: float = 0.5) -> void:
	var target: Vector2 = node.position
	node.position = target + from_offset
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position", target, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, duration * 0.8).set_delay(delay)


## Pequeño rebote de escala para dar énfasis.
static func pop(node: Control, strength: float = 1.12, duration: float = 0.2) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(strength, strength), duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
