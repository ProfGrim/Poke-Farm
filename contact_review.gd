extends Node3D

const SAVE_PATH:="user://contact-review.json"
const CLIPS:=["BallAction","Play","Happy","Look","Grumpy"]
const STAGE_X:=1.25
var loader:=preload("res://model_loader.gd").new()
var queue:Array=[]
var decisions:Dictionary={}
var index:=-1
var subject:Node3D
var player:AnimationPlayer
var current_clip:=""
var ball:=MeshInstance3D.new()
var title:=Label.new()
var status:=Label.new()
var progress:=Label.new()
var clip_picker:=OptionButton.new()
var ball_offset:=Vector3(STAGE_X,.17,.78)
var normalized_scale:=1.0

func _ready():
    ResourceLoader.add_resource_format_loader(loader,true)
    _load_decisions()
    _build_world()
    _build_ui()
    _build_queue()
    _next_unreviewed(1)

func _exit_tree():
    ResourceLoader.remove_resource_format_loader(loader)

func _build_world():
    var environment:=WorldEnvironment.new()
    environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=Color("#b9d6bd")
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color=Color.WHITE
    environment.environment.ambient_light_energy=.72
    add_child(environment)
    var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);sun.light_energy=1.05;add_child(sun)
    var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(12,12)
    var grass:=StandardMaterial3D.new();grass.albedo_color=Color("#73a85f");plane.material=grass;floor.mesh=plane;add_child(floor)
    var camera:=Camera3D.new();camera.position=Vector3(.65,1.35,4.8);camera.fov=35;add_child(camera);camera.look_at(Vector3(.65,1.05,0))
    var sphere:=SphereMesh.new();sphere.radius=.17;sphere.height=.34
    var ball_material:=StandardMaterial3D.new();ball_material.albedo_color=Color("#e9b34a");ball_material.metallic=.08;ball_material.roughness=.62
    sphere.material=ball_material;ball.mesh=sphere;ball.position=ball_offset;add_child(ball)

func _panel()->VBoxContainer:
    var panel:=PanelContainer.new();panel.position=Vector2(18,18);panel.size=Vector2(410,0)
    var style:=StyleBoxFlat.new();style.bg_color=Color("#173f39e8");style.corner_radius_top_left=14;style.corner_radius_top_right=14;style.corner_radius_bottom_left=14;style.corner_radius_bottom_right=14
    style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=14;style.content_margin_bottom=14;panel.add_theme_stylebox_override("panel",style)
    var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box);add_child(panel);return box

func _button(text_value:String,callable:Callable)->Button:
    var button:=Button.new();button.text=text_value;button.pressed.connect(callable);button.custom_minimum_size.y=34;return button

func _build_ui():
    var box:=_panel()
    title.add_theme_font_size_override("font_size",24);box.add_child(title)
    progress.modulate=Color("#d5f0c5");box.add_child(progress)
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
    box.add_child(HSeparator.new())
    var clip_row:=HBoxContainer.new();var clip_label:=Label.new();clip_label.text="Animation";clip_label.custom_minimum_size.x=88;clip_row.add_child(clip_label);clip_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;clip_picker.item_selected.connect(_select_clip);clip_row.add_child(clip_picker);clip_row.add_child(_button("Replay",_replay));box.add_child(clip_row)
    var ball_label:=Label.new();ball_label.text="Place the ball where contact should happen:";box.add_child(ball_label)
    var ball_row:=HBoxContainer.new()
    for item in [["Left",Vector3(-.09,0,0)],["Right",Vector3(.09,0,0)],["Closer",Vector3(0,0,.09)],["Farther",Vector3(0,0,-.09)],["Up",Vector3(0,.09,0)],["Down",Vector3(0,-.09,0)]]:
        ball_row.add_child(_button(item[0],func():_move_ball(item[1])))
    box.add_child(ball_row)
    box.add_child(HSeparator.new())
    var approve:=GridContainer.new();approve.columns=2
    approve.add_child(_button("Approve nudge",func():_decide("nudge")))
    approve.add_child(_button("Approve kick",func():_decide("kick")))
    approve.add_child(_button("Approve greeting",func():_decide("greeting")))
    approve.add_child(_button("Approve group play",func():_decide("group_play")))
    approve.add_child(_button("Reject contact",func():_decide("reject")))
    approve.add_child(_button("Skip for now",func():_next_unreviewed(1)))
    box.add_child(approve)
    var navigation:=HBoxContainer.new();navigation.add_child(_button("Previous",func():_next_unreviewed(-1)));navigation.add_child(_button("Next",func():_next_unreviewed(1)));box.add_child(navigation)
    var help:=Label.new();help.text="Space: replay  •  ←/→: previous/next  •  Decisions save automatically";help.modulate=Color("#c8d9d3");box.add_child(help)

func _build_queue():
    var seen:Dictionary={}
    for row in JSON.parse_string(FileAccess.get_file_as_string("res://ranch-dex.json")):
        var key:String=str(row.get("model",""))
        if key.is_empty() or seen.has(key) or not FileAccess.file_exists("res://models/"+key+".glb"):continue
        # The standardized clips live inside each GLB. ambient-clips.json only
        # contains two legacy source-name overrides, so it cannot be used as
        # the catalog for this review queue.
        seen[key]=true;queue.append({"key":key,"name":row.get("name",key),"form":row.get("form",0)})
    print("CONTACT REVIEW queue=",queue.size())

func _load_decisions():
    if FileAccess.file_exists(SAVE_PATH):
        var parsed=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
        if parsed is Dictionary:decisions=parsed

func _save_decisions():
    var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    file.store_string(JSON.stringify(decisions,"  "))

func _next_unreviewed(direction:int):
    if queue.is_empty():return
    var attempts:=0
    while attempts<queue.size():
        index=posmod(index+direction,queue.size());attempts+=1
        if not decisions.has(queue[index].key):break
    _show_current()

func _show_current():
    if subject:subject.queue_free();subject=null;player=null
    var row:Dictionary=queue[index];var packed=ResourceLoader.load("res://models/"+row.key+".glb","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
    if not packed:
        status.text="Could not load this model.";return
    subject=packed.instantiate();add_child(subject)
    player=_find_player(subject)
    _normalize_subject()
    title.text=str(row.name)+(" · form "+str(row.form) if int(row.form)>0 else "")
    progress.text="Candidate %d of %d  •  %d reviewed"%[index+1,queue.size(),decisions.size()]
    clip_picker.clear()
    if player:
        for clip in CLIPS:
            if player.has_animation(clip):clip_picker.add_item(clip)
    if clip_picker.item_count==0:
        status.text="No reviewable animation found.";_next_unreviewed(1);return
    status.text="Adjust the ball until it sits at the natural contact point, then replay and classify only if contact is convincing."
    _select_clip(0)

func _find_player(node:Node)->AnimationPlayer:
    if node is AnimationPlayer:return node
    for child in node.get_children():
        var found:=_find_player(child)
        if found:return found
    return null

func _normalize_subject():
    var bounds:=AABB();var first:=true
    for mesh in subject.find_children("*","MeshInstance3D",true,false):
        var local:Transform3D=subject.global_transform.affine_inverse()*mesh.global_transform
        var box:AABB=local*mesh.get_aabb()
        bounds=box if first else bounds.merge(box);first=false
    if first:return
    var extent:=maxf(bounds.size.y,maxf(bounds.size.x,bounds.size.z))
    normalized_scale=2.25/maxf(.01,extent);subject.scale=Vector3.ONE*normalized_scale
    subject.position=Vector3(STAGE_X-bounds.get_center().x*normalized_scale,-bounds.position.y*normalized_scale,0)
    ball_offset=Vector3(STAGE_X,.17,maxf(.52,bounds.size.z*normalized_scale*.48+.25));ball.position=ball_offset
    print("CONTACT REVIEW bounds=",bounds," scale=",normalized_scale," subject=",subject.position)

func _select_clip(item:int):
    if not player or item<0 or item>=clip_picker.item_count:return
    current_clip=clip_picker.get_item_text(item);_replay()

func _replay():
    if player and not current_clip.is_empty():player.stop();player.play(current_clip,.12)

func _move_ball(delta:Vector3):
    ball_offset+=delta;ball_offset.y=maxf(.17,ball_offset.y);ball.position=ball_offset;_replay()

func _decide(kind:String):
    var row:Dictionary=queue[index]
    decisions[row.key]={"name":row.name,"form":row.form,"clip":current_clip,"classification":kind,"normalized_ball":[ball_offset.x-STAGE_X,ball_offset.y,ball_offset.z],"reviewed":Time.get_datetime_string_from_system()}
    _save_decisions();_next_unreviewed(1)

func _unhandled_key_input(event:InputEvent):
    if not event.pressed:return
    if event.keycode==KEY_SPACE:_replay()
    elif event.keycode==KEY_LEFT:_next_unreviewed(-1)
    elif event.keycode==KEY_RIGHT:_next_unreviewed(1)
