shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley;

// TEXTURAS COLORIDAS, com repeticao: a mesma UV pinta toda a superficie.
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_pebble_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_pebble_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rocky_path_tex : source_color, filter_linear_mipmap, repeat_enable;

// MASCARAS RGB em dados lineares (sem source_color) e SEM repeticao.
// base: R=terra, G=pedra; detalhe: R=grama pedregosa, G=terra pedregosa, B=trilha pedregosa.
uniform sampler2D base_control : filter_linear, repeat_disable;
uniform sampler2D detail_control : filter_linear, repeat_disable;

uniform vec2 texture_tiling = vec2(12.0,12.0);
uniform float details_strength : hint_range(0.0, 1.0) = 0.75;
uniform float material_roughness : hint_range(0.0, 1.0) = 0.96;
uniform vec4 grass_tint : source_color = vec4(0.80, 0.94, 0.72, 1.0);
uniform vec4 dirt_tint : source_color = vec4(0.75, 0.68, 0.60, 1.0);

void fragment() {
    vec2 material_uv = UV * texture_tiling;
    vec3 grass = texture(grass_tex, material_uv).rgb * grass_tint.rgb;
    vec3 dirt = texture(dirt_tex, material_uv).rgb * dirt_tint.rgb;
    vec3 stone = texture(stone_tex, material_uv).rgb;
    vec3 ctrl = texture(base_control, UV).rgb;
    float wd = clamp(ctrl.r,0.0,1.0);
    float ws = clamp(ctrl.g,0.0,1.0);
    float wg = max(0.0,1.0-wd-ws);
    float weights = max(wg+wd+ws,0.0001);
    vec3 color = (grass*wg+dirt*wd+stone*ws)/weights;

    // Detalhes locais: onde o controle e preto, manter base sem pedrinhas.
    vec3 decor = texture(detail_control, UV).rgb * details_strength;
    color = mix(color, texture(grass_pebble_tex, material_uv).rgb * grass_tint.rgb, clamp(decor.r,0.0,1.0));
    color = mix(color, texture(dirt_pebble_tex, material_uv).rgb * dirt_tint.rgb, clamp(decor.g,0.0,1.0));
    color = mix(color, texture(rocky_path_tex, material_uv).rgb, clamp(decor.b,0.0,1.0));

    ALBEDO = color;
    ROUGHNESS = material_roughness;
    METALLIC = 0.0;
    // Nao usar unshaded: permite sol, luz noturna e sombras reais do Godot.
}
