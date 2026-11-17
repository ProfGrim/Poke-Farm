extends PanelContainer

var kicker:=Label.new()
var shiny_icon:=TextureRect.new()
var headline:=Label.new()
var subtitle:=Label.new()
var details:=VBoxContainer.new()
var trainer_line:=Label.new()
var origin_line:=Label.new()
var ball_line:=HBoxContainer.new()
var ball_icon:=TextureRect.new()
var ball_name:=Label.new()
var sprite_sheet:Texture2D
var last_subject=-1
var last_group:=""

func _ready():
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    position=Vector2(12,12)
    var plate:=preload("res://meadow_theme.gd").box("#224c46ef",18)
    plate.border_color=Color("#e6cb85");plate.set_border_width_all(1)
    plate.content_margin_left=14;plate.content_margin_right=14
    add_theme_stylebox_override("panel",plate)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",2);add_child(column)
    column.add_child(kicker)
    var name_row:=HBoxContainer.new();column.add_child(name_row)
    name_row.add_child(headline);name_row.add_child(shiny_icon);column.add_child(subtitle)
    shiny_icon.texture=ImageTexture.create_from_image(Image.load_from_file("res://map/resident-shiny.png"))
    shiny_icon.stretch_mode=TextureRect.STRETCH_KEEP_CENTERED
    shiny_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    shiny_icon.accessibility_name="Shiny Pokémon";shiny_icon.hide()
    kicker.add_theme_font_size_override("font_size",11);kicker.add_theme_color_override("font_color",Color("#e6cb85"))
    headline.add_theme_font_size_override("font_size",20);headline.add_theme_color_override("font_color",Color("#fff5de"))
    column.add_child(details)
    var rule:=ColorRect.new();rule.color=Color("#55776b");rule.custom_minimum_size.y=1
    rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(rule)
    details.add_theme_constant_override("separation",3)
    details.add_child(trainer_line);details.add_child(origin_line);details.add_child(ball_line)
    ball_line.add_child(ball_icon);ball_line.add_child(ball_name)
    ball_icon.custom_minimum_size=Vector2(22,22);ball_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    ball_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;ball_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    for field in [subtitle,trainer_line,origin_line,ball_name]:
        field.add_theme_font_size_override("font_size",13);field.add_theme_color_override("font_color",Color("#d8e8de"))
    sprite_sheet=ImageTexture.create_from_image(Image.load_from_file("res://map/capture-balls.png"))

func show_subject(actor):
    kicker.text="SNACKING" if actor.meal and actor.dinner_day<0 else "RESIDENT RECORD"
    if last_subject==actor.slot:return
    last_subject=actor.slot;last_group=""
    var info:Dictionary=actor.info
    var nickname:=str(info.get("nickname",""))
    var named:=bool(info.get("nicknamed",nickname!="" and nickname!=info.get("name",""))) and nickname!=""
    shiny_icon.visible=bool(info.get("shiny",true))
    headline.text=nickname if named else actor.species_title
    subtitle.text=(actor.species_title+"   ·   " if named else "")+("Lv. "+str(int(info.level)) if info.has("level") else "")
    var gender=info.get("gender")
    if typeof(gender) in [TYPE_INT,TYPE_FLOAT] and int(gender) in [0,1]:
        subtitle.text+=("   ·   " if subtitle.text!="" else "")+("Male" if gender==0 else "Female")
    subtitle.visible=subtitle.text!=""
    trainer_line.text="OT   "+str(info.get("ot","—"))+"     ID   "+str(info.get("trainerId","—"))
    origin_line.text=str(info.get("nature","Unknown"))+" nature   ·   "+str(info.get("origin","Origin unknown"))
    var id:=int(info.get("ballId",0));ball_icon.visible=id>0 and id<=37
    if ball_icon.visible:
        var icon:=AtlasTexture.new();icon.atlas=sprite_sheet;icon.region=Rect2((id%8)*32+6,floori(id/8.)*32+6,20,20);ball_icon.texture=icon
    ball_name.text=("Hisuian " if id in [28,29,30,34] else "")+str(info.get("ball","Capture ball unknown"))
    for field in [headline,subtitle,trainer_line,origin_line,ball_name]:field.text=clean_display_text(field.text)
    details.show();reset_size()

func show_activity(kind:String,names:PackedStringArray):
    var roster:="\n".join(names)
    if last_group==kind+roster:return
    last_subject=-1;last_group=kind+roster
    kicker.text="MEADOW EVENT";headline.text=kind;subtitle.text=clean_display_text(roster);subtitle.show()
    shiny_icon.hide();details.hide();reset_size()

# Repair known UTF-8 text decoded as Windows-1252 by older save readers.
# Match exact broken sequences; preserve legitimate names and accents.
static func clean_display_text(value:String)->String:
    value=value.replace("Ã©","é")
    value=value.replace("Â·","·")
    value=value.replace("â€™","’")
    value=value.replace("â€”","—")
    value=value.replace("â™€","♀")
    value=value.replace("â™‚","♂")
    return value
