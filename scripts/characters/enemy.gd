extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var _fighter_ref: Node2D = null
var _move_tween: Tween = null 
var _bobbing_tween: Tween = null # Guardamos el tween de rebote

func setup(is_flying: bool, fall_time: float, target_pos: Vector2, fighter_node: Node2D) -> void:
	_fighter_ref = fighter_node
	
	if is_flying:
		anim.play("fly")
	else:
		anim.play("walk")

	# 1. Animación de rebote (Bobbing) aplicada al Sprite
	_bobbing_tween = create_tween().set_loops()
	# Sube 30 píxeles respecto a su centro y luego regresa a 0
	_bobbing_tween.tween_property(anim, "position:y", -30.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bobbing_tween.tween_property(anim, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Movimiento lineal de avance aplicado al nodo raíz
	_move_tween = create_tween()
	_move_tween.tween_property(self, "global_position", target_pos, fall_time)
	_move_tween.tween_callback(self._on_target_reached)

func _on_target_reached() -> void:
	# Detenemos el rebote antes de encogerlo
	if _bobbing_tween and _bobbing_tween.is_valid():
		_bobbing_tween.kill()
		
	# Animación por defecto (MISS): Encogimiento rápido hasta desaparecer
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(self.queue_free)

func defeat() -> void:
	# 1. Detener el avance lineal
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	# 2. Detener el rebote para que el impacto se congele en el aire
	if _bobbing_tween and _bobbing_tween.is_valid():
		_bobbing_tween.kill()
		
	# 3. Detener la animación del spritesheet
	anim.stop()
		
	# 4. Animación de impacto (Destello blanco + Expansión + Desvanecimiento)
	var tw = create_tween()
	
	anim.modulate = Color(2.0, 2.0, 2.0, 1.0)
	
	tw.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(anim, "modulate:a", 0.0, 0.15)
	
	tw.chain().tween_callback(self.queue_free)
