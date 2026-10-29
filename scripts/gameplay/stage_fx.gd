## stage_fx.gd
## Haces de luz de escenario (los Beam0..4 de la escena) que oscilan lentamente
## con mezcla aditiva. Los exports reconfiguran cuántos haces se ven, su origen,
## largo, apertura e intensidad al empezar; pulse() los intensifica un instante.
extends Node2D

@export var beam_count: int = 4
@export var origin_y: float = -40.0
@export var length: float = 808.0
@export var beam_spread: float = 300.0
@export var base_alpha: float = 0.085

var _beams: Array[Polygon2D] = []
var _t: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size
	for child in get_children():
		if child is Polygon2D:
			_beams.append(child as Polygon2D)
	var count: int = mini(beam_count, _beams.size())
	for i in _beams.size():
		var poly: Polygon2D = _beams[i]
		if i >= count:
			poly.visible = false
			continue
		poly.visible = true
		var base: Color = poly.vertex_colors[0]
		var top := Color(base.r, base.g, base.b, base_alpha * 1.6)
		var bottom := Color(base.r, base.g, base.b, 0.0)
		poly.polygon = PackedVector2Array([
			Vector2(-8.0, 0.0), Vector2(8.0, 0.0),
			Vector2(beam_spread * 0.5, length), Vector2(-beam_spread * 0.5, length),
		])
		poly.vertex_colors = PackedColorArray([top, top, bottom, bottom])
		poly.position = Vector2(vp.x * (float(i) + 0.5) / float(count), origin_y)


func _process(delta: float) -> void:
	_t += delta
	for i in _beams.size():
		if _beams[i].visible:
			_beams[i].rotation = sin(_t * (0.35 + 0.07 * float(i)) + float(i) * 1.9) * 0.26


## Destello breve de intensidad.
func pulse(amount: float = 0.6) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var k: float = 1.0 + amount * 2.0
	modulate = Color(k, k, k, 1.0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
