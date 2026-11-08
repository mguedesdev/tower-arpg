shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;

// ============================================================================
// SHADER ESTILIZADO DE BARRA DE VIDA OVERHEAD DO PLAYER (ARPG DARK FANTASY)
// Renderiza em uma única chamada de desenho: moldura de ferro forjado chanfrada,
// filete em bronze/ouro antigo, fundo de ardósia, rastro de dano (ghost trail),
// preenchimento em rubi/cristal com degradê e reflexo de brilho, e notches.
// ============================================================================

uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float trail_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 frame_color : source_color = vec4(0.12, 0.11, 0.13, 0.98); // Ferro escuro
uniform vec4 trim_color : source_color = vec4(0.82, 0.64, 0.32, 1.0);  // Ouro / bronze antigo
uniform vec4 bg_color : source_color = vec4(0.05, 0.04, 0.05, 0.95);    // Fundo escuro de ardósia
uniform vec4 fill_top : source_color = vec4(0.96, 0.24, 0.28, 1.0);    // Rubi luminoso
uniform vec4 fill_bottom : source_color = vec4(0.58, 0.05, 0.09, 1.0); // Carmesim profundo
uniform vec4 trail_color : source_color = vec4(1.0, 0.82, 0.35, 0.96); // Rastro âmbar de dano
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;             // Pulso de vida baixa

void vertex() {
	// Billboard perfeito no espaço da câmera preservando a escala do nó
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	vec2 uv = UV;

	// 1. Corte chanfrado ornamental nos 4 cantos (estilo placa de metal gótica)
	vec2 corner = min(uv, 1.0 - uv);
	if (corner.x * 2.2 + corner.y < 0.045) {
		discard;
	}

	// 2. Delimitação das bordas da moldura
	const float border_x = 0.035;
	const float border_y = 0.18;
	bool is_border = (uv.x < border_x || uv.x > 1.0 - border_x || uv.y < border_y || uv.y > 1.0 - border_y);

	// Filete interno em ouro antigo na transição entre moldura e interior
	float dist_to_inner = min(
		min(abs(uv.x - border_x), abs(uv.x - (1.0 - border_x))),
		min(abs(uv.y - border_y), abs(uv.y - (1.0 - border_y)))
	);
	bool is_trim = is_border && (dist_to_inner < 0.012);

	vec4 col = bg_color;

	if (is_border) {
		if (is_trim) {
			// Filete dourado com reflexo sutil
			col = trim_color;
			if (uv.y < 0.5) {
				col.rgb += vec3(0.12, 0.10, 0.05);
			}
		} else {
			// Ferro forjado com chanfro de luz no topo e sombra embaixo
			col = frame_color;
			if (uv.y < 0.3) {
				col.rgb += vec3(0.08, 0.08, 0.10);
			} else if (uv.y > 0.7) {
				col.rgb -= vec3(0.04, 0.04, 0.04);
			}
		}
	} else {
		// 3. Interior da barra
		float u = (uv.x - border_x) / (1.0 - border_x * 2.0);
		float v = (uv.y - border_y) / (1.0 - border_y * 2.0);

		// Fundo escuro com sombra interna no topo
		col = bg_color;
		if (v < 0.25) {
			col.rgb -= vec3(0.02, 0.02, 0.02);
		}

		// Camada 1: Rastro de Dano (Ghost Trail)
		if (u <= trail_ratio && trail_ratio > 0.001) {
			col = trail_color;
			if (v < 0.35) {
				col.rgb += vec3(0.15, 0.12, 0.05); // Brilho superior no rastro
			}
		}

		// Camada 2: Preenchimento de Vida Atual (Rubi Carmesim Estilizado)
		if (u <= health_ratio && health_ratio > 0.001) {
			// Degradê vertical suave de rubi luminoso para carmesim profundo
			vec4 liquid = mix(fill_top, fill_bottom, v);

			// Reflexo vítreo horizontal no terço superior
			if (v < 0.38) {
				liquid.rgb += vec3(0.24, 0.12, 0.14) * (1.0 - v / 0.38);
			}
			// Brilho suave na ponta ativa (borda direita da barra)
			float edge_glow = smoothstep(health_ratio - 0.02, health_ratio, u);
			liquid.rgb += vec3(0.20, 0.08, 0.10) * edge_glow;

			col = liquid;
		}

		// Divisores de segmento (notches) sutis em 25%, 50% e 75%
		float notch_dist = min(abs(u - 0.25), min(abs(u - 0.50), abs(u - 0.75)));
		if (notch_dist < 0.005) {
			float notch_alpha = (u < max(health_ratio, trail_ratio)) ? 0.35 : 0.60;
			col.rgb = mix(col.rgb, vec3(0.02, 0.02, 0.03), notch_alpha);
		}

		// Alerta pulsante quando a vida estiver crítica (< 25%)
		if (health_ratio < 0.25 && health_ratio > 0.0) {
			col.rgb += vec3(0.28, 0.04, 0.04) * pulse_intensity;
		}
	}

	ALBEDO = col.rgb;
	ALPHA = col.a;
}
