extends PanelContainer

var cycle
var text:=Label.new()
var badge:=Control.new()

func _ready():
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    size_flags_horizontal=Control.SIZE_SHRINK_CENTER
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);add_child(row)
    badge.custom_minimum_size=Vector2(22,24);row.add_child(badge)
    badge.draw.connect(draw_badge)
    text.add_theme_color_override("font_color",Color("#244d44"))
    text.add_theme_font_size_override("font_size",14);row.add_child(text)
    tooltip_text="Ranch time"

func draw_badge():
    if cycle and cycle.night:
        badge.draw_circle(Vector2(11,12),8,Color("#7187b1"))
        badge.draw_circle(Vector2(15,9),7,Color("#fff5de"))
    else:
        badge.draw_circle(Vector2(11,12),5,Color("#d69a36"))
        for i in 8:
            var direction:=Vector2.from_angle(i*TAU/8.)
            badge.draw_line(Vector2(11,12)+direction*7,Vector2(11,12)+direction*10,Color("#d69a36"),1.5,true)

func _process(_dt):
    if not cycle:return
    var minutes:int=cycle.clock_minutes()
    var hour:int=minutes/60
    text.text="%d:%02d %s"%[12 if hour%12==0 else hour%12,minutes%60,"AM" if hour<12 else "PM"]
    badge.queue_redraw()
