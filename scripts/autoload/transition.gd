## transition.gd  (autoload: SceneFade)
## Cambio de escena con fundido a negro. Uso:  SceneFade.go("res://scenes/x.tscn")
extends CanvasLayer

var _rect: ColorRect = null
var _busy: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Entrada suave al abrir el juego
	_rect.modulate.a = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	create_tween().tween_property(_rect, "modulate:a", 0.0, 0.7)


func go(path: String, duration: float = 0.35) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_rect, "modulate:a", 1.0, duration)
	await out.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_rect, "modulate:a", 0.0, duration)
	await back.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
