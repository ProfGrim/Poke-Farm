extends "res://landscape.gd"
const Shape=preload("res://biome_shape.gd")
const NAMES=["Clover Downs","Fernwood Hollow","Reedwater Lake","Ember Terraces","Frostpine Ridge"]
const STEP:=3.35
var cutaway_materials:Array[ShaderMaterial]=[]
var cutaway_count:=0
var preferences:Dictionary
var zones:=PackedInt32Array()

func build():
    add_child(preload("res://map/biome_world.scn").instantiate())
    prepare_cutaways(get_child(0))
    preferences=JSON.parse_string(FileAccess.get_file_as_string("res://map/biome_preferences.json"))
    var rocks:Array=JSON.parse_string(FileAccess.get_file_as_string("res://map/biome_obstacles.json"))
    var blocked={}
    for rock in rocks:
        obstacles.append([rock[0],rock[1],rock[2],rock[2]])
        var p:=Vector2(rock[0],rock[1])
        var cell:=Vector2i(roundi(p.x/STEP),roundi(p.y/STEP))
        for dx in range(-2,3):
            for dz in range(-2,3):
                var near:=cell+Vector2i(dx,dz)
                # Extra clearance keeps edges connecting adjacent nodes clear as well.
                if (Vector2(near)*STEP).distance_to(p)<float(rock[2])+STEP*.65:blocked[near]=true
    for aquatic in [false,true]:
        var grid={}
        for x in range(-50,51):
            for z in range(-34,35):
                var cell:=Vector2i(x,z);var pt:=Vector2(cell)*STEP
                if blocked.has(cell) or not Shape.inside(pt,6.0):continue
                var lake:=Shape.lake_r(pt.x/Shape.UNIT,pt.y/Shape.UNIT)
                if (aquatic and lake>.78) or (not aquatic and lake<1.16):continue
                var id:=points.size();grid[cell]=id;points.append(pt);zones.append(Shape.region(pt))
                navigation.add_point(id,pt)
                for dir in [Vector2i.LEFT,Vector2i.UP]:
                    if grid.has(cell+dir):navigation.connect_points(id,grid[cell+dir])
        if not aquatic:land_count=points.size()
    for i in 144:
        var angle:=i*TAU/144.
        var dir:=Vector2(7*cos(angle),4.7*sin(angle));var lo:=0.;var hi:=1.4
        for j in 14:
            var m:float=(lo+hi)*.5;var pt:=Vector2(-12,6)+dir*m
            if Shape.height_at(pt.x,pt.y)<-.03:lo=m
            else:hi=m
        pond_outline.append((Vector2(-12,6)+dir*lo)*Shape.UNIT)

func ground(pt:Vector2,swimming:bool=false)->float:
    return -.03*Shape.RISE if swimming else Shape.ground(pt)

func preferred(row:Dictionary)->int:
    return preferences.get("%d/%d"%[int(row.species),int(row.form)],0)

func prepare_cutaways(world:Node):
    # Props retain their existing mesh batches. Terrain and water have their own
    # shaders and are never candidates for a cutaway.
    var converted:Dictionary={}
    for node in world.get_children():
        var mesh:Mesh
        if node is MultiMeshInstance3D:mesh=node.multimesh.mesh
        elif node is MeshInstance3D:mesh=node.mesh
        else:continue
        if not mesh or mesh.get_surface_count()!=1:continue
        var source:Material=node.material_override if node.material_override else mesh.surface_get_material(0)
        if mesh is PlaneMesh and source is ShaderMaterial and "glint" in source.shader.code:
            var lake_material:=ShaderMaterial.new()
            lake_material.shader=preload("res://reedwater.gdshader")
            node.material_override=lake_material
            continue
        if not source is StandardMaterial3D:continue
        if not converted.has(source):
            var mat:=ShaderMaterial.new();mat.shader=preload("res://scenery_cutaway.gdshader")
            mat.set_shader_parameter("tint",source.albedo_color)
            if source.albedo_texture:mat.set_shader_parameter("albedo_map",source.albedo_texture)
            mat.set_shader_parameter("uv_scale",Vector2(source.uv1_scale.x,source.uv1_scale.y))
            mat.set_shader_parameter("use_vertex_color",source.vertex_color_use_as_albedo)
            if source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
                mat.set_shader_parameter("alpha_cut",source.alpha_scissor_threshold)
            cutaway_materials.append(mat);converted[source]=mat
        node.material_override=converted[source]

func update_cutaways(eye:Vector3,targets:PackedVector4Array):
    if targets.is_empty() and cutaway_count==0:return
    cutaway_count=targets.size()
    targets.resize(3)
    for mat in cutaway_materials:
        mat.set_shader_parameter("subject_count",cutaway_count)
        if cutaway_count:
            mat.set_shader_parameter("camera_eye",eye)
            mat.set_shader_parameter("subjects",targets)
