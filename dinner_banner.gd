extends Control

var age:=0.
var caption:="Dinner Time!"
func _ready():
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    offset_left=-160;offset_right=160;offset_top=91;offset_bottom=171
    hide();set_process(false)

func announce(text:String="Dinner Time!"):
    caption=text;queue_redraw()
    age=0.;modulate.a=0.;show();set_process(true)

func _process(dt):
    age+=dt
    modulate.a=smoothstep(0.,.32,age)*(1.-smoothstep(4.,5.,age))
    if age>=5.:hide();set_process(false)

func _draw():
    var gold:=Color("#ffdc91")
    for flip in [false,true]:
        var tail:=PackedVector2Array()
        for pt in [Vector2(7,32),Vector2(51,22),Vector2(55,58),Vector2(13,68),Vector2(23,47)]:
            tail.append(Vector2(320-pt.x if flip else pt.x,pt.y))
        draw_colored_polygon(tail,Color("#d98073"))
    var face:=PackedVector2Array()
    for i in 33:
        var t:=i/32.;face.append(Vector2(35+250*t,22.-15.*sin(t*PI)))
    for i in range(32,-1,-1):
        var t:=i/32.;face.append(Vector2(35+250*t,78.-15.*sin(t*PI)))
    draw_colored_polygon(face,Color("#fff1d5"));face.append(face[0]);draw_polyline(face,gold,2.,true)
    var font:=ThemeDB.fallback_font
    draw_string(font,Vector2(40,38), caption,HORIZONTAL_ALIGNMENT_CENTER,240,24,Color("#325f50"))
    for x in [29,291]:
        var center:=Vector2(x,39)
        draw_circle(center,13,Color("#335a50"))
        draw_circle(center,11,Color("#fff9e9"))
        var cap:=PackedVector2Array([center])
        for i in 17:cap.append(center+Vector2.from_angle(PI+i*PI/16.)*11)
        draw_colored_polygon(cap,Color("#e87e70"))
        draw_line(center+Vector2(-11,0),center+Vector2(11,0),Color("#335a50"),2.)
        draw_circle(center,4,Color("#335a50"));draw_circle(center,2.5,Color("#fff9e9"))
    draw_string(font,Vector2(40,55),"Berries for everyone",HORIZONTAL_ALIGNMENT_CENTER,240,12,Color("#687d60"))
