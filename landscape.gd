extends Node3D

const MAP_SCALE:=2.75
var land_count:=0
var pond_outline:=PackedVector2Array()
var navigation := AStar2D.new()
var points := PackedVector2Array()
var obstacles: Array
var water_material: StandardMaterial3D
var barriers: Array

func triples(values: Array) -> PackedVector3Array:
    var result := PackedVector3Array()
    for i in range(0,values.size(),3):
        result.append(Vector3(values[i],values[i+1],values[i+2]))
    return result

func pairs(values: Array) -> PackedVector2Array:
    var result := PackedVector2Array()
    for i in range(0,values.size(),2):
        result.append(Vector2(values[i],values[i+1]))
    return result

func transform_from(m: Array) -> Transform3D:
    var basis := Basis(Vector3(m[0],m[1],m[2]),Vector3(m[4],m[5],m[6]),Vector3(m[8],m[9],m[10]))
    return Transform3D(basis,Vector3(m[12],m[13],m[14]))

func build():
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://map/ranch.json"))
    var materials := {}
    var textures := {}
    for id in data.mats:
        var row: Dictionary = data.mats[id]
        var mat := StandardMaterial3D.new()
        mat.albedo_color=Color("#"+row.color)
        mat.roughness=1
        mat.cull_mode=BaseMaterial3D.CULL_DISABLED if row.doubleSided else BaseMaterial3D.CULL_BACK
        if row.alphaTest>0:
            mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            mat.alpha_scissor_threshold=row.alphaTest
        elif row.transparent:mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        if row.basic:mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        if row.get("texture"):
            var key:String=row.texture
            if not textures.has(key):
                var img := Image.load_from_file("res://map/"+key+".png")
                if row.flip:img.flip_y()
                # Double the tile to reproduce the original mirrored-repeat ground texture.
                if row.mirror:
                    var tile := Image.create(img.get_width()*2,img.get_height()*2,false,img.get_format())
                    var size:=img.get_size()
                    for y in 2:
                        for x in 2:
                            var part:Image=img.duplicate()
                            if x:part.flip_x()
                            if y:part.flip_y()
                            tile.blit_rect(part,Rect2i(Vector2i.ZERO,size),Vector2i(x,y)*size)
                    img=tile
                img.generate_mipmaps()
                textures[key]=ImageTexture.create_from_image(img)
            mat.albedo_texture=textures[key]
            var factor:=0.5 if row.mirror else 1.0
            mat.uv1_scale=Vector3(row.repeat[0]*factor,row.repeat[1]*factor,1)
        if row.water:water_material=mat
        materials[id]=mat
    var geometries := {}
    for item in data.meshes:
        var geom_key:String=item.g+item.m
        if not geometries.has(geom_key):
            var g:Dictionary=data.geoms[item.g]
            var verts:=triples(g.pos)
            var indices:=PackedInt32Array(g.indices)
            if indices.is_empty():
                for i in verts.size():indices.append(i)
            for i in range(0,indices.size(),3):
                var swap:=indices[i+1];indices[i+1]=indices[i+2];indices[i+2]=swap
            var arrays: Array=[]
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX]=verts
            arrays[Mesh.ARRAY_INDEX]=indices
            if not g.normal.is_empty():arrays[Mesh.ARRAY_NORMAL]=triples(g.normal)
            if not g.uv.is_empty():arrays[Mesh.ARRAY_TEX_UV]=pairs(g.uv)
            var mesh:=ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
            var surface_material:StandardMaterial3D=materials[item.m]
            if item.name=="Bush_Common" and textures.has("foliage_Leaves_NormalTree_C"):
                surface_material=surface_material.duplicate()
                surface_material.albedo_texture=textures["foliage_Leaves_NormalTree_C"]
            mesh.surface_set_material(0,surface_material)
            geometries[geom_key]=mesh
        var batch:=MultiMesh.new()
        batch.transform_format=MultiMesh.TRANSFORM_3D
        batch.mesh=geometries[geom_key]
        batch.instance_count=item.matrices.size()
        for i in batch.instance_count:batch.set_instance_transform(i,transform_from(item.matrices[i]))
        var obj:=MultiMeshInstance3D.new()
        obj.name=item.name
        obj.multimesh=batch
        add_child(obj)
    scale=Vector3(MAP_SCALE,1,MAP_SCALE)
    obstacles=data.solidPlots
    for box in obstacles:
        for i in 4:box[i]*=MAP_SCALE
    barriers=data.barriers
    for row in data.nodes:
        var point:=Vector2(row[0],row[1])*MAP_SCALE
        navigation.add_point(points.size(),point)
        points.append(point)
    for i in points.size():
        for j in data.nodes[i][2]:
            if j>i:navigation.connect_points(i,j)
    land_count=points.size()
    for item in data.meshes:
        if not data.mats[item.m].water:continue
        var vertices:=triples(data.geoms[item.g].pos)
        for i in range(1,vertices.size()-1):pond_outline.append(Vector2(vertices[i].x,vertices[i].z)*MAP_SCALE)
        break
    build_pond_routes()
    dress_berry_bushes(data)

func dress_berry_bushes(data:Dictionary):
    var fruit:=SphereMesh.new()
    fruit.radius=.054;fruit.height=.115;fruit.radial_segments=8;fruit.rings=4
    var cap:=CylinderMesh.new()
    cap.top_radius=.009;cap.bottom_radius=.025;cap.height=.022;cap.radial_segments=5
    var green:=StandardMaterial3D.new();green.albedo_color=Color("#527341");cap.material=green
    var colors={"Oran":"5277bf","Pecha":"db8290","Sitrus":"d3ae4e"}
    for patch in data.patches:
        var canopy:=PackedVector3Array()
        for item in data.meshes:
            if not str(item.name).begins_with("Bush"):continue
            for matrix in item.matrices:
                var pose:=transform_from(matrix)
                if Vector2(pose.origin.x,pose.origin.z).distance_to(Vector2(patch[0],patch[1]))>.15:continue
                for point in triples(data.geoms[item.g].pos):canopy.append(pose*point)
        if canopy.is_empty():continue
        var bounds:=AABB(canopy[0],Vector3.ZERO)
        for point in canopy:bounds=bounds.expand(point)
        var mat:=StandardMaterial3D.new()
        mat.albedo_color=Color(colors.get(patch[2],"be7379"));mat.roughness=.88
        for i in 5:
            var angle:=i*2.4+float(patch[0])
            var target:=bounds.get_center()+bounds.size*Vector3(.43*cos(angle),.12+.15*sin(angle*2),.43*sin(angle))
            var anchor:=canopy[0]
            for point in canopy:
                if point.distance_squared_to(target)<anchor.distance_squared_to(target):anchor=point
            var berry:=MeshInstance3D.new();berry.mesh=fruit;berry.material_override=mat
            berry.position=anchor.lerp(bounds.get_center(),.06)+Vector3(0,-.024,0)
            # The map stretches in X and Z. Keep the ripe fruit round in world space.
            var size_factor:=.8+.08*(i%3)
            berry.scale=Vector3(1/MAP_SCALE,1,1/MAP_SCALE)*size_factor
            add_child(berry)
            var calyx:=MeshInstance3D.new();calyx.mesh=cap;calyx.position.y=.052;berry.add_child(calyx)

func build_pond_routes():
    var grid:Dictionary={}
    var extent:=Rect2(pond_outline[0],Vector2.ZERO)
    for pt in pond_outline:extent=extent.expand(pt)
    for x in range(ceili(extent.position.x/3),floori(extent.end.x/3)+1):
        for z in range(ceili(extent.position.y/3),floori(extent.end.y/3)+1):
            var pt:=Vector2(x*3,z*3)
            # Keep the body and the full navigation edge inside the shoreline.
            var safe:=Geometry2D.is_point_in_polygon(pt,pond_outline)
            for offset in [Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
                if not Geometry2D.is_point_in_polygon(pt+offset,pond_outline):safe=false;break
            if not safe:continue
            var id:=points.size();points.append(pt);navigation.add_point(id,pt)
            var cell:=Vector2i(x,z);grid[cell]=id
            for step in [Vector2i.LEFT,Vector2i.UP]:
                if grid.has(cell+step):navigation.connect_points(id,grid[cell+step])

func tick(t:float):
    if water_material:water_material.uv1_offset=Vector3(t*.025,t*.009,0)
