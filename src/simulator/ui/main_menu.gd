extends Control
## MainMenu — the shell: title, training programme, scenario browser, free
## practice set-up, controls reference, settings and progress.
##
## One node with a screen stack rather than a scene per screen: every screen
## needs the same catalogues and the same selection state, and swapping scenes
## to change a dropdown was never going to be worth the file count. `_show()`
## rebuilds the content column; `_back()` pops.
##
## Behind everything sits a slowly-orbiting 3D preview of the currently
## selected machine, so the menu answers "what am I about to drive?" before
## the player reads a word.

const UiKit := preload("res://ui/ui_kit.gd")
const MachineRigScript := preload("res://core/machine_rig.gd")
const MachineVisualScript := preload("res://machines/machine_visual.gd")

var content: VBoxContainer
var header: VBoxContainer
var footer: Label
var preview_root: Node3D
var preview_cam: Camera3D
var preview_visual: Node3D
var preview_rig: RefCounted

var _stack: Array = []
var _orbit := 0.0
var _reset_armed := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_chrome()
	_show("title")


# --- background preview ---------------------------------------------------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.055, 0.075)
	add_child(bg)

	preview_root = Node3D.new()
	add_child(preview_root)

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.10, 0.14, 0.22)
	sky_mat.sky_horizon_color = Color(0.24, 0.30, 0.40)
	sky_mat.ground_bottom_color = Color(0.05, 0.06, 0.08)
	sky_mat.ground_horizon_color = Color(0.12, 0.14, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.13, 0.18)
	env.fog_density = 0.010
	var we := WorldEnvironment.new()
	we.environment = env
	preview_root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -46.0, 0.0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.shadow_enabled = true
	preview_root.add_child(sun)

	var key := OmniLight3D.new()
	key.position = Vector3(14.0, 12.0, 14.0)
	key.light_energy = 6.0
	key.omni_range = 60.0
	key.light_color = Color(0.5, 0.7, 1.0)
	preview_root.add_child(key)

	preview_cam = Camera3D.new()
	preview_cam.fov = 42.0
	preview_cam.far = 600.0
	preview_root.add_child(preview_cam)
	preview_cam.current = true

	# A ground plate so the machine is not floating in the void.
	var plate := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 60.0
	cyl.bottom_radius = 60.0
	cyl.height = 0.4
	plate.mesh = cyl
	plate.material_override = MaterialLibrary.get_mat("concrete_dirty")
	plate.position = Vector3(0.0, -0.2, 0.0)
	preview_root.add_child(plate)

	_rebuild_preview()


func _rebuild_preview() -> void:
	if preview_visual != null:
		preview_visual.queue_free()
	var spec := MachineCatalog.get_spec(GameState.machine_id)
	preview_rig = MachineRigScript.new()
	preview_rig.setup(spec, Vector3.ZERO)
	preview_rig.outriggers = 1.0
	preview_visual = MachineVisualScript.new()
	preview_root.add_child(preview_visual)
	preview_visual.setup(spec, preview_rig, Vector3.ZERO)
	preview_visual.sync()


func _process(delta: float) -> void:
	_orbit += delta * 0.10
	var spec := MachineCatalog.get_spec(GameState.machine_id)
	var g: Dictionary = spec.get("geometry", {})
	var height: float = float(g.get("head_height", g.get("pivot_height", 8.0)))
	var dist: float = clampf(height * 2.3 + 18.0, 26.0, 130.0)
	var focus := Vector3(0.0, height * 0.45, 0.0)
	# Framed from the right so the machine sits behind the menu column on the
	# left rather than underneath it.
	preview_cam.position = focus + Vector3(cos(_orbit) * dist, height * 0.35 + 6.0,
		sin(_orbit) * dist)
	preview_cam.look_at(focus + Vector3(6.0, 0.0, 0.0))
	if preview_visual != null:
		preview_visual.sync()


# --- chrome ------------------------------------------------------------------------

func _build_chrome() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	scrim.custom_minimum_size = Vector2(760, 0)
	scrim.size.x = 760
	scrim.color = Color(0.03, 0.04, 0.06, 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.custom_minimum_size = Vector2(760, 0)
	margin.size.x = 760
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	column.add_child(header)
	header.add_child(UiKit.label(Loc.t("app_title"), 30, UiKit.TEXT))
	header.add_child(UiKit.label(Loc.t("app_sub"), 13, UiKit.ACCENT))
	column.add_child(UiKit.spacer(14))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.custom_minimum_size = Vector2(660, 0)
	scroll.add_child(content)

	column.add_child(UiKit.spacer(8))
	footer = UiKit.disclaimer_label(660)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(footer)


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func _show(screen: String) -> void:
	if _stack.is_empty() or _stack[-1] != screen:
		_stack.append(screen)
	_render(screen)


func _back() -> void:
	if _stack.size() > 1:
		_stack.pop_back()
	_render(_stack[-1])


func _render(screen: String) -> void:
	_clear()
	_reset_armed = false
	match screen:
		"title": _screen_title()
		"programme": _screen_programme()
		"scenarios": _screen_scenarios()
		"free": _screen_free()
		"controls": _screen_controls()
		"settings": _screen_settings()
		"progress": _screen_progress()
		_: _screen_title()


func _add_back() -> void:
	content.add_child(UiKit.spacer(10))
	var b := UiKit.button("← " + Loc.t("menu_back"), false, 220)
	b.pressed.connect(_back)
	content.add_child(b)


func _section(title: String) -> void:
	content.add_child(UiKit.spacer(8))
	content.add_child(UiKit.label(title, 17, UiKit.ACCENT))


# --- screens ---------------------------------------------------------------------

func _screen_title() -> void:
	var next_id := ScenarioDB.next_for_learner(GameState.is_completed)
	var done := GameState.completed_count()
	var total := ScenarioDB.all_ids().size()

	if next_id != "":
		var cont := UiKit.button("%s — %s" % [Loc.t("menu_continue"),
			ScenarioDB.title_of(next_id)], true, 480)
		cont.pressed.connect(func():
			GameState.select_scenario(ScenarioDB.get_scenario(next_id))
			_start())
		content.add_child(cont)

	_menu_entry(Loc.t("menu_training"), Loc.t("menu_training_sub"), func(): _show("programme"))
	_menu_entry(Loc.t("menu_scenarios"), Loc.t("menu_scenarios_sub"), func(): _show("scenarios"))
	_menu_entry(Loc.t("menu_free"), Loc.t("menu_free_sub"), func(): _show("free"))

	content.add_child(UiKit.spacer(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	for pair in [[Loc.t("menu_controls"), "controls"], [Loc.t("menu_settings"), "settings"],
			[Loc.t("menu_progress"), "progress"]]:
		var b := UiKit.button(String(pair[0]), false, 205)
		var target := String(pair[1])
		b.pressed.connect(func(): _show(target))
		row.add_child(b)

	content.add_child(UiKit.spacer(4))
	content.add_child(UiKit.label("%d / %d %s   ·   %s: %s" % [done, total,
		Loc.t("menu_completed"), Loc.t("set_language"), Loc.lang_name()], 13, UiKit.TEXT_DIM))

	if not ScenarioDB.load_errors.is_empty():
		content.add_child(UiKit.spacer(6))
		content.add_child(UiKit.label("Scenario load problems:", 13, UiKit.DANGER))
		for e in ScenarioDB.load_errors:
			content.add_child(UiKit.wrapped("• " + String(e), 11, 640, UiKit.WARN))

	content.add_child(UiKit.spacer(10))
	var quit := UiKit.button(Loc.t("menu_quit"), false, 205)
	quit.pressed.connect(func(): get_tree().quit())
	content.add_child(quit)


func _menu_entry(title: String, subtitle: String, on_press: Callable) -> void:
	var c := UiKit.card(title, subtitle, 640)
	c.custom_minimum_size.y = 84
	c.pressed.connect(on_press)
	content.add_child(c)


func _screen_programme() -> void:
	content.add_child(UiKit.label(Loc.t("menu_training"), 24))
	for pid in ScenarioDB.PROGRAMME_ORDER:
		var ids := ScenarioDB.ids_in_programme(pid)
		if ids.is_empty():
			continue
		var done := 0
		for id in ids:
			if GameState.is_completed(id):
				done += 1
		_section("%s   (%d/%d)" % [ScenarioDB.programme_name(pid), done, ids.size()])
		content.add_child(UiKit.wrapped(ScenarioDB.programme_desc(pid), 12, 640, UiKit.TEXT_DIM))
		for id in ids:
			_scenario_row(id)
	_add_back()


func _screen_scenarios() -> void:
	content.add_child(UiKit.label(Loc.t("menu_scenarios"), 24))
	for id in ScenarioDB.all_ids():
		_scenario_row(id)
	_add_back()


func _scenario_row(id: String) -> void:
	var s := ScenarioDB.get_scenario(id)
	var spec := MachineCatalog.get_spec(String(s.machine))
	var passed := GameState.is_completed(id)
	var mark := "✔ " if passed else "· "
	var sub := "%s · %s · %s · %.0f kg" % [
		MachineCatalog.display_name(spec),
		EnvironmentCatalog.display_name(String(s.environment)),
		Weather.display_name(String(s.get("weather", "clear"))),
		ScenarioDB.gross_kg(s)]
	var card := UiKit.card("%s%s — %s" % [mark, id, Loc.pick(s.get("title", {}))], sub, 640)
	card.custom_minimum_size.y = 74
	if passed:
		UiKit.set_card_selected(card, true)
	card.pressed.connect(func():
		GameState.select_scenario(s)
		_show_briefing(s, spec))
	content.add_child(card)


## Briefing screen: the job, the machine, the load and the rules, BEFORE the
## player is dropped into the world. A real lift starts with a briefing and
## this is where the difficulty is chosen.
func _show_briefing(s: Dictionary, spec: Dictionary) -> void:
	_clear()
	content.add_child(UiKit.label(Loc.pick(s.get("title", {})), 24))
	content.add_child(UiKit.label("%s · %s · %s" % [MachineCatalog.display_name(spec),
		EnvironmentCatalog.display_name(String(s.environment)),
		Weather.display_name(String(s.get("weather", "clear")))], 13, UiKit.ACCENT))
	content.add_child(UiKit.spacer(6))
	content.add_child(UiKit.wrapped(Loc.pick(s.get("briefing", {})), 15, 640))

	_section(Loc.t("briefing"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	content.add_child(grid)
	var success := ScenarioDB.success_of(s)
	_kv(grid, Loc.t("gross"), "%.0f kg" % ScenarioDB.gross_kg(s))
	_kv(grid, Loc.t("score_swing"), "≤ %.1f°" % float(success.max_swing_deg))
	_kv(grid, Loc.t("score_time"), "%.0f s" % float(success.time_target_s))
	_kv(grid, Loc.t("wind_limit"), "%.0f m/s" % float(
		Weather.get_preset(String(s.get("weather", "clear"))).get("wind_limit_ms", 12.0)))

	_section(Loc.t("menu_difficulty"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var cards: Array = []
	for did in GameState.DIFFICULTY_ORDER:
		var d: Dictionary = GameState.DIFFICULTY[did]
		var c := UiKit.card(Loc.pick(d.name), Loc.pick(d.desc), 208)
		c.custom_minimum_size.y = 132
		UiKit.set_card_selected(c, GameState.difficulty == did)
		c.pressed.connect(func():
			GameState.difficulty = did
			GameState.save_profile()
			for other in cards:
				UiKit.set_card_selected(other.node, other.id == did))
		cards.append({"node": c, "id": did})
		row.add_child(c)

	content.add_child(UiKit.spacer(12))
	var start := UiKit.button(Loc.t("menu_start"), true, 300)
	start.pressed.connect(_start)
	content.add_child(start)
	_add_back()
	start.grab_focus()


func _kv(grid: GridContainer, k: String, v: String) -> void:
	grid.add_child(UiKit.label(k, 13, UiKit.TEXT_DIM))
	grid.add_child(UiKit.label(v, 13, UiKit.TEXT))


## Free practice: pick a machine, then a site it can actually work on, then
## the weather. The site list is filtered by the machine so an impossible
## combination cannot be selected at all.
func _screen_free() -> void:
	content.add_child(UiKit.label(Loc.t("menu_free"), 24))

	_section(Loc.t("menu_machine"))
	var m_row := _grid(2)
	for id in MachineCatalog.all_ids():
		var spec := MachineCatalog.get_spec(id)
		var c := UiKit.card(MachineCatalog.display_name(spec), Loc.pick(spec.blurb), 315)
		c.custom_minimum_size.y = 128
		UiKit.set_card_selected(c, GameState.machine_id == id)
		c.pressed.connect(func():
			GameState.machine_id = id
			if not spec.environments.has(GameState.environment_id):
				GameState.environment_id = String(spec.environments[0])
			_rebuild_preview()
			_render("free"))
		m_row.add_child(c)

	var machine_spec := MachineCatalog.get_spec(GameState.machine_id)

	_section(Loc.t("menu_site"))
	var e_row := _grid(2)
	for eid in EnvironmentCatalog.all_ids():
		var allowed: bool = machine_spec.environments.has(eid)
		var c := UiKit.card(EnvironmentCatalog.display_name(eid),
			Loc.pick(EnvironmentCatalog.get_env(eid).blurb) if allowed else Loc.t("menu_locked_env"),
			315)
		c.custom_minimum_size.y = 128
		c.disabled = not allowed
		UiKit.set_card_selected(c, GameState.environment_id == eid)
		c.pressed.connect(func():
			GameState.environment_id = eid
			_render("free"))
		e_row.add_child(c)

	_section(Loc.t("menu_weather"))
	var w_row := _grid(4)
	for wid in Weather.ORDER:
		var p := Weather.get_preset(wid)
		var c := UiKit.card(Weather.display_name(wid),
			"%s %.0f m/s · %s %.0f m" % [Loc.t("wind"), float(p.wind_mul) * 8.0,
				Loc.t("visibility"), float(p.visibility_m)], 152)
		c.custom_minimum_size.y = 104
		UiKit.set_card_selected(c, GameState.weather_id == wid)
		c.pressed.connect(func():
			GameState.weather_id = wid
			_render("free"))
		w_row.add_child(c)

	content.add_child(UiKit.spacer(12))
	var start := UiKit.button(Loc.t("menu_start"), true, 300)
	start.pressed.connect(func():
		GameState.select_free_practice(GameState.machine_id, GameState.environment_id,
			GameState.weather_id)
		_start())
	content.add_child(start)
	_add_back()


func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	content.add_child(g)
	return g


func _screen_controls() -> void:
	content.add_child(UiKit.label(Loc.t("menu_controls"), 24))
	content.add_child(UiKit.wrapped(Loc.t("ctrl_universal"), 14, 640, UiKit.ACCENT_2))
	for id in MachineCatalog.all_ids():
		var spec := MachineCatalog.get_spec(id)
		_section(MachineCatalog.display_name(spec))
		for pair in ControlScheme.pairs_for(spec):
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 14)
			var k := UiKit.label("%s / %s" % [pair.keys[0], pair.keys[1]], 13, UiKit.ACCENT_2)
			k.custom_minimum_size = Vector2(120, 0)
			line.add_child(k)
			line.add_child(UiKit.label(String(pair.label), 13, UiKit.TEXT))
			content.add_child(line)
	_section(Loc.t("ctrl_hdr_any"))
	for c in ControlScheme.COMMANDS:
		if c.ctx == "title":
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var k := UiKit.label(String(c.key), 13, UiKit.ACCENT_2)
		k.custom_minimum_size = Vector2(120, 0)
		line.add_child(k)
		line.add_child(UiKit.label(Loc.pick(c.label), 13, UiKit.TEXT))
		content.add_child(line)
	_add_back()


func _screen_settings() -> void:
	content.add_child(UiKit.label(Loc.t("menu_settings"), 24))

	var lang := UiKit.button("%s: %s" % [Loc.t("set_language"), Loc.lang_name()], false, 340)
	lang.pressed.connect(func():
		Loc.cycle()
		_render("settings"))
	content.add_child(lang)

	_toggle(Loc.t("set_keys"), "show_key_overlay")
	_toggle(Loc.t("set_path"), "show_ghost_path")
	_toggle(Loc.t("set_invert"), "invert_y")

	_section(Loc.t("set_sensitivity"))
	var slider := HSlider.new()
	slider.min_value = 0.2
	slider.max_value = 3.0
	slider.step = 0.1
	slider.value = float(GameState.settings.get("mouse_sensitivity", 1.0))
	slider.custom_minimum_size = Vector2(340, 24)
	slider.value_changed.connect(func(v):
		GameState.settings["mouse_sensitivity"] = v
		GameState.save_profile())
	content.add_child(slider)

	content.add_child(UiKit.spacer(14))
	var reset := UiKit.button(Loc.t("set_reset"), false, 340)
	reset.pressed.connect(func():
		if _reset_armed:
			GameState.reset_progress()
			_render("settings")
		else:
			_reset_armed = true
			reset.text = Loc.t("set_reset_confirm"))
	content.add_child(reset)
	_add_back()


func _toggle(title: String, key: String) -> void:
	var cb := CheckButton.new()
	cb.text = title
	cb.button_pressed = bool(GameState.settings.get(key, true))
	cb.add_theme_font_size_override("font_size", 15)
	cb.add_theme_color_override("font_color", UiKit.TEXT)
	cb.toggled.connect(func(v):
		GameState.settings[key] = v
		GameState.save_profile())
	content.add_child(cb)


func _screen_progress() -> void:
	content.add_child(UiKit.label(Loc.t("menu_progress"), 24))
	content.add_child(UiKit.label("%d / %d %s   ·   %d %s" % [
		GameState.completed_count(), ScenarioDB.all_ids().size(), Loc.t("menu_completed"),
		GameState.total_sessions, Loc.t("score_time")], 14, UiKit.TEXT_DIM))
	for id in ScenarioDB.all_ids():
		var best := GameState.best_result(id)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var mark := UiKit.label("✔" if GameState.is_completed(id) else "—", 14,
			UiKit.OK if GameState.is_completed(id) else UiKit.TEXT_DIM)
		mark.custom_minimum_size = Vector2(24, 0)
		line.add_child(mark)
		var t := UiKit.label("%s %s" % [id, ScenarioDB.title_of(id)], 13, UiKit.TEXT)
		t.custom_minimum_size = Vector2(430, 0)
		line.add_child(t)
		line.add_child(UiKit.label("%.0f" % float(best.get("points", 0.0)) if not best.is_empty()
			else "", 13, UiKit.ACCENT_2))
		content.add_child(line)
	_add_back()


func _start() -> void:
	GameState.save_profile()
	get_tree().change_scene_to_file("res://game/session.tscn")
