extends RefCounted

const ART={
    "Hide/Show":'<circle cx="12" cy="12" r="9" fill="#fff6dd"/><path d="M3 12a9 9 0 0 1 18 0Z" fill="#eb7165"/><circle cx="12" cy="12" r="2.8" fill="#fff6dd"/>',
    "Map":'<path d="m2 5 6-2 8 3 6-2v15l-6 2-8-3-6 2z" fill="#a3d7b4"/><path d="M8 3v15m8-12v15"/>',
    "Pause":'<rect x="5" y="4" width="5" height="16" rx="1" fill="#ffe6a7"/><rect x="14" y="4" width="5" height="16" rx="1" fill="#ffe6a7"/>',
    "Resume":'<path d="m6 3 15 9-15 9z" fill="#ffe6a7"/>',
    "Find":'<circle cx="10" cy="10" r="6.5" fill="#a5deda"/><path d="m15 15 6 6" stroke="#ffe7bb" stroke-width="3"/>',
    "Next":'<path d="m4 5 10 7-10 7zm10 0 8 7-8 7z" fill="#f4cc99"/>',
    "Deposits":'<path d="m3 9 3-5h12l3 5v11H3z" fill="#afd4e7"/><path d="M3 10h5l2 3h4l2-3h5"/>',
    "Settings":'<path d="m9 3 1-2h4l1 3 3 1 2-1 2 4-2 2v4l2 2-2 4-3-1-3 1-1 3H9l-1-3-3-1-2 1-2-4 2-2v-4L1 8l2-4 3 1z" fill="#bfd2c8"/><circle cx="11.5" cy="12" r="3.5" fill="#345952"/>'
}

static func icon(action:String)->Texture2D:
    var img:=Image.new()
    img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24"><g stroke="#24483f" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round" fill="none">'+ART[action]+'</g></svg>')
    return ImageTexture.create_from_image(img)
