extends RefCounted

static func texture(path:String)->Texture2D:
    var image:=Image.load_from_file("res://map/cryogonal-"+path+".png")
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)

static func apply(model:Node):
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://map/cryogonal-materials.json"))
    var textures:Dictionary={}
    var materials:Dictionary={}
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        for index in mesh.mesh.get_surface_count():
            var original=mesh.get_active_material(index)
            if not original is StandardMaterial3D or not config.has(original.resource_name):continue
            if not materials.has(original):
                var settings:Dictionary=config[original.resource_name]
                var mat:=ShaderMaterial.new()
                mat.shader=preload("res://cryogonal_ice.gdshader")
                mat.set_shader_parameter("base_map",original.albedo_texture)
                mat.set_shader_parameter("tint",original.albedo_color)
                for param in ["reflection","specular_strength","glow_strength","eye"]:
                    mat.set_shader_parameter(param,settings[param])
                for param in ["sphere_map","glow_mask"]:
                    var file:String=settings[param]
                    if file.is_empty():continue
                    if not textures.has(file):textures[file]=texture(file)
                    mat.set_shader_parameter(param,textures[file])
                materials[original]=mat
            mesh.set_surface_override_material(index,materials[original])
