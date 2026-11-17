extends RefCounted
static var config:Dictionary={}
static var textures:Dictionary={}

static func texture(file:String)->Texture2D:
    var weak:WeakRef=textures.get(file)
    var result:Texture2D=weak.get_ref() if weak else null
    if not result:
        var image:=Image.load_from_file("res://map/"+file)
        if image.is_empty():return null
        image.generate_mipmaps()
        result=ImageTexture.create_from_image(image)
        textures[file]=weakref(result)
    return result

static func apply(model:Node,key:String,shiny:bool):
    if config.is_empty():config=JSON.parse_string(FileAccess.get_file_as_string("res://map/native-light.json"))
    if not config.has(key):return
    var copies:Dictionary={}
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        for i in mesh.mesh.get_surface_count():
            var original=mesh.get_active_material(i)
            if not original is StandardMaterial3D or not config[key].has(original.resource_name):continue
            if not copies.has(original):
                var mat:StandardMaterial3D=original.duplicate()
                var settings:Dictionary=config[key][original.resource_name]
                if settings.has("sphere"):
                    var overlay:=ShaderMaterial.new()
                    overlay.shader=preload("res://native_reflection.gdshader")
                    overlay.set_shader_parameter("environment_map",texture(settings.sphere))
                    overlay.set_shader_parameter("weight",settings.weight)
                    mat.next_pass=overlay
                else:
                    var emission:Array=settings.shiny if shiny else settings.regular
                    mat.emission_enabled=true
                    if settings.get("black_emission_base",false):mat.albedo_color=Color.BLACK
                    mat.emission_texture=texture(emission[0])
                    mat.emission_energy_multiplier=emission[1]
                copies[original]=mat
            mesh.set_surface_override_material(i,copies[original])
