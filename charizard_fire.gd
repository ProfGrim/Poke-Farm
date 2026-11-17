extends RefCounted
# Ranch approximation of Charizard's layered fire, attached to the original animated fire cores.
static var shader:Shader
static var palette:Dictionary={}
static func apply(model:Node):
    if not shader:
        shader=Shader.new()
        shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float resident_opacity=1.0;
uniform vec4 inner : source_color;
uniform vec4 outer : source_color;
void fragment(){
    float h=clamp(1.0-UV.y,0.0,1.0);
    float drift=sin(UV.x*15.0+h*4.0-TIME*5.0)*0.09
               +sin(UV.x*24.0-h*3.0+TIME*6.8)*0.05;
    float heat=clamp(h+drift,0.0,1.0);
    ALBEDO=mix(inner.rgb,outer.rgb,smoothstep(0.08,0.83,heat));
    ALPHA=resident_opacity*(1.0-smoothstep(0.67,1.0,heat))*.94;
}
"""
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        for i in mesh.mesh.get_surface_count():
            var mat=mesh.get_active_material(i)
            if not mat or not mat.resource_name.begins_with("RanchFlame"):continue
            var label=mat.resource_name
            if not palette.has(label):
                var effect:=ShaderMaterial.new();effect.shader=shader
                var blue:bool=label.begins_with("RanchFlameBlue")
                effect.set_shader_parameter("inner",Color("#aefaff" if blue else "#ffeb50"))
                effect.set_shader_parameter("outer",Color("#177dfb" if blue else "#f34510"))
                palette[label]=effect
            mesh.set_surface_override_material(i,palette[label])
