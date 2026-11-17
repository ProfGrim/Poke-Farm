extends Node3D

const Landscape=preload("res://biome_land.gd")
const DWELL=16.0
const MIN_VISIBLE_SHOT:=7.0
var settled_watch:=0.0
var portrait_age:=0.0
# Events are simulated across the whole pasture, so discovery must reach beyond
# the current portrait. Only a short ranked queue is retained; the selected
# group is then preloaded inside the existing model budget while the current
# resident finishes its minimum visible shot.
const EVENT_PICKUP_RADIUS:=72.0
const EVENT_CANDIDATE_LIMIT:=4
var pending_activity:Dictionary={}
var pending_activity_age:=0.0
var event_candidates:Array=[]
var event_scan_left:=0.0
var event_stats:Dictionary={"reservations":0,"featured":0,"expired":0,"warmup_seconds":0.0}
var event_yaw:=0.0
var activity_watch:=0.0
var activity_age:=0.0
var activity_ended:=false
var activity_end_hold:=0.0
var requested_next:=false
const RECORD_FADE:=.45
const PAN=3.5
const LONG_CUT=.8
var preparing_shot:=true
var setup_elapsed:=0.0
var neighbors_waiting:=false
var distant_pair:=false
var cut_overlay:=ColorRect.new()
const CELL_SIZE=2.5
var land=Landscape.new()
var population=preload("res://full_population.gd").new()
# Fish whose native locomotion depicts swimming. Pond routing is opt-in per species.
# Residents whose ranch locomotion is aquatic. Amphibious walkers stay on land.
const POND_SPECIES=[72,73,86,87,90,91,116,117,118,119,129,130,131,170,171,211,223,226,230,318,319,320,321,339,340,349,350,366,367,368,369,370,382,456,457,458,489,490,550,592,593,594,690,691,692,693,746,779,846,847,902,904,963,964,976,977]

var loader:=preload("res://model_loader.gd").new()
var loading_path:=""
var loading_key:=""
var retry_after:Dictionary={}
var load_attempts:Dictionary={}
var staged:Dictionary={}
const LIMITS=[50,100,200,500,1000,0]
const STYLES=["Mixed","3D residents","Shiny sprites"]
const MODEL_LIMITS=[4,8,12,24]
var regular_materials:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://map/regular-materials.json"))
var model_budget:=8
var budget_ui:=OptionButton.new()
var warm_view:SubViewport
var warm_camera:Camera3D
var warming:=false
var stream_wait:=0.0
var display_config:=ConfigFile.new()
var display_limit:int=100
static var session_style:String=""
var display_style:String="3D residents"
var start_3d:=true
var allow_f:=false
var start_option:=CheckBox.new()
var shortcut_option:=CheckBox.new()
var dinner_banner=preload("res://dinner_banner.gd").new()
var restore_layer:=CanvasLayer.new()
var name_edit:=LineEdit.new()
var ranch_clock:=preload("res://ranch_clock.gd").new()
var resident_tag:=preload("res://resident_card.gd").new()
var visit_point:=Vector3.ZERO
var visit_left:=0.0
var biome_labels:Array[Label]=[]
const EVENT_FADE_SECONDS:=1.25
var event_fading:Array=[]
var activity_group:Dictionary={}
var activity_kind:=""
var activity_delay:=0.0
var zoom_step:=0
var welcome:=preload("res://welcome.gd").new()
var deposits:=preload("res://deposits.gd").new()
var dock_buttons:Dictionary={}
var hide_ui:=false
var ui_layer:=CanvasLayer.new()
var settings:=PanelContainer.new()
var phase_button:=Button.new()
var limits_ui:=OptionButton.new()
var styles_ui:=OptionButton.new()
var hide_ui_option:=CheckBox.new()
var music_option:=CheckBox.new()
var music_enabled:=true
var close_camera:=true
var pose_profiles:Dictionary={}
const SPRITE_BOX:=AABB(Vector3(-.675,0,-.05),Vector3(1.35,1.35,.1))
var close_camera_option:=CheckBox.new()
var inactive:Array=[]
var population_enabled:=false
var full_mode:=false
var expected_count:=100
var animated:Array=[]
var camera:=Camera3D.new()
var rng:=RandomNumberGenerator.new()
var herd:Array=[]
var cells:Dictionary={}
var tour:Array=[]
var tour_index:=0
var shot_time:=0.0
var ranch_time:=0.0
var overview:=false
var paused:=false
var label:=Label.new()
var finder:=PanelContainer.new()
var query:=LineEdit.new()
var matches:=ItemList.new()
var yaw:=0.6
var fade_clock:=-1.0
var phase_camera_grace:=0.0
var tour_cut_done:=false
const HALF_FADE:=.38

func orbit_toward(desired:float,dt:float)->float:
    var delta:=angle_difference(yaw,desired)
    if absf(delta)<.055:return yaw
    return yaw+clampf(delta*(1.-exp(-dt*1.3)),-dt*1.1,dt*1.1)

func position_camera(pos:Vector3,aim:Vector3,dt:float,snap:bool,tour_opacity:float):
    var opacity:=tour_opacity
    if snap:
        fade_clock=-1.
    elif phase_camera_grace<=0. and not overview and fade_clock<0 and camera_target.distance_to(aim)>maxf(14.,pos.distance_to(aim)*2.5):
        fade_clock=0.
    if fade_clock>=0:
        var previous:=fade_clock
        fade_clock+=dt
        if fade_clock<HALF_FADE:
            cut_overlay.color.a=maxf(opacity,smoothstep(0,HALF_FADE,fade_clock))
            return
        if previous<HALF_FADE:
            snap=true;opacity=1.
        else:opacity=maxf(opacity,1.-smoothstep(HALF_FADE,2.*HALF_FADE,fade_clock))
        if fade_clock>=2.*HALF_FADE:fade_clock=-1.
    var shift:=maxf(camera.position.distance_to(pos),camera_target.distance_to(aim))
    var speed:=clampf(pos.distance_to(aim)*1.7,2.5,12.)
    var weight:=1. if snap else minf(1.-exp(-dt*2.3),speed*dt/maxf(.001,shift))
    camera.position=camera.position.lerp(pos,weight)
    camera_target=camera_target.lerp(aim,weight)
    camera.look_at(camera_target)
    cut_overlay.color.a=opacity

func portrait_angle(subject:Resident)->float:
    # The resident faces local +Z. Move between a near-frontal and a three-quarter portrait.
    var side:=1.0 if subject.slot%2==0 else -1.0
    return subject.body.rotation.y+subject.facing_bias+side*(.38+.32*sin(ranch_time*.19))

var audit:=false
var audit_frames:=0
var audit_delta_total:=0.0
var focus_seen:Dictionary={}
var shadow_mesh:=PlaneMesh.new()
var camera_target:=Vector3.ZERO
var off_route:=0
var measuring:=false
var sample_start:=0
var previous_us:=0
var frame_seconds:=PackedFloat64Array()
var init_ms:=0
var benchmark_wide:=false

class Resident:
    var body:Node3D
    var player:AnimationPlayer
    var info:Dictionary={}
    var home_zone:int
    var appearance_group:=""
    var render_ready:=false
    var stroll_left:=0.0
    var species_title:String
    var title:String
    var here:int
    var path:=PackedInt64Array()
    var route_index:=0
    var eye_materials:Array=[]
    var blink_wait:=0.0
    var blinking:=false
    var facing_bias:=0.0
    var meal:Node3D
    var meal_stage:=0
    var meal_time:=0.0
    var meal_after:=0.0
    var dinner_day:=-1
    var bedtime:=60.0
    var morning_time:=30.0
    var sleep_effect:Node3D
    var resting_at_night:=false
    # 0 awake, 1 entering sleep, 2 sustained sleep, 3 waking.
    # Keeping entry/loop/exit distinct prevents lie-down and wake-up clips from
    # being replayed as loops when a resident remains loaded near the camera.
    var sleep_stage:=0
    var stroll_edges:=0
    var rest:=0.0
    var stuck:=0.0
    var speed:=1.0
    var native_speed:=1.0
    var cadence:=1.0
    var radius:=.65
    var food_height:=1.0
    var food_width:=1.0
    var height:=1.0
    var traveled:=0.0
    var trips:=0
    var aborted:=0
    var pose_box:=AABB(Vector3(-.5,0,-.5),Vector3.ONE)
    var altitude:=0.0
    var group:Dictionary={}
    var social_after:=0.0
    var ambient_clip:=""
    var ambient_active:=false
    var ambient_sequence:Array[String]=[]
    var ambient_index:=0
    var last_ambient_clip:=""
    var stationary:=false
    var swimming:=false
    var move_clip:="Walk"
    var walking:=false
    var turning:=false
    var turn_clip:=""
    var turn_target:=0.0
    var asset:Dictionary={}
    var event_transition:=false
    var event_mix:=1.0
    var event_visible:=true
    var visual_mix:=1.0
    var fades:Array=[]
    var visual:Node3D
    var slot:int
    var occluding_proxy:=false
    var pan_visibility:=0.0
    var proxy_color:=Color.BLACK
    var has_art:=false
    var failed:=false

var night_clips:Dictionary={}
var iris_patches:Dictionary={}
var blink_eyes:Dictionary={}
var drowsing_eyes:Dictionary={}
var night_eye_offsets:Dictionary={}
var form_titles:Dictionary={}
var lake_offsets:Dictionary={}
var filtered_night:=false
var filtered_meal:=false
var meal_capable:Array=[]

func _ready():
    form_titles=JSON.parse_string(FileAccess.get_file_as_string("res://map/form_titles.json"))
    lake_offsets=JSON.parse_string(FileAccess.get_file_as_string("res://map/lake_offsets.json"))
    night_eye_offsets=JSON.parse_string(FileAccess.get_file_as_string("res://map/night-eye-offsets.json"))
    meal_capable=JSON.parse_string(FileAccess.get_file_as_string("res://map/meal-capable.json"))
    iris_patches=JSON.parse_string(FileAccess.get_file_as_string("res://map/iris-patches.json"))
    blink_eyes=JSON.parse_string(FileAccess.get_file_as_string("res://map/blink-eyes.json"))
    drowsing_eyes=JSON.parse_string(FileAccess.get_file_as_string("res://map/drowsing_eyes.json"))
    night_clips=JSON.parse_string(FileAccess.get_file_as_string("res://map/night_clips.json"))
    ResourceLoader.add_resource_format_loader(loader,true)
    init_ms=Time.get_ticks_msec()
    measuring="--measure" in OS.get_cmdline_user_args()
    audit="--audit" in OS.get_cmdline_user_args()
    benchmark_wide="--overview" in OS.get_cmdline_user_args()
    full_mode=not OS.has_feature("editor") or "--full" in OS.get_cmdline_user_args()
    overview=benchmark_wide
    rng.seed=4712
    var world:=WorldEnvironment.new()
    world.environment=Environment.new()
    world.environment.background_mode=Environment.BG_SKY
    world.environment.sky=Sky.new()
    var sky_material:=ProceduralSkyMaterial.new()
    sky_material.sky_top_color=Color("#79a9d1")
    sky_material.sky_horizon_color=Color("#dcebd4")
    sky_material.ground_bottom_color=Color("#516747")
    sky_material.ground_horizon_color=Color("#b8cda4")
    sky_material.sky_curve=.18
    sky_material.ground_curve=.12
    world.environment.sky.sky_material=sky_material
    world.environment.background_color=Color("#cee0d6")
    world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    world.environment.ambient_light_color=Color.WHITE
    world.environment.ambient_light_energy=.43
    world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    world.environment.adjustment_enabled=true
    world.environment.adjustment_brightness=1.03
    world.environment.adjustment_contrast=1.06
    world.environment.adjustment_saturation=1.04
    world.environment.fog_enabled=true
    world.environment.fog_light_color=Color("#dbe5d2")
    world.environment.fog_light_energy=.55
    world.environment.fog_density=.00055
    world.environment.fog_sky_affect=.22
    add_child(world)
    var sun:=DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-54,-28,0)
    sun.light_energy=.78
    add_child(sun)
    add_child(cycle);cycle.setup(world.environment,sun)
    add_child(land);land.build()
    camera.fov=37;camera.near=.35;camera.far=1000;add_child(camera)
    display_config.load("user://display.cfg")
    display_limit=int(display_config.get_value("display","stream_population",0))
    if not display_limit in LIMITS:display_limit=100
    start_3d=display_config.get_value("display","start_3d",true)
    allow_f=display_config.get_value("display","allow_f",false)
    display_style=session_style if session_style!="" else ("3D residents" if start_3d else display_config.get_value("display","mode","3D residents"))
    if not display_style in STYLES:display_style="3D residents"
    hide_ui=bool(display_config.get_value("display","hide_ui",false))
    music_enabled=bool(display_config.get_value("audio","music_enabled",true))
    cycle.set_music_enabled(music_enabled)
    close_camera=bool(display_config.get_value("display","frame_to_subject",true))
    pose_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://map/pose_bounds.json"))
    model_budget=int(display_config.get_value("display","model_budget",8))
    if not model_budget in MODEL_LIMITS:model_budget=8
    make_ui()
    var roster=JSON.parse_string(FileAccess.get_file_as_string("res://roster.json"))
    var fade:=Gradient.new()
    fade.colors=PackedColorArray([Color(0.12,.18,.09,.30),Color(.12,.18,.09,0)])
    var footprint:=GradientTexture2D.new()
    footprint.gradient=fade;footprint.width=64;footprint.height=64
    footprint.fill=GradientTexture2D.FILL_RADIAL
    footprint.fill_from=Vector2(.5,.5);footprint.fill_to=Vector2(1,.5)
    var shadow:=StandardMaterial3D.new()
    shadow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow.albedo_texture=footprint;shadow_mesh.material=shadow
    var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ranch-dex.json"))
    var assets:Dictionary={}
    for row in roster:assets[row.key]=row
    for row in JSON.parse_string(FileAccess.get_file_as_string("res://supplement.json")):assets[row.key]=row
    var source:Array=[]
    add_child(deposits);deposits.setup(self,catalog)
    add_child(welcome);welcome.setup(self)
    if deposits.use_deposits:source=deposits.pasture_rows()
    elif full_mode:
        source=catalog
    else:
        for model in roster:
            var entry={"model":model.key,"name":model.name,"form":model.form,"sweet":null,"art":"","species":model.species}
            for row in catalog:
                if row.model==model.key:
                    entry=row.duplicate();break
            source.append(entry)
    var selected:Array=[]
    for entry in source:
        if entry.model or entry.art:selected.append(entry)
        else:inactive.append(entry)
    if display_limit and selected.size()>display_limit:
        var order_rng:=RandomNumberGenerator.new();order_rng.seed=9537
        for j in range(selected.size()-1,0,-1):
            var k:=order_rng.randi_range(0,j)
            var swap=selected[j];selected[j]=selected[k];selected[k]=swap
        inactive.append_array(selected.slice(display_limit))
        selected.resize(display_limit)
    expected_count=selected.size()
    if expected_count==0 and deposits.use_deposits:
        overview=true
        show_empty_welcome()
        for action in ["Map","Next","Find"]:dock_buttons[action].disabled=true
        camera.projection=Camera3D.PROJECTION_ORTHOGONAL
        camera.position=Vector3(4,33,25)*land.Shape.UNIT
        camera.look_at(Vector3.ZERO)
        print("READY residents=0 nav=",land.points.size())
        return
    if expected_count<1 or not population.build(self,selected,assets):
        push_error("Could not build the selected display roster");get_tree().quit(2);return
    population_enabled=true
    if herd.size()!=expected_count:
        push_error("Incomplete resident roster");get_tree().quit(2);return
    next_tour()
    if not population.groups.is_empty():
        var opening=tour.find(population.groups[0].members[0])
        if opening>=0:
            var first=tour[0];tour[0]=tour[opening];tour[opening]=first
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--follow="):
            for i in tour.size():
                if herd[tour[i]].title==arg.trim_prefix("--follow="):
                    var first=tour[0];tour[0]=tour[i];tour[i]=first
                    break
    plan_next_stop()
    aim_camera(1,true);update_stream()
    print("LOAD_MS ",Time.get_ticks_msec()-init_ms)
    print("READY residents=",herd.size()," nav=",land.points.size()," GPU=",RenderingServer.get_video_adapter_name())

func show_empty_welcome():
    var card:=PanelContainer.new()
    card.name="EmptyWelcome"
    card.theme=preload("res://meadow_theme.gd").meadow()
    card.add_theme_stylebox_override("panel",preload("res://meadow_theme.gd").box("#193932f4",16))
    ui_layer.add_child(card)
    card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    card.grow_horizontal=Control.GROW_DIRECTION_BOTH
    card.grow_vertical=Control.GROW_DIRECTION_BOTH
    var stack:=VBoxContainer.new()
    stack.add_theme_constant_override("separation",10)
    card.add_child(stack)
    var greeting:=Label.new()
    greeting.text="Welcome to your meadow!"
    greeting.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    greeting.add_theme_color_override("font_color",Color("#fff4dc"))
    greeting.add_theme_font_size_override("font_size",21)
    stack.add_child(greeting)
    var button:=Button.new()
    button.text="Deposit your first Pokémon"
    stack.add_child(button)
    button.pressed.connect(deposits.open_boxes)

func make_ui():
    var meadow_skin:=preload("res://meadow_theme.gd").meadow()
    var transition_layer:=CanvasLayer.new()
    transition_layer.layer=0;add_child(transition_layer);transition_layer.add_child(cut_overlay)
    cut_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cut_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;cut_overlay.color=Color(0.08,.13,.10,0)
    var records:=CanvasLayer.new();add_child(records)
    var layer:=ui_layer;add_child(layer)
    var panel:=PanelContainer.new()
    var style:=preload("res://meadow_theme.gd").box("#fff4dcef",16)
    style.border_color=Color("#9fbd9d");style.set_border_width_all(2)
    layer.add_child(panel);panel.add_theme_stylebox_override("panel",style)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    panel.grow_horizontal=Control.GROW_DIRECTION_BOTH;panel.offset_top=12;panel.offset_bottom=12
    label.text="Shiny Ranch";label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",18);label.add_theme_color_override("font_color",Color("#2c5143"))
    var title_stack:=VBoxContainer.new();title_stack.add_theme_constant_override("separation",1)
    panel.add_child(title_stack);title_stack.add_child(label)
    ranch_clock.cycle=cycle;title_stack.add_child(ranch_clock)
    for biome in land.NAMES:
        var marker:=Label.new();marker.text=biome;marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
        marker.add_theme_font_size_override("font_size",13)
        marker.add_theme_stylebox_override("normal",preload("res://meadow_theme.gd").box("#264a41da",8))
        layer.add_child(marker);biome_labels.append(marker);marker.hide()
    records.add_child(resident_tag)
    resident_tag.hide()
    layer.add_child(finder);finder.hide();finder.position=Vector2(16,80)
    finder.custom_minimum_size=Vector2(390,270);finder.add_theme_stylebox_override("panel",style)
    var stack:=VBoxContainer.new();finder.add_child(stack)
    query.placeholder_text="Search resident or form…";stack.add_child(query)
    matches.custom_minimum_size=Vector2(360,190);stack.add_child(matches)
    var buttons:=HBoxContainer.new();stack.add_child(buttons)
    var follow:=Button.new();follow.text="Follow selected";buttons.add_child(follow)
    follow.pressed.connect(func():
        var selection=matches.get_selected_items()
        if not selection.is_empty():jump_to(selection[0]))
    var close:=Button.new();close.text="Close";buttons.add_child(close)
    close.pressed.connect(func():finder.hide())
    query.text_changed.connect(populate_finder);matches.item_activated.connect(jump_to)
    settings.theme=meadow_skin;finder.theme=meadow_skin
    var dock:=PanelContainer.new();layer.add_child(dock);dock.theme=meadow_skin
    dock.add_theme_stylebox_override("panel",preload("res://meadow_theme.gd").box("#fff4dcef",22))
    dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    dock.grow_horizontal=Control.GROW_DIRECTION_BOTH;dock.grow_vertical=Control.GROW_DIRECTION_BEGIN
    dock.offset_bottom=-12;dock.offset_top=-12
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",5);dock.add_child(row)
    for action in ["Hide/Show","Map","Pause","Find","Next","Deposits","Settings"]:
        var button:=Button.new();button.custom_minimum_size=Vector2(44,40);button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button.tooltip_text=action;button.accessibility_name=action
        button.icon=preload("res://ranch_icons.gd").icon(action)
        button.pressed.connect(dock_action.bind(action));row.add_child(button);dock_buttons[action]=button
    layer.add_child(settings);settings.hide();settings.position=Vector2(16,80);var settings_style:=style.duplicate() as StyleBoxFlat
    settings_style.bg_color=Color("#203831")
    settings_style.content_margin_left=18;settings_style.content_margin_right=18
    settings_style.content_margin_top=14;settings_style.content_margin_bottom=14
    settings.add_theme_stylebox_override("panel",settings_style)
    var options:=VBoxContainer.new();settings.add_child(options)
    var heading:=Label.new();heading.text="Ranch display";options.add_child(heading)
    var rename_row:=HBoxContainer.new();options.add_child(rename_row)
    var rename_label:=Label.new();rename_label.text="Ranch name";rename_row.add_child(rename_label)
    rename_row.add_child(name_edit);name_edit.max_length=32;name_edit.placeholder_text="Enter a ranch name"
    name_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var lim_label:=Label.new();lim_label.text="Maximum residents in the pasture";options.add_child(lim_label)
    options.add_child(limits_ui)
    for v in LIMITS:limits_ui.add_item("All" if v==0 else str(v))
    var budget_label:=Label.new();budget_label.text="Nearby 3D models";options.add_child(budget_label)
    options.add_child(budget_ui)
    for v in MODEL_LIMITS:budget_ui.add_item(str(v))
    var style_label:=Label.new();style_label.text="Appearance";options.add_child(style_label)
    options.add_child(styles_ui)
    for mode in STYLES:styles_ui.add_item(mode)
    close_camera_option.text="Frame the camera to each resident’s size";options.add_child(close_camera_option)
    start_option.text="Always start in 3D";options.add_child(start_option)
    shortcut_option.text="Allow F to switch between 3D and sprites";options.add_child(shortcut_option)
    hide_ui_option.text="Hide controls, keep Resident Record (click the Poké Ball or press H to restore)";options.add_child(hide_ui_option)
    music_option.text="Play background music (meal bells stay on)";options.add_child(music_option)
    var note:=Label.new();note.text="Changing the lineup reloads the pasture. Your collection is preserved.";options.add_child(note)
    var controls:=HBoxContainer.new();options.add_child(controls)
    controls.add_child(phase_button)
    phase_button.pressed.connect(func():
        cycle.skip_to_phase(not cycle.night)
        cycle.tick(0.,paused)
        settings.hide()
        ui_layer.visible=not hide_ui)
    var apply:=Button.new();apply.text="Apply";controls.add_child(apply);apply.pressed.connect(apply_settings)
    var cancel:=Button.new();cancel.text="Close";controls.add_child(cancel);cancel.pressed.connect(func():settings.hide();ui_layer.visible=not hide_ui)
    add_child(restore_layer);restore_layer.add_child(dinner_banner)
    cycle.dinner_started.connect(on_dinner_bell)
    cycle.lunch_started.connect(on_dinner_bell)
    cycle.breakfast_started.connect(on_dinner_bell)
    restore_layer.layer=layer.layer+1
    # Keep the same dock and Poké Ball interactive when the main interface is hidden.
    dock.reparent(restore_layer,false)
    var sync_dock:=func():
        for action in dock_buttons:dock_buttons[action].visible=layer.visible or action=="Hide/Show"
        dock.reset_size()
    layer.visibility_changed.connect(sync_dock)
    layer.visible=not hide_ui
    sync_dock.call()

func dock_action(action:String):
    if herd.is_empty() and action in ["Map","Next","Find"]:return
    match action:
        "Hide/Show":
            hide_ui=not hide_ui;finder.hide();settings.hide();ui_layer.visible=not hide_ui;save_settings()
        "Map":
            leave_activity(4)
            visit_left=0
            overview=not overview;aim_camera(1,true);update_stream()
            for r in herd:population.refresh_proxy(self,r)
            dock_buttons["Map"].tooltip_text="Follow residents" if overview else "Map"
        "Pause":
            paused=not paused
            for r in animated:r.player.speed_scale=0.0 if paused else r.cadence
            var caption:="Resume" if paused else "Pause"
            dock_buttons["Pause"].tooltip_text=caption;dock_buttons["Pause"].icon=preload("res://ranch_icons.gd").icon(caption)
            dock_buttons["Pause"].accessibility_name=caption
        "Find":
            settings.hide();finder.show();populate_finder(query.text);query.grab_focus()
        "Next":leave_activity(4);requested_next=true;visit_left=0;preparing_shot=false;shot_time=maxf(shot_time,DWELL)
        "Deposits":deposits.open_boxes()
        "Settings":open_settings()

func open_settings():
    ui_layer.show();finder.hide();name_edit.text=label.text
    budget_ui.select(MODEL_LIMITS.find(model_budget))
    limits_ui.select(LIMITS.find(display_limit));styles_ui.select(STYLES.find(display_style))
    close_camera_option.button_pressed=close_camera
    start_option.button_pressed=start_3d
    shortcut_option.button_pressed=allow_f
    hide_ui_option.button_pressed=hide_ui
    music_option.button_pressed=music_enabled
    phase_button.text="Skip to morning" if cycle.night else "Skip to night"
    settings.show()

func save_settings():
    display_config.set_value("display","stream_population",display_limit)
    display_config.set_value("display","model_budget",model_budget)
    session_style=display_style
    display_config.set_value("display","start_3d",start_3d)
    display_config.set_value("display","allow_f",allow_f)
    display_config.set_value("display","mode",display_style)
    display_config.set_value("display","hide_ui",hide_ui)
    display_config.set_value("display","frame_to_subject",close_camera)
    display_config.set_value("audio","music_enabled",music_enabled)
    if display_config.save("user://display.cfg")!=OK:push_error("Could not save ranch preferences")

func apply_settings():
    var proposed:=name_edit.text.strip_edges()
    if proposed.is_empty():name_edit.grab_focus();return
    if proposed!=label.text:
        var config:=ConfigFile.new()
        if config.load(welcome.profile_path)!=OK:return
        config.set_value("player","ranch_name",proposed)
        if config.save(welcome.profile_path)!=OK:return
        label.text=proposed
    var limit:int=LIMITS[limits_ui.selected]
    var mode:String=STYLES[styles_ui.selected]
    var rebuild:=limit!=display_limit or mode!=display_style
    model_budget=MODEL_LIMITS[budget_ui.selected];stream_wait=0
    display_limit=limit;display_style=mode;hide_ui=hide_ui_option.button_pressed
    start_3d=start_option.button_pressed;allow_f=shortcut_option.button_pressed
    close_camera=close_camera_option.button_pressed
    music_enabled=music_option.button_pressed
    cycle.set_music_enabled(music_enabled)
    save_settings();settings.hide();ui_layer.visible=not hide_ui
    if rebuild:get_tree().call_deferred("reload_current_scene")


func populate_finder(term:String):
    matches.clear()
    for i in herd.size():
        var resident=herd[i]
        if not term.is_empty() and resident.title.findn(term)<0:continue
        var line:String=resident.title
        var hidden_sprite:bool=display_style=="3D residents" and resident.asset.is_empty()
        var missing_sprite:bool=display_style=="Shiny sprites" and not resident.has_art
        if missing_sprite:line+=" · choose Mixed to follow"
        elif resident.asset:line+=" · 3D"
        elif hidden_sprite:line+=" · choose Mixed to follow"
        if cycle.night and not night_allowed(resident):line+=" · returns at dawn"
        if cycle.mealtime and not meal_allowed(resident):line+=" · returns after the meal"
        matches.add_item(line);matches.set_item_metadata(matches.item_count-1,i)
        if hidden_sprite or missing_sprite or (cycle.night and not night_allowed(resident)) or (cycle.mealtime and not meal_allowed(resident)):matches.set_item_disabled(matches.item_count-1,true)
    for row in inactive:
        var title:String=row.name+(" · form %d"%int(row.form) if row.form else "")+(" · Sweet %d"%int(row.sweet) if row.sweet!=null else "")
        if not term.is_empty() and title.findn(term)<0:continue
        matches.add_item(title+(" · artwork unavailable" if not row.art and not row.model else " · outside current display"))
        matches.set_item_metadata(matches.item_count-1,-1)
        matches.set_item_disabled(matches.item_count-1,true)
    for i in matches.item_count:
        if not matches.is_item_disabled(i):matches.select(i);break

func jump_to(item:int):
    var index:int=matches.get_item_metadata(item)
    if index<0:return
    if not herd[index].player and not population.sprite_node.visible:
        population.sprite_node.show();next_tour(true)
    var selected=tour.find(index)
    if selected<0:
        tour.insert(tour_index+1,index)
        selected=tour_index+1
    leave_activity(DWELL)
    var old=tour[tour_index];tour[tour_index]=tour[selected];tour[selected]=old
    visit_left=0;finder.hide();overview=false;shot_time=0;plan_next_stop();aim_camera(1,true);update_stream()
    for r in herd:population.refresh_proxy(self,r)

func warm_model(r:Resident):
    if warming or not is_instance_valid(r.visual):return
    warming=true;r.render_ready=false
    if not is_instance_valid(warm_view):
        warm_view=SubViewport.new();warm_view.size=Vector2i(96,96)
        warm_view.world_3d=get_world_3d();warm_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
        add_child(warm_view)
        warm_camera=Camera3D.new();warm_camera.cull_mask=1<<19;warm_view.add_child(warm_camera)
    var parts:Array=[]
    for mesh in r.visual.find_children("*","GeometryInstance3D",true,false):
        parts.append([mesh,mesh.layers]);mesh.layers|=1<<19
    var box:=shot_box(r);var center:=box.get_center();var radius:=maxf(.1,box.size.length())
    warm_camera.near=maxf(.001,radius*.01);warm_camera.far=radius*20.
    warm_camera.position=center+Vector3(.25,.2,1)*radius*1.7;warm_camera.look_at(center)
    warm_view.render_target_update_mode=SubViewport.UPDATE_ONCE
    await RenderingServer.frame_post_draw
    for part in parts:
        if is_instance_valid(part[0]):part[0].layers=part[1]
    if is_instance_valid(r.visual):r.render_ready=true
    warming=false

func mount_model(r:Resident)->bool:
    var packed:PackedScene=staged.get(r.asset.key)
    if not packed:return false
    var model=packed.instantiate()
    if not model:return false
    if not r.info.get("shiny",true) and not preload("res://regular_palette.gd").apply(model,regular_materials.get(r.asset.key,{})):
        model.free();return false
    var iris:Dictionary=iris_patches.get(r.asset.key,{}).get("shiny" if r.info.get("shiny",true) else "regular",{})
    if not iris.is_empty():preload("res://regular_palette.gd").apply(model,iris)
    var players=model.find_children("*","AnimationPlayer",true,false)
    if players.is_empty() or not players[0].has_animation("Walk") or not players[0].has_animation("Idle"):
        model.free();return false
    r.visual=model;r.body.add_child(model);model.scale=Vector3.ONE*float(r.asset.get("scale",.008))
    preload("res://native_light.gd").apply(model,r.asset.key,r.info.get("shiny",true))
    if int(r.asset.species)==615:preload("res://cryogonal_ice.gd").apply(model)
    if int(r.asset.species)==6:preload("res://charizard_fire.gd").apply(model)
    if int(r.asset.species)==92:preload("res://gastly_cloud.gd").apply(model,r.info.get("shiny",true))
    r.eye_materials.clear()
    var blink:Dictionary=blink_eyes.get(r.asset.key,{})
    var resting:Array=drowsing_eyes.get(r.asset.key,[])
    r.blinking=false;r.blink_wait=randf_range(2.8,6.2)
    if not resting.is_empty() or not blink.is_empty():
        for mesh in model.find_children("*","MeshInstance3D",true,false):
            for idx in mesh.mesh.get_surface_count():
                var mat=mesh.get_active_material(idx)
                if mat is StandardMaterial3D and (mat.resource_name in resting or blink.has(mat.resource_name)):
                    var own=mat.duplicate()
                    mesh.set_surface_override_material(idx,own)
                    own.set_meta("awake_offset",own.uv1_offset)
                    var shift:Array=night_eye_offsets.get(r.asset.key,{}).get(mat.resource_name,[.5,.25] if mat.resource_name=="Mouth" else [0,.5])
                    own.set_meta("rest_shift",Vector3(shift[0],shift[1],0) if mat.resource_name in resting else Vector3.ZERO)
                    if blink.has(mat.resource_name):
                        var uv:Array=blink[mat.resource_name]
                        own.set_meta("blink_shift",Vector3(uv[0],uv[1],0))
                    r.eye_materials.append(own)
    # Imported rigs can face either direction. Use an anatomical front marker where available.
    var rigs=model.find_children("*","Skeleton3D",true,false)
    if not rigs.is_empty():
        var rig:Skeleton3D=rigs[0]
        var markers={}
        for i in rig.get_bone_count():
            markers[rig.get_bone_name(i).to_lower().replace("_","")]=i
        for pair in [["efffront01","effcenter01"],["nose","head"],["effmouth01","head"],["head","hips"]]:
            if not markers.has(pair[0]) or not markers.has(pair[1]):continue
            var face:Vector3=rig.global_basis*(rig.get_bone_global_rest(markers[pair[0]]).origin-rig.get_bone_global_rest(markers[pair[1]]).origin)
            face=r.body.global_basis.inverse()*face
            if absf(face.z)>maxf(.012*r.pose_box.size.length(),absf(face.x)*2.):
                r.facing_bias=PI if face.z<0 else 0.
                break
    r.player=players[0]
    for clip in ["Walk","Idle"]:r.player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
    var bounds:=AABB()
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        if not mesh.visible:continue
        var box:AABB=mesh.global_transform*mesh.get_aabb()
        bounds=box if not bounds.has_volume() else bounds.merge(box)
    # The skinned mesh AABB describes its bind pose. Use the audited posed envelope.
    var food_box:AABB=r.pose_box
    var profile:Array=pose_profiles.get(r.asset.key,[])
    if profile.size()>=6:
        food_box=AABB(Vector3(profile[0],profile[1],profile[2]),Vector3(profile[3]-profile[0],profile[4]-profile[1],profile[5]-profile[2]))
    r.food_height=maxf(.001,food_box.size.y)
    r.food_width=maxf(.001,maxf(food_box.size.x,food_box.size.z))
    r.height=clampf(bounds.size.y,.25,4.5);r.radius=clampf(maxf(bounds.size.x,bounds.size.z)*.30,.35,1.35)
    if r.swimming:
        if not r.player.has_animation("Swim"):
            r.player.get_animation_library("").add_animation("Swim",r.player.get_animation("Walk"))
        r.move_clip="Swim"
    var clip:String=r.move_clip if r.walking else "Idle"
    if r.group.get("phase","")=="Playing":clip=population.play_phase_clip(r,r.group)
    if r.resting_at_night and night_allowed(r):
        if r.sleep_stage==1 and r.player.has_animation("SleepStart"):
            clip="SleepStart";r.player.get_animation(clip).loop_mode=Animation.LOOP_NONE
        elif r.sleep_stage==3 and r.player.has_animation("SleepEnd"):
            clip="SleepEnd";r.player.get_animation(clip).loop_mode=Animation.LOOP_NONE
        else:
            clip=night_clips[r.asset.key];r.sleep_stage=2;set_rest_eyes(r,true);r.player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
    r.player.play(clip)
    r.player.seek(fmod(ranch_time,r.player.current_animation_length),true)
    r.player.speed_scale=0 if paused else 1
    # Only a model entering the actual view needs temporary blended materials.
    if camera.is_position_in_frustum(r.body.position+Vector3.UP*r.height*.5):
        r.visual_mix=0.
    else:r.visual_mix=1.
    apply_model_opacity(r)
    animated.append(r);population.refresh_proxy(self,r)
    warm_model.call_deferred(r)
    return true

func apply_model_opacity(r:Resident):
    var opacity:=r.visual_mix*smoothstep(0.,1.,r.event_mix)
    if opacity>=1.:
        for part in r.fades:
            if part[1]<0:part[0].material_override=part[2]
            else:part[0].set_surface_override_material(part[1],part[2])
        r.fades.clear()
        return
    if r.fades.is_empty():
        for mesh in r.visual.find_children("*","MeshInstance3D",true,false):
            for idx in mesh.mesh.get_surface_count():
                var original=mesh.get_active_material(idx)
                if not original:continue
                var fade=original.duplicate()
                if original.next_pass is ShaderMaterial:fade.next_pass=original.next_pass.duplicate()
                var alpha:=1.
                if fade is StandardMaterial3D:
                    alpha=fade.albedo_color.a
                    fade.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
                elif not fade is ShaderMaterial:continue
                if mesh.material_override:
                    r.fades.append([mesh,-1,mesh.material_override,fade,alpha])
                    mesh.material_override=fade
                    break
                r.fades.append([mesh,idx,mesh.get_surface_override_material(idx),fade,alpha])
                mesh.set_surface_override_material(idx,fade)
    for part in r.fades:
        if part[3].next_pass is ShaderMaterial:part[3].next_pass.set_shader_parameter("resident_opacity",opacity)
        if part[3] is ShaderMaterial:part[3].set_shader_parameter("resident_opacity",opacity)
        else:part[3].albedo_color.a=part[4]*opacity

func advance_material_fades(dt:float):
    for i in range(event_fading.size()-1,-1,-1):
        var r:Resident=event_fading[i]
        var target:=1. if r.event_visible else 0.
        r.event_mix=move_toward(r.event_mix,target,dt/EVENT_FADE_SECONDS)
        if r.event_mix==target:
            r.body.visible=r.event_visible
            r.event_transition=false
            event_fading.remove_at(i)
        if r.visual:apply_model_opacity(r)
        population.refresh_proxy(self,r)
    for r in animated:
        var sleeping:bool=r.player.current_animation in ["Nap","Drowse"]
        if not sleeping and not r.resting_at_night and blink_eyes.has(r.asset.key):
            r.blink_wait-=dt
            if r.blink_wait<=0:
                r.blinking=not r.blinking
                r.blink_wait=randf_range(.11,.16) if r.blinking else randf_range(2.8,6.2)
                for mat in r.eye_materials:
                    if mat.has_meta("blink_shift"):
                        mat.uv1_offset=mat.get_meta("awake_offset")+(mat.get_meta("blink_shift") if r.blinking else Vector3.ZERO)
                sync_eye_fades(r)
        if sleeping and not r.sleep_effect:
            r.sleep_effect=preload("res://sleep_effect.gd").new()
            r.visual.add_child(r.sleep_effect)
            var identity:String=str(r.info.get("id",""))
            if identity.is_empty():identity=r.asset.key+"-"+str(r.slot)
            r.sleep_effect.setup(r.visual,r.pose_box,identity,r.asset.key)
        if r.sleep_effect:
            r.sleep_effect.visible=sleeping and r.body.visible and not overview
            if r.sleep_effect.visible:r.sleep_effect.advance(r.body,camera,dt,r.event_mix*r.visual_mix)
        if r.swimming and r.player.is_playing():
            var clip:String=r.player.current_animation
            var samples:Array=lake_offsets.get(r.asset.key,{}).get("Walk" if clip=="Swim" else clip,[])
            if not samples.is_empty() and r.player.current_animation_length>0:
                var t:=fposmod(r.player.current_animation_position/r.player.current_animation_length,1.)*samples.size()
                var i:=floori(t)
                var height:float=lerpf(samples[i],samples[(i+1)%samples.size()],t-i)-r.altitude
                r.visual.position.y=lerpf(r.visual.position.y,height,1.-exp(-dt*12.))
        if r.visual_mix>=1.:continue
        r.visual_mix=minf(1.0,r.visual_mix+dt/.35)
        apply_model_opacity(r)
        population.refresh_proxy(self,r)

func _exit_tree():
    # Finish the outstanding request before removing its format loader on reload.
    if not loading_path.is_empty() and ResourceLoader.load_threaded_get_status(loading_path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:
        ResourceLoader.load_threaded_get(loading_path)
    ResourceLoader.remove_resource_format_loader(loader)

func update_foreground_proxies():
    # An unloaded billboard can still hide a very small featured resident.
    var hide_foreground:=not overview and visit_left<=0
    var subject:Resident=herd[tour[tour_index]]
    if not activity_group.is_empty():subject=herd[activity_members()[0]]
    if activity_group.is_empty() and shot_time>DWELL+(LONG_CUT if distant_pair else PAN)*.5:
        subject=herd[tour[tour_index+1]]
    var focus:=shot_box(subject)
    var direction:=focus.get_center()-camera.position
    var depth:=direction.length()
    var axis:=direction.normalized()
    var focus_radius:=minf(.7,focus.size.length()*.22)
    var phase:=clampf((shot_time-DWELL-RECORD_FADE)/PAN,0,1)
    var pan_fill:=smoothstep(0,.16,phase)*(1.0-smoothstep(.84,1,phase)) if display_style=="3D residents" and not overview and not distant_pair and activity_group.is_empty() else 0.0
    for r in herd:
        var fill:float=pan_fill if r.has_art and r.body.position.distance_squared_to(camera_target)<900 else 0.0
        var changed:bool=absf(fill-r.pan_visibility)>.005 or (fill==0 and r.pan_visibility>0)
        r.pan_visibility=fill
        var overlap:=false
        if hide_foreground and r!=subject:
            var toward:Vector3=r.body.position+Vector3.UP*.67-camera.position
            var along:=toward.dot(axis)
            if along>0 and along<depth-.05:
                overlap=(toward-axis*along).length()<.67+focus_radius*along/maxf(depth,.01)
        if r.visual:
            var blocked:=false
            if hide_foreground and r!=subject and (activity_group.is_empty() or not activity_members().has(r.slot)):
                var bounds:=shot_box(r)
                var padding:=minf(.35,focus.size.length()*.12)
                blocked=bounds.grow(padding).intersects_segment(camera.position,focus.get_center())!=null
            r.visual.visible=not blocked
            if r.meal:r.meal.visible=not blocked
            overlap=overlap or blocked
        if changed or r.occluding_proxy!=overlap:
            r.occluding_proxy=overlap
            population.refresh_proxy(self,r)

func model_failed(key:String):
    var tries:int=int(load_attempts.get(key,0))+1
    load_attempts[key]=tries
    retry_after[key]=ranch_time+minf(60.,3.*pow(2,mini(tries-1,5)))
    for resident in herd:
        if resident.asset.get("key","")==key:resident.failed=true

func update_stream():
    if not tour.is_empty():update_foreground_proxies()
    for key in retry_after.keys():
        if ranch_time<float(retry_after[key]):continue
        retry_after.erase(key)
        for resident in herd:
            if resident.asset.get("key","")==key:resident.failed=false
    if not loading_path.is_empty():
        var status:=ResourceLoader.load_threaded_get_status(loading_path)
        if status==ResourceLoader.THREAD_LOAD_LOADED:
            var resource=ResourceLoader.load_threaded_get(loading_path)
            if resource is PackedScene:staged[loading_key]=resource
            else:model_failed(loading_key)
            loading_path=""
        elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
            model_failed(loading_key)
            loading_path=""
    var wanted:Array=[]
    if not tour.is_empty() and not overview and display_style!="Shiny sprites":
        var subject:Resident=herd[tour[tour_index]]
        var upcoming:Resident=herd[tour[tour_index+1]]
        if not activity_group.is_empty():
            subject=herd[activity_members()[0]]
            for id in activity_members():
                var peer:Resident=herd[id]
                if peer.asset and not peer.failed:wanted.append(peer)
        if activity_group.is_empty() and not pending_activity.is_empty():
            if subject.asset and not subject.failed:wanted.append(subject)
            for id in pending_activity.get("members",[]):
                var peer:Resident=herd[id]
                if peer.asset and not peer.failed and not wanted.has(peer) and wanted.size()<model_budget:wanted.append(peer)
        for r in [subject,upcoming]:
            # Reserve the next subject immediately, throughout the current dwell.
            if r.event_visible and r.asset and not r.failed and not wanted.has(r) and wanted.size()<model_budget:wanted.append(r)
        # Give the current group first choice of the remaining camera slots.
        for principal in [subject,upcoming]:
            for id in principal.group.get("members",[]):
                var peer:Resident=herd[id]
                if peer.event_visible and peer.asset and not peer.failed and not wanted.has(peer) and wanted.size()<model_budget:wanted.append(peer)
        var nearby:Array=[]
        var frustum:=camera.get_frustum()
        var focus_box:=shot_box(subject)
        var focus_size:=maxf(focus_box.size.length(),.05)
        var focus_center:=focus_box.get_center()
        var projection:=tan(deg_to_rad(camera.fov*.5))
        var focus_depth:=camera.global_position.distance_to(focus_center)
        for r in herd:
            if not r.event_visible or not r.asset or r.failed or wanted.has(r):continue
            # The focus and queued subject already have reserved slots. Every
            # other model must intersect this shot and be large enough to see.
            if r.body.position.distance_squared_to(camera.position)>3600.0:continue
            var box:AABB=r.body.global_transform*r.pose_box
            var center:=box.get_center()
            var visible:=true
            for plane:Plane in frustum:
                var reach:=plane.normal.abs().dot(box.size*.5)
                if plane.distance_to(center)>reach:
                    visible=false;break
            if not visible:continue
            var depth:=maxf(.05,-camera.global_transform.basis.z.dot(center-camera.position))
            var size:=box.size.length()
            var coverage:=size/(2.0*projection*depth)
            if coverage<(.055 if r.visual else .075):continue
            var on_focus:=center.distance_to(focus_center)<focus_size+size*.8
            if on_focus and size>focus_size*2.5 and depth<focus_depth:continue
            var size_penalty:=1.0+absf(log(maxf(.05,size)/focus_size))*.35
            nearby.append([center.distance_squared_to(focus_center)*size_penalty/(1.12 if r.visual else 1.0),r])
        nearby.sort_custom(func(a,b):return a[0]<b[0])
        for candidate in nearby:
            if wanted.size()>=model_budget:break
            wanted.append(candidate[1])
    neighbors_waiting=false
    for r in wanted:
        if not r.visual or r.visual_mix<.99:neighbors_waiting=true;break
    for r in animated.duplicate():
        if wanted.has(r) or (not r.event_visible and r.event_mix>0.):continue
        if r.meal:r.meal.queue_free();r.meal=null
        animated.erase(r);r.fades.clear();r.eye_materials.clear();r.visual.free();r.sleep_effect=null;r.visual=null;r.player=null
        population.refresh_proxy(self,r)
    var keep:Dictionary={}
    for r in wanted:keep[r.asset.key]=true
    for key in staged.keys():
        if not keep.has(key):staged.erase(key)
    for r in wanted:
        if r.visual:continue
        if animated.size()>=model_budget or warming:break
        if staged.has(r.asset.key):
            if not mount_model(r):model_failed(r.asset.key)
            else:load_attempts.erase(r.asset.key)
            staged.erase(r.asset.key)
            break
        if loading_path.is_empty():
            loading_key=r.asset.key;loading_path="res://models/"+loading_key+".glb"
            if ResourceLoader.load_threaded_request(loading_path,"PackedScene",false,ResourceLoader.CACHE_MODE_IGNORE)!=OK:
                loading_path="";model_failed(loading_key)
        break

func point_of(r:Resident)->Vector2:
    return Vector2(r.body.position.x,r.body.position.z)

func bucket(p:Vector2)->Vector2i:
    return Vector2i(floori(p.x/CELL_SIZE),floori(p.y/CELL_SIZE))

func add_cell(r:Resident,p:Vector2):
    var k:=bucket(p)
    if not cells.has(k):cells[k]=[]
    cells[k].append(r)

func clear_position(r:Resident,p:Vector2,margin:float=0)->bool:
    var k:=bucket(p)
    for x in range(-2,3):
        for z in range(-2,3):
            for other in cells.get(k+Vector2i(x,z),[]):
                if other!=r and p.distance_squared_to(point_of(other))<pow(r.radius+other.radius+margin,2):return false
    return true

func motion(r:Resident,walk:bool):
    if r.walking==walk:return
    r.walking=walk
    r.cadence=r.speed/r.native_speed if walk else 1.0
    r.player.speed_scale=r.cadence
    r.player.play("Walk" if walk else "Idle",.22)

func pick_route(r:Resident):
    var origin:Vector2=land.points[r.here]
    for attempt in 15:
        var goal:=rng.randi_range(0,land.points.size()-1)
        var length:=origin.distance_to(land.points[goal])
        if length<4 or length>(42 if attempt==0 else 19):continue
        var path:PackedInt64Array=land.navigation.get_id_path(r.here,goal)
        if path.size()<2:continue
        r.path=path;r.route_index=1;r.stuck=0;return
    r.rest=.8

func update_resident(r:Resident,dt:float):
    if r.rest>0:
        r.rest-=dt;motion(r,false);return
    if r.path.is_empty():
        pick_route(r);return
    var p:=point_of(r)
    var dest:Vector2=land.points[r.path[r.route_index]]
    var delta:=dest-p
    if delta.length()<.012:
        r.here=r.path[r.route_index];r.route_index+=1
        if r.route_index>=r.path.size():
            r.path.clear();r.trips+=1;r.rest=rng.randf_range(1,6);motion(r,false)
            return
        # Continue into the next edge this frame instead of pausing at each waypoint.
        dest=land.points[r.path[r.route_index]]
        delta=dest-p
    var angle:=atan2(delta.x,delta.y)
    r.body.rotation.y=rotate_toward(r.body.rotation.y,angle,dt*2.9)
    var stride:=minf(delta.length(),r.speed*dt*maxf(0,cos(angle-r.body.rotation.y)))
    var proposed:=p+delta.normalized()*stride
    if not clear_position(r,proposed):
        r.stuck+=dt
        # Yield to sustained obstructions; a single blocked frame keeps the footfall phase.
        if r.stuck>=.30:motion(r,false)
        if r.stuck>1.8:
            # Backtrack on the same validated edge before choosing another route.
            var last_node:int=r.path[r.route_index-1]
            if p.distance_to(land.points[last_node])<.012:
                r.here=last_node
                r.path.clear();r.rest=rng.randf_range(.4,1.6)
            else:
                r.path=PackedInt64Array([r.path[r.route_index],last_node]);r.route_index=1
            r.stuck=0;r.aborted+=1
        return
    if audit:
        var a:Vector2=land.points[r.path[r.route_index-1]]
        var b:Vector2=land.points[r.path[r.route_index]]
        if proposed.distance_to(Geometry2D.get_closest_point_to_segment(proposed,a,b))>.018:off_route+=1
    var old:=bucket(p)
    if old!=bucket(proposed):
        cells[old].erase(r);add_cell(r,proposed)
    r.body.position=Vector3(proposed.x,0,proposed.y)
    r.traveled+=stride;r.stuck=0
    if stride>.00001:motion(r,true)
    if r.walking:
        var rate:=stride/(r.native_speed*dt)
        r.cadence=lerpf(r.cadence,rate,1-exp(-dt*10))
        r.player.speed_scale=r.cadence

func meal_allowed(r:Resident)->bool:
    return not r.asset.is_empty() and meal_capable.has(r.asset.key)

func night_allowed(r:Resident)->bool:
    return night_clips.has(r.asset.get("key",""))

func set_rest_eyes(r:Resident,closed:bool):
    r.blinking=false;r.blink_wait=randf_range(2.8,6.2)
    for mat in r.eye_materials:
        mat.uv1_offset=mat.get_meta("awake_offset")+(mat.get_meta("rest_shift") if closed else Vector3.ZERO)
    sync_eye_fades(r)

func sync_eye_fades(r:Resident):
    for part in r.fades:
        if part[2] in r.eye_materials:part[3].uv1_offset=part[2].uv1_offset

var appearance_visits:Dictionary={}

func next_tour(reset:bool=false):
    var previous:int=tour.back() if not reset and not tour.is_empty() else -1
    tour.clear()
    for i in herd.size():
        if cycle.night and not night_allowed(herd[i]):continue
        if cycle.mealtime and not meal_allowed(herd[i]):continue
        if display_style=="3D residents" and not herd[i].asset:continue
        if display_style=="Shiny sprites" and not herd[i].has_art:continue
        tour.append(i)
    var appearances:Dictionary={}
    var unique:Array=[]
    for id in tour:
        var key:String=herd[id].appearance_group
        if key.is_empty():
            unique.append(id)
        else:
            if not appearances.has(key):appearances[key]=[]
            appearances[key].append(id)
    for key in appearances:
        var members:Array=appearances[key]
        var visit:int=appearance_visits.get(key,0)
        unique.append(members[visit%members.size()])
        appearance_visits[key]=visit+1
    tour.assign(unique)
    for j in range(tour.size()-1,0,-1):
        var k:=rng.randi_range(0,j);var swap=tour[j];tour[j]=tour[k];tour[k]=swap
    if tour.is_empty() and (cycle.night or cycle.mealtime):
        tour_index=0;return
    if tour.is_empty():
        for i in herd.size():tour.append(i)
    if tour.size()==1:tour.append(tour[0])
    if tour[0]==previous:
        var swap=tour[0];tour[0]=tour[1];tour[1]=swap
    if previous>=0:tour.push_front(previous)
    tour_index=0

func advance_tour():
    if tour.is_empty():return
    tour_index+=1;shot_time=0
    if tour_index+1>=tour.size():next_tour()
    plan_next_stop()

func plan_next_stop():
    if tour.is_empty():return
    # Only reorder the unvisited suffix. Every resident still gets a turn.
    var current:Resident=herd[tour[tour_index]]
    var slot:=tour_index+1
    var best:=slot
    var score:=INF
    var size:=maxf(.1,shot_box(current).size.length())
    for i in range(slot,tour.size()):
        var candidate:Resident=herd[tour[i]]
        var distance:=current.body.position.distance_squared_to(candidate.body.position)
        var mismatch:=absf(log(maxf(.1,shot_box(candidate).size.length())/size))
        var cost:=distance*(1.0+.15*minf(3,mismatch))
        if candidate.visual:cost*=.7
        if candidate.group and not current.group and distance<225:cost*=.12
        if cost<score:best=i;score=cost
    var swap=tour[slot];tour[slot]=tour[best];tour[best]=swap
    distant_pair=current.body.position.distance_to(herd[tour[slot]].body.position)>24
    requested_next=false;settled_watch=0;portrait_age=0
    tour_cut_done=false
    preparing_shot=true;setup_elapsed=0;stream_wait=0
    cut_overlay.color.a=0

func update_scenery_view(ids:Array):
    var targets:=PackedVector4Array()
    for id in ids:
        var bounds:=shot_box(herd[id])
        var center:=bounds.get_center()
        targets.append(Vector4(center.x,center.y,center.z,maxf(.26,bounds.size.length()*.57)))
    land.update_cutaways(camera.position,targets)

func shot_box(r:Resident)->AABB:
    if r.asset.is_empty() or display_style=="Shiny sprites":
        return AABB(r.body.position+SPRITE_BOX.position*r.proxy_color.a,SPRITE_BOX.size*r.proxy_color.a)
    return r.body.global_transform*r.pose_box

func social_box(r:Resident)->AABB:
    var box:=shot_box(r)
    for id in r.group.get("members",[]):
        var peer:Resident=herd[id]
        if peer!=r:box=box.merge(shot_box(peer))
    return box

func fit_distance(box:AABB,angle:float)->float:
    var back:=Vector3(sin(angle),.31,cos(angle)).normalized()
    var right:=Vector3(cos(angle),0,-sin(angle))
    var up:=back.cross(right)
    var half:=box.size*.5
    var aspect:=get_viewport().get_visible_rect().size.aspect()
    var tangent:=tan(deg_to_rad(camera.fov*.5))
    var vertical:=up.abs().dot(half)/(.65*tangent)
    var horizontal:=right.abs().dot(half)/(.68*tangent*aspect)
    return maxf(.18,back.abs().dot(half)+maxf(vertical,horizontal))

func live_activity(group:Dictionary)->String:
    if group.has("ball") and is_instance_valid(group.ball) and not group.ball.is_queued_for_deletion():return "Ball play"
    if group.has("turn"):return "Playing together"
    if group.get("phase","")=="Parade":return "Parade"
    return ""

func activity_members()->Array:
    return activity_group.players if activity_kind in ["Ball play","Playing together"] else activity_group.members

func show_event_members(ids:Array):
    for r in herd:
        var visible_here:bool=(ids.is_empty() or ids.has(r.slot)) and (not cycle.night or night_allowed(r)) and (not cycle.mealtime or meal_allowed(r))
        if r.event_visible==visible_here:continue
        r.event_visible=visible_here
        if visible_here:r.body.show()
        if not r.event_transition:
            r.event_transition=true
            event_fading.append(r)

func leave_activity(delay:float):
    if not activity_kind.is_empty() and "--activity-test" in OS.get_cmdline_user_args():print("CAMERA END ",activity_kind)
    if not activity_group.is_empty():
        show_event_members([])
        # Give the returning portrait a fresh dwell instead of finishing an old pan.
        shot_time=0.;preparing_shot=true;setup_elapsed=0.;settled_watch=0.;portrait_age=0.;tour_cut_done=false
    pending_activity={};pending_activity_age=0.
    activity_group={};activity_kind="";activity_ended=false;activity_delay=delay;stream_wait=0

func activity_ready(members:Array)->bool:
    if members.is_empty() or members.size()>model_budget:return false
    for id in members:
        if int(id)<0 or int(id)>=herd.size():return false
        var peer:Resident=herd[int(id)]
        if not is_instance_valid(peer.visual) or not is_instance_valid(peer.player) or peer.failed:return false
        if not peer.render_ready or peer.visual_mix<.99 or peer.event_mix<.99:return false
    return true

func scheduled_activity(group:Dictionary)->String:
    var live:=live_activity(group)
    if live!="":return live
    return "Getting together" if group.get("phase","") in ["Greeting","Strolling together"] else ""

func refresh_event_candidates():
    event_candidates.clear()
    if tour.is_empty() or cycle.night or cycle.mealtime:return
    for g in population.groups:
        var kind:=scheduled_activity(g)
        if kind=="" or g.get("filmed_"+kind,false):continue
        var members:Array=g.get("members",[])
        var needed:Array=members.duplicate()
        if not needed.has(tour[tour_index]):needed.append(tour[tour_index])
        if members.is_empty() or needed.size()>model_budget:continue
        if members.any(func(id):return herd[id].asset.is_empty() or herd[id].failed):continue
        var distance:=INF;var ready:=0
        for id in members:
            distance=minf(distance,herd[id].body.position.distance_squared_to(camera_target))
            if herd[id].render_ready and is_instance_valid(herd[id].visual):ready+=1
        if distance>EVENT_PICKUP_RADIUS*EVENT_PICKUP_RADIUS:continue
        event_candidates.append({"group":g,"score":distance/(1.+.4*ready)})
    event_candidates.sort_custom(func(a,b):return a.score<b.score)
    if event_candidates.size()>EVENT_CANDIDATE_LIMIT:event_candidates.resize(EVENT_CANDIDATE_LIMIT)

func notice_activity(dt:float):
    event_scan_left-=dt
    if event_scan_left<=0:
        refresh_event_candidates();event_scan_left=.5
    if not activity_group.is_empty():
        activity_age+=dt
        var continuing:=scheduled_activity(activity_group) if population.groups.has(activity_group) else ""
        if continuing==activity_kind:return
        if continuing!="":
            activity_kind=continuing
            show_event_members(activity_members())
            activity_group["filmed_"+continuing]=true
            stream_wait=0
            return
        activity_ended=true
        activity_end_hold+=dt
        if activity_end_hold<1.5:return
        leave_activity(MIN_VISIBLE_SHOT)
        advance_tour()
        return
    if not pending_activity.is_empty():
        pending_activity_age+=dt
        var kind:=scheduled_activity(pending_activity)
        if not population.groups.has(pending_activity) or kind=="" or pending_activity_age>20. or cycle.night or cycle.mealtime:
            event_stats.expired+=1
            pending_activity={};pending_activity_age=0.;stream_wait=0
        elif activity_ready(pending_activity.get("members",[])) and settled_watch>=MIN_VISIBLE_SHOT:
            event_stats.featured+=1;event_stats.warmup_seconds+=pending_activity_age
            activity_group=pending_activity;activity_kind=kind
            pending_activity={};pending_activity_age=0.
            show_event_members(activity_members());event_yaw=yaw
            activity_age=0.;activity_watch=0.;activity_ended=false;activity_end_hold=0.
            activity_group["filmed_"+activity_kind]=true;stream_wait=0
            if "--activity-test" in OS.get_cmdline_user_args():print("CAMERA PREPARED EVENT ",activity_kind)
            return
        else:return
    activity_delay=maxf(0,activity_delay-dt)
    if overview or visit_left>0 or activity_delay>0 or settings.visible or finder.visible or deposits.visible or welcome.visible:return
    if requested_next or shot_time>=DWELL:return
    for candidate in event_candidates:
        var g:Dictionary=candidate.group
        if not population.groups.has(g) or scheduled_activity(g)=="":continue
        pending_activity=g;pending_activity_age=0.;stream_wait=0
        event_stats.reservations+=1
        if g.get("phase","")=="Greeting":g["camera_gather_until"]=population.social_clock+8.
        if "--activity-test" in OS.get_cmdline_user_args():print("EVENT SCHEDULED ",scheduled_activity(g)," stats=",JSON.stringify(event_stats))
        break

func activity_shot(dt:float,snap:bool):
    var ids:=activity_members()
    var lead:Resident=herd[ids[0]]
    var bounds:=shot_box(lead)
    var names:=PackedStringArray()
    for id in ids:
        var peer:Resident=herd[id];bounds=bounds.merge(shot_box(peer));names.append(peer.species_title)
    # Keep the viewing side steady when a marching leader turns toward its peers.
    var angle:=event_yaw
    if activity_kind in ["Ball play","Playing together"]:
        var along:Vector3=herd[ids[1]].body.position-lead.body.position
        angle=atan2(along.x,along.z)+PI*.5
        if cos(angle-event_yaw)<0:angle+=PI
        if not activity_ended and is_instance_valid(activity_group.get("ball")):
            bounds=bounds.merge(AABB(activity_group.ball.position-Vector3.ONE*.12,Vector3.ONE*.24))
    var aim:=bounds.get_center()
    var radius:float
    yaw=angle if snap else orbit_toward(angle,dt)
    radius=fit_distance(bounds,yaw)*maxf(1.,pow(1.13,zoom_step))
    var pos:=aim+Vector3(sin(yaw),.32,cos(yaw)).normalized()*radius
    camera.near=clampf(radius*.06,.015,.35)
    position_camera(pos,aim,dt,snap,0.)
    update_scenery_view(ids)
    resident_tag.show_activity("Around the ranch" if activity_ended else activity_kind,names)
    resident_tag.visible=activity_watch>0. or (cut_overlay.color.a<.15 and camera_target.distance_to(aim)<maxf(.25,radius*.12))
    if resident_tag.visible:resident_tag.modulate.a=1.
    if resident_tag.visible:activity_watch+=dt
    if resident_tag.visible and not activity_group.get("photo_"+activity_kind,false) and "--activity-test" in OS.get_cmdline_user_args():
        if ids.all(func(id):return herd[id].visual!=null and herd[id].visual_mix>.9):
            activity_group["photo_"+activity_kind]=true;capture_activity(activity_kind)
    dock_buttons["Next"].tooltip_text="Leave activity"

func aim_camera(dt:float,snap:bool=false):
    if tour.is_empty():return
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL if overview else Camera3D.PROJECTION_PERSPECTIVE
    for marker in biome_labels:marker.visible=overview
    if overview:
        camera.size=maxf(232,350/get_viewport().get_visible_rect().size.aspect())*pow(1.13,zoom_step)
    if not activity_group.is_empty() and not overview:
        activity_shot(dt,snap);return
    var current:Resident=herd[tour[tour_index]]
    var following:Resident=herd[tour[tour_index+1]]
    var progress:=clampf((shot_time-DWELL-RECORD_FADE)/(LONG_CUT if distant_pair else PAN),0,1)
    var blend:float=(1.0 if progress>=.5 else 0.0) if distant_pair else smoothstep(0,1,progress)
    var opacity:=sin(progress*PI) if distant_pair and not overview else 0.0
    if distant_pair and progress>=.5 and not overview and not tour_cut_done:
        snap=true;tour_cut_done=true;opacity=1.
    var pos:=current.body.position.lerp(following.body.position,blend)
    var height:=lerpf(current.height,following.height,blend)
    var lift:=sin(blend*PI)*minf(1.4,current.body.position.distance_to(following.body.position)*.08)
    var radius:=8.2+height*.85+lift*.4
    var aim:=pos+Vector3.UP*clampf(height*.44,.45,1.8)
    var elevation:=4.2+height*.35+lift
    if (close_camera or current.group or following.group) and not overview:
        var current_box:=social_box(current)
        var next_box:=social_box(following)
        var distance:=lerpf(fit_distance(current_box,yaw),fit_distance(next_box,yaw),blend)
        radius=distance/sqrt(1.0+.31*.31)+lift*.4
        elevation=radius*.31+lift
        aim=current_box.get_center().lerp(next_box.get_center(),blend)
    var zoom_factor:=pow(1.13,zoom_step)
    radius*=zoom_factor
    elevation*=zoom_factor
    camera.near=clampf(radius*.12,.015,.35) if close_camera and not overview else .35
    var angle:=lerp_angle(portrait_angle(current),portrait_angle(following),blend)
    yaw=angle if snap else orbit_toward(angle,dt)
    var cam_pos:=aim+Vector3(sin(yaw)*radius,elevation,cos(yaw)*radius)
    if visit_left>0 and not overview:
        var weight:=smoothstep(0,1,visit_left)
        aim=aim.lerp(visit_point+Vector3.UP*.6,weight)
        cam_pos=cam_pos.lerp(visit_point+Vector3(sin(yaw)*8,5,cos(yaw)*8)*zoom_factor,weight)
    if overview:
        aim=Vector3(0,0,-2);cam_pos=aim+(Vector3(4,33,25)*land.Shape.UNIT-aim)*zoom_factor
    position_camera(cam_pos,aim,dt,snap,opacity)
    if overview:
        for i in biome_labels.size():
            var pt:Vector2=land.Shape.CENTERS[i]*land.Shape.UNIT
            var screen:=camera.unproject_position(Vector3(pt.x,land.ground(pt)+1.5,pt.y))
            biome_labels[i].position=screen-biome_labels[i].size*.5
    var featured:Resident=following if blend>.5 else current
    var settled:=camera_target.distance_to(aim)<maxf(.12,radius*.08) and camera.position.distance_to(cam_pos)<maxf(.28,radius*.25)
    if overview or visit_left>0:
        resident_tag.hide()
        resident_tag.modulate.a=0.
    elif current!=following and shot_time>DWELL:
        # Start only after the next model is ready. Finish the outgoing fade
        # before moving the camera, then introduce the new record on approach.
        var incoming:=progress>=.5
        resident_tag.show_subject(following if incoming else current)
        var alpha:=smoothstep(.5,.96,progress) if incoming else 1.-smoothstep(0.,RECORD_FADE,shot_time-DWELL)
        resident_tag.modulate.a=alpha
        resident_tag.visible=alpha>0.
    else:
        var continuing:=resident_tag.visible and resident_tag.last_subject==current.slot
        var ready:=display_style=="Shiny sprites" or current.asset.is_empty() or (current.visual and current.visual_mix>.85)
        if continuing or (ready and settled and cut_overlay.color.a<.15):
            if not continuing:resident_tag.modulate.a=0.
            resident_tag.show_subject(current)
            resident_tag.show()
            resident_tag.modulate.a=move_toward(resident_tag.modulate.a,1.,dt/RECORD_FADE)
            if settled:settled_watch+=dt
        else:resident_tag.hide()
    var subjects:Array=[]
    if not overview and visit_left<=0:
        subjects=[featured.slot]
        for id in featured.group.get("members",[]):
            if id!=featured.slot and subjects.size()<3:subjects.append(id)
    update_scenery_view(subjects)
    focus_seen[featured.title]=true
    dock_buttons["Next"].tooltip_text="Next · "+featured.title

func visit_map(screen:Vector2):
    if tour.is_empty():return
    var hit=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
    if hit==null:return
    var origin:=camera.project_ray_origin(screen);var ray:=camera.project_ray_normal(screen)
    for refinement in 4:
        var pt:=Vector2(hit.x,hit.z)
        var surface:=maxf(-.03*land.Shape.RISE,land.ground(pt))
        hit=Plane(Vector3.UP,surface).intersects_ray(origin,ray)
        if hit==null:return
    var closest_node:int=land.navigation.get_closest_point(Vector2(hit.x,hit.z))
    if closest_node<0 or land.points[closest_node].distance_to(Vector2(hit.x,hit.z))>12:return
    var best:=tour_index
    var distance:=INF
    for i in tour.size():
        var d:float=herd[tour[i]].body.position.distance_squared_to(hit)
        if d<distance:distance=d;best=i
    var previous=tour[tour_index];tour[tour_index]=tour[best];tour[best]=previous
    overview=false;visit_point=hit;visit_left=4;shot_time=0
    plan_next_stop();aim_camera(1,true);update_stream()
    for r in herd:population.refresh_proxy(self,r)
    dock_buttons["Map"].tooltip_text="Map"

func _unhandled_input(event):
    if settings.visible or finder.visible:return
    if event is InputEventMouseButton and event.pressed:
        if overview and event.button_index==MOUSE_BUTTON_LEFT:visit_map(event.position)
        elif event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom_step=maxi(-4,zoom_step-1)
        elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom_step=mini(4,zoom_step+1)
        else:return
        get_viewport().set_input_as_handled()

func _unhandled_key_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_H and not query.has_focus() and not name_edit.has_focus():
            dock_action("Hide/Show");return
        if event.keycode==KEY_S and not query.has_focus() and not name_edit.has_focus():
            if settings.visible:settings.hide();ui_layer.visible=not hide_ui
            else:open_settings()
            return
        if settings.visible:
            if event.keycode==KEY_ESCAPE:settings.hide();ui_layer.visible=not hide_ui
            return
        if finder.visible:
            if event.keycode==KEY_ESCAPE:finder.hide()
            return
        match event.keycode:
            KEY_EQUAL,KEY_PLUS,KEY_KP_ADD:zoom_step=maxi(-4,zoom_step-1)
            KEY_MINUS,KEY_KP_SUBTRACT:zoom_step=mini(4,zoom_step+1)
            KEY_0,KEY_KP_0:zoom_step=0
            KEY_F:
                if not allow_f:return
                display_style="Shiny sprites" if display_style=="3D residents" else "3D residents"
                save_settings();get_tree().call_deferred("reload_current_scene")
            KEY_D:
                if not hide_ui:dock_action("Find")
            KEY_SPACE:dock_action("Map")
            KEY_N:dock_action("Next")
            KEY_P:dock_action("Pause")
            KEY_ESCAPE:get_tree().quit()

var cycle=preload("res://ranch_cycle.gd").new()

func on_dinner_bell():
    dinner_banner.announce("Breakfast Time!" if cycle.breakfast else ("Lunch Time!" if cycle.lunch else "Dinner Time!"))
    leave_activity(DWELL)
    for group in population.groups:
        if group.has("ball") and is_instance_valid(group.ball):group.ball.queue_free()
        for id in group.members:population.light_residents[id].group={}
    population.groups.clear()

func _process(delta):
    if cycle.is_inside_tree():cycle.tick(delta,paused)
    if expected_count==0:
        camera.size=maxf(232,350/get_viewport().get_visible_rect().size.aspect())*pow(1.13,zoom_step)
        if not paused:
            ranch_time+=minf(delta,.1);land.tick(ranch_time)
        return
    if herd.size()!=expected_count:return
    if paused:return
    if filtered_night!=cycle.night or filtered_meal!=cycle.mealtime:
        filtered_night=cycle.night
        filtered_meal=cycle.mealtime
        var watched:int=tour[tour_index] if not tour.is_empty() else -1
        leave_activity(DWELL);show_event_members([]);next_tour(true)
        # Keep the same portrait across dawn/dusk whenever it remains eligible.
        # Otherwise approach the nearest eligible resident without a black cut.
        if not tour.is_empty():
            var chosen:int=tour.find(watched)
            if chosen<0:
                var nearest:=INF
                for j in tour.size():
                    var distance:float=herd[tour[j]].body.position.distance_squared_to(camera_target)
                    if distance<nearest:nearest=distance;chosen=j
            var first=tour[0];tour[0]=tour[chosen];tour[chosen]=first
        fade_clock=-1.;phase_camera_grace=8.;cut_overlay.color.a=0.
        visit_left=0.;shot_time=0.
        if not tour.is_empty():plan_next_stop()
    var dt:=minf(delta,.1)
    phase_camera_grace=maxf(0.,phase_camera_grace-dt)
    advance_material_fades(dt)
    ranch_time+=dt;land.tick(ranch_time)
    if cycle.night or cycle.mealtime:pending_activity={}
    stream_wait-=dt
    if stream_wait<=0:
        update_stream();stream_wait=.10
    if population_enabled:
        population.advance(self,dt)
        if not cycle.night and not cycle.mealtime:notice_activity(dt)
    if tour.is_empty():
        resident_tag.hide()
        camera.projection=Camera3D.PROJECTION_ORTHOGONAL
        camera.size=350;camera.position=Vector3(4,33,25)*land.Shape.UNIT;camera.look_at(Vector3.ZERO)
        return
    visit_left=maxf(0,visit_left-dt)
    if activity_group.is_empty() and not overview and visit_left<=0:
        var upcoming:Resident=herd[tour[tour_index+1]]
        var wait_for_target:=not pending_activity.is_empty() or display_style!="Shiny sprites" and not upcoming.asset.is_empty() and (not upcoming.visual or not upcoming.render_ready or upcoming.visual_mix<1.0) and not upcoming.failed
        var subject:Resident=herd[tour[tour_index]]
        if preparing_shot:
            setup_elapsed+=dt
            var focus_ready:=display_style=="Shiny sprites" or subject.asset.is_empty() or subject.failed or (subject.visual!=null and subject.render_ready and subject.visual_mix>=1)
            if focus_ready and (not neighbors_waiting or setup_elapsed>=5.0):preparing_shot=false
        else:
            portrait_age+=dt
            if shot_time<=DWELL and not requested_next and settled_watch<MIN_VISIBLE_SHOT and portrait_age<DWELL*2 and not subject.failed:
                shot_time=minf(shot_time+dt,DWELL-.05)
            else:shot_time=minf(shot_time+dt,DWELL) if wait_for_target and shot_time<=DWELL else shot_time+dt
        if shot_time>=DWELL+RECORD_FADE+(LONG_CUT if distant_pair else PAN):
            advance_tour()
    aim_camera(dt)
    if measuring and ranch_time>=2:
        var now:=Time.get_ticks_usec()
        if previous_us:
            frame_seconds.append((now-previous_us)/1000000.0)
        else:sample_start=now
        previous_us=now
        if now-sample_start>=10000000:
            frame_seconds.sort()
            var moved:=0
            for r in herd:
                if r.traveled>.01:moved+=1
            print("SCALE ",JSON.stringify({"count":herd.size(),"fps":frame_seconds.size()*1000000.0/(now-sample_start),"p95_ms":1000*frame_seconds[floori(frame_seconds.size()*.95)],"moved":moved,"3d":animated.size(),"sprites":population.loaded_art,"markers":population.markers}))
            get_tree().quit()
    if audit:
        audit_frames+=1;audit_delta_total+=delta
        if audit_frames==900:
            var moved:=0
            var trips:=0
            var retries:=0
            for r in herd:
                if r.traveled>0.2:moved+=1
                trips+=r.trips;retries+=r.aborted
            print("AUDIT ",JSON.stringify({"outside_validated_edges":off_route,"moved":moved,"trips":trips,"reroutes":retries,"featured":focus_seen.size(),"fps":audit_frames/audit_delta_total}))
            get_tree().quit()

# Observation only: preserve the normal tour and record the rendered frames.
func capture_activity(tag:String):
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("user://activity-"+tag+".png")
