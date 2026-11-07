shader_type canvas_item;

// Shader 2D para dar vida ao Mapa do Ato 1 (As Terras de Velen):
// 1. Ondulação suave da água no mar, porto, rio e cachoeira + brilho de espuma.
// 2. Balanço sutil de vento nas copas das árvores da floresta.
// 3. Pulsação mágica nos cristais roxos (Minas), Cripta do Carrasco e vórtice vermelho (Fenda Abissal).

uniform float anim_time = 0.0;

void fragment() {
	vec2 uv = UV;
	vec4 base_sample = texture(TEXTURE, uv);
	vec3 col = base_sample.rgb;

	// 1. Detecção de Água (mar no canto inferior esquerdo + rio e cachoeira)
	float is_water_color = clamp((col.b - col.r * 1.08) * 4.5 + (col.g - col.r * 1.05) * 3.5, 0.0, 1.0);
	float water_region = 0.0;
	if (uv.x < 0.46 && uv.y > 0.38) {
		water_region = 1.0;
	}
	float water_mask = is_water_color * water_region;

	// 2. Detecção de Árvores/Folhagem para vento sutil
	float is_foliage = clamp((col.g - max(col.r, col.b) * 0.92) * 5.0, 0.0, 1.0);
	float foliage_region = (uv.y > 0.25 && uv.y < 0.85 && uv.x > 0.15 && uv.x < 0.82) ? 1.0 : 0.0;
	float wind_mask = is_foliage * foliage_region * (1.0 - water_mask);

	// Deslocamento UV de água (ondas suaves) + vento nas árvores
	vec2 uv_offset = vec2(0.0);
	if (water_mask > 0.01) {
		float wave_x = sin(uv.y * 55.0 + anim_time * 2.8) * 0.0018 + cos(uv.x * 40.0 - anim_time * 2.1) * 0.0012;
		float wave_y = cos(uv.x * 48.0 + anim_time * 2.4) * 0.0014;
		uv_offset += vec2(wave_x, wave_y) * water_mask;
	}
	if (wind_mask > 0.01) {
		float breeze = sin(uv.x * 24.0 + uv.y * 18.0 + anim_time * 1.9) * 0.0011;
		uv_offset.x += breeze * wind_mask;
	}

	vec4 final_tex = texture(TEXTURE, clamp(uv + uv_offset, vec2(0.001), vec2(0.999)));
	vec3 final_rgb = final_tex.rgb;

	// Brilho cintilante suave nas ondas da água e cachoeira
	if (water_mask > 0.05) {
		float shimmer = pow(max(0.0, sin(uv.x * 90.0 + uv.y * 70.0 - anim_time * 3.4)), 6.0);
		final_rgb += vec3(0.10, 0.18, 0.22) * shimmer * water_mask * 0.55;
	}

	// 3. Pulsação de Luzes Mágicas (Fenda Abissal vermelha, Cristais das Minas e Cripta roxa)
	float red_glow = clamp((final_rgb.r - max(final_rgb.g, final_rgb.b) * 1.35) * 3.2, 0.0, 1.0);
	float purple_glow = clamp((final_rgb.b + final_rgb.r - final_rgb.g * 2.1) * 1.8, 0.0, 1.0);
	float pulse_red = 0.85 + 0.30 * sin(anim_time * 2.6);
	float pulse_purple = 0.88 + 0.28 * sin(anim_time * 3.1 + uv.x * 6.0);

	if (uv.y < 0.35 && uv.x > 0.28 && uv.x < 0.52) {
		final_rgb += vec3(0.22, 0.03, 0.05) * red_glow * (pulse_red - 0.75);
	}
	if (uv.x > 0.70 && uv.y > 0.35 && uv.y < 0.82) {
		final_rgb += vec3(0.16, 0.05, 0.26) * purple_glow * (pulse_purple - 0.75);
	}

	COLOR = vec4(final_rgb, final_tex.a);
}
