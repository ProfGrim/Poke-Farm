extends RefCounted

# Indexed in the game's nature stat order: Attack, Defense, Speed, Sp. Atk, Sp. Def.
const NATURES=["Hardy","Lonely","Brave","Adamant","Naughty","Bold","Docile","Relaxed","Impish","Lax","Timid","Hasty","Serious","Jolly","Naive","Modest","Mild","Quiet","Bashful","Rash","Calm","Gentle","Sassy","Careful","Quirky"]
const FRUIT=[301,305,303,302,304]
static var templates:Dictionary={}

static func menu(nature:String,rng:RandomNumberGenerator)->Array:
    var index:=NATURES.find(nature.strip_edges().capitalize())
    var preferred:=floori(index/5.)
    var avoided:=index%5
    var result:Array=[]
    for i in 4:
        var choices:=FRUIT.duplicate()
        if index>=0 and preferred!=avoided:
            choices.erase(FRUIT[avoided])
            if i<2:choices=[FRUIT[preferred]]
        result.append(choices[rng.randi_range(0,choices.size()-1)])
    return result

static func add_fruit(parent:Node3D,id:int,pos:Vector3,width:float,angle:float):
    if not templates.has(id):
        var path:="res://map/dinner-%d.glb"%id
        if not FileAccess.file_exists(path):return
        var doc:=GLTFDocument.new()
        var state:=GLTFState.new()
        if doc.append_from_buffer(FileAccess.get_file_as_bytes(path),"",state)!=OK:return
        var tree:=doc.generate_scene(state)
        var original:MeshInstance3D=tree.find_children("*","MeshInstance3D",true,false)[0]
        var transform:=original.transform
        var ancestor:=original.get_parent()
        while ancestor is Node3D:
            transform=ancestor.transform*transform
            ancestor=ancestor.get_parent()
        var box:AABB=transform*original.get_aabb()
        templates[id]=[original.mesh,transform,box]
        tree.free()
    var data:Array=templates[id]
    var box:AABB=data[2]
    var basis:=Basis(Vector3.UP,angle).scaled(Vector3.ONE*width/maxf(.001,box.size[box.size.max_axis_index()]))
    var fruit:=MeshInstance3D.new()
    fruit.mesh=data[0]
    fruit.transform=Transform3D(basis,pos-basis*box.get_center())*data[1]
    parent.add_child(fruit)
