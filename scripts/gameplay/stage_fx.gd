## stage_fx.gd
## Haces de luz de escenario que oscilan lentamente (mezcla aditiva).
## pulse() los intensifica un instante, útil al acertar notas.
extends Node2D

@export var beam_count: int = 4
@export var origin_y: float = 0.0
@export var length: float = 600.0
@export var beam_spread: float = 240.0
@export var base_alpha: float = 0.10
@export var beam_colors: Array[Color] = [
	Color(0.45, 0.60, 1.00), Color(0.70, 0.45, 1.00),
	Color(0.30, 0.80, 1.00), Color(1.00, 0.50, 0.80),
]

var _beams: Array[Polygon2D] = []
var _t: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in beam_count:
		var col: Color = beam_colors[i % beam_colors.size()]
		var top := Color(col.r, col.g, col.b, base_alpha * 1.6)
		var bottom := Color(col.r, col.g, col.b, 0.0)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-8.0, 0.0), Vector2(8.0, 0.0),
			Vector2(beam_spread * 0.5, length), Vector2(-beam_spread * 0.5, length),
		])
		poly.vertex_colors = PackedColorArray([top, top, bottom, bottom])
		poly.position = Vector2(vp.x * (float(i) + 0.5) / float(beam_count), origin_y)
		poly.material = mat
		add_child(poly)
		_beams.append(poly)


func _process(delta: float) -> void:
	_t += delta
	for i in _beams.size():
		_beams[i].rotation = sin(_t * (0.35 + 0.07 * float(i)) + float(i) * 1.9) * 0.26


## Destello breve de intensidad.
func pulse(amount: float = 0.6) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var k: float = 1.0 + amount * 2.0
	modulate = Color(k, k, k, 1.0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
