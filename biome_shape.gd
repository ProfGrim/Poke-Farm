extends RefCounted
const UNIT:=7.0
const RISE:=1.7
const CENTERS=[Vector2(0,2),Vector2(-9,-4),Vector2(-12,6),Vector2(12,5),Vector2(8,-8)]
static func lake_r(x:float,z:float)->float:
    return Vector2((x+12)/7.,(z-6)/4.7).length()+.06*sin(z*1.1)+.04*cos(x*.77)
static func height_at(x:float,z:float)->float:
    var snow=exp(-Vector2((x-9)/8.,(z+9)/6.).length_squared())
    var rock=exp(-Vector2((x-14)/7.,(z-5)/7.).length_squared())
    var land=.5+.16*sin(x*.62+z*.33)+snow*(4.5+.65*cos(x*.85))+rock*(1.4+.27*sin(x*.7))
    return lerpf(-.72,land,smoothstep(.74,1.13,lake_r(x,z)))

static func rim(a:float)->float:return 1.+.045*sin(3*a)+.026*cos(5*a)
static func inside(pt:Vector2,inset:float)->bool:
    var v:=Vector2(pt.x/23.,pt.y/15.)/UNIT
    return v.length()<rim(v.angle())-inset/(15.*UNIT)
static func ground(pt:Vector2)->float:return height_at(pt.x/UNIT,pt.y/UNIT)*RISE
static func region(pt:Vector2)->int:
    var q:=pt/UNIT;var best:=0
    for i in range(1,CENTERS.size()):
        if q.distance_squared_to(CENTERS[i])<q.distance_squared_to(CENTERS[best]):best=i
    return best
