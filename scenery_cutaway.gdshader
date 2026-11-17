shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale=vec2(1.0);
uniform float alpha_cut=0.0;
uniform bool use_vertex_color=false;
uniform vec3 camera_eye;
uniform vec4 subjects[3];
uniform int subject_count=0;
varying vec3 world_pos;

void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
    vec4 base=texture(albedo_map,UV*uv_scale)*tint;
    if(base.a<alpha_cut){discard;}
    float fade=0.0;
    vec3 offset=world_pos-camera_eye;
    for(int i=0;i<subject_count;i++){
        vec3 line=subjects[i].xyz-camera_eye;
        float t=dot(offset,line)/max(dot(line,line),0.0001);
        if(t>0.0 && t<1.0){
            // The opening follows the apparent size of this resident at this depth.
            float radius=max(.07,t*subjects[i].w);
            float separation=length(offset-t*line)/radius;
            fade=max(fade,1.0-smoothstep(.76,1.24,separation));
        }
    }
    if(fade>0.0){
        // Screen-door fading keeps the opaque batches and avoids alpha sorting.
        float threshold=fract(52.9829189*fract(dot(floor(FRAGCOORD.xy),vec2(.06711056,.00583715))));
        if(fade>threshold){discard;}
    }
    ALBEDO=base.rgb*(use_vertex_color?COLOR.rgb:vec3(1.0));
    ROUGHNESS=.95;
}
