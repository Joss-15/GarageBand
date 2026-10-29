@tool
## hint_item.gd
## Ayuda de teclas de las barras inferiores: [chip de color] [TECLA] texto.
## Escena hint_item.tscn. Es @tool: los cambios de sus propiedades se ven en el editor.
extends HBoxContainer

@export var chip_color: Color = Color(0.15, 0.8, 0.25):
	set(v):
		chip_color = v
		_refresh()

## Tecla que se muestra en la pastilla (vacío = sin pastilla).
@export var key: String = "ENTER":
	set(v):
		key = v
		_refresh()

@export var text: String = "ACCIÓN":
	set(v):
		text = v
		_refresh()

@export var font_size: int = 18:
	set(v):
		font_size = v
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	$Chip.color = chip_color
	$Chip.custom_minimum_size = Vector2(12.0, float(font_size) + 6.0)
	$KeyPill.visible = key != ""
	$KeyPill/KeyLabel.text = key
	$KeyPill/KeyLabel.add_theme_font_size_override("font_size", font_size - 4)
	$Text.text = text
	$Text.add_theme_font_size_override("font_size", font_size)
