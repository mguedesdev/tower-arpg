shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Material do chao do terreno com composicao de duas gramas estilizadas (clara e escura),
// terra batida e mascara de ruido procedural.
// Recebe iluminacao natural e sombras 3D nitidas do Godot 4 (GL Compatibility / Mobile / Forward+).

uniform sampler2D grass_light_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_dark_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D blend_noise_tex : filter_linear_mipmap, repeat_enable;

// Fallback / retrocompatibilidade se algum script passar grass_tex
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;

uniform float color_boost : hint_range(0.8, 2.5, 0.05) = 1.0;
uniform float ambient_fill : hint_range(0.0, 1.5, 0.02) = 0.0;
uniform float dirt_mix_width : hint_range(0.0, 0.5, 0.01) = 0.28;
uniform float grass_noise_scale : hint_range(0.05, 0.50, 0.01) = 0.16;

void fragment() {
    // 1. Amostragem das texturas de grama estilizadas
    vec3 g_light = texture(grass_light_tex, UV).rgb;
    vec3 g_dark = texture(grass_dark_tex, UV).rgb;

    // 2. Ruido organico para quebrar repeticao e mesclar grama clara e escura
    float macro_noise = texture(blend_noise_tex, UV * grass_noise_scale).r;
    float micro_noise = texture(blend_noise_tex, UV * 0.45).r;
    float grass_blend = smoothstep(0.32, 0.68, macro_noise * 0.70 + micro_noise * 0.30);
    vec3 composite_grass = mix(g_dark, g_light, grass_blend);

    // 3. Amostragem da terra e calculo da transicao com vertice (COLOR.r)
    vec3 dirt_color = texture(dirt_tex, UV).rgb;
    float edge_noise = texture(blend_noise_tex, UV * 0.32).r;
    float weight = clamp(COLOR.r + (edge_noise - 0.5) * dirt_mix_width, 0.0, 1.0);
    float dirt_amount = smoothstep(0.18, 0.80, weight);

    // Transicao natural: perto da borda com a terra, a grama escurece sutilmente (raizes e umidade)
    float border_damp = smoothstep(0.05, 0.50, dirt_amount);
    vec3 final_grass = mix(composite_grass, g_dark * 0.90, border_damp * 0.55);

    // 4. Composicao final de Albedo
    vec3 terrain_color = mix(final_grass, dirt_color, dirt_amount);
    ALBEDO = min(terrain_color * color_boost, vec3(1.0));
    EMISSION = terrain_color * ambient_fill;
    ROUGHNESS = 0.92;
    SPECULAR = 0.06;
}
