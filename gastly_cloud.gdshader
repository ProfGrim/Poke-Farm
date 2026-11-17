shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float resident_opacity=1.0;
uniform vec4 tint : source_color;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex(){
    float scale=length(MODEL_MATRIX[0].xyz);
    vec4 center=MODELVIEW_MATRIX*vec4(0,0,0,1);
    center.xy+=VERTEX.xy*scale;
    center.z-=0.25*scale;
    POSITION=PROJECTION_MATRIX*center;
}
void fragment(){
    vec2 p=UV*2.0-1.0;
    vec2 drift=vec2(TIME*.11,TIME*.27);
    vec2 warp=vec2(noise2(p*2.6+drift),noise2(p*2.6-drift+9.7));
    float broad=noise2(p*3.5+drift+warp*1.65);
    float fine=noise2(p*8.0+drift*1.7+vec2(broad));
    float curl=broad*.68+fine*.32;
    float radius=length(p*vec2(1.02,.94));
    float edge=1.0-smoothstep(.62,.94,radius+.53*(.5-curl));
    float wisps=smoothstep(.13,.80,curl);
    ALBEDO=tint.rgb*mix(.62,1.32,fine);
    ALPHA=resident_opacity*edge*wisps*.88;
}
