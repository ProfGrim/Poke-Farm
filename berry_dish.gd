extends RefCounted

static func piece(parent:Node3D,mesh:PrimitiveMesh,color:Color,pos:Vector3):
    var part:=MeshInstance3D.new()
    var material:=StandardMaterial3D.new();material.albedo_color=color
    part.mesh=mesh;part.material_override=material;part.position=pos;parent.add_child(part)

static func serve(actor,land)->Node3D:
    var dish:=Node3D.new();actor.body.add_child(dish)
    var size:float=minf(actor.food_height*.22,actor.food_width*.24)
    dish.position.z=actor.pose_box.end.z+size*.62 if absf(actor.facing_bias)<1. else actor.pose_box.position.z-size*.62
    var world:=dish.global_position
    world.y=land.ground(Vector2(world.x,world.z),actor.swimming)+.015;dish.global_position=world
    dish.scale=Vector3.ONE*size
    var base:=CylinderMesh.new();base.bottom_radius=.65;base.top_radius=1;base.height=.42;base.radial_segments=20
    piece(dish,base,Color("#c49763"),Vector3.UP*.21)
    var rim:=TorusMesh.new();rim.inner_radius=.84;rim.outer_radius=1.04;rim.rings=20;rim.ring_segments=8
    piece(dish,rim,Color("#e5bf88"),Vector3.UP*.44)
    var rng:=RandomNumberGenerator.new()
    rng.randomize()
    var berries:=preload("res://dinner_fruit.gd").menu(str(actor.info.get("nature","")),rng)
    for i in berries.size():
        var angle:=i*TAU/berries.size()
        preload("res://dinner_fruit.gd").add_fruit(dish,berries[i],Vector3(cos(angle)*.42,.64,sin(angle)*.42),.71,angle)
    return dish
