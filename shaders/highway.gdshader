// highway.gdshader
// Carril de notas en perspectiva con "banda eléctrica": corrientes de energía y
// chispas que avanzan hacia el jugador, divisiones parpadeantes, rieles cromados,
// líneas de compás sincronizadas con la canción y brillo por carril al presionar.
// Se dibuja sobre un ColorRect del tamaño de la pantalla.
shader_type canvas_item;

uniform vec2 view_size = vec2(1152.0, 648.0);
uniform float center_x = 576.0;
uniform float hit_y = 566.0;
uniform float horizon_y = 19.0;
uniform float lane_w = 88.0;
uniform float lane_count = 5.0;
uniform float far_z = 2.5;
uniform float song_time = 0.0;
uniform float beat_period = 0.5;
uniform float fall_time = 2.0;
uniform float pulse = 0.0;
uniform float lane_energy[5];

const vec3 LANE_COL[5] = vec3[5](
	vec3(0.14, 0.86, 0.28),
	vec3(0.95, 0.16, 0.16),
	vec3(0.98, 0.86, 0.10),
	vec3(0.18, 0.44, 0.98),
	vec3(1.00, 0.56, 0.10)
);

void fragment() {
	vec2 px = UV * view_size;

	// Proyección: s = 1 en la línea de golpe, s = 1/far_z en el fondo.
	float s = (px.y - horizon_y) / (hit_y - horizon_y);
	float sc = clamp(s, 0.05, 2.0);
	float z = 1.0 / sc;
	float p = (z - 1.0) / (far_z - 1.0);                              // 0 = línea de golpe, 1 = fondo
	float f = (px.x - center_x) / (lane_w * sc) + lane_count * 0.5;   // coordenada de carril
	float aa = max(fwidth(f), 0.0005);

	// Máscaras
	float vmask = step(1.0 / far_z - 0.005, s) * (1.0 - step(1.16, s));
	float edge_out = 0.14;
	float hmask = smoothstep(-edge_out - aa, -edge_out, f)
		* (1.0 - smoothstep(lane_count + edge_out, lane_count + edge_out + aa, f));
	float inside = step(0.0, f) * (1.0 - step(lane_count, f));
	float depth_fade = 1.0 - smoothstep(0.78, 1.0, p);

	// Base oscura con ligero brillo de lámina
	vec3 base = mix(vec3(0.012, 0.014, 0.022), vec3(0.075, 0.080, 0.110), clamp(sc, 0.0, 1.0));
	base += vec3(0.010, 0.012, 0.020) * (0.5 + 0.5 * sin(f * 1.5 + 1.0));

	// Banda eléctrica: avanza hacia el jugador (z decrece al pasar el tiempo)
	float w = z * 7.0 + TIME * 3.2;
	float lane_id = floor(f);
	float center_d = abs(fract(f) - 0.5);
	float band = exp(-pow(center_d * 4.2, 2.0));
	float flow = 0.5 + 0.5 * sin(w + lane_id * 1.9);
	float flow2 = 0.5 + 0.5 * sin(w * 0.37 - lane_id * 2.3 + TIME);
	float energy = band * pow(flow, 7.0) * (0.35 + 0.65 * flow2);
	vec3 elec = vec3(0.35, 0.62, 1.0) * energy * 0.55;
	float spark = pow(0.5 + 0.5 * sin(w * 2.6 + f * 17.0 + sin(TIME * 5.0 + f * 3.0) * 2.0), 40.0);
	elec += vec3(0.7, 0.85, 1.0) * spark * 0.35 * band;

	// Divisiones interiores parpadeantes
	float dd = min(fract(f), 1.0 - fract(f));
	float div_mask = (1.0 - smoothstep(0.012, 0.012 + aa * 1.3, dd)) * step(0.5, f) * (1.0 - step(lane_count - 0.5, f));
	float flick = 0.55 + 0.45 * sin(w * 1.7 + lane_id * 3.0 + TIME * 6.0);
	vec3 div_col = mix(vec3(0.38, 0.40, 0.46), vec3(0.65, 0.82, 1.0), flick) * 0.9;

	// Líneas de compás (fina por pulso, gruesa por compás de 4)
	float ph = (song_time + p * fall_time) / beat_period;
	float d1 = abs(ph - floor(ph + 0.5));
	float aa1 = max(fwidth(ph), 0.0005);
	float beat = 1.0 - smoothstep(0.0, aa1 * 1.6, d1);
	float ph4 = ph / 4.0;
	float d4 = abs(ph4 - floor(ph4 + 0.5));
	float aa4 = max(fwidth(ph4), 0.0005);
	float bar = 1.0 - smoothstep(0.0, aa4 * 2.6, d4);
	vec3 beat_col = vec3(0.55, 0.58, 0.66) * (0.28 * beat + 0.55 * bar);

	// Brillo del carril al presionar su tecla
	int idx = int(clamp(floor(f), 0.0, lane_count - 1.0));
	float en = lane_energy[idx];
	vec3 lc = LANE_COL[idx];
	float glow = en * (1.0 - smoothstep(0.0, 0.7, p)) * (0.35 + 0.65 * band);

	// Rieles cromados laterales
	float de = min(abs(f), abs(f - lane_count));
	float rail = 1.0 - smoothstep(0.075, 0.075 + aa * 1.4, de);
	float rail_hi = 0.5 + 0.5 * sin(w * 0.9);
	vec3 rail_col = mix(vec3(0.55, 0.58, 0.66), vec3(0.92, 0.95, 1.0), rail_hi * 0.7);

	vec3 col = base + elec;
	col = mix(col, div_col, div_mask * 0.85);
	col += beat_col * inside;
	col += lc * glow * 0.9;
	col += vec3(0.05, 0.07, 0.12) * pulse * (1.0 - p);
	col = mix(col, rail_col, rail);

	float alpha = mix(0.88, 1.0, rail) * hmask * vmask * depth_fade;
	COLOR = vec4(col, alpha);
}
