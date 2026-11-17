extends Node

func _ready():
    print("Testing 3D render...")
    var vp = SubViewport.new()
    vp.transparent_bg = true
    vp.size = Vector2i(512, 512)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(vp)
    
    var cam = Camera3D.new()
    cam.position = Vector3(0, 1.0, 2.5)
    cam.look_at(Vector3(0, 0.8, 0))
    vp.add_child(cam)
    
    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35, 45, 0)
    vp.add_child(light)
    
    var doc = GLTFDocument.new()
    var state = GLTFState.new()
    if doc.append_from_file("res://models/herd_0123_00.glb", state) == OK:
        var model = doc.generate_scene(state)
        model.scale = Vector3.ONE * 0.008
        vp.add_child(model)
        
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    
    var img = vp.get_texture().get_image()
    if img:
        img.save_png("user://test_scyther_render.png")
        print("Saved test_scyther_render.png!")
    else:
        print("Failed to get image")
    get_tree().quit(0)
