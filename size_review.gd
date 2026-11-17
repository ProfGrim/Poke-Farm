extends Node3D

const SAVE_PATH:="user://size-review.json"
const STAGE_X:=1.0
var loader:=preload("res://model_loader.gd").new()
var audit:Dictionary={}
var queue:Array=[]
var decisions:Dictionary={}
var index:=0
var subject:Node3D
var title:=Label.new()
var details:=Label.new()
var progress:=Label.new()
var capture_batch:bool="--capture-size-batch" in OS.get_cmdline_user_args()
var capture_start:=0

func _ready():
    ResourceLoader.add_resource_format_loader(loader,true)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--size-start="):capture_start=maxi(0,int(argument.get_slice("=",1)))
    audit=JSON.parse_string(FileAccess.get_file_as_string("res://map/height-audit.json"))
    queue=audit.get("entries",{}).values()
    queue.sort_custom(func(a,b):return a.assetId<b.assetId)
    if FileAccess.file_exists(SAVE_PATH):
        var parsed=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
        if parsed is Dictionary:decisions=parsed
    _build_world();_build_ui();_show()
    if capture_batch:call_deferred("_capture_first_batch")

func _exit_tree():ResourceLoader.remove_resource_format_loader(loader)

func _build_world():
    var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("#e8eee8");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_energy=.8;add_child(world)
    var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-28,0);sun.light_energy=1.;add_child(sun)
    var camera:=Camera3D.new();camera.position=Vector3(.2,4.0,13.5);camera.fov=38;add_child(camera);camera.look_at(Vector3(.2,4.,0))
    var backdrop:=MeshInstance3D.new();var plane:=QuadMesh.new();plane.size=Vector2(7.2,8.6);var material:=StandardMaterial3D.new();material.albedo_color=Color("#f7f6f0");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;plane.material=material;backdrop.mesh=plane;backdrop.position=Vector3(.2,4.15,-.45);add_child(backdrop)
    var lines:=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
    for step in 81:
        var y:=float(step)/10.;var major:=step%5==0
        lines.surface_set_color(Color("#40504a") if major else Color("#aab4ae"));lines.surface_add_vertex(Vector3(-3.3,y,-.4));lines.surface_set_color(Color("#40504a") if major else Color("#aab4ae"));lines.surface_add_vertex(Vector3(3.7,y,-.4))
        if major:
            var label:=Label3D.new();label.text="%.1f m  /  %.1f ft"%[y,y*3.28084];label.font_size=20;label.modulate=Color("#273832");label.position=Vector3(-3.75,y,-.35);label.no_depth_test=true;add_child(label)
    lines.surface_end();var grid:=MeshInstance3D.new();grid.mesh=lines;add_child(grid)
    var floor:=MeshInstance3D.new();var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(8,6);var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("#ccd8c8");floor_mesh.material=floor_mat;floor.mesh=floor_mesh;add_child(floor)

func _button(text_value:String,callable:Callable)->Button:
    var button:=Button.new();button.text=text_value;button.pressed.connect(callable);button.custom_minimum_size.y=36;return button

func _build_ui():
    var panel:=PanelContainer.new();panel.position=Vector2(18,18);panel.size=Vector2(470,0);var style:=StyleBoxFlat.new();style.bg_color=Color("#173f39ed");style.set_corner_radius_all(14);style.set_content_margin_all(15);panel.add_theme_stylebox_override("panel",style);add_child(panel)
    var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box);title.add_theme_font_size_override("font_size",24);box.add_child(title);progress.modulate=Color("#d5f0c5");box.add_child(progress);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(details)
    var row:=HBoxContainer.new();row.add_child(_button("Approve scale",func():_decide("approved")));row.add_child(_button("Hold / wrong axis",func():_decide("hold")));row.add_child(_button("Previous",func():_move(-1)));row.add_child(_button("Next",func():_move(1)));box.add_child(row)
    var help:=Label.new();help.text="The chart is true world scale. Giants use the documented ranch soft cap.";help.modulate=Color("#c8d9d3");box.add_child(help)

func _show():
    if subject:subject.queue_free();subject=null
    if queue.is_empty():return
    var row:Dictionary=queue[index];var packed=ResourceLoader.load("res://models/"+row.sourceResourceIdentity+".glb","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
    title.text=str(row.formName);progress.text="Model %d of %d  •  %d reviewed"%[index+1,queue.size(),decisions.size()]
    if row.currentPoseHeightM==null or row.ranchScaleMultiplier==null:
        details.text="Official: %.2f m (%.2f ft)\nON HOLD: this form has no trustworthy measured pose bounds yet.\nReference: %s"%[float(row.officialHeightM),float(row.officialHeightFt),str(row.referencePrecision)]
        if packed:subject=packed.instantiate();add_child(subject);_scale_to_height(float(row.ranchDisplayHeightM))
        return
    details.text="Official: %.2f m (%.2f ft)\nCurrent measured %s: %.2f m\nProposed ranch display: %.2f m\nScale correction: ×%.3f\nReference: %s%s"%[float(row.officialHeightM),float(row.officialHeightFt),str(row.measurementSemantic),float(row.currentPoseHeightM),float(row.ranchDisplayHeightM),float(row.ranchScaleMultiplier),str(row.referencePrecision),"  •  GIANT SOFT CAP" if row.giantSoftCapApplied else ""]
    if not packed:return
    subject=packed.instantiate();add_child(subject);_scale_to_height(float(row.ranchDisplayHeightM))

func _scale_to_height(target_height:float):
    var bounds:=AABB();var first:=true
    for mesh in subject.find_children("*","MeshInstance3D",true,false):
        if not mesh.visible:continue
        var local:Transform3D=subject.global_transform.affine_inverse()*mesh.global_transform;var box:AABB=local*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
    if first:return
    var row:Dictionary=queue[index]
    var measured_size:float=maxf(bounds.size.x,bounds.size.z) if row.measurementAxis=="longest-horizontal" else bounds.size.y
    var scale_value:=target_height/maxf(.001,measured_size);subject.scale=Vector3.ONE*scale_value;subject.position=Vector3(STAGE_X-bounds.get_center().x*scale_value,-bounds.position.y*scale_value,0)
    var player:=_find_player(subject)
    if player and player.has_animation("Idle"):player.play("Idle")

func _find_player(node:Node)->AnimationPlayer:
    if node is AnimationPlayer:return node
    for child in node.get_children():
        var found:=_find_player(child)
        if found:return found
    return null

func _move(amount:int):index=posmod(index+amount,queue.size());_show()

func _decide(result:String):
    var row:Dictionary=queue[index];decisions[row.assetId]={"result":result,"reviewed":Time.get_datetime_string_from_system(),"officialHeightM":row.officialHeightM,"ranchDisplayHeightM":row.ranchDisplayHeightM,"scaleMultiplier":row.ranchScaleMultiplier}
    var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(decisions,"  "));_move(1)

func _unhandled_key_input(event:InputEvent):
    if not event.pressed:return
    if event.keycode==KEY_LEFT:_move(-1)
    elif event.keycode==KEY_RIGHT:_move(1)

func _capture_first_batch():
    var finish:=mini(queue.size(),capture_start+24)
    var output:=ProjectSettings.globalize_path("res://review-output/size-batch-%04d-%04d"%[capture_start+1,finish])
    DirAccess.make_dir_recursive_absolute(output)
    for item in range(capture_start,finish):
        index=item;_show()
        for frame in 5:await get_tree().process_frame
        var image:=get_viewport().get_texture().get_image()
        image.save_png(output.path_join("%04d-%s.png"%[item+1,str(queue[item].assetId)]))
        print("SIZE REVIEW CAPTURE ",item+1,"/",finish," ",queue[item].assetId)
    get_tree().quit(0)
