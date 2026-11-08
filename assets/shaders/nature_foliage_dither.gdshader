shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.50;
uniform vec4 foliage_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float material_roughness : hint_range(0.0, 1.0) = 0.85;

// Instância única por malha: permite controlar o fade individual sem duplicar material!
instance uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;

// Matriz de Bayer 4x4 balanceada para screen-door transparency (Dithered Fade)
// Mantém o objeto 100% na fila de renderização OPACA do Godot.
// Vantagens:
// 1. Zero custo de sorting de transparência.
// 2. Zero travamento ou stuttering por troca de pipeline opaco <-> transparente.
// 3. Early-Z buffer e Depth Pre-Pass continuam funcionando normalmente.
const mat4 BAYER4 = mat4(
    vec4( 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0),
    vec4(12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0),
    vec4( 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0),
    vec4(15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0)
);

void fragment() {
    vec4 tex = texture(albedo_texture, UV);

    // 1. Recorte alpha clássico das folhas
    if (tex.a < alpha_scissor_threshold) {
        discard;
    }

    // 2. Dither fade por screening de pixels na tela (sem alpha blend)
    if (fade_amount < 0.999) {
        ivec2 coord = ivec2(FRAGCOORD.xy) % 4;
        float bayer_val = BAYER4[coord.x][coord.y];
        if (fade_amount < bayer_val) {
            discard;
        }
    }

    ALBEDO = tex.rgb * foliage_tint.rgb;
    ROUGHNESS = material_roughness;
    METALLIC = 0.0;
}
