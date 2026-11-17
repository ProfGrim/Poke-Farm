extends AcceptDialog

const LIBRARY="user://deposits.cfg"
const LEGACY_APP_NAME="Shiny Ranch"
var library:=ConfigFile.new()
var deposited:Dictionary={}
var use_deposits:=true
var species_forms:Dictionary={}
var listing:=ItemList.new()
var status:=Label.new()
var picker:=FileDialog.new()
var deposit:=Button.new()
var pasture:=Button.new()
var ranch
var candidates:Array=[]
var found:=OptionButton.new()
var box_filter:=OptionButton.new()
var selection_label:=Label.new()
var picks:Dictionary={}
var missing_regular_art:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://map/regular-missing-art.json"))
var regular_sheet:Image
var regular_atlas:Texture2D
var sheet_image:Image
var atlas:Texture2D
var shiny_only:=CheckBox.new()
var searched:=false
var managing:=false
var manage:=Button.new()
var confirm_remove:=ConfirmationDialog.new()
var save_rows:Array=[]
var save_boxes:=PackedStringArray()
var saved_box:=0
var heading:=Label.new()
var instructions:=Label.new()
var sources:=HBoxContainer.new()
var box_label:=Label.new()
var select_all:=Button.new()
var clear_selection:=Button.new()
var loaded_save:=false

func toggle_manage():
    picks.clear();listing.clear()
    if not managing:
        save_rows=candidates
        saved_box=box_filter.selected
        save_boxes.clear()
        for i in box_filter.item_count:save_boxes.append(box_filter.get_item_text(i))
        candidates=deposited.values()
        box_filter.clear();box_filter.add_item("All deposits")
        var boxes:Dictionary={}
        for row in candidates:boxes[box_name(row.location)]=true
        for box in boxes:box_filter.add_item(box)
    else:
        candidates=save_rows
        box_filter.clear()
        for box in save_boxes:box_filter.add_item(box)
        if saved_box>=0:box_filter.select(saved_box)
    managing=not managing
    heading.text="Manage ranch Pokémon" if managing else "Deposit Pokémon"
    instructions.text="Select ranch copies to remove, then choose Remove selected." if managing else "1  Choose a save    ›    2  Choose Pokémon    ›    3  Add them to your ranch"
    sources.visible=not managing
    shiny_only.visible=not managing
    manage.text="Back to deposits" if managing else "Manage ranch Pokémon"
    deposit.text="Remove selected…" if managing else "Add selected to ranch"
    refresh();show_box()

func request_action():
    if not managing:commit();return
    if picks.is_empty():return
    confirm_remove.dialog_text="Remove %d selected ranch copies? You can deposit them again from the original save."%picks.size()
    if use_deposits and picks.size()==deposited.size():confirm_remove.dialog_text+=" Your ranch will be empty."
    confirm_remove.popup_centered()

func remove_selected():
    if not managing or picks.is_empty():return
    var next:=deposited.duplicate()
    for id in picks:next.erase(id)
    if save_collection(next,use_deposits):
        ranch.get_tree().call_deferred("reload_current_scene")


func open_boxes():
    var trainer_profile:=ConfigFile.new()
    if trainer_profile.load("user://trainer.cfg")==OK:title=str(trainer_profile.get_value("player","name","Trainer"))+"’s ranch storage"
    popup_centered(Vector2i(780,485))
    if searched:return
    searched=true;found.add_item("Finding saves…")
    call_deferred("discover")

func discover():
    var roots:Array=[OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS),OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Poke-Farm/Saves"),OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Shiny Ranch/Saves")]
    for base in ["Ryujinx/bis/user/save","yuzu/nand/user/save","Ryubing/bis/user/save"]:
        roots.append(OS.get_environment("APPDATA").path_join(base))
    var files:Array=[]
    for base in roots:
        var pending:Array=[[base,0]];var visited:=0
        while not pending.is_empty() and visited<220:
            var pair=pending.pop_front();var dir:=DirAccess.open(pair[0]);visited+=1
            if not dir:continue
            for file in dir.get_files():
                if file=="main":files.append(str(pair[0]).path_join(file))
            if int(pair[1])<6 and base!=roots[0]:
                for sub in dir.get_directories():
                    if not dir.is_link(sub):pending.append([str(pair[0]).path_join(sub),int(pair[1])+1])
    found.clear();found.add_item("Choose a detected save" if files.size() else "No saves detected — use Browse files")
    for path in files:
        found.add_item(str(path).trim_suffix("/main").get_file()+"  ·  "+str(path).get_base_dir().get_base_dir().get_file())
        var idx:=found.item_count-1;found.set_item_metadata(idx,path);found.get_popup().set_item_tooltip(idx,path)

func box_name(location:String)->String:
    return "Party" if location.begins_with("Party") else location.get_slice(",",0)

func has_art(row:Dictionary,entry:Dictionary)->bool:
    if row.get("shiny",true):return not str(entry.get("art","")).is_empty()
    return entry.has("tile") and not missing_regular_art.has(str(int(entry.tile)))

func update_count():
    selection_label.text="%d Pokémon selected"%picks.size()
    deposit.disabled=picks.is_empty()
    clear_selection.disabled=picks.is_empty()

func show_box():
    listing.clear()
    if not atlas:
        sheet_image=Image.load_from_file("res://map/shiny-atlas.png");atlas=ImageTexture.create_from_image(sheet_image)
    if not regular_atlas:
        regular_sheet=Image.load_from_file("res://map/regular-atlas.png");regular_atlas=ImageTexture.create_from_image(regular_sheet)
    for i in candidates.size():
        var row=candidates[i]
        if not managing and shiny_only.button_pressed and not row.shiny:continue
        if box_filter.selected>0 and box_name(row.location)!=box_filter.get_item_text(box_filter.selected):continue
        var entry:Dictionary=species_forms.get(form_key(row),{})
        var icon:=AtlasTexture.new();icon.atlas=atlas if row.get("shiny",true) else regular_atlas;var t:=int(entry.get("tile",0))
        var tile:=Rect2i((t%40)*64,floori(float(t)/40)*64,64,64)
        var ink:=(sheet_image if row.get("shiny",true) else regular_sheet).get_region(tile).get_used_rect()
        icon.region=Rect2(tile.position+ink.position,ink.size) if ink.has_area() else Rect2(tile)
        var species_label:String=ranch.form_titles.get(form_key(row),row.name)
        var display_name:String=row.nickname+" · "+species_label if row.get("nicknamed",false) else species_label
        var slot:=listing.add_item(display_name,icon if has_art(row,entry) else null)
        listing.set_item_metadata(slot,i);listing.set_item_tooltip(slot,"%s · %s · Lv. %d · %s"%[species_label,"Shiny" if row.get("shiny",true) else "Regular",int(row.level),row.location])
        if picks.has(row.id):listing.select(slot,false)
    update_count()

func migrate_legacy_deposits():
    if FileAccess.file_exists(LIBRARY):return
    var appdata:=OS.get_environment("APPDATA")
    if appdata.is_empty():return
    var legacy:=appdata.path_join("Godot/app_userdata").path_join(LEGACY_APP_NAME).path_join("deposits.cfg")
    if not FileAccess.file_exists(legacy):return
    var destination:=ProjectSettings.globalize_path(LIBRARY)
    DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
    var error:=DirAccess.copy_absolute(legacy,destination)
    if error!=OK:push_warning("Could not migrate legacy deposits.cfg: %s"%error_string(error))

func setup(owner_ranch,catalog:Array):
    ranch=owner_ranch
    for row in catalog:
        species_forms[form_key(row)]=row
    migrate_legacy_deposits()
    if library.load(LIBRARY)==OK:
        deposited=library.get_value("collection","residents",{})
        use_deposits=library.get_value("collection","active",false)
    theme=preload("res://meadow_theme.gd").meadow()
    wrap_controls=false;max_size=Vector2i(840,560);title="Pokémon storage";size=Vector2i(840,560)
    var frame:=Control.new();add_child(frame)
    var panel:=VBoxContainer.new();panel.add_theme_constant_override("separation",8);frame.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    get_ok_button().text="Back to meadow"
    heading.text="Deposit Pokémon";heading.add_theme_font_size_override("font_size",24);panel.add_child(heading)
    instructions.text="1  Choose a save    ›    2  Choose Pokémon    ›    3  Add them to your ranch";panel.add_child(instructions)
    panel.add_child(sources)
    var save_label:=Label.new();save_label.text="Save file";sources.add_child(save_label)
    sources.add_child(found);found.size_flags_horizontal=Control.SIZE_EXPAND_FILL;found.item_selected.connect(func(i):if i>0:preview(found.get_item_metadata(i)))
    var load_button:=Button.new();load_button.text="Choose a save file…";sources.add_child(load_button)
    load_button.pressed.connect(func():picker.popup_centered_ratio(.8))
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status)
    var filters:=HBoxContainer.new();panel.add_child(filters)
    box_label.text="Box";filters.add_child(box_label)
    box_filter.add_item("Choose a save first")
    filters.add_child(box_filter);box_filter.item_selected.connect(func(_i):show_box())
    shiny_only.text="Shinies only";filters.add_child(shiny_only)
    shiny_only.toggled.connect(func(_enabled):picks.clear();show_box())
    filters.add_child(selection_label)
    listing.select_mode=ClassDB.class_get_integer_constant("ItemList","SELECT_TOGGLE") if ClassDB.class_has_integer_constant("ItemList","SELECT_TOGGLE") else ItemList.SELECT_MULTI
    listing.max_columns=6;listing.fixed_column_width=108;listing.icon_mode=ItemList.ICON_MODE_TOP
    listing.fixed_icon_size=Vector2i(48,48);listing.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(listing)
    listing.multi_selected.connect(func(i,selected):
        var row=candidates[listing.get_item_metadata(i)]
        if selected:picks[row.id]=true
        else:picks.erase(row.id)
        update_count())
    var buttons:=HBoxContainer.new();panel.add_child(buttons)
    select_all.text="Select all shown";buttons.add_child(select_all)
    select_all.pressed.connect(func():
        for i in listing.item_count:
            listing.select(i,false);picks[candidates[listing.get_item_metadata(i)].id]=true
        update_count())
    clear_selection.text="Clear selection";buttons.add_child(clear_selection)
    clear_selection.pressed.connect(func():picks.clear();listing.deselect_all();update_count())
    var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.add_child(spacer)
    deposit.text="Add selected to ranch";buttons.add_child(deposit);deposit.pressed.connect(request_action)
    var secondary:=HBoxContainer.new();panel.add_child(secondary)
    secondary.add_child(manage);manage.text="Manage ranch Pokémon";manage.pressed.connect(toggle_manage)
    confirm_remove.title="Remove from ranch";confirm_remove.ok_button_text="Remove";add_child(confirm_remove);confirm_remove.confirmed.connect(remove_selected)
    secondary.add_child(pasture);pasture.pressed.connect(switch_pasture)
    picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.access=FileDialog.ACCESS_FILESYSTEM
    picker.title="Select a game save (.sav, .dsv, main, or another supported save)";add_child(picker);picker.file_selected.connect(preview)
    refresh();update_count()

func form_key(row:Dictionary)->String:
    return "%d/%d/%s"%[int(row.species),int(row.form),str(int(row.sweet)) if row.get("sweet")!=null else "-"]

func refresh():
    if managing:
        status.text="%d Pokémon currently in your ranch. Removing one never changes the original save."%deposited.size()
    elif loaded_save:
        status.text="Choose the Pokémon you want to copy into your ranch. Your save file will not be changed."
    else:
        status.text="Choose a detected save above, or select a save file from your computer. Your original save stays untouched."
    pasture.text="Use built-in showcase" if use_deposits else "Use my deposited Pokémon"
    pasture.tooltip_text="Temporarily show the included showcase ranch" if use_deposits else "Return to the Pokémon you deposited"
    pasture.disabled=not use_deposits and deposited.is_empty()
    manage.disabled=deposited.is_empty() and not managing
    box_filter.disabled=not managing and not loaded_save
    shiny_only.disabled=not loaded_save
    select_all.disabled=candidates.is_empty()
    clear_selection.disabled=picks.is_empty()
    deposit.disabled=picks.is_empty()

func preview(path:String):
    if managing:toggle_manage()
    loaded_save=false;candidates.clear();picks.clear();box_filter.clear();listing.clear();refresh();update_count()
    var reader:=OS.get_executable_path().get_base_dir().path_join("Save Reader/Inventory.exe")
    if OS.has_feature("editor"):
        var source_build:=ProjectSettings.globalize_path("res://tools/save-reader/bin/Release/net9.0/Inventory.exe")
        var legacy_build:=ProjectSettings.globalize_path("res://").path_join("../Shiny Ranch for Windows/Save Reader/Inventory.exe")
        reader=source_build if FileAccess.file_exists(source_build) else legacy_build
    var out:Array=[]
    if not FileAccess.file_exists(reader):
        status.text="Save Reader is missing. Keep its folder beside Poke-Farm.exe.";return
    if OS.execute(reader,[path],out,true)!=0:
        status.text="Could not read this save. Choose an intact, decrypted Generation 1–9 save file. The reader requires .NET 9.";return
    var data=JSON.parse_string("".join(out))
    if not data is Dictionary or not data.has("rows"):status.text="The save reader returned no inventory.";return
    loaded_save=true
    var normal:=0;var missing:=0;var known:=0;var seen:Dictionary={}
    var refreshed:=deposited.duplicate()
    var upgrades:=0
    for row in data.rows:
        if not row.shiny:normal+=1
        var entry:Dictionary=species_forms.get(form_key(row),{})
        if entry.is_empty() or (not has_art(row,entry) and (not entry.model or (not row.shiny and not ranch.regular_materials.has(entry.model)))):missing+=1;continue
        if deposited.has(row.id):
            var old:Dictionary=deposited[row.id]
            if not old.has("trainerId") and form_key(old)==form_key(row):
                var upgraded:=old.duplicate()
                for field in ["ot","trainerId","nature","origin","ball","ballId","nicknamed"]:upgraded[field]=row[field]
                refreshed[row.id]=upgraded;upgrades+=1
            known+=1;continue
        if seen.has(row.id):known+=1;continue
        seen[row.id]=true;row["game"]=data.game
        candidates.append(row)
    if upgrades:
        if not save_collection(refreshed,use_deposits):return
        for actor in ranch.herd:
            var id=actor.info.get("id","")
            if refreshed.has(id):actor.info=refreshed[id]
        ranch.resident_tag.last_subject=-1
    box_filter.add_item("All eligible")
    var boxes:Dictionary={}
    for row in candidates:boxes[box_name(row.location)]=true
    for box in boxes:box_filter.add_item(box)
    refresh()
    show_box()
    update_count()
    status.text="%d available to add · %d already in your ranch · %d unavailable artwork · %d regular · %d eggs · %d unreadable"%[candidates.size(),known,missing,normal,int(data.eggs),data.invalid.size()]
    if upgrades:status.text+=" · %d records updated"%upgrades

func save_collection(next:Dictionary,active:bool)->bool:
    var copy:=ConfigFile.new();copy.set_value("collection","residents",next);copy.set_value("collection","active",active)
    if copy.save(LIBRARY+".tmp")!=OK or DirAccess.rename_absolute(LIBRARY+".tmp",LIBRARY)!=OK:
        status.text="Could not save the deposits. Your existing collection is unchanged.";return false
    deposited=next;use_deposits=active;return true

func commit():
    var next:=deposited.duplicate()
    for i in listing.get_selected_items():picks[candidates[listing.get_item_metadata(i)].id]=true
    for row in candidates:
        if picks.has(row.id):next[row.id]=row
    if next.size()==deposited.size():status.text="Select at least one Pokémon first.";return
    if save_collection(next,true):ranch.get_tree().call_deferred("reload_current_scene")

func switch_pasture():
    if save_collection(deposited,not use_deposits):ranch.get_tree().call_deferred("reload_current_scene")

func pasture_rows()->Array:
    var rows:Array=[];var wet:=0;var dry:=0
    for resident in deposited.values():
        if ranch.display_limit and rows.size()>=ranch.display_limit:break
        var entry:Dictionary=species_forms.get(form_key(resident),{})
        if entry.is_empty():continue
        if int(entry.species) in ranch.POND_SPECIES:
            if wet>=ranch.land.points.size()-ranch.land.land_count:continue
            wet+=1
        else:
            if dry>=ranch.land.land_count:continue
            dry+=1
        var own:=entry.duplicate();own["deposit_record"]=resident;own["depositor_name"]=resident.nickname;rows.append(own)
    return rows
