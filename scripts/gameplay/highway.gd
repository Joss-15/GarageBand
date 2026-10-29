## highway.gd
## Carril en perspectiva de un jugador (nodo HighwayRoot de gameplay.tscn): el
## ColorRect "Road" con el shader highway.gdshader (banda eléctrica), la barra
## cromada "Bar" de la línea de golpe con las teclas, los 5 receptores, y las
## funciones que convierten "tiempo restante para el golpe" en posición/escala
## de pantalla para las notas. Los nodos viven en la escena; aquí solo se
## calcula la geometría y se alimentan los parámetros del shader.
extends Node2D

var center_x: float = 576.0
var hit_y: float = 566.0
var horizon_y: float = 19.0
var lane_w: float = 88.0
var lane_count: int = 5
var far_z: float = 2.5
var fall_time: float = 2.0

@onready var _road: ColorRect = $Road
@onready var _bar: Node2D = $Bar

var _mat: ShaderMaterial = null
var _energy := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _pulse: float = 0.0


func setup(vp: Vector2, p_hit_y: float, p_top_y: float, p_lane_w: float, p_far_z: float, p_fall_time: float) -> void:
	hit_y = p_hit_y
	lane_w = p_lane_w
	far_z = p_far_z
	fall_time = p_fall_time
	center_x = vp.x * 0.5
	# y(p=1) = p_top_y  =>  horizonte virtual donde convergen los bordes
	horizon_y = (p_top_y - hit_y / far_z) / (1.0 - 1.0 / far_z)

	_road.position = Vector2.ZERO
	_road.size = vp
	_mat = _road.material as ShaderMaterial
	_mat.set_shader_parameter("view_size", vp)
	_mat.set_shader_parameter("center_x", center_x)
	_mat.set_shader_parameter("hit_y", hit_y)
	_mat.set_shader_parameter("horizon_y", horizon_y)
	_mat.set_shader_parameter("lane_w", lane_w)
	_mat.set_shader_parameter("lane_count", float(lane_count))
	_mat.set_shader_parameter("far_z", far_z)
	_mat.set_shader_parameter("fall_time", fall_time)
	_mat.set_shader_parameter("beat_period", 0.5)
	_mat.set_shader_parameter("song_time", 0.0)
	_mat.set_shader_parameter("pulse", 0.0)
	_mat.set_shader_parameter("lane_energy", _energy)

	_bar.center_x = center_x
	_bar.hit_y = hit_y
	_bar.lane_w = lane_w
	_bar.lane_count = lane_count


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
