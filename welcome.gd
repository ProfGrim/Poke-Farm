extends AcceptDialog
var farm:LineEdit
var trainer:LineEdit
var profile:=ConfigFile.new()
var guide:Label
var ranch
var profile_path:="user://trainer.cfg"
var panel:VBoxContainer

func setup(owner_ranch):
    ranch=owner_ranch;theme=preload("res://meadow_theme.gd").meadow()
    profile.load(profile_path)
    var existing:=str(profile.get_value("player","name",""))
    var saved_farm:=str(profile.get_value("player","ranch_name","")).strip_edges()
    if not saved_farm.is_empty() and not existing.is_empty():ranch.label.text=saved_farm;return
    trainer=LineEdit.new();guide=Label.new();panel=VBoxContainer.new()
    wrap_controls=false;max_size=Vector2i(540,350);title="Welcome to Shiny Ranch";exclusive=true;dialog_hide_on_ok=false;get_ok_button().hide()
    size=Vector2i(540,320);add_child(panel);panel.add_theme_constant_override("separation",14)
    var title_label:=Label.new();title_label.text="🌿   Welcome to your meadow";title_label.add_theme_font_size_override("font_size",27);panel.add_child(title_label)
    guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    guide.text="Choose your trainer name and a name for your ranch. Visit your ranch or deposit copies from a save. The built-in meadow is available in Deposits."
    panel.add_child(guide);trainer.placeholder_text="Trainer name";trainer.max_length=30;panel.add_child(trainer)
    trainer.text=existing
    farm=LineEdit.new();farm.placeholder_text="Ranch name";farm.max_length=32;panel.add_child(farm)
    var start:=Button.new();start.text="Continue to save boxes";panel.add_child(start);start.pressed.connect(complete.bind(true))
    var skip:=Button.new();skip.text="Visit my ranch first";panel.add_child(skip);skip.pressed.connect(complete.bind(false))
    trainer.text_submitted.connect(func(_name):farm.grab_focus())
    farm.text_submitted.connect(func(_name):complete(true))
    close_requested.connect(func():if not profile.has_section_key("player","ranch_name"):call_deferred("popup_centered"))
    call_deferred("popup_centered",Vector2i(540,350));(farm if not existing.is_empty() else trainer).call_deferred("grab_focus")

func complete(open_boxes:bool):
    var name_text:=trainer.text.strip_edges()
    if name_text.is_empty():guide.text="Enter a trainer name to continue.";trainer.grab_focus();return
    var ranch_name:=farm.text.strip_edges()
    if ranch_name.is_empty():guide.text="Give your ranch a name to continue.";farm.grab_focus();return
    profile.set_value("player","ranch_name",ranch_name)
    profile.set_value("player","name",name_text)
    if profile.save(profile_path)!=OK:guide.text="Could not save your trainer profile. Please try again.";return
    ranch.label.text=ranch_name
    hide()
    if open_boxes:ranch.deposits.open_boxes()
