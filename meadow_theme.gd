extends RefCounted

static func box(color:String,radius:int=9)->StyleBoxFlat:
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(color);style.set_corner_radius_all(radius)
    style.shadow_color=Color(0.05,.15,.12,.18);style.shadow_size=3;style.shadow_offset=Vector2(0,2)
    style.content_margin_left=12;style.content_margin_right=12
    style.content_margin_top=7;style.content_margin_bottom=7
    return style

static func meadow()->Theme:
    var t:=Theme.new();t.default_font_size=15
    for kind in ["Button","OptionButton","CheckBox"]:
        var normal:=box("#39766c",13);normal.border_color=Color("#69a99a");normal.set_border_width_all(1)
        var hover:=box("#519989",13);hover.border_color=Color("#d9c77e");hover.set_border_width_all(2)
        var pressed:=box("#285c56",13);pressed.border_color=Color("#f1dc92");pressed.set_border_width_all(2)
        var focus:=hover.duplicate() as StyleBoxFlat;focus.shadow_color=Color("#efd98c55");focus.shadow_size=5
        t.set_stylebox("normal",kind,normal)
        t.set_stylebox("hover",kind,hover)
        t.set_stylebox("pressed",kind,pressed)
        t.set_stylebox("focus",kind,focus)
        t.set_stylebox("disabled",kind,box("#2d4f49aa",13))
        t.set_color("font_color",kind,Color("#f5fff5"))
        t.set_color("font_hover_color",kind,Color("#fff4cf"))
    for kind in ["LineEdit","ItemList"]:
        var field:=box("#142f37",11);field.border_color=Color("#416c67");field.set_border_width_all(1)
        t.set_stylebox("normal" if kind=="LineEdit" else "panel",kind,field)
    var edit_focus:=box("#183b40",11);edit_focus.border_color=Color("#dfca7d");edit_focus.set_border_width_all(2)
    t.set_stylebox("focus","LineEdit",edit_focus)
    t.set_stylebox("selected","ItemList",box("#258170"))
    t.set_stylebox("selected_focus","ItemList",box("#258170"))
    t.set_stylebox("panel","AcceptDialog",box("#183c40",14))
    t.set_color("font_color","Label",Color("#edf8eb"))
    return t
