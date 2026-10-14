extends Control
const Rules = preload("res://scripts/rules.gd")
const Content = preload("res://scripts/content.gd")
const Opponent = preload("res://scripts/opponent.gd")
const BoardView = preload("res://scripts/board_view.gd")
const Presentation = preload("res://scripts/presentation.gd")
const PuzzleSession = preload("res://scripts/puzzle_session.gd")
const BG = Color("e8e7dd")
const PAPER = Color("f0e5cf")
const MUTED = Color("c9bba2")
const GOLD = Color("da9c72")
var game = Rules.new(19)
var exercise = null
var lessons: Array = Content.lessons()
var puzzles: Array = Content.puzzles()
var section: String = "home"
var mode: String = "local"
var lesson_index: int = 0
var puzzle_index: int = 0
var solved: bool = false
var assisted: bool = false
var hint_point: int = -1
var progress: Dictionary = {}
var sound_on: bool = true
var show_numbers: bool = false
var busy: bool = false
var ai_generation: int = 0
var feedback_text: String = "木盘与黑白之间，慢慢下一局。"
var board_view
var viewport: SubViewport
var left: VBoxContainer
var right: VBoxContainer
var title_label: Label
var subtitle_label: Label
var feedback_label: Label
var hover_label: Label
var action_bar: HBoxContainer
var nav_buttons: Dictionary = {}
var audio_player: AudioStreamPlayer
var recorded_sounds: Array = []
var sound_index: int = 0
var save_path: String = "user://quiet-go.json"
var test_mode: bool = false
var ai_wait: float = 0.45
var export_dialog: FileDialog
var left_panel: PanelContainer
var right_panel: PanelContainer
var dock_panel: PanelContainer
var sound_button: Button
var nav_row: HBoxContainer
var settings_open: bool = false
var catalog_open: bool = false
var history_open: bool = false
var home_preview = Rules.new(19)
var puzzle_session = null
var puzzle_difficulty: String = "all"
var puzzle_status: String = "all"
var puzzle_search: String = ""
var puzzle_page: int = 0
var puzzle_attempts: Dictionary = {}
var mistakes: Dictionary = {}
var focus_puzzle: bool = true
var ui_shade: ShaderMaterial
const PAGE_SIZE: int = 8

func _ready():
	test_mode = OS.get_cmdline_user_args().has("--test-mode")
	if test_mode: save_path = "res://.runtime/test-save.json"
	_make_theme()
	_load_save()
	_build_ui()
	for p in [60,300,72,288,249,268,250,309,111,51,52,71,53,70,32,50,97,98,78,79,61,80,40,59,41,58,308,289,290,271,311,293]:
		home_preview.play(p)
	_make_sound()
	_refresh()

func _make_theme():
	Presentation.configure(self)

func _build_ui():
	Presentation.build(self)

func sidebar(parent: Node, width: int) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return content

func label(parent: Node, text_value: String, font_size: int = 16, color: Color = PAPER) -> Label:
	var node: Label = Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func paragraph(parent: Node, text_value: String, font_size: int = 15, color: Color = MUTED) -> Label:
	var node: Label = label(parent, text_value, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_constant_override("line_spacing", 6)
	return node

func button(parent: Node, text_value: String, action: Callable, disabled: bool = false) -> Button:
	var node: Button = Button.new()
	node.text = text_value
	node.disabled = disabled
	if parent == left or parent == right: node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func rule(parent: Node):
	parent.add_child(HSeparator.new())

func clear(parent: Node):
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func current():
	return exercise if section in ["lessons", "puzzles"] and exercise != null else game

func _navigate(to: String):
	ai_generation += 1
	busy = false
	section = to
	settings_open = false
	catalog_open = false
	history_open = false
	hint_point = -1
	if to in ["lessons", "puzzles"]: _load_exercise()
	else:
		exercise = null
		feedback_text = "点击空交叉点落子。双方连续停着后，进入死子确认。" if to == "play" else "木盘与黑白之间，慢慢下一局。"
		_refresh()
		_maybe_ai()

func _load_exercise():
	var item: Dictionary = lessons[lesson_index] if section == "lessons" else puzzles[puzzle_index]
	puzzle_session = null
	if section == "puzzles" and item.has("nodes"):
		var attempt: int = int(puzzle_attempts.get(item.id, 0))
		puzzle_session = PuzzleSession.new(item, attempt)
		puzzle_attempts[item.id] = attempt + 1
		exercise = puzzle_session.game
	else:
		exercise = Rules.new(9)
		exercise.setup(item.board, int(item.turn))
	for p in item.get("preplay", []): exercise.play(p)
	solved = false
	assisted = false
	hint_point = -1
	feedback_text = "请在棋盘上作答。" if section == "lessons" else "先读题，再落子。做错可以直接重试。"
	_save()
	_refresh()

func _refresh():
	if not is_instance_valid(left): return
	sound_button.text = "声音 开" if sound_on else "声音 关"
	for key in nav_buttons:
		nav_buttons[key].set_pressed_no_signal(section == key)
	clear(left)
	clear(right)
	clear(action_bar)
	var g = current()
	var learning: bool = section in ["lessons", "puzzles"]
	Presentation.arrange(self)
	board_view.set_training(learning)
	if section == "home" and game.moves.is_empty(): g = home_preview
	board_view.active = section != "home" and not busy and not (section in ["lessons", "puzzles"] and solved)
	var annotations: Dictionary = puzzle_session.annotations() if section == "puzzles" and puzzle_session != null else {}
	board_view.refresh(g, show_numbers, g.phase in ["scoring", "finished"] and not g.resigned, hint_point, annotations)
	board_view.set_focus(puzzles[puzzle_index].get("focus", []) if section == "puzzles" and focus_puzzle else [])
	if section == "home": _home_ui()
	elif section == "play": _play_ui()
	else: _exercise_ui()
	button(action_bar, "斜视" if board_view.top_view else "俯视", func(): board_view.set_camera(not board_view.top_view); _refresh())
	button(action_bar, "隐藏手数" if show_numbers else "显示手数", func(): show_numbers = not show_numbers; _refresh())
	feedback_label.text = feedback_text
	feedback_label.add_theme_color_override("font_color", GOLD if solved and section in ["lessons", "puzzles"] else PAPER)

func _home_ui():
	label(right, "棋 室    /    Q U I E T  G O", 11, GOLD)
	Presentation.space(right, 15)
	Presentation.entry(self, right, "01", "入席对弈", "同屏双人  ·  入门陪练", func(): _navigate("play")).name = "home_start"
	Presentation.entry(self, right, "02", "从零入门", "八节交互课程，认识围棋。", func(): _navigate("lessons")).name = "home_lessons"
	Presentation.entry(self, right, "03", "死活研习", "%d 道练习，从眼形到死活与手筋。" % puzzles.size(), func(): _navigate("puzzles")).name = "home_puzzles"
	Presentation.space(right, 12)
	paragraph(right, "已学 %d / 8 课    已解 %d / %d 题" % [_progress_count("lesson_"), _progress_count("puzzle_", true), puzzles.size()], 12)

func _play_ui():
	var c: String = "黑" if game.turn == 1 else "白"
	title_label.text = "手谈 · %d 路" % game.size
	subtitle_label.text = ("同屏双人" if mode == "local" else "入门陪练 · 你执黑") + "    /    黑贴 3¾ 子    /    不限时"
	Presentation.heading(self, left, "对局设置", 23)
	paragraph(left, "当前棋局会自动保存。开始新局将替换这盘棋。", 13)
	for n in [9, 13, 19]:
		button(left, "%d 路 · %s" % [n, "入门" if n == 9 else ("进阶" if n == 13 else "标准")], func(): _request_new(n, mode))
	rule(left)
	button(left, "✓ 同屏双人" if mode == "local" else "同屏双人", func(): _request_new(game.size, "local"))
	button(left, "✓ 入门陪练" if mode == "ai" else "入门陪练", func(): _request_new(game.size, "ai"))
	if mode == "ai": paragraph(left, "陪练会提子、逃打吃、连接与占点，适合熟悉操作；不标称段位。终局由你复核盘面。", 13)
	rule(left)
	button(left, "导出棋谱 SGF", _export_sgf)
	if game.phase == "play": button(left, "认输结束本局", _request_resign, busy)
	paragraph(left, "悔棋是练习工具；同屏对弈时请先与对手商量。", 13)
	if game.phase == "play":
		label(right, "对 局    /    %d 路" % game.size, 11, GOLD)
		Presentation.space(right, 8)
		Presentation.heading(self, right, "白方思考中" if busy else c + "方落子", 32)
		paragraph(right, "第 %d 手  ·  %s" % [game.moves.size()+1, "同屏双人" if mode == "local" else "入门陪练"], 14)
		Presentation.space(right, 18)
		paragraph(right, "提子    黑  %d    /    白  %d" % [game.captures[1], game.captures[2]], 14)
		if game.passes == 1: paragraph(right, "上一手停着。再停一手就进入终局确认。", 15, GOLD)
		button(action_bar, "停着", _pass, busy).name = "pass_button"
		button(action_bar, "悔棋", _undo, busy or game.moves.is_empty()).name = "undo_button"
	elif game.resigned:
		label(right, ("白" if game.resigned == 1 else "黑") + "棋获胜", 25, GOLD)
		paragraph(right, ("黑" if game.resigned == 1 else "白") + "方中盘认输。")
		button(action_bar, "再来一局", func(): _request_new(game.size, mode))
	else:
		var s: Dictionary = game.score()
		label(right, "确认死子" if game.phase == "scoring" else _result_text(s), 22, GOLD)
		paragraph(right, "黑  %.1f 子\n白  %.1f 子\n公气 %d 点，各得一半\n黑贴还 3¾ 子" % [s.black, s.white, s.neutral], 15, PAPER)
		paragraph(right, "盘上活子 + 围住空点 + 公气一半；上方数值尚未贴子。", 12)
		if game.phase == "scoring":
			paragraph(right, "点击整块棋，标记或取消死子。红 × 是拟移除的棋子。死活有争议时继续下。", 14, GOLD)
			button(right, "✓ 黑方已确认" if game.approvals[1] else "黑方确认", func(): _approve(1), game.approvals[1]).name = "approve_black"
			button(right, "✓ 白方已确认" if game.approvals[2] else "白方确认", func(): _approve(2), game.approvals[2]).name = "approve_white"
			button(action_bar, "继续对弈", _resume).name = "resume_button"
			if mode == "ai": paragraph(right, "陪练局也请检查双方死子，再代双方确认。未使用自动死活裁判。", 12)
		else:
			paragraph(right, "双方已确认结果。胜差按中国数子法以“子”显示。", 14)
			button(action_bar, "再来一局", func(): _request_new(game.size, mode))
	rule(right)
	button(right, "棋谱  −" if history_open else "棋谱  +", func():
		history_open = not history_open
		_refresh()).name = "history_button"
	if history_open:
		var start: int = maxi(0, game.moves.size()-5)
		for i in range(start, game.moves.size()):
			var m: Dictionary = game.moves[i]
			label(right, "%02d    %s    %s" % [i+1, "黑" if m.color == 1 else "白", game.coord(m.point)], 14, MUTED)
		if game.moves.is_empty(): paragraph(right, "黑先。点击棋盘开始。", 14)
	button(right, "收起设置  −" if settings_open else "棋局设置  +", func():
		settings_open = not settings_open
		_refresh()).name = "settings_button"

func _exercise_ui():
	var is_lesson: bool = section == "lessons"
	var list: Array = lessons if is_lesson else puzzles
	var index: int = lesson_index if is_lesson else puzzle_index
	var item: Dictionary = list[index]
	title_label.text = item.title
	subtitle_label.text = ("入门教学  /  " if is_lesson else "死活练习  /  ") + ("第 %d / %d 课" if is_lesson else "第 %d / %d 题") % [index+1, list.size()]
	Presentation.heading(self, left, "入门课程" if is_lesson else "研习题库", 22)
	paragraph(left, "每课只练一个概念。" if is_lesson else "%d 道题 · 分级研习" % puzzles.size(), 13)
	var indices: Array = range(list.size()) if is_lesson else _puzzle_catalog_filters()
	for i in indices:
		var status: String = str(progress.get("lesson_" + str(i) if is_lesson else _puzzle_key(i), ""))
		var mark: String = "✓ " if status == "independent" else ("◌ " if status == "guided" else "")
		var b: Button = button(left, ("%02d  " % [i+1] if is_lesson else "") + mark + list[i].title, func():
			if is_lesson: lesson_index = i
			else: puzzle_index = i
			_load_exercise())
		b.add_theme_font_size_override("font_size", 14)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.theme_type_variation = "PrimaryButton" if i == index else "ListButton"
		b.name = "exercise_" + str(i)
	button(right, ("收起目录  −" if catalog_open else "打开目录  +") + "    %02d / %02d" % [index+1,list.size()], func():
		catalog_open = not catalog_open
		_refresh()).name = "catalog_button"
	Presentation.space(right, 13)
	Presentation.heading(self, right, "本课目标" if is_lesson else item.get("goal", "黑先 · 做活" if item.turn == 1 else "白先 · 杀棋"), 26)
	paragraph(right, item.text, 15, PAPER)
	rule(right)
	if solved:
		label(right, "参考完成" if assisted else "独立完成", 19, GOLD)
		paragraph(right, item.get("success", item.get("explain", "")), 14, PAPER)
		if item.has("branches"):
			for branch in range(item.branches.size()):
				button(right, "演示变化 " + str(branch+1), func(): _show_branch(branch))
		button(action_bar, "再练一次", _load_exercise)
		if is_lesson:
			button(action_bar, "下一课", func(): lesson_index = (lesson_index+1) % list.size(); _load_exercise())
	else:
		button(right, "给一点提示", _hint)
		button(right, "查看落点", _show_answer)
		if is_lesson and item.answer.has(-1): button(action_bar, "练习停着", func(): _answer(-1)).name = "lesson_pass"
		if puzzle_session != null and puzzle_session.answers().has(-1): button(action_bar, "练习停着", func(): _answer(-1)).name = "puzzle_pass"
		button(action_bar, "重置练习", _load_exercise)
	if not is_lesson:
		button(action_bar, "上一题", func(): _step_puzzle(-1)).name = "previous_puzzle"
		button(action_bar, "下一题", func(): _step_puzzle(1)).name = "next_puzzle"
		button(right, "随机练一题", _random_puzzle).name = "random_puzzle"
		if item.has("nodes"):
			button(right, "查看全盘" if focus_puzzle else "聚焦题形", func(): focus_puzzle = not focus_puzzle; _refresh()).name = "puzzle_focus"
			button(right, "原题评注与来源" if solved else "题目来源", _puzzle_source).name = "puzzle_source"
			paragraph(right, "Go Game Guru  /  " + str(item.level), 12)
	paragraph(right, "✓ 独立完成    ◌ 参考完成\n使用提示后完成会单独记录。", 12)

func _puzzle_key(index: int) -> String:
	return "puzzle_" + str(puzzles[index].id)

func _filtered_puzzles() -> Array:
	var out: Array = []
	for i in range(puzzles.size()):
		var item: Dictionary = puzzles[i]
		if puzzle_difficulty != "all" and item.difficulty != puzzle_difficulty: continue
		var status: String = str(progress.get(_puzzle_key(i), ""))
		if puzzle_status == "unsolved" and status == "independent": continue
		if puzzle_status in ["guided", "independent"] and status != puzzle_status: continue
		if puzzle_status == "mistakes" and not mistakes.has(item.id): continue
		var query: String = puzzle_search.strip_edges().to_lower()
		if not query.is_empty() and not (str(item.title) + " " + str(item.id) + " " + str(item.type)).to_lower().contains(query): continue
		out.append(i)
	return out

func _puzzle_catalog_filters() -> Array:
	var difficulty = OptionButton.new()
	difficulty.name = "difficulty_filter"
	var keys: Array = ["all", "basic", "easy", "intermediate", "hard"]
	for text_value in ["全部难度", "基础 · 10 题", "初级 · 140 题", "中级 · 140 题", "高级 · 140 题"]: difficulty.add_item(text_value)
	difficulty.select(keys.find(puzzle_difficulty))
	difficulty.item_selected.connect(func(i): puzzle_difficulty = keys[i]; puzzle_page = 0; _refresh())
	left.add_child(difficulty)
	var state = OptionButton.new()
	state.name = "progress_filter"
	var states: Array = ["all", "unsolved", "independent", "guided", "mistakes"]
	for text_value in ["全部进度", "尚未独立完成", "已独立完成", "参考完成", "错题重练"]: state.add_item(text_value)
	state.select(states.find(puzzle_status))
	state.item_selected.connect(func(i): puzzle_status = states[i]; puzzle_page = 0; _refresh())
	left.add_child(state)
	var search = LineEdit.new()
	search.name = "puzzle_search"
	search.placeholder_text = "题号 / 名称，回车搜索"
	search.text = puzzle_search
	search.clear_button_enabled = true
	search.text_submitted.connect(func(value): puzzle_search = value; puzzle_page = 0; _refresh())
	search.text_changed.connect(func(value):
		if value.is_empty() and not puzzle_search.is_empty():
			puzzle_search = ""
			puzzle_page = 0
			call_deferred("_refresh"))
	left.add_child(search)
	var matches: Array = _filtered_puzzles()
	var pages: int = maxi(1, ceili(matches.size() / float(PAGE_SIZE)))
	puzzle_page = clampi(puzzle_page, 0, pages-1)
	var pager = HBoxContainer.new()
	left.add_child(pager)
	button(pager, "‹", func(): puzzle_page -= 1; _refresh(), puzzle_page == 0).name = "catalog_previous"
	var page_label: Label = label(pager, "%d / %d  ·  %d 题" % [puzzle_page+1, pages, matches.size()], 12)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button(pager, "›", func(): puzzle_page += 1; _refresh(), puzzle_page >= pages-1).name = "catalog_next"
	if matches.is_empty(): paragraph(left, "没有符合条件的题目。试着更换筛选或清空搜索。", 13)
	return matches.slice(puzzle_page * PAGE_SIZE, (puzzle_page+1) * PAGE_SIZE)

func _step_puzzle(direction: int):
	var matches: Array = _filtered_puzzles()
	if matches.is_empty():
		feedback_text = "当前筛选没有题目，请打开目录调整筛选。"
		_refresh()
		return
	var at: int = matches.find(puzzle_index)
	if at < 0: at = -1 if direction > 0 else 0
	puzzle_index = matches[posmod(at + direction, matches.size())]
	puzzle_page = matches.find(puzzle_index) / PAGE_SIZE
	_load_exercise()

func _random_puzzle():
	var matches: Array = _filtered_puzzles()
	if matches.size() > 1: matches.erase(puzzle_index)
	if matches.is_empty():
		feedback_text = "当前筛选没有其他题目，请调整筛选。"
		_refresh()
		return
	puzzle_index = matches.pick_random()
	puzzle_page = _filtered_puzzles().find(puzzle_index) / PAGE_SIZE
	_load_exercise()

func _puzzle_source():
	var item: Dictionary = puzzles[puzzle_index]
	var text_value: String = "%s\nGo Game Guru Weekly Go Problems\n作者：David Ormerod、An Younggil（职业八段）" % item.title
	if solved and puzzle_session != null: text_value += "\n\n本次变化 · 英文原注\n\n" + puzzle_session.commentary()
	text_value += "\n\n题集包含死活、劫争和手筋。正确结论以原题评注为准；原题没有收录的着手不会直接判错。难度沿用作者分组，不代表棋力段位。\n\n许可：CC BY-NC-SA 4.0（署名、非商业、相同方式共享）。原始棋谱、许可全文和改编说明随题库提供。"
	var dialog = AcceptDialog.new()
	dialog.name = "puzzle_source_dialog"
	dialog.title = "题目来源与评注"
	dialog.ok_button_text = "返回棋盘"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	var body = VBoxContainer.new()
	dialog.add_child(body)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 390)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var copy: Label = paragraph(scroll, text_value, 15, PAPER)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(body, "打开原始题谱网页 ↗", func(): OS.shell_open(item.source_url))
	dialog.popup_centered(Vector2i(750, 530))

func _on_point(p: int):
	if section == "home" or busy: return
	if section in ["lessons", "puzzles"]:
		if not solved: _answer(p)
		return
	if game.phase == "scoring":
		if game.mark_dead(p):
			feedback_text = "死子标记已更新，双方需要重新确认。"
			_save()
			_refresh()
		return
	if game.phase != "play": return
	var r: Dictionary = game.play(p)
	if not r.ok:
		feedback_text = r.reason
		_refresh()
		return
	_click_sound()
	feedback_text = "%s落在 %s%s" % ["黑棋" if game.turn == 2 else "白棋", game.coord(p), "，提走 %d 子。" % r.captured.size() if not r.captured.is_empty() else "。"]
	_save()
	_refresh()
	_maybe_ai()

func _answer(p: int):
	var item: Dictionary = lessons[lesson_index] if section == "lessons" else puzzles[puzzle_index]
	if section == "puzzles" and puzzle_session != null:
		var result: Dictionary = puzzle_session.submit(p)
		if result.status not in ["continue", "complete"]:
			feedback_text = result.reason
			if result.status == "refuted":
				mistakes[item.id] = true
				_save()
			_refresh()
			return
		hint_point = -1
		_click_sound()
		if result.status == "complete": _complete_exercise(item)
		else:
			var last: Dictionary = exercise.moves[-1]
			feedback_text = "白棋应在 %s。轮到黑棋，请继续读后续变化。" % exercise.coord(int(last.point))
		_refresh()
		return
	if p >= 0:
		var r: Dictionary = exercise.probe(p)
		if not r.ok:
			feedback_text = r.reason
			_refresh()
			return
	if not item.answer.has(p):
		feedback_text = "这里可以落子，但还没有完成题目目标。再看看棋子的气和眼位。"
		if section == "puzzles":
			mistakes[item.id] = true
			_save()
		_refresh()
		return
	if p < 0: exercise.pass_turn()
	else: exercise.play(p)
	_click_sound()
	_complete_exercise(item)
	_refresh()

func _complete_exercise(item: Dictionary):
	solved = true
	hint_point = -1
	var key: String = ("lesson_" + str(lesson_index)) if section == "lessons" else _puzzle_key(puzzle_index)
	if progress.get(key, "") != "independent": progress[key] = "guided" if assisted else "independent"
	if section == "puzzles" and not assisted: mistakes.erase(item.id)
	feedback_text = item.get("success", item.get("explain", "完成。"))
	_save()

func _show_branch(index: int):
	var item: Dictionary = puzzles[puzzle_index]
	exercise = Rules.new(9)
	exercise.setup(item.board, item.turn)
	exercise.play(item.answer[0])
	for p in item.branches[index]:
		var result: Dictionary = exercise.play(p)
		if not result.ok:
			feedback_text = "变化校验失败。"
			_refresh()
			return
	feedback_text = "变化 %d：黑棋无法做出两眼，白棋用最后一手提掉整块黑棋。点击再练一次返回初始题面。" % (index+1)
	_refresh()

func _hint():
	assisted = true
	feedback_text = (lessons[lesson_index] if section == "lessons" else puzzles[puzzle_index]).hint
	_refresh()

func _show_answer():
	assisted = true
	var item: Dictionary = lessons[lesson_index] if section == "lessons" else puzzles[puzzle_index]
	hint_point = int(puzzle_session.answers()[0]) if section == "puzzles" and puzzle_session != null else int(item.answer[0])
	feedback_text = "绿色圈标记参考落点，请亲自落子观察结果。" if hint_point >= 0 else "请点击练习停着。"
	_refresh()

func _on_hover(p: int):
	var g = current()
	if p < 0: return
	var text_value: String = g.coord(p)
	if g.board[p] != 0:
		var group: Dictionary = g.group(p)
		text_value += "  ·  %d 子 / %d 口气" % [group.stones.size(), group.liberties.size()]
	hover_label.text = text_value

func _pass():
	if busy or section != "play" or not game.pass_turn(): return
	feedback_text = "双方连续停着。请共同标记死子并确认；有争议可以继续对弈。" if game.phase == "scoring" else "上一方停着，现在轮到对方。"
	_save()
	_refresh()
	_maybe_ai()

func _undo():
	if busy or section != "play": return
	if not game.undo(): return
	if mode == "ai" and game.turn == 2 and not game.moves.is_empty(): game.undo()
	feedback_text = "已回到上一回合。"
	_save()
	_refresh()

func _approve(color: int):
	game.approve(color)
	feedback_text = "双方确认完成。" + _result_text(game.score()) if game.phase == "finished" else "等待另一方确认；更改死子会清除已有确认。"
	_save()
	_refresh()

func _result_text(score: Dictionary) -> String:
	if score.winner == 0: return "和棋"
	return "%s胜 %s 子" % ["黑" if score.winner == 1 else "白", str(absf(score.margin_zi))]

func _resume():
	game.resume_play()
	feedback_text = "恢复原盘面继续对弈；死子标记已取消，全局历史仍然保留。"
	_save()
	_refresh()
	_maybe_ai()

func confirm(text_value: String, action: Callable):
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "静枰"
	dialog.dialog_text = text_value
	dialog.ok_button_text = "确定"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(action)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 190))

func _request_new(n: int, opponent: String):
	if not game.moves.is_empty():
		confirm("开始 %d 路新局会替换当前棋局。需要保留时，请先导出 SGF 棋谱。" % n, func(): new_game(n, opponent))
	else: new_game(n, opponent)

func new_game(n: int, opponent: String):
	ai_generation += 1
	busy = false
	game = Rules.new(n)
	mode = opponent
	settings_open = false
	history_open = false
	section = "play"
	exercise = null
	solved = false
	feedback_text = "新局开始，黑棋先行。"
	_save()
	_refresh()

func _request_resign():
	confirm("确认由当前行棋方认输并结束本局？", func():
		game.resign()
		feedback_text = "本局结束。"
		_save()
		_refresh())

func _maybe_ai():
	if mode != "ai" or section != "play" or game.turn != 2 or game.phase != "play" or busy: return
	busy = true
	var generation: int = ai_generation
	_refresh()
	await get_tree().create_timer(ai_wait).timeout
	if generation != ai_generation or section != "play": return
	var p: int = Opponent.new().choose(game)
	busy = false
	if p < 0:
		game.pass_turn()
		feedback_text = "白棋停着。"
	else:
		game.play(p)
		_click_sound()
		feedback_text = "白棋落在 " + game.coord(p) + "，轮到你了。"
	_save()
	_refresh()

func _show_rules():
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.name = "rules_dialog"
	dialog.title = "规则与操作"
	dialog.ok_button_text = "明白了"
	dialog.dialog_text = "【本棋室规则】\n黑先白后；上下左右连通的棋共享气。落子先提敌方无气棋，再检查己方的气。禁止自杀。\n采用位置禁全同：落子不得重复任何历史盘面，停着不受此限制。\n这是明确的软件规则预设；不模拟中国赛事中长生、三劫循环等由裁判决定的例外处理。\n\n【终局与计分】\n连续两次停着后，双方标记死子并分别确认。更改标记后需要重新确认。\n有争议时继续下；不会自动推断死子。双活棋保留，双方之间的空点平分。\n中国数子法：活子 + 所围空点 + 公气一半。黑贴还 3¾ 子，等价于双方分差贴 7.5 点。\n提子不另外加分。胜差以“子”显示；SGF 结果按双方分差的“点”记录。\n\n【操作】\n鼠标左键落子；悬停棋子可看气。V 切换俯视，N 切换手数，M 切换声音。\n对局与课程、题目进度自动保存。教学不会覆盖你的对局。\n入门陪练是基础启发式对手；不提供段位、在线匹配或职业级分析。\n\n【素材与依据】\n木纹：Poly Haven / Fine Grained Wood（CC0 扫描材质）；环境光：Studio Small 09（CC0）。棋具为原创三维模型。\n落子声：billhails2 的云子落盘实录（CC0）。白子贝纹为程序模拟。规则参考：中国围棋协会官网。"
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	var text_value: String = dialog.dialog_text
	dialog.dialog_text = ""
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(810, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var text_label: Label = paragraph(scroll, text_value, 15, PAPER)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog.popup_centered(Vector2i(880, 590))

func _export_sgf():
	export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.filters = PackedStringArray(["*.sgf ; SGF 棋谱"])
	export_dialog.current_file = "静枰_%d路.sgf" % game.size
	export_dialog.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(game.sgf())
			feedback_text = "棋谱已导出：" + path
		else: feedback_text = "棋谱保存失败，请选择可写文件夹。"
		_refresh()
		export_dialog.queue_free())
	export_dialog.canceled.connect(export_dialog.queue_free)
	add_child(export_dialog)
	export_dialog.popup_centered(Vector2i(850, 560))

func _save():
	if test_mode: return
	var data: Dictionary = {"game": game.to_data(), "mode": mode, "progress": progress, "sound": sound_on, "mistakes": mistakes, "puzzle_id": puzzles[puzzle_index].id}
	var temporary: String = save_path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		var error: Error = DirAccess.rename_absolute(temporary, save_path)
		if error != OK: push_warning("Could not replace local save: %s" % error)

func _load_save():
	if test_mode or not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	if data.get("progress", {}) is Dictionary: progress = data.get("progress", {})
	if data.get("mistakes", {}) is Dictionary: mistakes = data.get("mistakes", {})
	for i in range(puzzles.size()):
		if str(puzzles[i].id) == str(data.get("puzzle_id", "0")):
			puzzle_index = i
			puzzle_page = i / PAGE_SIZE
			break
	sound_on = bool(data.get("sound", true))
	if data.get("game", {}) is Dictionary:
		var restored = Rules.from_data(data.game)
		if restored:
			game = restored
			mode = "ai" if data.get("mode", "local") == "ai" else "local"

func _progress_count(prefix: String, independent_only: bool = false) -> int:
	var count: int = 0
	for key in progress:
		if str(key).begins_with(prefix) and (not independent_only or progress[key] == "independent"): count += 1
	return count

func _make_sound():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	for i in range(1,6): recorded_sounds.append(load("res://assets/audio/stone-%d.wav" % i))
	audio_player.volume_db = -6

func _click_sound():
	if sound_on and not test_mode:
		audio_player.stream = recorded_sounds[sound_index % recorded_sounds.size()]
		sound_index += 1
		audio_player.pitch_scale = 1.0
		audio_player.play()

func _unhandled_key_input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE:
			settings_open = false
			catalog_open = false
			history_open = false
			_refresh()
		KEY_V: board_view.set_camera(not board_view.top_view); _refresh()
		KEY_N: show_numbers = not show_numbers; _refresh()
		KEY_M: sound_on = not sound_on; _save(); _refresh()
