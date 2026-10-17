extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _idle_tween: Tween = null
var _base_y: float = 0.0

func _ready() -> void:
	# Guardamos la posición Y original para usarla como ancla
	_base_y = anim.position.y
	
	# Empezar a caminar por defecto
	anim.play("walk")
	# Conectamos la señal para saber cuándo termina un golpe o daño
	anim.animation_finished.connect(_on_animation_finished)
	
	_start_bobbing()

# --- NUEVAS FUNCIONES DE MOVIMIENTO (Game Feel) ---
func _start_bobbing() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		
	_idle_tween = create_tween().set_loops()
	# Sube ligeramente (4 píxeles) y baja en un ciclo infinito suave
	_idle_tween.tween_property(anim, "position:y", _base_y - 4.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(anim, "position:y", _base_y, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _jump_action() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		
	var tw = create_tween()
	# Salto rápido hacia arriba (20 píxeles) y caída rápida
	tw.tween_property(anim, "position:y", _base_y - 50.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(anim, "position:y", _base_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
# --------------------------------------------------

# Funciones que llamaremos desde el gameplay
func play_punch() -> void:
	anim.play("punch")
	_jump_action()
	_trigger_neon_flash()

func play_kick() -> void:
	anim.play("kick")
	_jump_action()
	_trigger_neon_flash()

func play_hurt() -> void:
	anim.play("hurt")
	
	# Detenemos el rebote si recibe daño
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	
	# 1. Pintar a Nat de rojo
	anim.modulate = Color(1.0, 0.2, 0.2, 1.0)
	
	# 2. Hacer que vibre (Shake) moviendo su posición rápidamente
	var tw = create_tween()
	for i in 6: # Se mueve 6 veces de forma aleatoria
		# Agregamos _base_y para que tiemble respetando su altura original
		tw.tween_property(anim, "position", Vector2(randf_range(-15, 15), _base_y + randf_range(-15, 15)), 0.05)
	
	# 3. Regresar a la posición original y al color normal
	tw.tween_property(anim, "position", Vector2(0, _base_y), 0.05)
	tw.tween_property(anim, "modulate", Color.WHITE, 0.15)
	
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		
	var tw2 = create_tween()
	# Salto rápido hacia arriba (20 píxeles) y caída rápida
	tw2.tween_property(anim, "position:y", _base_y - 100.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(anim, "position:y", _base_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_animation_finished() -> void:
	# Si terminó cualquier animación que no sea caminar, vuelve a caminar
	if anim.animation != "walk":
		anim.play("walk")
		# Rein

func _trigger_neon_flash() -> void:
	# 1. Guardamos el modulate original para restaurarlo después
	var original_modulate = anim.modulate
	
	# 2. Creamos un flash HDR rápido
	# Un valor RGB de 5.0 es tan brillante que el motor de Godot
	# lo procesa como un destello blanco neón intenso gracias al Glow
	anim.modulate = Color(0.877, 0.877, 0.877, 1.0)
	
	# 3. Tween para volver al color normal rápidamente
	var tw = create_tween()
	tw.tween_property(anim, "modulate", original_modulate, 0.2).set_trans(Tween.TRANS_CUBIC)
