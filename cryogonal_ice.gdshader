shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_map : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D sphere_map : source_color, repeat_disable, filter_linear_mipmap;
uniform sampler2D glow_mask : repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float reflection;
uniform float specular_strength;
uniform float glow_strength;
uniform bool eye;
uniform float resident_opacity = 1.0;

void fragment() {
    vec3 base = texture(base_map, UV).rgb * tint.rgb;
    vec3 n = normalize(NORMAL);
    vec3 ray = reflect(-VIEW, n);
    vec2 sphere_uv = vec2(ray.x, -ray.y) / max(0.001, 2.0 * length(ray + vec3(0.,0.,1.))) + 0.5;
    vec3 ice = texture(sphere_map, sphere_uv).rgb;
    vec3 mask = texture(glow_mask, UV).rgb;
    ALBEDO = base;
    ROUGHNESS = reflection > 0.0 ? 0.27 : 0.65;
    SPECULAR = specular_strength;
    EMISSION = ice * reflection * (vec3(.35) + base * .65) + base * (eye ? mask.r : mask.g) * glow_strength;
    ALPHA = resident_opacity;
    ALPHA_HASH_SCALE = 1.0;
}
