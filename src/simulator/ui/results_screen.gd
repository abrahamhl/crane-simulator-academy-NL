extends CanvasLayer
## ResultsScreen — the debrief.
##
## A score with no explanation teaches nothing, so this screen leads with WHAT
## DECIDED IT: an itemised list of every deduction, in points, with the event
## that caused it named. A learner should be able to leave this screen able to
## state exactly why the lift failed and what to do differently — which is the
## same thing an assessor would ask them.

const UiKit := preload("res://ui/ui_kit.gd")

signal retry_requested
signal next_requested
signal menu_requested

var root: Control
var body: VBoxContainer


func build() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	root.add_child(UiKit.scrim(0.90))

	var panel := UiKit.panel(UiKit.BG_SOLID, 26)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -280)
	panel.custom_minimum_size = Vector2(720, 0)
	root.add_child(panel)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)


func show_result(result: Dictionary, scenario: Dictionary, spec: Dictionary) -> void:
	for c in body.get_children():
		c.queue_free()

	var passed := bool(result.get("passed", false))
	var verdict := UiKit.label(Loc.t("result_pass") if passed else Loc.t("result_fail"), 40,
		UiKit.OK if passed else UiKit.WARN)
	body.add_child(verdict)
	body.add_child(UiKit.label(Loc.pick(scenario.get("title", {})), 19, UiKit.TEXT))
	body.add_child(UiKit.label("%s · %s" % [MachineCatalog.display_name(spec),
		GameState.difficulty_name(String(result.get("difficulty", "standard")))],
		13, UiKit.TEXT_DIM))
	body.add_child(UiKit.separator())

	# Headline figures.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	_stat(grid, Loc.t("score_points"), "%.0f" % float(result.get("points", 0.0)))
	_stat(grid, Loc.t("score_time"), "%.0f s" % float(result.get("time_s", 0.0)))
	_stat(grid, Loc.t("score_swing"), "%.1f°" % float(result.get("max_swing_deg", 0.0)))
	var err := float(result.get("placement_error_m", -1.0))
	_stat(grid, Loc.t("score_precision"), "%.2f m" % err if err >= 0.0 else "—")

	body.add_child(UiKit.spacer(6))
	body.add_child(UiKit.label(Loc.t("result_why"), 16, UiKit.ACCENT))

	var rows: Array = result.get("breakdown", [])
	if rows.is_empty():
		body.add_child(UiKit.label("+%.0f  %s" % [AppSettings.BASE_POINTS,
			Loc.t("obj_delivered")], 14, UiKit.OK))
	else:
		for row in rows:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 12)
			var pts := UiKit.label("%.0f" % float(row.points), 14, UiKit.DANGER)
			pts.custom_minimum_size = Vector2(70, 0)
			pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(pts)
			line.add_child(UiKit.label("%s × %d" % [Loc.t(String(row.key)), int(row.count)],
				14, UiKit.TEXT))
			body.add_child(line)

	# Name the specific rules that were broken, not just the count.
	var violated: Dictionary = result.get("violated", {})
	if not violated.is_empty():
		body.add_child(UiKit.spacer(4))
		for key in violated:
			body.add_child(UiKit.label("• %s (× %d)" % [Loc.t(String(key)), int(violated[key])],
				13, UiKit.WARN))

	if String(result.get("phase", "")) == "stopped_work":
		body.add_child(UiKit.spacer(4))
		body.add_child(UiKit.wrapped(Loc.t("obj_stopped"), 14, 660, UiKit.OK))

	var best: Dictionary = GameState.best_result(String(scenario.get("id", "")))
	if not best.is_empty():
		body.add_child(UiKit.label("%s: %.0f" % [Loc.t("result_best"),
			float(best.get("points", 0.0))], 12, UiKit.TEXT_DIM))

	body.add_child(UiKit.spacer(10))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	body.add_child(buttons)

	var retry := UiKit.button(Loc.t("result_retry"), not passed, 200)
	retry.pressed.connect(func(): retry_requested.emit())
	buttons.add_child(retry)

	var next_id := ScenarioDB.next_after(String(scenario.get("id", "")))
	if next_id != "":
		var nxt := UiKit.button(Loc.t("result_next"), passed, 200)
		nxt.pressed.connect(func(): next_requested.emit())
		buttons.add_child(nxt)

	var menu := UiKit.button(Loc.t("menu_to_menu"), false, 200)
	menu.pressed.connect(func(): menu_requested.emit())
	buttons.add_child(menu)

	body.add_child(UiKit.spacer(6))
	body.add_child(UiKit.disclaimer_label(660))

	root.visible = true
	retry.grab_focus()


func _stat(grid: GridContainer, title: String, value: String) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(UiKit.label(title, 11, UiKit.TEXT_DIM))
	col.add_child(UiKit.label(value, 22, UiKit.TEXT))
	grid.add_child(col)
