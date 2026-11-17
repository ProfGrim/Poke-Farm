shader_type spatial;
varying vec2 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xz/7.;}
void fragment(){if(length((p-vec2(-12.,6.))/vec2(7.,4.7))>1.12){discard;}float t=TIME*.42;float wave=sin(p.y*9.+sin(p.x*2.7+t)*1.4+t)+sin(p.y*5.3+p.x*.8-t);
float glint=smoothstep(1.54,1.83,wave)*.32;
ALBEDO=mix(vec3(.065,.35,.41),vec3(.29,.71,.69),.4+.17*sin(p.x*.45+p.y*.27)+glint);
ALPHA=.53+glint*.25;ROUGHNESS=.42;}