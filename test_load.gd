extends SceneTree

func _init():
    print("Testing Godot GLTF loading from res://models/herd_0123_00.glb...")
    var doc = GLTFDocument.new()
    var state = GLTFState.new()
    var path = "res://models/herd_0123_00.glb"
    var err = doc.append_from_file(path, state)
    print("Append result:", err)
    if err == OK:
        var scene = doc.generate_scene(state)
        print("Generated scene successfully! Name:", scene.name)
    quit(0)
