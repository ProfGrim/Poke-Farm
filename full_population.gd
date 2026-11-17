extends RefCounted
# One atlas, one draw batch for the residents that do not yet have an exact animated model.
var batch:=MultiMesh.new()
var occupied:Dictionary={}
var light_residents:Array=[]
var groups:Array=[]
var supper=preload("res://group_dinner.gd").new()
var walk_clips:Dictionary={}
const ActivityPolicy=preload("res://activity_policy.gd")
var social_clock:=0.0
var recruitment_delay:=1.0
var longest_navigation_edge:=0.0
var activity_durations:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://map/activity-durations.json"))
var ambient_clips:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://map/ambient-clips.json"))
var destinations:=PackedInt32Array()
var loaded_art:=0
var markers:=0
var unavailable:Array=[]
var sprite_node:=MultiMeshInstance3D.new()
const TILES_PER_ROW=40
# Offsets are in ranch units, measured from these specific imported models.
# Each resting ball sits just beyond the neutral pose and inside the moving tip’s reach.
const BALL_RADIUS:=.12
const BALL_CONTACTS={
    "herd_0079_00":["EffMouth01",Vector3(0.00000,0.12000,0.70900),"Play"],
    "herd_0813_00":["LToe1",Vector3(0.04700,0.12000,0.15400),"Play"],
    "full_SH_122_1":["LToe",Vector3(0.22922,0.12000,0.47882),"Play"],
    "full_SH_866_0":["EffFoot01",Vector3(-0.23946,0.12000,0.47757),"Play"],
    "herd_0057_00":["right_toe",Vector3(-0.39804,0.12000,0.50988),"Play"],
    "herd_0236_00":["EffMouth01",Vector3(-0.00824,0.12000,0.29335),"Play"],
    "herd_0427_00":["EffFoot01",Vector3(0.02786,0.12000,0.30694),"Play"],
    "herd_0498_00":["nose",Vector3(-0.11503,0.12000,0.60678),"Play"],
    "herd_0506_00":["Nose",Vector3(0.04548,0.12000,0.31645),"Play"],
    "herd_0834_00":["EffMouth01",Vector3(-0.06161,0.12000,0.87606),"Play"],
    "p0960_00":["nose",Vector3(-0.07771,0.12000,0.84872),"EatStart"],
    "herd_0814_00":["EffFoot01",Vector3(0.21028,0.12000,0.76397),"BallAction"],
    "herd_0815_00":["RToe2",Vector3(-0.10690,0.12000,1.27000),"BallAction"],
}

func ball_clip(actor)->String:
    return BALL_CONTACTS[actor.asset.key][2]

func eligible(actor)->bool:
    return not actor.swimming and actor.player and actor.visual and BALL_CONTACTS.has(actor.asset.get("key","")) and actor.player.has_animation(ball_clip(actor))

func play_phase_clip(actor,g)->String:
    if g.has("ball") and actor.slot in g.players:
        return ball_clip(actor) if actor.slot==g.players[g["pass"]%g.players.size()] else "Idle"
    if g.has("turn"):return "Play" if actor.slot==g.players[g.turn%g.players.size()] else "Idle"
    return "Idle"

func waiting_ball(actor)->Vector3:
    return actor.body.to_global(BALL_CONTACTS[actor.asset.key][1])

func contact_tip(actor):
    var bones=actor.visual.find_children("*","Skeleton3D",true,false)
    if bones.is_empty():return null
    var sk:Skeleton3D=bones[0]
    var bone:=sk.find_bone(BALL_CONTACTS[actor.asset.key][0])
    if bone<0:return null
    return sk.to_global(sk.get_bone_global_pose(bone).origin)


var wander_rng:=RandomNumberGenerator.new()

func build(ranch,rows:Array,by_key:Dictionary):
    wander_rng.randomize()
    walk_clips=JSON.parse_string(FileAccess.get_file_as_string("res://map/walk_clips.json"))
    var records:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://map/resident_profiles.json"))
    var texture:=ImageTexture.create_from_image(Image.load_from_file("res://map/shiny-atlas.png"))
    var shader:=Shader.new()
    shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float max_screen_height = 0.16;
uniform sampler2D regular_atlas : source_color, filter_linear, repeat_disable;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
varying vec2 tile;
varying float hidden;
void vertex(){
    tile=INSTANCE_CUSTOM.xy;hidden=INSTANCE_CUSTOM.z;
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
    // Limit fallback billboards near the lens, including during camera travel.
    float depth = abs(PROJECTION_MATRIX[3][3]) < 0.5 ? max(0.001,-MODELVIEW_MATRIX[3].z) : 1.0;
    float world_limit = max_screen_height * 2.0 * depth / max(0.001,abs(PROJECTION_MATRIX[1][1]));
    VERTEX *= min(INSTANCE_CUSTOM.w,world_limit/1.35);
}
void fragment(){
    if(hidden>0.0 && (hidden>=1.0 || fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)<hidden)){discard;}
    vec2 uv=(vec2(tile.x,mod(tile.y,40.0))+clamp(UV,vec2(.006),vec2(.994)))/40.0;
    vec4 c=tile.y>=40.0 ? texture(regular_atlas,uv) : texture(atlas,uv);
    ALBEDO=c.rgb; ALPHA=c.a; ALPHA_SCISSOR_THRESHOLD=.35;
}
"""
    var material:=ShaderMaterial.new()
    material.shader=shader;material.set_shader_parameter("atlas",texture)
    material.set_shader_parameter("max_screen_height",.16 if ranch.display_style=="3D residents" else .55)
    material.set_shader_parameter("regular_atlas",ImageTexture.create_from_image(Image.load_from_file("res://map/regular-atlas.png")))
    var quad:=QuadMesh.new();quad.size=Vector2(1.35,1.35);quad.material=material
    batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true
    batch.mesh=quad
    var mounted:Array=rows
    batch.instance_count=mounted.size()
    sprite_node.multimesh=batch;ranch.add_child(sprite_node)
    var home_pools:Array=[[],[],[],[],[]]
    var dry_count:=0
    var pond_free:Array=[]
    for i in range(ranch.land.land_count,ranch.land.points.size()):pond_free.append(i)
    for i in ranch.land.land_count:
        if not occupied.has(i):home_pools[ranch.land.zones[i]].append(i);dry_count+=1
    if mounted.size()>dry_count+pond_free.size():return false
    for i in mounted.size():
        var row=mounted[i]
        var swimming:bool=int(row.species) in ranch.POND_SPECIES
        var home:int=ranch.land.preferred(row)
        var pool:Array=pond_free if swimming else home_pools[home]
        if not swimming and pool.is_empty():
            for other in home_pools:
                if other.size()>pool.size():pool=other
        if pool.is_empty():return false
        var choice=ranch.rng.randi_range(0,pool.size()-1)
        var node:int=pool[choice];pool[choice]=pool.back();pool.pop_back()
        occupied[node]=i
        var r=ranch.Resident.new();r.body=Node3D.new();ranch.add_child(r.body)
        var pos:Vector2=ranch.land.points[node];r.swimming=swimming;r.home_zone=ranch.land.zones[node]
        var profile:Array=ranch.pose_profiles.get(row.model,[]) if not row.get("visual_hold","") else []
        if not profile.is_empty():
            var low:=Vector3(profile[0],profile[1],profile[2])
            var high:=Vector3(profile[3],profile[4],profile[5])
            r.pose_box=AABB(low,high-low)
            r.altitude=profile[6]
        if swimming:
            # Put the waterline through the lower third of the animated body,
            # regardless of whether the imported skeleton starts above or below zero.
            r.altitude=ranch.lake_offsets.get(row.model,{}).get("Idle",[.07])[0]
        r.body.position=Vector3(pos.x,r.altitude+ranch.land.ground(pos,swimming),pos.y)
        r.title=ranch.form_titles.get(ranch.deposits.form_key(row),row.name)
        r.species_title=r.title
        r.stationary=row.get("stationary",false)
        r.info=row.get("deposit_record",records.get(ranch.deposits.form_key(row),{}))
        if int(row.species) in [414,664,665,744] or (int(row.species)==658 and int(row.form) in [0,1]):
            r.appearance_group=str(int(row.species))+("/shiny" if r.info.get("shiny",true) else "/regular")
            r.title=row.name
            r.species_title=row.name
        if row.get("depositor_name","") and row.depositor_name!=row.name:r.title=str(row.depositor_name)+" · "+r.title
        if row.model and (r.info.get("shiny",true) or ranch.regular_materials.has(row.model)) and not row.get("visual_hold",""):r.asset=by_key[row.model]
        else:r.title+=" · sprite"
        r.bedtime=wander_rng.randf_range(12.,110.);r.morning_time=wander_rng.randf_range(.03,.98) # Fraction of 7-8 AM wake window.
        r.slot=i;r.has_art=ranch.deposits.has_art(r.info,row)
        r.proxy_color=Color(int(row.get("tile",0))%TILES_PER_ROW,floori(float(row.get("tile",0))/TILES_PER_ROW),0,float(row.get("sprite_size",1.0)))
        if not r.info.get("shiny",true):r.proxy_color.g+=40
        r.here=node;r.speed=ranch.rng.randf_range(.55,1.2);r.rest=ranch.rng.randf()*meadow_pause(wander_rng)
        loaded_art+=1
        light_residents.append(r);destinations.append(-1);ranch.herd.append(r)
        refresh_proxy(ranch,r)
        place(i,r,0)
    # Seed a few meetings while residents are still at their starting nodes.
    for attempt in mini(64,mounted.size()):
        if groups.size()>=clampi(mounted.size()/50,1,5):break
        try_group(ranch,light_residents[ranch.rng.randi_range(0,mounted.size()-1)])
    return true

func refresh_proxy(ranch,r):
    var color:Color=r.proxy_color
    color.b=r.visual_mix if r.visual else 0.0
    if ranch.display_style=="3D residents" and not ranch.overview and (r.asset or r.info.get("shiny",true)):color.b=maxf(color.b,1.0-r.pan_visibility)
    color.b=1.0-(1.0-color.b)*smoothstep(0.,1.,r.event_mix)
    if not r.body.visible or r.occluding_proxy or not r.has_art:color.b=1.0
    batch.set_instance_custom_data(r.slot,color)

func place(i:int,r,bob:float):
    batch.set_instance_transform(i,Transform3D(Basis.IDENTITY,r.body.position+Vector3.UP*(.67*r.proxy_color.a+bob)))

func try_group(ranch,leader)->bool:
    if groups.size()>=clampi(light_residents.size()/20,1,16):return false
    if not ranch.cycle.can_start_activity(25.):return false
    if leader.resting_at_night or leader.meal or leader.stationary or leader.group or leader.social_after>social_clock or destinations[leader.slot]>=0:return false
    if ranch.display_style=="3D residents" and not leader.asset:return false
    var peers:Array=[leader.slot]
    var neighbors:PackedInt64Array=ranch.land.navigation.get_point_connections(leader.here)
    if neighbors.is_empty():return false
    var start:int=ranch.rng.randi_range(0,neighbors.size()-1)
    var goal:int=3
    for j in neighbors.size():
        var node:int=neighbors[(start+j)%neighbors.size()]
        if not occupied.has(node):continue
        var other=light_residents[occupied[node]]
        if other.resting_at_night or other.meal or other.stationary or other.here!=node or other.group or other.social_after>social_clock or destinations[other.slot]>=0:continue
        if other.swimming!=leader.swimming or absf(other.altitude-leader.altitude)>1.5:continue
        if ranch.display_style=="3D residents" and not other.asset:continue
        var fits:=true
        for peer in peers:
            var ratio:float=other.pose_box.size.length()/maxf(.01,light_residents[peer].pose_box.size.length())
            if ratio<.625 or ratio>1.6:fits=false;break
        if not fits:continue
        peers.append(other.slot)
        if peers.size()==goal:break
    if peers.size()<2:return false
    if longest_navigation_edge<=0:
        for node in range(ranch.land.points.size()):
            for next in ranch.land.navigation.get_point_connections(node):
                longest_navigation_edge=maxf(longest_navigation_edge,ranch.land.points[node].distance_to(ranch.land.points[next]))
    var pace:float=leader.speed
    for id in peers:pace=minf(pace,light_residents[id].speed)
    var parade_capable:bool=peers.size()==3 and not leader.swimming and peers.all(func(id):return walk_clips.has(light_residents[id].asset.get("key","")))
    var travel_allowance:float=longest_navigation_edge/maxf(.1,pace)*(4. if parade_capable else 2.)
    var play_allowance:float=6.*peers.size()+8.
    for id in peers:
        var actor=light_residents[id]
        var play_length:float=activity_durations.get(actor.asset.get("key",""),{}).get("Play",0.)
        play_allowance=maxf(play_allowance,(play_length+.45)*peers.size()*2.)
    if not ranch.cycle.can_start_activity(12.+travel_allowance+play_allowance):return false
    var g={"members":peers,"phase":"Greeting","time":3.5,"steps":0,"pace":pace}
    # Reserve a legal first step before greeting so a meeting never starts
    # in a pocket where its members cannot walk together.
    g["parade"]=peers.size()==3 and not leader.swimming and peers.all(func(id):return walk_clips.has(light_residents[id].asset.get("key","")))
    if g.parade:
        # Recruitment finds two neighbors of the recruiter, so the recruiter
        # is already the middle link of a connected three-resident trail.
        g.members=[peers[1],leader.slot,peers[2]]
        if not step_in_line(ranch,g):
            g.members.reverse()
            if not step_in_line(ranch,g):
                g.parade=false;g.members=peers
    if not g.parade and not step_together(ranch,g):
        if peers.size()<3:return false
        peers.pop_back()
        if not step_together(ranch,g):return false
    g.phase="Greeting"
    groups.append(g)
    for id in peers:
        light_residents[id].group=g
        g.pace=minf(g.pace,light_residents[id].speed)
    return true

func step_in_line(ranch,g)->bool:
    var head=light_residents[g.members[0]]
    var middle=light_residents[g.members[1]]
    var points:PackedVector2Array=ranch.land.points
    var forward:Vector2=(points[head.here]-points[middle.here]).normalized()
    var best:=-INF
    var goal:=-1
    for node in ranch.land.navigation.get_point_connections(head.here):
        if occupied.has(node):continue
        var dir:Vector2=(points[node]-points[head.here]).normalized()
        var score:=forward.dot(dir)+float(ranch.rng.randf_range(0,.35))
        if score>best:goal=node;best=score
    if goal<0:return false
    var targets:=[goal,head.here,middle.here]
    var longest:=0.0
    for i in targets.size():
        var id:int=g.members[i]
        var length:=points[light_residents[id].here].distance_to(points[targets[i]])
        longest=maxf(longest,length)
        destinations[id]=targets[i];occupied[targets[i]]=id
    g["line_length"]=longest
    g.steps+=1;g.phase="Parade"
    return true

func step_together(ranch,g)->bool:
    if g.get("parade",false):return step_in_line(ranch,g)
    var leader=light_residents[g.members[0]]
    var neighbors:PackedInt64Array=ranch.land.navigation.get_point_connections(leader.here)
    var start:int=ranch.rng.randi_range(0,neighbors.size()-1)
    for j in neighbors.size():
        var shift:Vector2=ranch.land.points[neighbors[(start+j)%neighbors.size()]]-ranch.land.points[leader.here]
        var targets:Array=[]
        for id in g.members:
            var r=light_residents[id]
            var best:=-1
            var error:=INF
            for node in ranch.land.navigation.get_point_connections(r.here):
                if occupied.has(node) or targets.has(node):continue
                var delta:Vector2=ranch.land.points[node]-ranch.land.points[r.here]
                if delta.dot(shift)<=0:continue
                if targets.is_empty() and delta.distance_squared_to(shift)>.01:continue
                if not targets.is_empty() and ranch.land.points[node].distance_to(ranch.land.points[targets[0]])>6.5*ranch.land.MAP_SCALE/2.2:continue
                var distance:=delta.distance_squared_to(shift)
                if distance<error:best=node;error=distance
            if best<0:break
            targets.append(best)
        if targets.size()!=g.members.size():continue
        for i in targets.size():
            var id:int=g.members[i];destinations[id]=targets[i];occupied[targets[i]]=id
        g.steps+=1;g.phase="Parade" if g.get("parade",false) else "Strolling together"
        return true
    return false

func socialize(ranch,dt:float):
    social_clock+=dt;recruitment_delay-=dt
    if ranch.cycle.can_start_activity(25.) and recruitment_delay<=0 and not ranch.tour.is_empty():
        recruitment_delay=ranch.rng.randf_range(2,4)
        if groups.size()<clampi(light_residents.size()/20,1,16):
            var focus=ranch.herd[ranch.tour[ranch.tour_index]]
            if ranch.shot_time>ranch.DWELL-4 and ranch.tour_index%3==0:
                try_group(ranch,ranch.herd[ranch.tour[ranch.tour_index+1]])
            elif ranch.rng.randf()<.5:
                if not try_group(ranch,focus):
                    try_group(ranch,ranch.herd[ranch.tour[ranch.tour_index+1]])
            # A large pasture has many residents in transit; sample more candidates
            # at the existing recruitment interval without increasing the group cap.
            for attempt in mini(128,light_residents.size()):
                if try_group(ranch,light_residents[ranch.rng.randi_range(0,light_residents.size()-1)]):break
    for g in groups.duplicate():
        var traveling:=false
        var center:=Vector3.ZERO
        for id in g.members:
            center+=light_residents[id].body.position
            if destinations[id]>=0:traveling=true
        if traveling and g.phase!="Greeting":continue
        center/=float(g.members.size())
        for id in g.members:
            var r=light_residents[id];var dir:Vector3=center-r.body.position
            if g.has("ball"):continue
            if g.has("turn") and id in g.players:
                dir=light_residents[g.players[(g.players.find(id)+1)%g.players.size()]].body.position-r.body.position
            r.body.rotation.y=rotate_toward(r.body.rotation.y,atan2(dir.x,dir.z)-r.facing_bias,dt*3.0)
        if g.has("ball"):
            advance_ball(ranch,g,dt)
        g.time-=dt
        if g.has("turn") and g.time<=0 and g.turn<g.players.size()*2-1 and not ranch.cycle.night:
            var a=light_residents[g.players[g.turn%g.players.size()]];var b=light_residents[g.players[(g.turn+1)%g.players.size()]]
            if a.player and b.player:
                a.player.play("Idle",.18);b.player.play("Play",.18);g.turn+=1
                g.time=b.player.get_animation("Play").length+.45
        if g.time>0:continue
        if g.phase=="Greeting":
            if g.get("camera_gather_until",0.)>social_clock and ranch.pending_activity==g and not ranch.activity_ready(g.members):
                g.time=.1;continue
            g.phase="Parade" if g.get("parade",false) else "Strolling together"
            if g.phase=="Parade" and "--activity-test" in OS.get_cmdline_user_args():print("AUTO PARADE ",g.members)
            continue
        if g.phase!="Playing" and g.steps<(4 if g.get("parade",false) else 2) and step_together(ranch,g):continue
        if g.phase!="Playing":
            g.phase="Playing";g.time=ranch.rng.randf_range(4,7)
            var players:Array=g.members
            if not ranch.cycle.night and players.all(func(id):return eligible(light_residents[id])):
                var ball:=MeshInstance3D.new();var mesh:=SphereMesh.new()
                mesh.radius=BALL_RADIUS;mesh.height=BALL_RADIUS*2;mesh.radial_segments=12;mesh.rings=6
                var paint:=StandardMaterial3D.new();paint.albedo_color=Color("#e69746");mesh.material=paint
                ball.mesh=mesh;ranch.add_child(ball)
                # Aim each player at its next receiver before the first pass. The ball
                # arrives at the same contact point from which the next pass starts.
                for i in players.size():
                    var sender=light_residents[players[i]]
                    var receiver=light_residents[players[(i+1)%players.size()]]
                    var direction:Vector3=receiver.body.position-sender.body.position
                    sender.body.rotation.y=atan2(direction.x,direction.z)
                ball.position=waiting_ball(light_residents[players[0]]);g["players"]=players
                g["ball"]=ball;g["pass"]=0;g["flight"]=-1.0;g["wait"]=0.0;g.time=6.0*players.size()
                if "--activity-test" in OS.get_cmdline_user_args():print("AUTO BALL ",g.players)
            elif not ranch.cycle.night:
                var partners:Array=g.members.filter(func(id):return light_residents[id].player and light_residents[id].player.has_animation("Play"))
                if partners.size()==g.members.size():
                    g.players=partners;g.turn=0
                    g.time=light_residents[partners[0]].player.get_animation("Play").length+.45
            for id in g.members:
                var r=light_residents[id]
                if r.player:
                    r.player.play(play_phase_clip(r,g),.12)
                    r.player.speed_scale=1
        else:
            for id in g.members:
                var r=light_residents[id];r.group={};r.stroll_edges=0;r.walking=false;r.rest=meadow_pause(wander_rng)
                r.social_after=social_clock+ranch.rng.randf_range(30,75)
                if r.player:r.player.play("Idle",.2)
            if g.has("ball"):g.ball.queue_free()
            groups.erase(g)

func advance_ball(ranch,g,dt:float):
    var a=light_residents[g.players[g["pass"]%g.players.size()]]
    var b=light_residents[g.players[(g["pass"]+1)%g.players.size()]]
    if not g.players.all(func(id):return eligible(light_residents[id])):
        g.time=0;return
    var start:Vector3=a.body.position;var end:Vector3=b.body.position
    var axis:Vector3=(end-start).normalized()
    start=waiting_ball(a);end=waiting_ball(b)
    if (end-start).dot(axis)<BALL_RADIUS*2:
        g.time=0;return
    var ball:MeshInstance3D=g.ball
    if g.flight<0:
        g.wait+=dt
        ball.position=start
        var clip:Animation=a.player.get_animation(ball_clip(a))
        var tip=contact_tip(a)
        if tip==null or a.player.current_animation!=ball_clip(a) or g.wait>clip.length+.25:
            g.time=0;return
        var previous:Vector3=g.get("previous_tip",tip)
        g.previous_tip=tip
        var nearest:Vector3=tip if previous.is_equal_approx(tip) else Geometry3D.get_closest_point_to_segment(start,previous,tip)
        if nearest.distance_to(start)>BALL_RADIUS or (tip-previous).dot(start-previous)<=0:return
        g.flight=0.0
        if "--activity-test" in OS.get_cmdline_user_args():
            print("PASS RELEASE ",a.title," phase=",a.player.current_animation_position/clip.length)
            ranch.capture_activity("release-"+str(g["pass"]))
    g.flight+=dt
    var t:=minf(1,g.flight/clampf(start.distance_to(end)/3,.45,1.4))
    ball.position=start.lerp(end,smoothstep(0,1,t));ball.rotate_x(dt*4)
    if t>=1:
        if g["pass"]+1>=g.players.size():g.time=0;return
        a.player.play("Idle",.12);b.player.play(ball_clip(b),.12);b.player.seek(0,true)
        g["pass"]+=1;g.flight=-1.0;g.wait=0.0;g.erase("previous_tip")

func meadow_pause(rng:RandomNumberGenerator)->float:
    # Short looks are common; a few residents linger over the view.
    return rng.randf_range(18.,32.) if rng.randf()<.25 else rng.randf_range(7.,16.)

func available_ambient(r)->Array[String]:
    if not r.player:return []
    var choices:Array[String]=[]
    for clip in ["IdleAction","IdleAlt","Look","Stretch","Rest","Happy","Grumpy","Lonely","Call"]:
        if r.player.has_animation(clip):choices.append(clip)
    var asset_key:String=r.asset.get("key","") if r.asset else ""
    for clip in ambient_clips.get(asset_key,[]):
        if r.player.has_animation(clip) and not choices.has(clip):choices.append(clip)
    return choices

func ambient_duration(r,sequence:Array[String])->float:
    var duration:=0.0
    for clip in sequence:
        if r.player.has_animation(clip):duration+=r.player.get_animation(clip).length
    return duration

func has_nearby_company(r)->bool:
    for other in light_residents:
        if other==r or other.body==null or other.resting_at_night:continue
        if other.home_zone==r.home_zone and other.body.position.distance_squared_to(r.body.position)<144.:return true
    return false

func start_ambient(ranch,r)->bool:
    var choices:=available_ambient(r)
    if choices.is_empty() or wander_rng.randf()>.48:return false
    var asset_key:String=r.asset.get("key","") if r.asset else ""
    var extra:Array[String]=[]
    for candidate in ambient_clips.get(asset_key,[]):extra.append(str(candidate))
    var clip:String=ActivityPolicy.choose(r.player,asset_key,r.last_ambient_clip,extra,has_nearby_company(r),wander_rng)
    if clip.is_empty():return false
    r.ambient_sequence.clear()
    r.ambient_sequence.append(clip)
    if clip=="Rest" and r.player.has_animation("RestStart") and r.player.has_animation("RestEnd"):
        r.ambient_sequence.clear()
        r.ambient_sequence.append("RestStart")
        r.ambient_sequence.append("Rest")
        r.ambient_sequence.append("RestEnd")
        clip="RestStart"
    if not ranch.cycle.can_start_activity(ambient_duration(r,r.ambient_sequence)+2.):
        r.ambient_sequence.clear()
        return false
    r.ambient_index=0
    var animation:Animation=r.player.get_animation(clip)
    animation.loop_mode=Animation.LOOP_NONE
    r.ambient_clip=clip;r.last_ambient_clip=r.ambient_sequence[0];r.ambient_active=true;r.walking=false
    r.player.play(clip,.28)
    return true

func advance_ambient_sequence(r)->bool:
    if r.ambient_sequence.is_empty() or r.ambient_index+1>=r.ambient_sequence.size():return false
    r.ambient_index+=1
    r.ambient_clip=r.ambient_sequence[r.ambient_index]
    var animation:Animation=r.player.get_animation(r.ambient_clip)
    # Rest is a source loop, but one complete cycle gives daytime variety
    # without trapping the resident in the settled pose indefinitely.
    animation.loop_mode=Animation.LOOP_NONE
    r.player.play(r.ambient_clip,.18)
    return true

func finish_ambient(r):
    r.ambient_active=false;r.ambient_clip="";r.ambient_sequence.clear();r.ambient_index=0
    r.rest=wander_rng.randf_range(4.,11.)
    if r.player:r.player.play("Idle",.3)

func animation_finished(r,clip:String)->bool:
    if not r.player or r.player.current_animation!=clip or not r.player.is_playing():return true
    return r.player.current_animation_position>=r.player.current_animation_length-.04

func enter_sleep_loop(ranch,r):
    r.sleep_stage=2
    if not r.player:return
    var clip:String=ranch.night_clips.get(r.asset.get("key",""),"Idle")
    ranch.set_rest_eyes(r,true)
    r.player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
    r.player.play(clip,.28)

func begin_night_rest(ranch,r):
    r.resting_at_night=true;r.walking=false;r.stroll_edges=0
    if not r.player:
        r.sleep_stage=2
        return
    ranch.set_rest_eyes(r,false)
    if r.player.has_animation("SleepStart"):
        r.sleep_stage=1
        r.player.get_animation("SleepStart").loop_mode=Animation.LOOP_NONE
        r.player.play("SleepStart",.35)
    else:enter_sleep_loop(ranch,r)

func begin_waking(ranch,r):
    if not r.player:
        r.resting_at_night=false;r.sleep_stage=0;r.rest=meadow_pause(wander_rng)
        return
    ranch.set_rest_eyes(r,false)
    if r.player.has_animation("SleepEnd"):
        r.sleep_stage=3
        r.player.get_animation("SleepEnd").loop_mode=Animation.LOOP_NONE
        r.player.play("SleepEnd",.35)
    else:
        r.resting_at_night=false;r.sleep_stage=0;r.rest=meadow_pause(wander_rng)
        r.player.play("Idle",.45)

func finish_waking(ranch,r):
    r.resting_at_night=false;r.sleep_stage=0;r.rest=meadow_pause(wander_rng)
    if r.player:
        ranch.set_rest_eyes(r,false)
        r.player.play("Idle",.38)

func apply_locomotion_rate(r):
    if not r.player or not r.walking:return
    if not r.player.has_animation(r.move_clip):r.move_clip="Walk"
    var animation:Animation=r.player.get_animation(r.move_clip)
    var stride_length:=clampf(r.radius*(1.15 if r.move_clip=="Run" else .78),.28,1.55)
    var ground_speed:float=float(r.group.get("pace",r.speed)) if not r.group.is_empty() else r.speed
    r.player.speed_scale=clampf(animation.length*ground_speed/stride_length,.62,1.65)
    if r.player.current_animation!=r.move_clip:r.player.play(r.move_clip,.22)

func set_wandering(r,walking:bool):
    if r.walking==walking:return
    if walking:
        r.ambient_active=false;r.ambient_clip=""
        if not r.swimming:
            r.move_clip="Walk"
            # Run remains uncommon: only quicker solitary residents on a
            # multi-edge stroll may use it. Events and parades stay on Walk so
            # their synchronized spacing is not disturbed.
            if r.player and r.group.is_empty() and r.stroll_edges>=2 and r.speed>=1.02 and r.player.has_animation("Run") and wander_rng.randf()<.28:
                r.move_clip="Run"
    r.walking=walking
    if r.player:
        if not walking:r.player.speed_scale=1.
        r.player.play(r.move_clip if walking else "Idle",.28)
        if walking:apply_locomotion_rate(r)

func start_native_turn(r,heading:float)->bool:
    if not r.player or r.walking or r.swimming or not r.group.is_empty():return false
    var difference:=wrapf(heading-r.body.rotation.y,-PI,PI)
    # Native clips are quarter-turns. Smaller corrections blend naturally into
    # walking; near reversals continue using the existing gradual body turn.
    if absf(difference)<deg_to_rad(48.) or absf(difference)>deg_to_rad(132.):return false
    var clip:="TurnRight" if difference>0 else "TurnLeft"
    if not r.player.has_animation(clip):return false
    r.turning=true;r.turn_clip=clip;r.turn_target=heading
    r.player.speed_scale=clampf(r.player.get_animation(clip).length/.72,.72,1.4)
    r.player.get_animation(clip).loop_mode=Animation.LOOP_NONE
    r.player.play(clip,.18)
    return true

func advance_native_turn(r)->bool:
    if not r.turning:return false
    if not r.player or r.player.current_animation!=r.turn_clip or not r.player.is_playing() or r.player.current_animation_position>=r.player.current_animation_length-.035:
        r.body.rotation.y=r.turn_target
        r.turning=false;r.turn_clip=""
        if r.player:r.player.speed_scale=1.
        return false
    return true

func start_meal(ranch,r):
    var duration:float=5.
    for clip in ["EatStart","Eat","EatEnd"]:duration+=r.player.get_animation(clip).length
    if not ranch.cycle.can_start_activity(duration):return
    r.dinner_day=-1
    r.meal=preload("res://berry_dish.gd").serve(r,ranch.land)
    r.meal_stage=0;r.player.play("EatStart",.15);r.meal_time=r.player.get_animation("EatStart").length

func dinner_pose(ranch,r):
    if r.dinner_day<0 and r.meal:
        r.meal.queue_free();r.meal=null
    r.dinner_day=ranch.cycle.day_number;r.stroll_edges=0
    if not supper.seats.has(r):r.walking=false
    if not r.player:return
    if not (r.player.has_animation("EatStart") and r.player.has_animation("Eat") and r.player.has_animation("EatEnd")):
        if r.player.current_animation!="Idle":r.player.play("Idle",.2)
        return
    if not r.meal and r.dinner_day>=0 and not supper.seats.has(r):
        supper.try_seat(ranch,r)
    var shared:Dictionary=supper.seats.get(r,{})
    if not shared.is_empty() and not shared.ready:return
    var elapsed:float=ranch.cycle.meal_elapsed-shared.get("started",0.)
    var intro:float=r.player.get_animation("EatStart").length
    var outro:float=r.player.get_animation("EatEnd").length
    var left:float=ranch.cycle.meal_remaining
    var stage:=3 if left<=.35 else (2 if left<=outro+.35 else (0 if elapsed<intro else 1))
    if not r.meal:
        if stage==3:
            if r.player.current_animation!="Idle":r.player.play("Idle",.15)
            return
        if shared.is_empty():r.meal=preload("res://berry_dish.gd").serve(r,ranch.land)
        else:
            r.meal=Node3D.new()
            r.body.add_child(r.meal)
        r.meal_stage=-1
    if r.meal_stage==stage:return
    r.meal_stage=stage;r.player.speed_scale=1.
    if stage>=2:
        for i in range(2,r.meal.get_child_count()):r.meal.get_child(i).hide()
    if stage==3:
        r.meal.queue_free();r.meal=null;r.player.play("Idle",.15);return
    var clip:String=["EatStart","Eat","EatEnd"][stage]
    var length:float=r.player.get_animation(clip).length
    r.player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR if stage==1 else Animation.LOOP_NONE
    r.player.play(clip,.12)
    var position:float=[elapsed,fposmod(maxf(0.,elapsed-intro),maxf(.01,length)),outro+.35-left][stage]
    r.player.seek(clampf(position,0.,length),true)

func advance(ranch,dt:float):
    supper.advance(ranch,dt)
    socialize(ranch,dt)
    for i in light_residents.size():
        var r=light_residents[i]
        if r.ambient_active and (ranch.cycle.mealtime or ranch.cycle.night or not r.group.is_empty()):
            finish_ambient(r)
        if r.ambient_active:
            if not r.player:
                r.ambient_active=false;r.ambient_clip="";r.ambient_sequence.clear();r.ambient_index=0
            elif r.player.current_animation!=r.ambient_clip:
                finish_ambient(r)
            elif not r.player.is_playing() or r.player.current_animation_position>=r.player.current_animation_length-.04:
                if not advance_ambient_sequence(r):finish_ambient(r)
            else:
                continue
        if ranch.cycle.mealtime:
            dinner_pose(ranch,r)
            continue
        if r.meal and (ranch.cycle.night or r.dinner_day>=0):
            r.meal.queue_free();r.meal=null
            if r.player:r.player.play("Idle",.15)
        if r.meal:
            if r.player:
                r.meal_time-=dt
                if r.meal_time>0:continue
                r.meal_stage+=1
                if r.meal_stage<3:
                    var clip:String=["EatStart","Eat","EatEnd"][r.meal_stage]
                    r.player.play(clip,.12);r.meal_time=r.player.get_animation(clip).length
                    if r.meal_stage==2:
                        for j in range(2,r.meal.get_child_count()):r.meal.get_child(j).hide()
                    continue
            r.meal.queue_free();r.meal=null
            if r.player:r.player.play("Idle",.2)
        var bedtime_now:bool=ranch.cycle.night or (r.resting_at_night and ranch.cycle.phase_seconds<ranch.cycle.phase_length/14.*r.morning_time)
        if ranch.cycle.can_start_activity(25.) and r.player and r.group.is_empty() and not r.swimming and not r.resting_at_night and destinations[i]<0 and r.rest>4 and social_clock>=r.meal_after:
            r.meal_after=social_clock+wander_rng.randf_range(30.,90.)
            if wander_rng.randf()<.32 and r.player.has_animation("EatStart") and r.player.has_animation("Eat") and r.player.has_animation("EatEnd"):
                start_meal(ranch,r)
                continue
        if bedtime_now and r.group.is_empty() and (destinations[i]<0 or r.dinner_day>=0):
            if not r.resting_at_night:
                begin_night_rest(ranch,r)
            elif r.sleep_stage==1 and animation_finished(r,"SleepStart"):
                enter_sleep_loop(ranch,r)
            continue
        if r.resting_at_night:
            if r.sleep_stage!=3:
                begin_waking(ranch,r)
                if r.resting_at_night:continue
            elif not animation_finished(r,"SleepEnd"):continue
            else:finish_waking(ranch,r)
        if r.stationary:continue
        if r.group.get("phase","")=="Greeting":continue
        if destinations[i]>=0 and not r.group and not r.walking and r.rest>0:
            r.rest-=dt
            if r.rest>0:continue
            r.stroll_left=wander_rng.randf_range(7.,15.)
            r.stroll_edges=wander_rng.randi_range(1,3)
        if destinations[i]<0:
            if r.group:continue
            r.rest-=dt
            if r.rest>0:continue
            if not r.swimming and start_ambient(ranch,r):continue
            var neighbors:PackedInt64Array=ranch.land.navigation.get_point_connections(r.here)
            if not neighbors.is_empty():
                var start=ranch.rng.randi_range(0,neighbors.size()-1)
                var choice:=-1
                var best:=-INF
                var forward:=Vector2(sin(r.body.rotation.y),cos(r.body.rotation.y))
                for j in neighbors.size():
                    var node:int=neighbors[(start+j)%neighbors.size()]
                    if occupied.has(node):continue
                    if not r.swimming and ranch.land.zones[node]!=r.home_zone:
                        var center:Vector2=ranch.land.Shape.CENTERS[r.home_zone]*ranch.land.Shape.UNIT
                        if ranch.land.zones[r.here]==r.home_zone or ranch.land.points[node].distance_squared_to(center)>=ranch.land.points[r.here].distance_squared_to(center):continue
                    if not r.swimming and r.stroll_edges==0:
                        choice=node;break
                    var direction:Vector2=(ranch.land.points[node]-ranch.land.points[r.here]).normalized()
                    var score: float =forward.dot(direction)+ranch.rng.randf_range(0,1.4)
                    if score>best:choice=node;best=score
                if choice>=0:destinations[i]=choice;occupied[choice]=i
            if destinations[i]<0:
                set_wandering(r,false);r.stroll_edges=0;r.rest=ranch.rng.randf_range(2.,5.)
                continue
            if r.stroll_edges==0:
                r.stroll_edges=wander_rng.randi_range(1,3)
                r.stroll_left=wander_rng.randf_range(7.,15.)
        var dest:Vector2=ranch.land.points[destinations[i]]
        var pos:=Vector2(r.body.position.x,r.body.position.z)
        var delta:=dest-pos
        var stride:float=(r.speed if not r.group else float(r.group.pace))*dt
        if r.group.get("parade",false):
            # Finish the three connected edges together even when their lengths differ.
            stride*=ranch.land.points[r.here].distance_to(dest)/float(r.group.line_length)
        if delta.length_squared()>.000001:
            var heading:=atan2(delta.x,delta.y)
            if advance_native_turn(r):continue
            if start_native_turn(r,heading):continue
            r.body.rotation.y=rotate_toward(r.body.rotation.y,heading,dt*3.0)
            if r.swimming:
                # Turn first on sharp reversals, then accelerate in the new direction.
                stride*=smoothstep(.5,1.0,cos(heading-r.body.rotation.y))
        var next:=pos.move_toward(dest,stride)
        var arrived:=next.is_equal_approx(dest)
        if arrived and not r.group:r.stroll_edges=maxi(0,r.stroll_edges-1)
        set_wandering(r,not arrived or (not r.group and r.stroll_edges>0))
        if r.walking:apply_locomotion_rate(r)
        r.body.position=Vector3(next.x,r.altitude+ranch.land.ground(next,r.swimming),next.y)
        r.traveled+=pos.distance_to(next)
        if arrived:
            if occupied.get(r.here,-1)==i:occupied.erase(r.here)
            r.here=destinations[i];destinations[i]=-1;r.trips+=1
            r.rest=meadow_pause(wander_rng) if not r.group and r.stroll_edges==0 else 0.
            place(i,r,0)
        else:place(i,r,.035*abs(sin(r.traveled*5)))
        if not r.group and r.walking:
            r.stroll_left-=dt
            if r.stroll_left<=0:
                set_wandering(r,false);r.stroll_edges=0;r.rest=meadow_pause(wander_rng)
