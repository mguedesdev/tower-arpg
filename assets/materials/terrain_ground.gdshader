shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Material do chao do terreno com mistura de grama, terra e ruido procedural.
// Recebe iluminacao natural e sombras 3D nitidas do Godot 4.
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D blend_noise_tex : filter_linear_mipmap, repeat_enable;

uniform float color_boost : hint_range(0.8, 2.5, 0.05) = 1.0;
uniform float ambient_fill : hint_range(0.0, 1.5, 0.02) = 0.0;
uniform float dirt_mix_width : hint_range(0.0, 0.3, 0.01) = 0.25;

void fragment() {
    vec3 grass_color = texture(grass_tex, UV).rgb;
    vec3 dirt_color = texture(dirt_tex, UV).rgb;
    float edge_noise = texture(blend_noise_tex, UV * 0.28).r;
    float weight = clamp(COLOR.r + (edge_noise - 0.5) * dirt_mix_width, 0.0, 1.0);
    float dirt_amount = smoothstep(0.20, 0.78, weight);

    vec3 terrain_color = mix(grass_color, dirt_color, dirt_amount);
    ALBEDO = min(terrain_color * color_boost, vec3(1.0));
    EMISSION = terrain_color * ambient_fill;
    ROUGHNESS = 0.94;
    SPECULAR = 0.05;
}
