extends Node2D


# Pseudocódigo básico en Godot para tu algoritmo
var espectro

func _ready():
	# Obtener el analizador del Bus Master (Asumiendo que es el efecto 0)
	espectro = AudioServer.get_bus_effect_instance(0, 0)
