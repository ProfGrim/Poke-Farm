extends RefCounted

# Keep textures shared only while a resident is using them.
static var live_textures:Dictionary={}

static func apply(model:Node,replacements:Dictionary)->bool:
    var materials:Dictionary={}
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        for idx in mesh.mesh.get_surface_count():
            var original=mesh.get_active_material(idx)
            if not original is StandardMaterial3D or not replacements.has(original.resource_name):continue
            if not materials.has(original):
                var path:String=replacements[original.resource_name]
                var ref:WeakRef=live_textures.get(path)
                var texture:Texture2D=ref.get_ref() if ref else null
                if not texture:
                    var img:=Image.load_from_file("res://map/"+path)
                    if img.is_empty():return false
                    texture=ImageTexture.create_from_image(img)
                    live_textures[path]=weakref(texture)
                var copy:StandardMaterial3D=original.duplicate()
                copy.albedo_texture=texture
                materials[original]=copy
            mesh.set_surface_override_material(idx,materials[original])
    return not materials.is_empty()
