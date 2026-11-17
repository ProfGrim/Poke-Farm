extends Node3D

static var bubble_texture:Texture2D
static var mark_texture:Texture2D
var particles:Array[Sprite3D]=[]
var rig:Skeleton3D
var bone:=-1
var face_marker:=false
var phase:=0.
var size_unit:=1.
var particle_size:=1.
static var sleep_profiles:Dictionary={}
var sleep_box:AABB
var visual:Node3D
var fallback:=Vector3.ZERO
var with_marks:=false

func setup(model:Node3D,box:AABB,identity:String,model_key:String):
    top_level=true
    # Particle widths and travel distances are already measured in ranch world units.
    global_transform=Transform3D.IDENTITY
    with_marks=(identity.hash()%2)==0
    phase=float(identity.hash()%997)/997.
    var skeletons=model.find_children("*","Skeleton3D",true,false)
    if not skeletons.is_empty():
        rig=skeletons[0]
        for wanted in ["effmouth01","mouth","jaw","lowerjaw","head"]:
            for i in rig.get_bone_count():
                if rig.get_bone_name(i).to_lower().replace("_","")==wanted:
                    bone=i;face_marker=wanted!="head";break
            if bone>=0:break
    visual=model
    if sleep_profiles.is_empty():
        sleep_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://map/sleep-pose-bounds.json"))
    var profile:Array=sleep_profiles.get(model_key,[])
    sleep_box=box
    if profile.size()==6:
        sleep_box=AABB(Vector3(profile[0],profile[1],profile[2]),Vector3(profile[3],profile[4],profile[5]))
    size_unit=maxf(.05,sleep_box.size.length()*.56)
    particle_size=maxf(size_unit,box.size.length()*.46)
    fallback=sleep_box.get_center()+Vector3(0,sleep_box.size.y*.18,sleep_box.size.z*.32)
    if not bubble_texture:
        bubble_texture=ImageTexture.create_from_image(Image.load_from_file("res://map/sleep-bubbles.png"))
        mark_texture=ImageTexture.create_from_image(Image.load_from_file("res://map/sleep-mark.png"))
    for i in (4 if with_marks else 2):
        var sprite:=Sprite3D.new()
        sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
        sprite.shaded=false;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        sprite.texture=bubble_texture if i<2 else mark_texture
        sprite.hframes=8 if i<2 else 1
        sprite.no_depth_test=false
        add_child(sprite);particles.append(sprite)

func advance(body:Node3D,camera:Camera3D,dt:float,opacity:float):
    phase=fposmod(phase+dt/2.8,1.)
    var right:=camera.global_basis.x.normalized()
    var pose:=body.global_transform
    pose.origin=visual.global_position
    var anchor:=pose*fallback
    if bone>=0:
        anchor=rig.to_global(rig.get_bone_global_pose(bone).origin)
    var local_anchor:=pose.affine_inverse()*anchor
    if local_anchor.distance_to(local_anchor.clamp(sleep_box.position,sleep_box.end))>size_unit*.15:
        anchor=pose*fallback
    # Preserve the face position in the shot while clearing the resident's own depth.
    var toward:=camera.global_basis.z.normalized() if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else anchor.direction_to(camera.global_position)
    var axis:Vector3=pose.basis.transposed()*toward
    var clearance:float=((pose*sleep_box.get_center())-anchor).dot(toward)+axis.abs().dot(sleep_box.size*.5)
    global_position=anchor+toward*maxf(size_unit*.09,clearance+size_unit*.045)
    for i in particles.size():
        var sprite:=particles[i]
        var t:=fposmod(phase+(.53 if i%2 else 0.)+(.17 if i>=2 else 0.),1.)
        var mark:=i>=2
        var width:=particle_size*lerpf(.085,.19,t)*(.68 if i%2 else 1.)
        sprite.pixel_size=width/(float(sprite.texture.get_width())/sprite.hframes)
        sprite.position=size_unit*(Vector3.UP*((.11 if mark else 0.)+t*(.54 if mark else .36))+right*(.07+.16*t+sin(t*PI)*.04))
        sprite.modulate.a=opacity*smoothstep(0.,.16,t)*(1.-smoothstep(.72,1.,t))*(.91 if mark else .77)
        if not mark:sprite.frame=mini(7,int(t*8))
