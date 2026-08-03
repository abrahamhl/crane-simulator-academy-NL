extends RefCounted
## UiKit — one visual language for every screen.
##
## All menus and the HUD build their controls through these helpers, so the
## simulator looks like one product instead of five differently-styled
## debug panels. Colours are chosen for a control-room feel and for legibility
## against a bright outdoor scene as well as a dark night one: high-contrast
## text on translucent dark panels, with the safety palette (green / amber /
## red) reserved exclusively for actual machine state so it never competes
## with ordinary UI decoration.

const BG        := Color(0.055, 0.065, 0.085, 0.92)
const BG_SOLID  := Color(0.055, 0.065, 0.085, 1.0)
const PANEL     := Color(0.10, 0.12, 0.155, 0.90)
const PANEL_HI  := Color(0.14, 0.17, 0.22, 0.95)
const LINE      := Color(0.32, 0.40, 0.50, 0.55)
const TEXT      := Color(0.90, 0.93, 0.97)
const TEXT_DIM  := Color(0.62, 0.68, 0.76)
const ACCENT    := Color(0.30, 0.68, 0.98)
const ACCENT_2  := Color(0.98, 0.72, 0.12)

const OK        := Color(0.24, 0.86, 0.42)
const WARN      := Color(0.98, 0.74, 0.10)
const DANGER    := Color(0.96, 0.24, 0.18)

const RADIUS := 6


static func panel_style(color: Color = PANEL, border: Color = LINE,
		radius: int = RADIUS, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func panel(color: Color = PANEL, margin: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color, LINE, RADIUS, margin))
	return p


static func label(text: String, size: int = 15, color: Color = TEXT,
		bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


static func wrapped(text: String, size: int = 15, width: float = 460.0,
		color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func heading(text: String, size: int = 26) -> Label:
	return label(text, size, TEXT)


## Menu button. `primary` gives the accent treatment used for the one action
## the screen most wants the player to take.
static func button(text: String, primary: bool = false, min_width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 46)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 17)
	var base := ACCENT if primary else PANEL_HI
	var fg := Color(0.03, 0.06, 0.10) if primary else TEXT
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", Color(0.03, 0.06, 0.10) if primary else Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color(0.03, 0.06, 0.10) if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_stylebox_override("normal", panel_style(base, LINE, RADIUS, 10))
	b.add_theme_stylebox_override("hover", panel_style(
		base.lightened(0.16), ACCENT, RADIUS, 10))
	b.add_theme_stylebox_override("pressed", panel_style(
		base.darkened(0.18), ACCENT, RADIUS, 10))
	b.add_theme_stylebox_override("focus", panel_style(
		Color(0, 0, 0, 0), ACCENT, RADIUS, 10))
	b.add_theme_stylebox_override("disabled", panel_style(
		Color(0.10, 0.11, 0.13, 0.7), Color(0.25, 0.28, 0.32, 0.5), RADIUS, 10))
	return b


## Selectable card used in the machine / site / weather pickers: a title, a
## subtitle and a selected state that is obvious at a glance.
static func card(title: String, subtitle: String, width: float = 300.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, 108)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = false
	b.add_theme_stylebox_override("normal", panel_style(PANEL, LINE, RADIUS, 12))
	b.add_theme_stylebox_override("hover", panel_style(PANEL_HI, ACCENT, RADIUS, 12))
	b.add_theme_stylebox_override("pressed", panel_style(PANEL_HI, ACCENT, RADIUS, 12))
	b.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), ACCENT, RADIUS, 12))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 10
	box.offset_right = -14
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	var t := label(title, 17, TEXT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)
	var s := wrapped(subtitle, 12, width - 34, TEXT_DIM)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(s)
	b.add_child(box)
	return b


static func set_card_selected(b: Button, selected: bool) -> void:
	var bg := PANEL_HI if selected else PANEL
	var border := ACCENT if selected else LINE
	b.add_theme_stylebox_override("normal", panel_style(bg, border, RADIUS, 12))
	if selected:
		b.add_theme_stylebox_override("hover", panel_style(bg, ACCENT, RADIUS, 12))


static func separator() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = LINE
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	return s


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## Full-screen dim behind a modal.
static func scrim(alpha: float = 0.80) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.025, 0.035, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## The legal line that must appear on the title screen, the briefing and the
## results screen. Kept in one function so it cannot drift between them.
static func disclaimer_label(width: float = 720.0) -> Label:
	var l := wrapped(Loc.t("disclaimer"), 11, width, TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
