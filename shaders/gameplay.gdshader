shader_type canvas_item;

// Esta variable aparecerá en el inspector para que controles la velocidad
uniform float scroll_speed = 0.5; 

void fragment() {
    vec2 shifted_uv = UV;
    // Movemos las coordenadas X basándonos en el tiempo del juego
    shifted_uv.x += TIME * scroll_speed;
    
    // Aplicamos la textura movida
    COLOR = texture(TEXTURE, shifted_uv);
}