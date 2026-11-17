extends RefCounted
const DATA:="res://map/ranch_visibility.json"

static func apply(root:Node,rules:Dictionary)->int:
    if rules.is_empty():return 0
    var players=root.find_children("*","AnimationPlayer",true,false)
    if players.is_empty():return 0
    var player:AnimationPlayer=players[0]
    var base:=player.get_node(player.root_node)
    var applied:=0
    for mesh in root.find_children("*","MeshInstance3D",true,false):
        var name:=String(mesh.name)
        if not rules.has(name):continue
        applied+=1
        var hidden:Array=rules[name]
        if hidden.has("*"):
            mesh.visible=false;continue
        mesh.visible=not hidden.has("Idle")
        var target:=NodePath(str(base.get_path_to(mesh))+":visible")
        for clip in player.get_animation_list():
            var anim:=player.get_animation(clip)
            var track:=anim.find_track(target,Animation.TYPE_VALUE)
            if track<0:track=anim.add_track(Animation.TYPE_VALUE);anim.track_set_path(track,target)
            anim.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
            anim.track_insert_key(track,0.0,not hidden.has(String(clip)))
    return applied
