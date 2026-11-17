shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform sampler2D environment_map : source_color, repeat_disable, filter_linear_mipmap;
uniform float weight;
uniform float resident_opacity = 1.0;
void fragment(){
    vec3 ray=reflect(-VIEW,normalize(NORMAL));
    vec2 uv=vec2(ray.x,-ray.y)/max(.001,2.*length(ray+vec3(0.,0.,1.)))+.5;
    ALBEDO=texture(environment_map,uv).rgb;
    ALPHA=weight*.55*resident_opacity;
}
