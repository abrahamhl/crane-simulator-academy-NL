extends CanvasLayer
## PauseMenu — Esc during a session. Doubles as the in-session controls
## reference, because the moment a player reaches for pause is usually the
## moment they have lost track of a key.

const UiKit := preload("res://ui/ui_kit.gd")

signal resume_requested
signal restart_requested
signal quit_requested

var root: Control
var controls_box: VBoxContainer


func build() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS   # must run while the tree is paused

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	root.add_child(UiKit.scrim(0.86))

	var columns := HBoxContainer.new()
	columns.set_anchors_preset(Control.PRESET_CENTER)
	columns.add_theme_constant_override("separation", 40)
	columns.position = Vector2(-430, -220)
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UiKit.heading(Loc.t("paused"), 30))
	left.add_child(UiKit.spacer(10))

	var resume := UiKit.button(Loc.t("menu_resume"), true)
	resume.pressed.connect(func(): resume_requested.emit())
	left.add_child(resume)

	var restart := UiKit.button(Loc.t("menu_restart"))
	restart.pressed.connect(func(): restart_requested.emit())
	left.add_child(restart)

	var lang := UiKit.button("%s: %s" % [Loc.t("set_language"), Loc.lang_name()])
	lang.pressed.connect(func():
		Loc.cycle()
		lang.text = "%s: %s" % [Loc.t("set_language"), Loc.lang_name()]
		_rebuild_controls())
	left.add_child(lang)

	left.add_child(UiKit.spacer(6))
	var quit := UiKit.button(Loc.t("menu_to_menu"))
	quit.pressed.connect(func(): quit_requested.emit())
	left.add_child(quit)

	var right := UiKit.panel(UiKit.PANEL, 16)
	columns.add_child(right)
	controls_box = VBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 3)
	right.add_child(controls_box)


func set_shown(shown: bool, spec: Dictionary = {}) -> void:
	root.visible = shown
	if shown:
		_spec = spec
		_rebuild_controls()


var _spec: Dictionary = {}


func _rebuild_controls() -> void:
	for c in controls_box.get_children():
		c.queue_free()
	if _spec.is_empty():
		return
	controls_box.add_child(UiKit.label(MachineCatalog.display_name(_spec), 18, UiKit.ACCENT))
	controls_box.add_child(UiKit.label(Loc.t("ctrl_universal"), 12, UiKit.ACCENT_2))
	controls_box.add_child(UiKit.spacer(6))
	for row in ControlScheme.reference_rows(_spec):
		if row.has("header"):
			controls_box.add_child(UiKit.spacer(8))
			controls_box.add_child(UiKit.label(String(row.header), 14, UiKit.ACCENT))
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var k := UiKit.label(String(row.keys), 13, UiKit.ACCENT_2)
		k.custom_minimum_size = Vector2(150, 0)
		line.add_child(k)
		line.add_child(UiKit.label(String(row.text), 13, UiKit.TEXT))
		controls_box.add_child(line)
