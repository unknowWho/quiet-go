extends RefCounted
const Presentation = preload("res://scripts/presentation.gd")
const Coach = preload("res://scripts/coach.gd")

static func row(parent: Node) -> HBoxContainer:
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	return box

static func small(app, parent: Node, text: String, action: Callable, id: String, disabled: bool = false) -> Button:
	var b: Button = app.button(parent, text, action, disabled)
	b.name = id
	b.add_theme_font_size_override("font_size", 13)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

static func build(app):
	var c = app.coach
	var g = c.game
	app.title_label.text = "跟着 AI 学棋"
	app.subtitle_label.text = "%d 路带练  /  你执%s  /  黑贴还 3¾ 子" % [g.size, "黑" if c.human == 1 else "白"]
	app.feedback_text = "先想一手，再看 AI 的应对。点击空交叉点选点，确认采用后才会落子。"
	if c.preview != null: app.feedback_text = "正在查看参考变化；编号从变化第 1 手起算。返回后仍是原局面。"
	elif c.busy: app.feedback_text = "KataGo 正在本机思考…"
	elif g.phase != "play": app.feedback_text = "形势估计不代替终局确认，请复核双方死子。"
	app.button(app.action_bar, "再练一局", func(): restart(app, g.size)).name = "coach_restart"
	app.button(app.action_bar, "悔一回合", c.undo, g.moves.is_empty()).name = "coach_undo"
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	app.right.add_child(body)
	app.label(body, "AI 带练    /    K A T A G O", 11, app.GOLD)
	if c.preview != null:
		Presentation.heading(app, body, "AI 的棋路" if c.line_kind == "best" else "你的下法之后", 27)
		app.paragraph(body, "变化  %02d / %02d" % [c.step, c.line.size()], 14, app.PAPER).name = "coach_step"
		app.rule(body)
		app.label(body, "盘面观察", 13, app.GOLD)
		app.paragraph(body, c.observation, 15, app.PAPER).name = "coach_observation"
		app.paragraph(body, "先猜对手会怎样回应，再点下一手验证。留意连接、气的变化和落子的方向。", 13)
		var controls = row(body)
		small(app, controls, "← 上一手", func(): c.set_step(c.step-1), "coach_previous", c.step == 0)
		small(app, controls, "下一手 →", func(): c.set_step(c.step+1), "coach_next", c.step == c.line.size())
		small(app, body, "返回选点", c.close_line, "coach_return")
		app.paragraph(body, "参考变化并非必然应手。盘面观察说明提子、连接与气的变化；请结合双方后续着法理解。", 12)
		var choice: Dictionary = c.best if c.line_kind == "best" else c.mine
		if choice.get("trimmed", false): app.paragraph(body, "仅显示已校验的前段；在停着终局、非法着手或长度上限处停止。", 12)
		return
	if g.phase != "play":
		var score: Dictionary = g.score()
		Presentation.heading(app, body, "确认死子" if g.phase == "scoring" else app._result_text(score), 26)
		app.paragraph(body, "黑 %.1f 子 / 白 %.1f 子\n公气 %d 点，各得一半\n上列数值尚未贴子。" % [score.black, score.white, score.neutral], 14)
		if g.phase == "scoring":
			app.paragraph(body, "点击棋块标记死子，请复核后代双方确认。有争议可以继续下。", 14)
			for color in [1, 2]:
				small(app, body, ("黑" if color == 1 else "白") + ("方已确认" if g.approvals[color] else "方确认"), func(): g.approve(color); c.changed.emit(), "coach_approve_" + str(color), g.approvals[color])
			small(app, body, "继续下", func(): g.resume_play(); c.clear_analysis(); c.enter(), "coach_resume")
		return
	Presentation.heading(app, body, "AI 应手中" if c.busy and g.turn != c.human else ("先想一手" if c.best.is_empty() else "比较下法"), 29)
	if c.busy:
		var message: String = "正在比较你的落点…" if c.request_context.get("purpose", "") == "compare" else "正在搜索后续棋路…"
		if app.katago.state == "starting": message = "正在载入本地 AI，首次显卡调优可能需要几分钟。"
		app.paragraph(body, message, 14, app.PAPER)
	if not c.error.is_empty():
		app.paragraph(body, c.error, 13, app.GOLD)
		small(app, body, "重试分析", c.retry, "coach_retry", c.busy)
	if c.best.is_empty():
		app.paragraph(body, "先在棋盘上选出你想下的位置；也可以先看 AI 的建议。", 15, app.PAPER)
		small(app, body, "看看 AI 怎么下", c.recommend, "coach_recommend", c.busy or g.turn != c.human)
		small(app, body, "我想停着", func(): c.choose(-1), "coach_pass", c.busy or g.turn != c.human)
	else:
		app.paragraph(body, "A  ·  AI 首选  " + g.coord(c.best.point), 16, app.PAPER).name = "coach_best"
		app.paragraph(body, "我  ·  " + (g.coord(c.proposal) if c.proposal >= -1 else "点击棋盘，试试你的选点"), 14, app.PAPER)
		if not c.mine.is_empty(): app.paragraph(body, c.comparison(), 14, app.GOLD).name = "coach_comparison"
		var variations = row(body)
		small(app, variations, "AI 棋路", func(): c.show_line("best"), "coach_best_line", c.busy)
		small(app, variations, "我的变化", func(): c.show_line("mine"), "coach_my_line", c.busy or c.mine.is_empty())
		var adopts = row(body)
		small(app, adopts, "采用 AI", func(): c.adopt("best"), "coach_adopt_best", c.busy)
		small(app, adopts, "采用我的", func(): c.adopt("mine"), "coach_adopt_mine", c.busy or c.mine.is_empty())
		app.paragraph(body, "采用后正式落子，AI 接着应手。也可点击其他空点重新比较。", 12)
		var samples: String = "首选 %d 次搜索" % c.best.visits
		if not c.mine.is_empty(): samples += " / 试下 %d 次" % c.mine.visits
		app.paragraph(body, samples + "\n目差为有限搜索估计，已计贴目。", 12)
		small(app, body, "我想停着", func(): c.choose(-1), "coach_pass", c.busy)
	app.rule(body)
	small(app, body, "收起设置  −" if app.settings_open else "带练设置  +", func(): app.settings_open = not app.settings_open; app._refresh(), "coach_settings")
	Presentation.heading(app, app.left, "带练设置", 22)
	app.paragraph(app.left, "带练棋局单独保存。新手可先用 9 路看清攻防，再练大棋盘。", 13)
	for n in [9, 13, 19]:
		app.button(app.left, "%d 路新练习" % n, func(): restart(app, n)).name = "coach_size_" + str(n)
	var strength = OptionButton.new()
	strength.name = "coach_strength"
	for budget in app.KataGo.LEVELS: strength.add_item("思考 · " + budget.name)
	strength.select(c.level)
	strength.disabled = c.busy
	strength.item_selected.connect(func(i): c.level = i; c.clear_analysis(); c.changed.emit())
	app.left.add_child(strength)
	app.paragraph(app.left, "深入会多搜索一段时间，结论仍可能变化。带练与对弈棋局互不覆盖。", 12)

static func restart(app, n: int):
	var action = func(): app.coach.reset(n); app.settings_open = false; app._refresh()
	if not app.coach.game.moves.is_empty() and app.coach.game.phase != "finished":
		app.confirm("开始 %d 路新带练？当前带练棋局将被替换，对弈棋局保留。" % n, action, "coach_new_dialog")
	else: action.call()
