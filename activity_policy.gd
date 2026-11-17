extends RefCounted

# Quiet behaviors dominate the meadow. Strong emotions and calls remain rare,
# while a stable per-resident preference keeps individuals from feeling alike.
const BASE_WEIGHTS={
    "IdleAction":3.2,
    "IdleAlt":2.4,
    "Look":3.4,
    "Stretch":1.8,
    "Rest":1.5,
    "Happy":1.1,
    "Grumpy":0.32,
    "Lonely":0.22,
    "Call":0.55,
}

static func preference(asset_key:String,clip:String)->float:
    var value:int=abs(hash(asset_key+"|"+clip))%1000
    return lerpf(.72,1.34,float(value)/999.)

static func choose(player:AnimationPlayer,asset_key:String,last_clip:String,extra:Array[String],has_company:bool,rng:RandomNumberGenerator)->String:
    var choices:Array[String]=[]
    for clip in BASE_WEIGHTS:
        if player.has_animation(clip):choices.append(clip)
    for clip in extra:
        if player.has_animation(clip) and not choices.has(clip):choices.append(clip)
    if choices.is_empty():return ""
    var weights:Array[float]=[]
    var total:=0.0
    for clip in choices:
        var weight:float=float(BASE_WEIGHTS.get(clip,.75))*preference(asset_key,clip)
        if clip=="Lonely" and has_company:weight=0.
        elif clip=="Call":weight*=.55 if has_company else 1.25
        elif clip=="Happy" and has_company:weight*=1.18
        if clip==last_clip:weight*=.08
        weights.append(weight);total+=weight
    if total<=0:return ""
    var roll:=rng.randf()*total
    for i in choices.size():
        roll-=weights[i]
        if roll<=0:return choices[i]
    return choices.back()

