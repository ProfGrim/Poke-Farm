extends Node
# Hide alternate drum/stick props while hands blend between their two poses.
var player:AnimationPlayer
var parts:Array=[]
var previous:String=""
var remaining:=0.0
func _ready():
    configure(get_parent(),JSON.parse_string(FileAccess.get_file_as_string("res://map/ranch_visibility.json")).get("herd_0812_00",{}))
func configure(root:Node,rules:Dictionary):
    player=root.find_children("*","AnimationPlayer",true,false)[0]
    for mesh in root.find_children("*","MeshInstance3D",true,false):
        if rules.has(String(mesh.name)):parts.append([mesh,rules[String(mesh.name)]])
    process_priority=100
func _process(delta:float):
    step(delta)
func step(delta:float):
    var clip:=String(player.current_animation)
    if clip!=previous:
        if previous in ["Idle","Walk"] and clip in ["Idle","Walk"]:remaining=.30
        previous=clip
    else:remaining=maxf(0.,remaining-delta)
    for part in parts:part[0].visible=remaining<=0. and not part[1].has(clip) and not part[1].has("*")
