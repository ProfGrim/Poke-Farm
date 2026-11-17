extends RefCounted

static func apply(model:Node,shiny:bool):
    var skeleton:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
    if skeleton.find_bone("waist")<0:return
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        if "_smoke_mesh" in str(mesh.name):mesh.hide()
    var joint:=BoneAttachment3D.new()
    skeleton.add_child(joint)
    joint.bone_name="waist"
    var cloud:=MeshInstance3D.new()
    var quad:=QuadMesh.new()
    quad.size=Vector2(1.75,1.75)
    cloud.mesh=quad
    cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material:=ShaderMaterial.new()
    material.shader=preload("res://gastly_cloud.gdshader")
    material.set_shader_parameter("tint",Color("#709cf5" if shiny else "#af65d8"))
    cloud.material_override=material
    joint.add_child(cloud)
