extends Node
const DAY=["Flower field","Living forest","Under a sycamore","Where the wind blows us","Wandering soul","Forever","Returning home"]
const NIGHT=["Falling to silence","Falling leaves","Always"]
var night:=false
var playlist:Array=[]
var previous_orders:Dictionary={}
var index:=0
var elapsed:=0.0
var seconds:Dictionary
signal dinner_started
signal lunch_started
signal breakfast_started
const BREAKFAST_FRACTION:=1.0/14.0 # 8 AM, after the last residents wake.
var breakfast_announced:=false
var breakfast:bool:
    get:return not night and phase_seconds>=phase_length*BREAKFAST_FRACTION and phase_seconds<phase_length*BREAKFAST_FRACTION+LUNCH_SECONDS and not dinner
const LUNCH_SECONDS:=90.
const LUNCH_FRACTION:=5.0/14.0 # Noon in the 7 AM to 9 PM daytime playlist.
var lunch_announced:=false
var lunch:bool:
    get:return not night and phase_seconds>=phase_length*LUNCH_FRACTION and phase_seconds<phase_length*LUNCH_FRACTION+LUNCH_SECONDS and not dinner
var mealtime:bool:
    get:return dinner or lunch or breakfast
var meal_elapsed:float:
    get:return phase_seconds-phase_length*BREAKFAST_FRACTION if breakfast else (phase_seconds-phase_length*LUNCH_FRACTION if lunch else elapsed)
var meal_remaining:float:
    get:return phase_length*BREAKFAST_FRACTION+LUNCH_SECONDS-phase_seconds if breakfast else (phase_length*LUNCH_FRACTION+LUNCH_SECONDS-phase_seconds if lunch else remaining)

var bell:=AudioStreamPlayer.new()
var music_enabled:=true
var dinner:bool:
    get:return not night and not playlist.is_empty() and index==playlist.size()-1
var audio:=AudioStreamPlayer.new()
var sun:DirectionalLight3D
var moon:=DirectionalLight3D.new()
var sky:Environment
var daylight:=1.0
var phase_seconds:=0.
var remaining:=0.
var phase_length:=1.
var day_number:=0
var sun_disc:MeshInstance3D
var moon_disc:MeshInstance3D

func clock_hour()->float:
    var fraction:=clampf(phase_seconds/maxf(1.,phase_length),0.,1.)
    return fposmod((21. if night else 7.)+fraction*(10. if night else 14.),24.)

func clock_minutes()->int:
    return floori(clock_hour()*60.+.00001)%1440

static func daylight_at(hour:float)->float:
    if hour>=6. and hour<8.:return smoothstep(6.,8.,hour)
    if hour>=20. and hour<22.:return 1.-smoothstep(20.,22.,hour)
    return 1. if hour>=8. and hour<20. else 0.

func time_until_meal()->float:
    if night or playlist.is_empty() or mealtime:return 0.
    var dinner_at:float=phase_length-float(seconds[playlist[-1]])
    var next_at:float=phase_length*LUNCH_FRACTION if phase_seconds<phase_length*LUNCH_FRACTION else dinner_at
    if phase_seconds<phase_length*BREAKFAST_FRACTION:next_at=phase_length*BREAKFAST_FRACTION
    return maxf(0.,minf(next_at,dinner_at)-phase_seconds)

func can_start_activity(duration:float=160.)->bool:
    return not night and not mealtime and time_until_meal()>duration

func disc(color:Color,radius:float)->MeshInstance3D:
    var node:=MeshInstance3D.new();var sphere:=SphereMesh.new()
    sphere.radius=radius;sphere.height=radius*2.;sphere.radial_segments=24;sphere.rings=12
    var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color=color;sphere.material=m;node.mesh=sphere
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
    return node

func setup(env:Environment,day_sun:DirectionalLight3D):
    sky=env;sun=day_sun
    moon.rotation_degrees=Vector3(-48,125,0)
    moon.light_color=Color("#bed6ff")
    moon.light_energy=0
    add_child(moon);add_child(audio);add_child(bell)
    bell.stream=AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://map/dinner-bell.ogg"));bell.volume_db=-7
    seconds=JSON.parse_string(FileAccess.get_file_as_string("res://map/music.json"))
    audio.volume_db=-12
    sun_disc=disc(Color("#ffe8ac"),12.);moon_disc=disc(Color("#e0eaff"),9.)
    shuffle_phase()
    start_track();update_light()

func shuffle_phase():
    playlist=(NIGHT if night else DAY).duplicate()
    playlist.shuffle()
    var previous:Array=previous_orders.get(night,[])
    if playlist.size()>1 and not previous.is_empty() and playlist[0]==previous[0]:
        var other:=randi_range(1,playlist.size()-1)
        var first=playlist[0]
        playlist[0]=playlist[other]
        playlist[other]=first
    previous_orders[night]=playlist
    phase_length=0.
    for title in playlist:phase_length+=float(seconds[title])
    if not night:
        day_number+=1
        lunch_announced=false
        breakfast_announced=false

func skip_to_phase(to_night:bool):
    night=to_night
    index=0
    shuffle_phase()
    start_track()
    elapsed=minf(float(seconds[playlist[0]])*.85,phase_length*(.19 if night else .10))
    if audio.playing:audio.seek(elapsed)
    update_light()

func start_track():
    var title:String=playlist[index]
    var bytes:=FileAccess.get_file_as_bytes("res://map/"+title+".ogg")
    if not bytes.is_empty():
        audio.stream=AudioStreamOggVorbis.load_from_buffer(bytes)
        if audio.stream and music_enabled:audio.play()
    elapsed=0
    if dinner:
        bell.play();dinner_started.emit()
    elif bell.playing:bell.stop()

func set_music_enabled(enabled:bool):
    music_enabled=enabled
    if music_enabled:
        if audio.stream:
            audio.play(maxf(0.,elapsed))
    else:
        audio.stop()

func tick(dt:float,held:bool):
    audio.stream_paused=held;bell.stream_paused=held
    if held:return
    if music_enabled and audio.playing:
        elapsed=maxf(elapsed,audio.get_playback_position()+AudioServer.get_time_since_last_mix())
    else:
        elapsed+=dt
    if elapsed>=float(seconds[playlist[index]])-.1:
        index+=1
        if index>=playlist.size():
            index=0;night=not night
            shuffle_phase()
        start_track()
    update_light()
    if breakfast and not breakfast_announced:
        breakfast_announced=true
        bell.play()
        breakfast_started.emit()
    if lunch and not lunch_announced:
        lunch_announced=true
        bell.play()
        lunch_started.emit()

func update_light():
    phase_seconds=elapsed
    for i in index:phase_seconds+=float(seconds[playlist[i]])
    remaining=maxf(0.,phase_length-phase_seconds)
    var fraction:=clampf(phase_seconds/phase_length,0.,1.)
    var angle:float=PI*(fraction+(1. if night else 0.))
    var direction:=Vector3(cos(angle),sin(angle)*.83,sin(angle)*.48).normalized()
    sun_disc.position=direction*570.;moon_disc.position=-direction*570.
    sun_disc.visible=direction.y>-.025;moon_disc.visible=direction.y<.025
    sun.look_at(sun.global_position-direction,Vector3.UP)
    moon.look_at(moon.global_position+direction,Vector3.UP)
    daylight=daylight_at(clock_hour())
    var warmth:=1.-absf(daylight*2.-1.)
    sun.light_color=Color.WHITE.lerp(Color("#ffb17c"),warmth)
    sun.light_energy=.78*daylight;moon.light_energy=.48*(1.-daylight)
    var night_top:=Color("#172745")
    var day_top:=Color("#73a9d5")
    var night_horizon:=Color("#667895")
    var day_horizon:=Color("#dcebd4")
    var dusk:=Color("#e5a18d")
    if sky.sky and sky.sky.sky_material is ProceduralSkyMaterial:
        var material:=sky.sky.sky_material as ProceduralSkyMaterial
        material.sky_top_color=night_top.lerp(day_top,daylight).lerp(Color("#7c6285"),warmth*.38)
        material.sky_horizon_color=night_horizon.lerp(day_horizon,daylight).lerp(dusk,warmth*.72)
        material.ground_bottom_color=Color("#182638").lerp(Color("#516747"),daylight)
        material.ground_horizon_color=Color("#536477").lerp(Color("#b8cda4"),daylight).lerp(Color("#b47770"),warmth*.45)
    sky.background_color=Color("#435679").lerp(Color("#cee0d6"),daylight).lerp(dusk,warmth*.72)
    sky.ambient_light_color=Color("#c4d7f4").lerp(Color.WHITE,daylight)
    sky.ambient_light_energy=lerpf(.48,.43,daylight)
    sky.fog_light_color=Color("#536477").lerp(Color("#dbe5d2"),daylight).lerp(Color("#d9a08e"),warmth*.45)
    sky.fog_light_energy=lerpf(.34,.55,daylight)
