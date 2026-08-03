extends Control
## Boot — the first screen. Shows the training-aid disclaimer before anything
## else, because the project rule "simulator performance never equals legal
## certification" is only real if the learner sees it before they play, not
## buried in a settings page they never open.
##
## Advances on any key, or automatically after a few seconds so an unattended
## demo machine still reaches the menu.

const UiKit := preload("res://ui/ui_kit.gd")
const DWELL_S := 4.5

var _t := 0.0
var _moved := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UiKit.BG_SOLID
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-420, -170)
	box.custom_minimum_size = Vector2(840, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	box.add_child(UiKit.label(Loc.t("app_title"), 34, UiKit.TEXT))
	box.add_child(UiKit.label(Loc.t("app_sub"), 15, UiKit.ACCENT))
	box.add_child(UiKit.spacer(18))
	box.add_child(UiKit.separator())
	box.add_child(UiKit.spacer(10))

	var d := UiKit.wrapped(Loc.t("disclaimer"), 15, 840, UiKit.TEXT)
	box.add_child(d)

	box.add_child(UiKit.spacer(22))
	var go := UiKit.button(Loc.t("menu_continue"), true, 320)
	go.pressed.connect(_advance)
	box.add_child(go)
	go.grab_focus()

	# Headless test runs must not sit on a title card for five seconds.
	if OS.get_cmdline_user_args().has("--selftest"):
		_advance()


func _process(delta: float) -> void:
	_t += delta
	if _t >= DWELL_S:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_advance()


func _advance() -> void:
	if _moved:
		return
	_moved = true
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
