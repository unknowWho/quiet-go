extends RefCounted
## Native Godot typography and controls over the live table.
const INK = Color("f0e5cf")
const SECONDARY = Color("c9bba2")
const ACCENT = Color("da9c72")

static func serif() -> SystemFont:
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Serif SC", "Source Han Serif SC", "SimSun"])
	font.font_weight = 400
	return font

static func configure(app):
	var t = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans SC", "Microsoft YaHei UI"])
	font.font_weight = 400
	t.default_font = font
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	for kind in ["Button", "NavButton", "PrimaryButton", "EntryButton", "ListButton"]:
		if kind != "Button": t.set_type_variation(kind, "Button")
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0,0,0,0)
			style.set_content_margin_all(10)
			style.content_margin_left = 14
			style.content_margin_right = 14
			if state in ["hover", "pressed"]:
				style.bg_color = Color(0.95,0.85,0.65,0.065)
			if state == "focus":
				style.border_color = ACCENT
				style.border_width_bottom = 1
			if kind == "NavButton":
				style.content_margin_left = 18
				style.content_margin_right = 18
				if state == "pressed":
					style.bg_color = Color(0,0,0,0)
					style.border_width_bottom = 1
					style.border_color = ACCENT
			if kind == "EntryButton":
				style.content_margin_left = 0
				style.content_margin_top = 16
				style.content_margin_bottom = 16
				style.bg_color = Color(0,0,0,0)
			if kind in ["ListButton", "PrimaryButton"]:
				style.content_margin_left = 12
				style.content_margin_right = 7
				if state == "pressed" or kind == "PrimaryButton":
					style.border_width_left = 2
					style.border_color = ACCENT
					style.bg_color = Color(0.9,0.75,0.5,0.07)
			t.set_stylebox(state,kind,style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
			var color = SECONDARY if state == "font_color" else INK
			if state == "font_disabled_color": color = Color("928978")
			if kind in ["EntryButton", "PrimaryButton"] and state != "font_disabled_color": color = INK
			if kind == "EntryButton" and state == "font_hover_color": color = ACCENT
			t.set_color(state,kind,color)
	t.set_font("font", "EntryButton", serif())
	t.set_font_size("font_size", "EntryButton", 30)
	var clear = StyleBoxEmpty.new()
	t.set_stylebox("panel", "PanelContainer", clear)
	var popup = StyleBoxFlat.new()
	popup.bg_color = Color("302c25")
	popup.border_color = Color("635747")
	popup.set_border_width_all(1)
	popup.set_content_margin_all(24)
	t.set_stylebox("panel", "AcceptDialog", popup)
	var field = StyleBoxFlat.new()
	field.bg_color = Color(0.10, 0.09, 0.07, 0.5)
	field.set_content_margin_all(9)
	field.border_width_bottom = 1
	field.border_color = Color("635747")
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", SECONDARY)
	t.set_color("caret_color", "LineEdit", ACCENT)
	var menu = popup.duplicate()
	menu.set_content_margin_all(8)
	t.set_stylebox("panel", "PopupMenu", menu)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	var separator = StyleBoxLine.new()
	separator.color = Color(0.9,0.82,0.65,0.20)
	separator.thickness = 1
	separator.content_margin_top = 8
	separator.content_margin_bottom = 8
	t.set_stylebox("separator", "HSeparator", separator)
	var track = StyleBoxEmpty.new()
	track.content_margin_left = 6
	t.set_stylebox("scroll", "VScrollBar", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var thumb = StyleBoxFlat.new()
		thumb.bg_color = Color("8e816c")
		thumb.content_margin_left = 3
		t.set_stylebox(state, "VScrollBar", thumb)
	app.theme = t

static func panel(parent: Node, rect: Vector4) -> PanelContainer:
	var result = PanelContainer.new()
	result.offset_left=rect.x
	result.offset_top=rect.y
	result.offset_right=rect.z
	result.offset_bottom=rect.w
	parent.add_child(result)
	return result

static func sidebar(parent: PanelContainer) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	return content

static func space(parent: Node, height: float):
	var gap = Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)

static func heading(app, parent: Node, text: String, size: int = 30) -> Label:
	var node: Label = app.label(parent, text, size, INK)
	node.add_theme_font_override("font", serif())
	return node

static func entry(app, parent: Node, number: String, title: String, note: String, action: Callable) -> Button:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var index: Label = app.label(row, number, 12, ACCENT)
	index.custom_minimum_size.x = 24
	index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var b: Button = app.button(row, title, action)
	b.theme_type_variation = "EntryButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint: Label = app.paragraph(parent, note, 13, SECONDARY)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.rule(parent)
	return b

static func build(app):
	var background = SubViewportContainer.new()
	background.name = "BoardViewport"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.stretch = true
	app.add_child(background)
	app.viewport = SubViewport.new()
	app.viewport.size = Vector2i(1440,900)
	app.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	app.viewport.msaa_3d = Viewport.MSAA_4X
	app.viewport.use_taa = true
	app.viewport.own_world_3d = true
	background.add_child(app.viewport)
	app.board_view = app.BoardView.new()
	app.viewport.add_child(app.board_view)
	app.board_view.point_clicked.connect(app._on_point)
	app.board_view.point_hovered.connect(app._on_hover)
	var edge = ColorRect.new()
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade = ShaderMaterial.new()
	shade.shader = load("res://assets/ui_shade.gdshader")
	app.ui_shade = shade
	edge.material = shade
	app.add_child(edge)
	var ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.add_child(ui)
	var header = panel(ui,Vector4(48,26,-48,90))
	header.anchor_right = 1
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)
	var logo = HBoxContainer.new()
	logo.custom_minimum_size.x = 265
	logo.add_theme_constant_override("separation", 17)
	row.add_child(logo)
	var brand: Label = heading(app, logo, "静 枰", 33)
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var seal = PanelContainer.new()
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seal_style = StyleBoxFlat.new()
	seal_style.bg_color = Color("9b4b35")
	seal_style.content_margin_left=5
	seal_style.content_margin_right=5
	seal_style.content_margin_top=3
	seal_style.content_margin_bottom=3
	seal.add_theme_stylebox_override("panel",seal_style)
	logo.add_child(seal)
	var stamp: Label = heading(app,seal,"手\n谈",11)
	stamp.add_theme_constant_override("line_spacing",-2)
	app.nav_row = HBoxContainer.new()
	app.nav_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	app.nav_row.add_theme_constant_override("separation", 7)
	row.add_child(app.nav_row)
	for item in [["home","棋室"],["play","对弈"],["lessons","入门教学"],["puzzles","死活练习"]]:
		var key: String = item[0]
		var b: Button = app.button(app.nav_row,item[1],func(): app._navigate(key))
		b.theme_type_variation = "NavButton"
		b.toggle_mode = true
		b.name = "nav_"+key
		app.nav_buttons[key] = b
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var help: Button = app.button(row,"规则",app._show_rules)
	help.name = "rules_button"
	help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	app.sound_button = app.button(row,"声音",func(): app.sound_on=not app.sound_on; app._save(); app._refresh())
	app.sound_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	app.title_label = heading(app,ui,"",23)
	app.title_label.position = Vector2(49,113)
	app.title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.subtitle_label = app.label(ui,"",12,SECONDARY)
	app.subtitle_label.position = Vector2(50,151)
	app.subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.left_panel = panel(ui,Vector4(32,198,279,-139))
	app.left_panel.anchor_bottom = 1
	var drawer = StyleBoxFlat.new()
	drawer.bg_color = Color(0.16,0.145,0.12,0.96)
	drawer.content_margin_left=19
	drawer.content_margin_right=19
	drawer.content_margin_top=22
	drawer.content_margin_bottom=20
	drawer.border_color=Color(0.85,0.7,0.5,0.3)
	drawer.border_width_top=1
	app.left_panel.add_theme_stylebox_override("panel",drawer)
	app.left = sidebar(app.left_panel)
	app.right_panel = panel(ui,Vector4(-290,210,-48,-115))
	app.right_panel.anchor_left=1
	app.right_panel.anchor_right=1
	app.right_panel.anchor_bottom=1
	app.right = sidebar(app.right_panel)
	app.dock_panel = panel(ui,Vector4(48,-108,-337,-34))
	app.dock_panel.anchor_top=1
	app.dock_panel.anchor_bottom=1
	app.dock_panel.anchor_right=1
	var dock = VBoxContainer.new()
	dock.add_theme_constant_override("separation",8)
	app.dock_panel.add_child(dock)
	app.action_bar = HBoxContainer.new()
	app.action_bar.add_theme_constant_override("separation",12)
	dock.add_child(app.action_bar)
	app.feedback_label = app.paragraph(dock,"",13,SECONDARY)
	var footer = HBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=49
	footer.offset_right=-49
	footer.offset_top=-24
	footer.offset_bottom=-5
	footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(footer)
	app.label(footer,"静枰  /  中国数子",10,SECONDARY)
	var spacer = Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	app.hover_label=app.label(footer,"V 俯视    N 手数    M 声音",10,SECONDARY)

static func arrange(app):
	var home: bool = app.section == "home"
	var learning: bool = app.section in ["lessons", "puzzles"]
	app.ui_shade.set_shader_parameter("learning_focus", 1.0 if app.section == "puzzles" and app.focus_puzzle and app.puzzles[app.puzzle_index].has("nodes") else 0.0)
	app.nav_row.visible = not home
	app.title_label.visible = not home
	app.subtitle_label.visible = not home
	app.dock_panel.visible = not home
	app.left_panel.visible = (learning and app.catalog_open) or (app.section == "play" and app.settings_open)
	app.dock_panel.offset_left = 304 if learning and app.catalog_open else 48
	app.right_panel.offset_top = 222 if home else (187 if learning else 220)
	app.right_panel.offset_bottom = -115
