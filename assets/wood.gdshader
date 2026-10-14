shader_type spatial;
uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
    vec3 tex = texture(grain, UV * vec2(0.9, 0.9)).rgb;
    float value = dot(tex, vec3(0.299,0.587,0.114));
    ALBEDO = vec3(0.52,0.385,0.22) * (0.84 + value * 0.36);
    ROUGHNESS = 0.58;
    SPECULAR = 0.25;
    NORMAL_MAP = texture(normal_map, UV * 0.9).rgb;
    NORMAL_MAP_DEPTH = 0.16;
}
