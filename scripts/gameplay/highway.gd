## highway.gd
## Carril en perspectiva de un jugador: un ColorRect con el shader highway.gdshader
## (banda eléctrica), la barra cromada de la línea de golpe con las teclas, y las
## funciones que convierten "tiempo restante para el golpe" en posición/escala
## de pantalla para las notas.
extends Node2D

const RB = preload("res://scripts/core/rb_theme.gd")
const ROAD_SHADER = preload("res://shaders/highway.gdshader")

var center_x: float = 576.0
var hit_y: float = 566.0
var horizon_y: float = 19.0
var lane_w: float = 88.0
var lane_count: int = 5
var far_z: float = 2.5
var fall_time: float = 2.0

var _road: ColorRect = null
var _mat: ShaderMaterial = null
var _bar: Node2D = null
var _energy := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _pulse: float = 0.0


## Barra cromada con las teclas de cada carril (se dibuja sobre el carril).
class Bar extends Node2D:
	const RB = preload("res://scripts/core/rb_theme.gd")
	var hw: Node2D = null

	func _draw() -> void:
		if hw == null:
			return
		var total_w: float = hw.lane_w * float(hw.lane_count)
		var x0: float = hw.center_x - total_w * 0.5 - 12.0
		var x1: float = hw.center_x + total_w * 0.5 + 12.0
		var y: float = hw.hit_y
		draw_rect(Rect2(x0, y - 22.0, x1 - x0, 44.0), Color(0.07, 0.075, 0.09))
		draw_rect(Rect2(x0, y - 22.0, x1 - x0, 4.0), Color(0.80, 0.83, 0.90))
		draw_rect(Rect2(x0, y + 18.0, x1 - x0, 4.0), Color(0.55, 0.58, 0.66))
		draw_rect(Rect2(x0, y - 18.0, x1 - x0, 3.0), Color(1.0, 1.0, 1.0, 0.07))
		draw_rect(Rect2(x0 - 6.0, y - 24.0, 8.0, 48.0), Color(1.0, 0.55, 0.12))
		draw_rect(Rect2(x1 - 2.0, y - 24.0, 8.0, 48.0), Color(1.0, 0.55, 0.12))
		var f: Font = RB.font(true)
		for i in hw.lane_count:
			var key_name: String = "?"
			var evs: Array[InputEvent] = InputMap.action_get_events("lane_%d" % i)
			if evs.size() > 0 and evs[0] is InputEventKey:
				var k := evs[0] as InputEventKey
				var code: int = int(k.physical_keycode) if int(k.physical_keycode) != 0 else int(k.keycode)
				key_name = OS.get_keycode_string(code as Key)
			var cx: float = hw.center_x + (float(i) - (float(hw.lane_count) - 1.0) * 0.5) * hw.lane_w
			var col: Color = RB.LANE_COLORS[i]
			draw_string_outline(f, Vector2(cx - 30.0, y + 54.0), key_name, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 24, 6, Color(0.0, 0.0, 0.0, 0.9))
			draw_string(f, Vector2(cx - 30.0, y + 54.0), key_name, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 24, col)


func setup(vp: Vector2, p_hit_y: float, p_top_y: float, p_lane_w: float, p_far_z: float, p_fall_time: float) -> void:
	hit_y = p_hit_y
	lane_w = p_lane_w
	far_z = p_far_z
	fall_time = p_fall_time
	center_x = vp.x * 0.5
	# y(p=1) = p_top_y  =>  horizonte virtual donde convergen los bordes
	horizon_y = (p_top_y - hit_y / far_z) / (1.0 - 1.0 / far_z)

	_road = ColorRect.new()
	_road.position = Vector2.ZERO
	_road.size = vp
	_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = ROAD_SHADER
	_mat.set_shader_parameter("view_size", vp)
	_mat.set_shader_parameter("center_x", center_x)
	_mat.set_shader_parameter("hit_y", hit_y)
	_mat.set_shader_parameter("horizon_y", horizon_y)
	_mat.set_shader_parameter("lane_w", lane_w)
	_mat.set_shader_parameter("lane_count", float(lane_count))
	_mat.set_shader_parameter("far_z", far_z)
	_mat.set_shader_parameter("fall_time", fall_time)
	_mat.set_shader_parameter("beat_period", 0.5)
	_mat.set_shader_parameter("lane_energy", _energy)
	_road.material = _mat
	add_child(_road)

	_bar = Bar.new()
	_bar.hw = self
	add_child(_bar)


# ── Proyección ───────────────────────────────────────────────────────────────

func lane_center_x(lane: int) -> float:
	return center_x + (float(lane) - (float(lane_count) - 1.0) * 0.5) * lane_w


## Posición en pantalla de una nota del carril `lane` a `dt` segundos de su golpe.
func project_pos(lane: int, dt: float) -> Vector2:
	var z: float = 1.0 + (far_z - 1.0) * (dt / fall_time)
	var s: float = 1.0 / z
	var y: float = horizon_y + (hit_y - horizon_y) * s
	var x: float = center_x + (float(lane) - (float(lane_count) - 1.0) * 0.5) * lane_w * s
	return Vector2(x, y)


func project_scale(dt: float) -> float:
	var z: float = 1.0 + (far_z - 1.0) * (dt / fall_time)
	return 1.0 / z


# ── Reloj y efectos ──────────────────────────────────────────────────────────

func set_clock(song_time: float, beat_period: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("song_time", song_time)
	_mat.set_shader_parameter("beat_period", maxf(beat_period, 0.1))


## Ilumina el carril al presionar su tecla.
func press_lane(lane: int, strength: float = 1.0) -> void:
	if lane >= 0 and lane < lane_count:
		_energy[lane] = maxf(_energy[lane], strength)


## Destello general del carril (aciertos).
func pulse(strength: float = 1.0) -> void:
	_pulse = maxf(_pulse, strength)


func _process(delta: float) -> void:
	if _mat == null:
		return
	for i in lane_count:
		_energy[i] = maxf(0.0, _energy[i] - delta * 2.6)
	_pulse = maxf(0.0, _pulse - delta * 2.0)
	_mat.set_shader_parameter("lane_energy", _energy)
	_mat.set_shader_parameter("pulse", _pulse)
