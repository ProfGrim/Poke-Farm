extends RefCounted

var seats:Dictionary={}
const Fruit=preload("res://dinner_fruit.gd")

func eligible(r)->bool:
    return r.food_height<=3.0 and r.food_width<=6.0 and r.player and not r.swimming and not r.stationary and r.altitude<.25 and not r.meal and not seats.has(r) and r.player.has_animation("EatStart") and r.player.has_animation("Eat") and r.player.has_animation("EatEnd")

func is_small(r)->bool:
    return r.food_height<=1.6 and r.food_width<=1.6

func try_seat(ranch,first):
    if not eligible(first) or ranch.cycle.meal_remaining<25.:return
    var diners:Array=[first]
    var small:=is_small(first)
    var capacity:=8 if small else 3
    for r in ranch.animated:
        if r==first or not eligible(r) or r.home_zone!=first.home_zone:continue
        if is_small(r)!=small:continue
        if maxf(first.food_height,r.food_height)>minf(first.food_height,r.food_height)*1.8:continue
        if r.body.position.distance_to(first.body.position)>maxf(9. if small else 6.,first.radius*9.):continue
        diners.append(r)
        if diners.size()==capacity:break
    if diners.size()<3:return
    var center:=Vector2.ZERO
    var smallest:=INF
    for r in diners:
        center+=ranch.point_of(r)
        smallest=minf(smallest,minf(r.food_height,r.food_width))
    center/=diners.size()
    var size:=smallest*.36
    var widest:=0.
    for r in diners:widest=maxf(widest,r.food_width*.5)
    var minimum_ring:float=(widest+size*.1)/sin(PI/diners.size())
    var spread:=size
    var start:float=(ranch.point_of(first)-center).angle()
    diners.sort_custom(func(a,b):return fposmod((ranch.point_of(a)-center).angle()-start,TAU)<fposmod((ranch.point_of(b)-center).angle()-start,TAU))
    var targets:Array=[]
    for i in diners.size():
        var r=diners[i]
        var reach:=absf(r.pose_box.end.z if absf(r.facing_bias)<1. else r.pose_box.position.z)
        var target:=center+Vector2.from_angle(start+i*TAU/diners.size())*maxf(minimum_ring,spread*.85+minf(reach,r.food_width*.6))
        var pos:Vector2=ranch.point_of(r)
        for j in range(1,9):
            var step:=pos.lerp(target,j/8.)
            if not ranch.land.Shape.inside(step,r.radius) or ranch.land.Shape.lake_r(step.x/ranch.land.Shape.UNIT,step.y/ranch.land.Shape.UNIT)<1.12:return
            for rock in ranch.land.obstacles:
                if step.distance_to(Vector2(rock[0],rock[1]))<maxf(rock[2],rock[3])+r.radius:return
        targets.append(target)
    var pile:=Node3D.new()
    ranch.land.add_child(pile)
    pile.global_position=Vector3(center.x,ranch.land.ground(center),center.y)
    pile.scale=Vector3.ONE*size
    var group:Dictionary={"members":diners,"targets":targets,"center":center,"pile":pile,"ready":false}
    for r in diners:seats[r]=group
    var rng:RandomNumberGenerator=ranch.rng
    var menu:Array=[]
    for r in diners:menu.append_array(Fruit.menu(str(r.info.get("nature","")),rng))
    var fullness:=clampf(minimum_ring/maxf(.001,size*7.),1.,3.)
    var layers:=ceili((6.+(diners.size()-3)*.8)*fullness)
    for layer in layers:
        var radius:float=(layers-1-layer)*.15
        var count:=maxi(1,11-layer*2) if fullness==1. and diners.size()==3 else maxi(1,ceili(TAU*radius/.43))
        for j in count:
            var angle:=j*TAU/count+layer*.61
            Fruit.add_fruit(pile,menu[rng.randi_range(0,menu.size()-1)],Vector3(cos(angle)*radius,.20+layer*.32,sin(angle)*radius),.56,angle)

func cancel(group):
    for member in group.members:
        seats.erase(member)
        if member.meal:
            member.meal.queue_free()
            member.meal=null
    group.pile.queue_free()

func advance(ranch,dt:float):
    var seen:Dictionary={}
    for r in seats.keys():
        if not seats.has(r):continue
        var g:Dictionary=seats[r]
        if seen.has(g.pile):continue
        seen[g.pile]=true
        if not ranch.cycle.mealtime or ranch.cycle.meal_remaining<=.35 or g.members.any(func(m):return not m.player):
            cancel(g)
            continue
        if g.ready:continue
        var ready:=true
        for i in g.members.size():
            var m=g.members[i]
            var pos:Vector2=ranch.point_of(m)
            var next:=pos.move_toward(g.targets[i],maxf(.4,m.speed)*dt)
            var moving:=next.distance_to(g.targets[i])>.015
            var direction:Vector2=(next-pos) if moving else (g.center-next)
            m.body.rotation.y=rotate_toward(m.body.rotation.y,atan2(direction.x,direction.y)-m.facing_bias,dt*4.)
            m.body.position=Vector3(next.x,ranch.land.ground(next)+m.altitude,next.y)
            ranch.population.place(m.slot,m,0)
            ranch.population.set_wandering(m,moving)
            if not moving and m.player.current_animation!="Idle":m.player.play("Idle",.15)
            var facing:float=atan2(direction.x,direction.y)-m.facing_bias
            ready=ready and not moving and absf(angle_difference(m.body.rotation.y,facing))<.12
        if ready:
            g.ready=true
            g.started=ranch.cycle.meal_elapsed
