extends CanvasLayer
## HUD — the operator's instrument panel and instructor in one layer.
##
## What is on screen is chosen to answer, at every instant, the four questions
## a crane operator actually has:
##   1. What am I supposed to be doing?      -> guidance strip (top centre)
##   2. Which key does that?                 -> live key overlay + hint line
##   3. Am I inside the machine's limits?    -> LMI bar, stability, swing, wind
##   4. Where is the load relative to where  -> minimap, target arrow, hook
##      it needs to be?                          height readout
##
## Difficulty changes what is shown, never what the machine does: guided mode
## adds the target arrow and keeps the load chart pinned, assessment mode
## removes the guidance strip entirely.

const UiKit := preload("res://ui/ui_kit.gd")
const LoadChartScript := preload("res://core/load_chart.gd")
const StabilityScript := preload("res://core/stability_model.gd")

## Fixed width for the load-chart panel. Its headings are long trilingual
## strings, so every label inside it is wrapped to this rather than allowed to
## push the panel off the edge of the screen.
const CHART_WIDTH := 340.0

# --- custom-drawn instruments ---------------------------------------------------

class SwingGauge extends Control:
	var swing_deg := 0.0
	var limit_deg := 6.0
	const MAX_DEG := 30.0

	func _ang(deg: float) -> float:
		return PI + clampf(deg / MAX_DEG, 0.0, 1.0) * PI

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.86)
		var r := minf(size.x * 0.46, size.y * 0.78)
		var amber: float = minf(limit_deg * 1.8, MAX_DEG)
		draw_arc(c, r, _ang(0.0), _ang(limit_deg), 20, UiKit.OK, 7.0)
		draw_arc(c, r, _ang(limit_deg), _ang(amber), 20, UiKit.WARN, 7.0)
		draw_arc(c, r, _ang(amber), _ang(MAX_DEG), 20, UiKit.DANGER, 7.0)
		var a := _ang(swing_deg)
		draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color.WHITE, 3.0)
		draw_circle(c, 4.0, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 1), "%.1f°" % swing_deg,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UiKit.TEXT)

	func set_values(deg: float, limit: float) -> void:
		swing_deg = deg
		limit_deg = maxf(1.0, limit)
		queue_redraw()


## Load Moment Indicator: the single most important instrument on a slewing
## crane, drawn as a percentage bar with the real alarm bands marked.
class LmiBar extends Control:
	var util := 0.0
	var status: int = 0
	var capacity_kg := 0.0
	var gross_kg := 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.09, 0.12, 0.9))
		draw_rect(Rect2(0, 0, w * LoadChartScript.WARNING_FRAC * 0.833, h), UiKit.OK)
		draw_rect(Rect2(w * LoadChartScript.WARNING_FRAC * 0.833, 0,
			w * 0.0833, h), UiKit.WARN)
		draw_rect(Rect2(w * 0.833, 0, w * 0.167, h), UiKit.DANGER)
		var x := clampf(util / 1.2, 0.0, 1.0) * w
		draw_rect(Rect2(0, h * 0.30, x, h * 0.40), Color(1, 1, 1, 0.28))
		draw_line(Vector2(x, -3), Vector2(x, h + 3), Color.WHITE, 3.0)
		var text := "%.0f%%" % (util * 100.0) if util < 9.0 else "OFF CHART"
		draw_string(ThemeDB.fallback_font, Vector2(6, h - 5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.05, 0.05, 0.07))
		var right := "%.0f / %.0f kg" % [gross_kg, capacity_kg] if capacity_kg > 0.0 \
			else "%.0f kg" % gross_kg
		draw_string(ThemeDB.fallback_font, Vector2(0, h - 5), right,
			HORIZONTAL_ALIGNMENT_RIGHT, w - 6, 13, Color(0.05, 0.05, 0.07))

	func set_values(p_util: float, p_status: int, p_cap: float, p_gross: float) -> void:
		util = p_util
		status = p_status
		capacity_kg = p_cap
		gross_kg = p_gross
		queue_redraw()


## Outrigger / stability diagram: the support rectangle seen from above, the
## boom bearing drawn across it, and the tipping side highlighted.
class StabilityDiagram extends Control:
	var deploy := 0.0
	var bearing := 0.0
	var level: int = 0
	var side := "front"
	var active := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.34
		var col: Color = StabilityScript.level_color(level)
		draw_rect(Rect2(c - Vector2(r, r) * 0.45, Vector2(r, r) * 0.9),
			Color(0.5, 0.55, 0.6, 0.75))
		if not active:
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 2), "—",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UiKit.TEXT_DIM)
			return
		var ext := lerpf(0.45, 1.0, deploy)
		var pts := PackedVector2Array([
			c + Vector2(-r, -r) * ext, c + Vector2(r, -r) * ext,
			c + Vector2(r, r) * ext, c + Vector2(-r, r) * ext,
			c + Vector2(-r, -r) * ext])
		draw_polyline(pts, col, 2.5)
		for p in [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]:
			draw_circle(c + p * ext, 4.0, col)
		var d := Vector2(cos(bearing), sin(bearing)) * r * 1.25
		draw_line(c, c + d, UiKit.ACCENT_2, 3.0)
		draw_circle(c + d, 4.0, UiKit.ACCENT_2)
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 2),
			"%.0f%%" % (deploy * 100.0), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, col)

	func set_values(p_deploy: float, p_bearing: float, p_level: int, p_side: String,
			p_active: bool) -> void:
		deploy = p_deploy
		bearing = p_bearing
		level = p_level
		side = p_side
		active = p_active
		queue_redraw()


class WindCompass extends Control:
	var dir := Vector2.ZERO
	var speed := 0.0
	var limit := 99.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.38
		var over := speed > limit
		draw_arc(c, r, 0.0, TAU, 32, UiKit.DANGER if over else Color(1, 1, 1, 0.45), 2.0)
		if speed > 0.05:
			var d := dir.normalized()
			draw_line(c, c + d * r, UiKit.DANGER if over else UiKit.ACCENT, 4.0)
			draw_circle(c + d * r, 4.0, UiKit.DANGER if over else UiKit.ACCENT)
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 2), "%.1f m/s" % speed,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UiKit.DANGER if over else UiKit.TEXT)


class Minimap extends Control:
	var world_rect := Rect2(-40, -40, 120, 120)
	var hook := Vector2.ZERO
	var load_xz := Vector2.ZERO
	var player_pos = null
	var pickup: Dictionary = {}
	var dropoff: Dictionary = {}
	var machine := Vector2.ZERO
	var radius_m := 0.0

	func _to_local(x: float, z: float) -> Vector2:
		return Vector2(
			(x - world_rect.position.x) / world_rect.size.x * size.x,
			(z - world_rect.position.y) / world_rect.size.y * size.y)

	func _scale() -> float:
		return size.x / world_rect.size.x

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.10, 0.88))
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.LINE, false, 1.5)
		if radius_m > 0.1:
			draw_arc(_to_local(machine.x, machine.y), radius_m * _scale(), 0.0, TAU, 48,
				Color(0.98, 0.72, 0.12, 0.45), 1.5)
		_zone(pickup, Color(0.98, 0.84, 0.10))
		_zone(dropoff, Color(0.20, 0.62, 0.98))
		draw_circle(_to_local(machine.x, machine.y), 5.0, Color(0.85, 0.87, 0.92))
		var l := _to_local(load_xz.x, load_xz.y)
		draw_circle(l, 5.0, UiKit.ACCENT_2)
		draw_arc(l, 8.0, 0.0, TAU, 16, UiKit.ACCENT_2, 1.5)
		if player_pos != null:
			draw_circle(_to_local(player_pos.x, player_pos.y), 3.5, Color.WHITE)

	func _zone(zone: Dictionary, color: Color) -> void:
		if zone.is_empty():
			return
		var p := _to_local(float(zone.x), float(zone.z))
		var rad: float = float(zone.get("radius", 1.8)) * _scale()
		draw_circle(p, maxf(rad, 3.0), Color(color.r, color.g, color.b, 0.35))
		draw_arc(p, maxf(rad, 3.0), 0.0, TAU, 24, color, 2.0)


## Big key cap that lights the instant its action is held. This is the single
## most-requested fix: a player must be able to SEE which key does what and
## confirm the press registered, without reading small print.
class KeyCap extends Control:
	var label := ""
	var active := false

	func _draw() -> void:
		var bg := Color(0.95, 0.96, 1.0, 0.96) if active else Color(0.10, 0.12, 0.16, 0.88)
		var fg := Color(0.04, 0.05, 0.08) if active else Color(0.86, 0.90, 0.95)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = UiKit.ACCENT if active else UiKit.LINE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		var fs := 16 if label.length() <= 2 else 12
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2(0, (size.y + ts.y) * 0.5 - 2), label,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, fg)

	func set_state(new_label: String, is_active: bool) -> void:
		if new_label != label or is_active != active:
			label = new_label
			active = is_active
			queue_redraw()


## Arrow pointing at the current target, drawn at the screen edge when the
## target is off camera. Guided/standard only.
class TargetArrow extends Control:
	var screen_pos := Vector2.ZERO
	var visible_arrow := false
	var behind := false
	var distance := 0.0

	func _draw() -> void:
		if not visible_arrow:
			return
		var c := screen_pos
		var col := UiKit.ACCENT_2
		var pts := PackedVector2Array([c + Vector2(0, -16), c + Vector2(13, 10), c + Vector2(-13, 10)])
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.6), 2.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-30, 30), "%.0f m" % distance,
			HORIZONTAL_ALIGNMENT_CENTER, 60, 14, col)


# --- nodes -----------------------------------------------------------------------

var spec: Dictionary = {}
var scenario: Dictionary = {}
var diff: Dictionary = {}

var status_label: Label
var readout_label: Label
var guidance_panel: PanelContainer
var guidance_label: Label
var objective_label: Label
var hint_label: Label
var alert_label: Label
var caution_label: Label
var impact_label: Label
var signal_label: Label
var lmi_text: Label
var stab_text: Label

var swing_gauge: SwingGauge
var lmi_bar: LmiBar
var stab_diagram: StabilityDiagram
var wind_compass: WindCompass
var minimap: Minimap
var target_arrow: TargetArrow
var key_row: HBoxContainer
var key_caps: Array = []
var step_strip: HBoxContainer
var step_dots: Array = []

var help_panel: PanelContainer
var help_body: VBoxContainer
var chart_panel: PanelContainer
var chart_body: VBoxContainer

var help_visible := false
var chart_visible := false
var map_visible := true

var _alert_t := 0.0
var _caution_t := 0.0
var _impact_t := 0.0
var _signal_t := 0.0
var _impact_key := "impact_floor"
var _alert_key := "danger_load"


func build(p_spec: Dictionary, p_scenario: Dictionary, p_diff: Dictionary) -> void:
	layer = 1
	spec = p_spec
	scenario = p_scenario
	diff = p_diff

	_build_status()
	_build_guidance()
	_build_objective()
	_build_instruments()
	_build_minimap()
	_build_alerts()
	_build_keys()
	_build_help()
	_build_chart()

	chart_visible = bool(diff.get("show_chart", true)) and not spec.get("load_chart", []).is_empty() \
		and spec.load_chart.size() > 1
	chart_panel.visible = chart_visible


func _build_status() -> void:
	var p := UiKit.panel(UiKit.PANEL, 10)
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.position = Vector2(12, 12)
	add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	p.add_child(box)
	# Bounded and wrapped: in EN/ES mode the machine name is two full names
	# joined, which otherwise pushed this panel under the guidance strip.
	status_label = UiKit.wrapped("", 14, CHART_WIDTH, UiKit.TEXT)
	box.add_child(status_label)
	box.add_child(UiKit.separator())
	readout_label = UiKit.wrapped("", 12, CHART_WIDTH, UiKit.TEXT_DIM)
	box.add_child(readout_label)


## Guidance strip: the always-visible answer to "what now?". Removed entirely
## in assessment mode, which is the whole difference between the two modes.
func _build_guidance() -> void:
	guidance_panel = UiKit.panel(Color(0.08, 0.24, 0.40, 0.92), 12)
	guidance_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	guidance_panel.position = Vector2(-330, 14)
	guidance_panel.custom_minimum_size = Vector2(660, 0)
	add_child(guidance_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	guidance_panel.add_child(box)
	guidance_label = UiKit.wrapped("", 17, 636, Color(1, 1, 1))
	guidance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(guidance_label)
	step_strip = HBoxContainer.new()
	step_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	step_strip.add_theme_constant_override("separation", 5)
	box.add_child(step_strip)
	for i in 9:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(52, 4)
		dot.color = Color(1, 1, 1, 0.18)
		step_strip.add_child(dot)
		step_dots.append(dot)
	guidance_panel.visible = bool(diff.get("show_hints", true))


func _build_objective() -> void:
	var p := UiKit.panel(UiKit.PANEL, 10)
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-352, 12)
	add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	p.add_child(box)
	box.add_child(UiKit.label(Loc.t("objective"), 13, UiKit.ACCENT))
	objective_label = UiKit.wrapped("", 13, 320, UiKit.TEXT)
	box.add_child(objective_label)


func _build_instruments() -> void:
	var bar := UiKit.panel(UiKit.PANEL, 10)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(12, -212)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	var col_swing := VBoxContainer.new()
	col_swing.add_child(UiKit.label(Loc.t("swing"), 11, UiKit.TEXT_DIM))
	swing_gauge = SwingGauge.new()
	swing_gauge.custom_minimum_size = Vector2(104, 66)
	col_swing.add_child(swing_gauge)
	row.add_child(col_swing)

	var col_lmi := VBoxContainer.new()
	col_lmi.add_child(UiKit.label(Loc.t("utilisation"), 11, UiKit.TEXT_DIM))
	lmi_bar = LmiBar.new()
	lmi_bar.custom_minimum_size = Vector2(230, 26)
	col_lmi.add_child(lmi_bar)
	lmi_text = UiKit.label("", 12, UiKit.TEXT)
	col_lmi.add_child(lmi_text)
	row.add_child(col_lmi)

	var col_stab := VBoxContainer.new()
	col_stab.add_child(UiKit.label(Loc.t("stability"), 11, UiKit.TEXT_DIM))
	stab_diagram = StabilityDiagram.new()
	stab_diagram.custom_minimum_size = Vector2(78, 66)
	col_stab.add_child(stab_diagram)
	row.add_child(col_stab)

	var col_wind := VBoxContainer.new()
	col_wind.add_child(UiKit.label(Loc.t("wind"), 11, UiKit.TEXT_DIM))
	wind_compass = WindCompass.new()
	wind_compass.custom_minimum_size = Vector2(78, 66)
	col_wind.add_child(wind_compass)
	row.add_child(col_wind)

	var col_txt := VBoxContainer.new()
	col_txt.add_theme_constant_override("separation", 2)
	stab_text = UiKit.label("", 13, UiKit.TEXT)
	col_txt.add_child(stab_text)
	row.add_child(col_txt)

	hint_label = UiKit.label("", 12, UiKit.TEXT_DIM)
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(14, -26)
	add_child(hint_label)


func _build_minimap() -> void:
	minimap = Minimap.new()
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.position = Vector2(-236, -240)
	minimap.custom_minimum_size = Vector2(224, 224)
	minimap.size = Vector2(224, 224)
	add_child(minimap)

	target_arrow = TargetArrow.new()
	target_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	target_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(target_arrow)


func _build_alerts() -> void:
	alert_label = UiKit.label("", 22, UiKit.DANGER)
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.position = Vector2(-380, 128)
	alert_label.custom_minimum_size = Vector2(760, 0)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.visible = false
	add_child(alert_label)

	caution_label = UiKit.label("", 18, UiKit.WARN)
	caution_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caution_label.position = Vector2(-380, 158)
	caution_label.custom_minimum_size = Vector2(760, 0)
	caution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caution_label.visible = false
	add_child(caution_label)

	impact_label = UiKit.label("", 17, UiKit.ACCENT_2)
	impact_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	impact_label.position = Vector2(-380, 186)
	impact_label.custom_minimum_size = Vector2(760, 0)
	impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact_label.visible = false
	add_child(impact_label)

	signal_label = UiKit.label("", 20, UiKit.OK)
	signal_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	signal_label.position = Vector2(-380, 214)
	signal_label.custom_minimum_size = Vector2(760, 0)
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signal_label.visible = false
	add_child(signal_label)


func _build_keys() -> void:
	var p := UiKit.panel(Color(0.06, 0.07, 0.10, 0.72), 8)
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.position = Vector2(-260, -76)
	add_child(p)
	key_row = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 6)
	p.add_child(key_row)
	for i in 12:
		var k := KeyCap.new()
		k.custom_minimum_size = Vector2(46, 40)
		k.visible = false
		key_row.add_child(k)
		key_caps.append(k)
	p.visible = bool(GameState.settings.get("show_key_overlay", true))


func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_panel.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.03, 0.04, 0.06, 0.95), UiKit.LINE, 0, 28))
	help_panel.visible = false
	add_child(help_panel)
	var scroll := ScrollContainer.new()
	help_panel.add_child(scroll)
	help_body = VBoxContainer.new()
	help_body.add_theme_constant_override("separation", 4)
	scroll.add_child(help_body)


## The load chart lives in the LEFT column, under the machine status panel.
## It used to sit on the right, where it covered the objective panel and the
## minimap and ran off the edge of the screen — the two things the operator
## most needs while they are reading it.
func _build_chart() -> void:
	chart_panel = UiKit.panel(UiKit.PANEL, 12)
	chart_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chart_panel.position = Vector2(12, 212)
	chart_panel.custom_minimum_size = Vector2(CHART_WIDTH, 0)
	add_child(chart_panel)
	chart_body = VBoxContainer.new()
	chart_body.add_theme_constant_override("separation", 2)
	chart_panel.add_child(chart_body)


# --- flashes -------------------------------------------------------------------

func flash_danger() -> void:
	_alert_key = "danger_load"
	alert_label.visible = true
	_alert_t = 2.0


func flash_violation(key: String) -> void:
	_alert_key = key
	alert_label.visible = true
	_alert_t = 2.4


func flash_caution() -> void:
	if not alert_label.visible:
		caution_label.visible = true
		_caution_t = 0.9


func flash_impact(key: String) -> void:
	_impact_key = key
	impact_label.visible = true
	_impact_t = 1.6


func flash_signal(text: String) -> void:
	signal_label.text = "%s: %s" % [Loc.t("signaller"), text]
	signal_label.visible = true
	_signal_t = 4.0


func toggle_help() -> void:
	help_visible = not help_visible
	help_panel.visible = help_visible
	if help_visible:
		_rebuild_help()


func toggle_chart() -> void:
	chart_visible = not chart_visible
	chart_panel.visible = chart_visible


func toggle_map() -> void:
	map_visible = not map_visible
	minimap.visible = map_visible


# --- per-frame update -----------------------------------------------------------

func update(delta: float, ctx: Dictionary) -> void:
	_tick_flashes(delta)
	_update_status(ctx)
	_update_guidance(ctx)
	_update_instruments(ctx)
	_update_minimap(ctx)
	_update_keys(ctx)
	if chart_visible:
		_rebuild_chart(ctx)
	if ctx.get("signal_text", "") != "" and not signal_label.visible:
		flash_signal(String(ctx.signal_text))


func _tick_flashes(delta: float) -> void:
	if _alert_t > 0.0:
		_alert_t -= delta
		if _alert_t <= 0.0:
			alert_label.visible = false
	if _caution_t > 0.0:
		_caution_t -= delta
		if _caution_t <= 0.0:
			caution_label.visible = false
	if _impact_t > 0.0:
		_impact_t -= delta
		if _impact_t <= 0.0:
			impact_label.visible = false
	if _signal_t > 0.0:
		_signal_t -= delta
		if _signal_t <= 0.0:
			signal_label.visible = false
	alert_label.text = "!! " + Loc.t(_alert_key)
	caution_label.text = Loc.t("caution_near")
	impact_label.text = Loc.t(_impact_key)


func _update_status(ctx: Dictionary) -> void:
	var lines := PackedStringArray()
	lines.append(MachineCatalog.display_name(ctx.spec))
	if bool(ctx.get("halted", false)):
		lines.append("!! " + Loc.t("fault"))
	if bool(ctx.get("estop", false)):
		lines.append("!! " + Loc.t("estop"))
	var checks: Array = ctx.get("checks", [])
	var marks := PackedStringArray()
	for i in checks.size():
		marks.append("%d[%s]" % [i + 1, "x" if checks[i] else " "])
	lines.append("%s: %s   %s: %s" % [Loc.t("power"),
		Loc.t("on") if ctx.powered else Loc.t("off"),
		Loc.t("inspection"), " ".join(marks)])
	if bool(ctx.get("needs_outriggers", false)):
		var og := float(ctx.outriggers)
		lines.append("%s: %s (%.0f%%)" % [Loc.t("outriggers"),
			Loc.t("outriggers_out") if og >= 0.99 else Loc.t("outriggers_in"), og * 100.0])
	status_label.text = "\n".join(lines)

	var r := PackedStringArray()
	if float(ctx.get("radius_m", 0.0)) > 0.01:
		r.append("%s %.1f m" % [Loc.t("radius"), ctx.radius_m])
	r.append("%s %.1f m" % [Loc.t("hook_height"), maxf(0.0, float(ctx.hook_height_m))])
	r.append("%s %.1f m" % [Loc.t("cable"), ctx.rope_out_m])
	var axes: Dictionary = ctx.get("axes", {})
	if axes.has("luff"):
		r.append("%s %.0f°" % [Loc.t("boom_angle"), axes.luff])
	if axes.has("telescope"):
		r.append("%s %.1f m" % [Loc.t("boom_length"), axes.telescope])
	if axes.has("slew"):
		r.append("%s %.0f°" % [Loc.t("slew_angle"), axes.slew])
	r.append("%s %.1f kN" % [Loc.t("tension"), float(ctx.tension_n) / 1000.0])
	r.append("%s %.0f s   [%s] %s" % [Loc.t("time"), ctx.time_s, Loc.lang_name(),
		Loc.t("cam_" + String(ctx.get("camera_view", "walk")))])
	readout_label.text = "\n".join(r)


func _update_guidance(ctx: Dictionary) -> void:
	if not guidance_panel.visible:
		return
	guidance_label.text = String(ctx.get("guidance_text", ""))
	var idx := int(round(float(ctx.get("guidance_progress", 0.0)) * float(step_dots.size() - 1)))
	for i in step_dots.size():
		step_dots[i].color = UiKit.ACCENT_2 if i <= idx else Color(1, 1, 1, 0.16)

	var obj := PackedStringArray()
	obj.append(Loc.pick(ctx.scenario.get("title", {})))
	obj.append(Loc.pick(ctx.scenario.get("briefing", {})))
	var live: Dictionary = ctx.get("live", {})
	obj.append("")
	obj.append("%s %.0f s   %s %.1f°" % [Loc.t("score_time"), live.get("time_s", 0.0),
		Loc.t("score_swing"), live.get("max_swing_deg", 0.0)])
	obj.append("%s %d   %s %d   %s %d" % [
		Loc.t("score_hits"), live.get("collisions", 0),
		Loc.t("score_violations"), live.get("violations", 0),
		Loc.t("score_near_miss"), live.get("near_misses", 0)])
	objective_label.text = "\n".join(obj)


func _update_instruments(ctx: Dictionary) -> void:
	var success: Dictionary = ScenarioDB.success_of(ctx.scenario)
	swing_gauge.set_values(float(ctx.swing_deg), float(success.max_swing_deg))
	lmi_bar.set_values(float(ctx.lmi_util), int(ctx.lmi_status),
		float(ctx.capacity_kg), float(ctx.gross_kg))
	lmi_text.text = Loc.t(LoadChartScript.status_key(ctx.lmi_status))
	lmi_text.add_theme_color_override("font_color",
		LoadChartScript.status_color(ctx.lmi_status))

	var stab: Dictionary = ctx.get("stability", {})
	var has_og := bool(ctx.get("needs_outriggers", false))
	stab_diagram.set_values(float(ctx.get("outriggers", 1.0)),
		-deg_to_rad(float(ctx.get("axes", {}).get("slew", 0.0))),
		int(stab.get("level", 0)), String(stab.get("tipping_side", "front")), has_og)
	var stab_line := Loc.t(String(stab.get("level_key", "stab_stable")))
	if has_og and is_finite(float(stab.get("factor", INF))):
		stab_line += "  (%.2f)" % float(stab.factor)
	if bool(ctx.get("over_wind", false)):
		stab_line += "\n" + Loc.t("over_wind")
	stab_text.text = stab_line
	stab_text.add_theme_color_override("font_color",
		UiKit.DANGER if bool(ctx.get("over_wind", false)) else Color(stab.get("color", UiKit.OK)))

	wind_compass.dir = Vector2(ctx.wind.x, ctx.wind.z)
	wind_compass.speed = float(ctx.wind_speed)
	wind_compass.limit = float(ctx.wind_limit)
	wind_compass.queue_redraw()

	hint_label.text = ControlScheme.hint_line(ctx.spec, bool(ctx.controlling))


func _update_minimap(ctx: Dictionary) -> void:
	if not map_visible:
		return
	# The map frames the machine, both zones and the load, with a margin, so
	# it is never "somewhere off the edge" whatever the site's scale is.
	var pts: Array = [ctx.load_xz, ctx.get("player_xz", Vector2.ZERO), Vector2.ZERO]
	for z in [ctx.get("pickup", {}), ctx.get("dropoff", {})]:
		if not z.is_empty():
			pts.append(Vector2(float(z.x), float(z.z)))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var pad := 12.0
	lo -= Vector2(pad, pad)
	hi += Vector2(pad, pad)
	var span: float = maxf(maxf(hi.x - lo.x, hi.y - lo.y), 20.0)
	var mid := (lo + hi) * 0.5
	minimap.world_rect = Rect2(mid - Vector2(span, span) * 0.5, Vector2(span, span))
	minimap.load_xz = ctx.load_xz
	minimap.player_pos = ctx.get("player_xz", null)
	minimap.pickup = ctx.get("pickup", {})
	minimap.dropoff = ctx.get("dropoff", {})
	minimap.radius_m = float(ctx.get("radius_m", 0.0))
	minimap.queue_redraw()

	_update_arrow(ctx)


func _update_arrow(ctx: Dictionary) -> void:
	var target = ctx.get("guidance_target", null)
	if target == null or not bool(diff.get("show_path", false)):
		target_arrow.visible_arrow = false
		target_arrow.queue_redraw()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var behind := cam.is_position_behind(target)
	var sp: Vector2 = cam.unproject_position(target)
	if behind:
		sp = vp - sp
	sp.x = clampf(sp.x, 60.0, vp.x - 60.0)
	sp.y = clampf(sp.y, 90.0, vp.y - 150.0)
	target_arrow.screen_pos = sp
	target_arrow.distance = cam.global_position.distance_to(target)
	target_arrow.visible_arrow = true
	target_arrow.queue_redraw()


func _update_keys(ctx: Dictionary) -> void:
	var keys: Array = ControlScheme.overlay_keys(ctx.spec, bool(ctx.controlling))
	for i in key_caps.size():
		var k: KeyCap = key_caps[i]
		if i >= keys.size():
			k.visible = false
			continue
		k.visible = true
		k.set_state(String(keys[i].label), Input.is_action_pressed(String(keys[i].action)))


func _rebuild_help() -> void:
	for c in help_body.get_children():
		c.queue_free()
	help_body.add_child(UiKit.heading(Loc.t("help_title"), 24))
	help_body.add_child(UiKit.label(Loc.t("ctrl_universal"), 14, UiKit.ACCENT_2))
	help_body.add_child(UiKit.spacer(8))
	for row in ControlScheme.reference_rows(spec):
		if row.has("header"):
			help_body.add_child(UiKit.spacer(10))
			help_body.add_child(UiKit.label(String(row.header), 16, UiKit.ACCENT))
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var k := UiKit.label(String(row.keys), 14, UiKit.ACCENT_2)
		k.custom_minimum_size = Vector2(160, 0)
		line.add_child(k)
		line.add_child(UiKit.label(String(row.text), 14, UiKit.TEXT))
		help_body.add_child(line)
	help_body.add_child(UiKit.spacer(14))
	help_body.add_child(UiKit.disclaimer_label(820))


## The load chart, drawn as a readable table with the operator's current
## radius marked. A learner must be able to LOOK UP the number, not just be
## told the answer by the LMI bar.
func _rebuild_chart(ctx: Dictionary) -> void:
	for c in chart_body.get_children():
		c.queue_free()
	var w := CHART_WIDTH - 26.0
	chart_body.add_child(UiKit.wrapped(Loc.t("chart_title"), 14, w, UiKit.ACCENT))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var h1 := UiKit.label(Loc.t("chart_radius"), 11, UiKit.TEXT_DIM)
	h1.custom_minimum_size = Vector2(96, 0)
	head.add_child(h1)
	head.add_child(UiKit.label(Loc.t("chart_capacity"), 11, UiKit.TEXT_DIM))
	chart_body.add_child(head)

	var radius := float(ctx.get("radius_m", 0.0))
	var chart: Array = ctx.spec.get("load_chart", [])
	var marked := false
	for row in LoadChartScript.rows(chart):
		var is_here := not marked and radius <= float(row.radius_m)
		if is_here:
			marked = true
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var col := UiKit.ACCENT_2 if is_here else UiKit.TEXT
		var a := UiKit.label("%.1f m" % row.radius_m, 12, col)
		a.custom_minimum_size = Vector2(96, 0)
		line.add_child(a)
		var b := UiKit.label("%.0f kg" % row.capacity_kg, 12, col)
		b.custom_minimum_size = Vector2(90, 0)
		line.add_child(b)
		if is_here:
			line.add_child(UiKit.label("← " + Loc.t("chart_current"), 11, UiKit.ACCENT_2))
		chart_body.add_child(line)

	chart_body.add_child(UiKit.separator())
	var max_r := LoadChartScript.max_radius_for(chart, float(ctx.gross_kg))
	if max_r < 1e8:
		chart_body.add_child(UiKit.wrapped("%s: %.1f m" % [Loc.t("chart_max_radius"), max_r],
			12, w, UiKit.OK if radius <= max_r else UiKit.DANGER))
	var rig_plan: Dictionary = ctx.get("rigging", {})
	if not rig_plan.is_empty():
		chart_body.add_child(UiKit.spacer(6))
		chart_body.add_child(UiKit.wrapped(Loc.t("rig_plan"), 13, w, UiKit.ACCENT))
		chart_body.add_child(UiKit.wrapped("%s: %.0f kg" % [Loc.t("gross"),
			rig_plan.gross_kg], 11, w))
		chart_body.add_child(UiKit.wrapped("%s: %d × %.0f°" % [Loc.t("rig_legs"),
			rig_plan.legs, rig_plan.angle_deg], 11, w))
		chart_body.add_child(UiKit.wrapped("%s: %.0f kg" % [Loc.t("rig_leg_tension"),
			rig_plan.leg_tension_kg], 11, w))
		if not bool(rig_plan.angle_acceptable):
			chart_body.add_child(UiKit.wrapped(Loc.t("rig_angle_bad"), 11, w, UiKit.DANGER))
	chart_body.add_child(UiKit.spacer(4))
	chart_body.add_child(UiKit.wrapped(Loc.t("chart_disclaimer"), 10, w, UiKit.TEXT_DIM))
