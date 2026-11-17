extends ResourceFormatLoader

var visibility_rules:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preload("res://ranch_visibility.gd").DATA))

func _get_recognized_extensions()->PackedStringArray:
    return PackedStringArray(["glb"])

func _handles_type(type:StringName)->bool:
    return type==&"PackedScene"

func _get_resource_type(path:String)->String:
    return "PackedScene" if path.begins_with("res://models/") and path.ends_with(".glb") else ""

func _load(path:String,_original_path:String,_use_sub_threads:bool,_cache_mode:int)->Variant:
    var doc:=GLTFDocument.new()
    var state:=GLTFState.new()
    # Validate the length and magic before passing a complete GLB to Godot.
    # These models embed their images and buffers, so no secondary file is needed.
    var bytes:=FileAccess.get_file_as_bytes(path)
    if bytes.size()<20 or bytes.decode_u32(0)!=0x46546c67 or bytes.decode_u32(4)!=2 or bytes.decode_u32(8)!=bytes.size():
        push_error("Incomplete ranch model: "+path)
        return ERR_FILE_CORRUPT
    if doc.append_from_buffer(bytes,path.get_base_dir(),state)!=OK:return ERR_FILE_CORRUPT
    var root:=doc.generate_scene(state)
    if not root:return ERR_FILE_CORRUPT
    preload("res://ranch_visibility.gd").apply(root,visibility_rules.get(path.get_file().get_basename(),{}))
    if path.get_file().get_basename()=="herd_0812_00":
        var guard=preload("res://rillaboom_props.gd").new()
        root.add_child(guard);guard.owner=root

    var packed:=PackedScene.new()
    var result:=packed.pack(root)
    root.free()
    if result!=OK:return result
    return packed
