shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// v0.16.1: material do chao com preenchimento de luz suave.
// Conserva a mistura de grama e terra criada na v0.16.
// Os uniforms podem ser ajustados no ShaderMaterial pelo Inspector.
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D blend_noise_tex : filter_linear_mipmap, repeat_enable;

uniform float color_boost : hint_range(0.8, 2.5, 0.05) = 1.06;
uniform float ambient_fill : hint_range(0.0, 1.5, 0.02) = 0.02;
uniform float dirt_mix_width : hint_range(0.0, 0.3, 0.01) = 0.25;

void fragment() {
    // Garante que a normal do terreno aponte sempre para cima (+Y no mundo),
    // evitando que o cull_disabled inverta a normal e bloqueie a luz direcional e as sombras 3D!
    vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    if (dot(NORMAL, up_view) < 0.0) {
        NORMAL = -NORMAL;
    }

    vec3 grass_color = texture(grass_tex, UV).rgb;
    vec3 dirt_color = texture(dirt_tex, UV).rgb;
    float edge_noise = texture(blend_noise_tex, UV * 0.28).r;
    float weight = clamp(COLOR.r + (edge_noise - 0.5) * dirt_mix_width, 0.0, 1.0);
    float dirt_amount = smoothstep(0.20, 0.78, weight);

    vec3 terrain_color = mix(grass_color, dirt_color, dirt_amount);
    ALBEDO = min(terrain_color * color_boost, vec3(1.0));
    EMISSION = terrain_color * ambient_fill;
    ROUGHNESS = 0.96;
    SPECULAR = 0.08;
}
