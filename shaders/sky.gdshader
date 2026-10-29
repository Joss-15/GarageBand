shader_type canvas_item;

uniform float scroll_speed = 0.05; 

void fragment() {
    vec2 shifted_uv = UV;
    shifted_uv.x += TIME * scroll_speed;
    COLOR = texture(TEXTURE, shifted_uv);
}