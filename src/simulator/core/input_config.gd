extends Node
## InputConfig — registers the whole input map in code, so actions exist in
## headless runs and the project file needs no editor-authored [input] block.
##
## The bindings themselves are DOCUMENTED in control_scheme.gd, which is what
## the HUD, the F1 card and the tutorial read. This file only wires physical
## keys and gamepad inputs to the action names that module refers to. If the
## two ever disagree, control_scheme.gd is the specification and this file is
## the bug.
##
## Key choices worth stating, because the previous build's overlap is exactly
## what made the crane feel broken:
##   * The machine axes NEVER share a key with an on-foot action. W drives the
##     bridge only while operating and walks only while on foot, but hoist is
##     R/F and interact is E, so no key means two different machine things.
##   * SPACE is jump on foot and ALL STOP while operating. That collision is
##     deliberate: the reflex "hit the big key to make it stop" is worth
##     training, and you cannot jump while holding a pendant anyway.
##   * BACKSPACE resets, not R — R is the hoist. Resetting a lift by accident
##     while reaching for "raise" was a real hazard in the old layout.

const KEYS := {
	# --- on foot ---------------------------------------------------------
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],

	# --- machine axes (see ControlScheme.AXIS_ACTIONS) --------------------
	"prim_pos": [KEY_W],        # reach out / bridge forward / telescope out
	"prim_neg": [KEY_S],        # reach in
	"lat_pos": [KEY_D],         # right / slew right
	"lat_neg": [KEY_A],         # left / slew left
	"hoist_up": [KEY_R],        # RAISE
	"hoist_down": [KEY_F],      # lower ("fall")
	"luff_up": [KEY_T],         # boom up
	"luff_down": [KEY_G],       # boom down
	"trav_pos": [KEY_E],        # rail travel forward (railway crane only)
	"trav_neg": [KEY_Q],        # rail travel back

	# --- machine commands -------------------------------------------------
	"fine_mode": [KEY_SHIFT],
	"all_stop": [KEY_SPACE],
	"outriggers_toggle": [KEY_O],
	"load_chart": [KEY_H],
	"signal_call": [KEY_B],
	"exit_machine": [KEY_X],
	"sim_reset": [KEY_BACKSPACE],
	"inspect_1": [KEY_1],
	"inspect_2": [KEY_2],
	"inspect_3": [KEY_3],
	"inspect_4": [KEY_4],

	# --- global -----------------------------------------------------------
	"camera_cycle": [KEY_TAB],
	"cam_reset": [KEY_C],
	"help_toggle": [KEY_F1],
	"map_toggle": [KEY_M],
	"lang_toggle": [KEY_L],
	"wind_toggle": [KEY_V],
	"pause_menu": [KEY_ESCAPE],
	"ui_confirm_alt": [KEY_ENTER, KEY_KP_ENTER],
	"toggle_mouse_capture": [KEY_F2],

	# --- free camera orbit -------------------------------------------------
	"cam_orbit_left": [KEY_LEFT],
	"cam_orbit_right": [KEY_RIGHT],
	"cam_orbit_up": [KEY_UP],
	"cam_orbit_down": [KEY_DOWN],
	"cam_zoom_in": [KEY_EQUAL],
	"cam_zoom_out": [KEY_MINUS],
}

## Gamepad: a crane has two joysticks in real life, so the mapping is close to
## the real thing — left stick drives the machine in plan, right stick handles
## the boom and the rope. Sticks are analogue, which matters: a real control
## lever is proportional and the fine-mode key is a poor substitute for it.
const PAD_AXES := {
	"lat_pos": [JOY_AXIS_LEFT_X, 1.0],
	"lat_neg": [JOY_AXIS_LEFT_X, -1.0],
	"prim_pos": [JOY_AXIS_LEFT_Y, -1.0],
	"prim_neg": [JOY_AXIS_LEFT_Y, 1.0],
	"luff_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"luff_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"hoist_up": [JOY_AXIS_RIGHT_X, -1.0],
	"hoist_down": [JOY_AXIS_RIGHT_X, 1.0],
}

const PAD_BUTTONS := {
	"fine_mode": [JOY_BUTTON_LEFT_SHOULDER],
	"all_stop": [JOY_BUTTON_B],
	"interact": [JOY_BUTTON_A],
	"exit_machine": [JOY_BUTTON_X],
	"camera_cycle": [JOY_BUTTON_RIGHT_SHOULDER],
	"pause_menu": [JOY_BUTTON_START],
	"load_chart": [JOY_BUTTON_Y],
	"map_toggle": [JOY_BUTTON_BACK],
}

const DEADZONE := 0.22


func _enter_tree() -> void:
	for action in KEYS:
		_ensure(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

	for action in PAD_AXES:
		_ensure(action)
		var spec: Array = PAD_AXES[action]
		var ev := InputEventJoypadMotion.new()
		ev.axis = spec[0]
		ev.axis_value = spec[1]
		InputMap.action_add_event(action, ev)
		InputMap.action_set_deadzone(action, DEADZONE)

	for action in PAD_BUTTONS:
		_ensure(action)
		for button in PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


## Actions are cleared before rebinding so a reload never stacks duplicate
## events onto the same action (which silently doubles analogue input).
func _ensure(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)


## The physical key currently bound to an action, for printing on the HUD.
## Returns "" when the action is pad-only.
func key_label(action: String) -> String:
	var keys: Array = KEYS.get(action, [])
	if keys.is_empty():
		return ""
	return OS.get_keycode_string(keys[0])
