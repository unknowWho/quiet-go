extends Node
## Practice and every variation use separate rules objects, retaining full ko history.
signal changed
signal stone_played
const Rules = preload("res://scripts/rules.gd")
const KataGo = preload("res://scripts/katago.gd")
var game = Rules.new(9)
var human: int = 1
var level: int = 1
var engine
var active: bool = false
var busy: bool = false
var error: String = ""
var request_context: Dictionary = {}
var proposal: int = -2
var best: Dictionary = {}
var mine: Dictionary = {}
var preview = null
var line: Array = []
var line_kind: String = "best"
var step: int = 0
var observation: String = ""

func connect_engine(service):
	engine = service
	engine.completed.connect(_completed)
	engine.failed.connect(_failed)

func current():
	return preview if preview != null else game

func enter():
	active = true
	if game.phase == "play" and game.turn != human: _request("reply")
	elif game.phase == "play" and proposal >= -1 and mine.is_empty(): choose(proposal)
	changed.emit()

func leave():
	active = false
	cancel()
	preview = null

func cancel():
	if not request_context.is_empty(): engine.cancel()
	request_context.clear()
	busy = false

func reset(n: int):
	cancel()
	game = Rules.new(n)
	human = 1
	clear_analysis()
	changed.emit()

func clear_analysis():
	proposal = -2
	best.clear()
	mine.clear()
	preview = null
	line.clear()
	step = 0
	observation = ""
	error = ""

func choose(p: int):
	if not active or busy or preview != null or game.phase != "play" or game.turn != human: return
	if p < -1 or (p >= 0 and not game.probe(p).ok):
		error = game.probe(p).reason
		changed.emit()
		return
	proposal = p
	mine.clear()
	if best.is_empty(): _request("recommend")
	elif p == best.point:
		mine = best.duplicate(true)
		error = ""
		changed.emit()
	else: _request("compare")

func recommend():
	if not active or busy or preview != null or game.phase != "play" or game.turn != human: return
	_request("recommend")

func retry():
	if not active or busy: return
	if game.turn != human: _request("reply")
	elif best.is_empty(): _request("recommend")
	elif proposal >= -1 and mine.is_empty(): _request("compare")
	else: _request("recommend")

func _request(purpose: String):
	error = ""
	busy = true
	var id: String = engine.request(game, level, proposal if purpose == "compare" else -2)
	request_context = {"id": id, "purpose": purpose, "key": KataGo.position_key(game), "proposal": proposal}
	changed.emit()

func _completed(id: String, data: Dictionary):
	if request_context.is_empty() or id != request_context.id: return
	var context: Dictionary = request_context.duplicate()
	request_context.clear()
	busy = false
	if not active or game.phase != "play" or context.key != KataGo.position_key(game): return
	var result: Dictionary = parse_line(data, game)
	if result.has("error"):
		error = result.error
		changed.emit()
		return
	match context.purpose:
		"recommend":
			best = result
			if proposal >= -1:
				if proposal == best.point: mine = best.duplicate(true)
				else:
					_request("compare")
					return
		"compare":
			if context.proposal != proposal or result.point != proposal:
				error = "AI 没有分析指定落点，请重试。"
			else: mine = result
		"reply":
			if apply_move(game, result.point) and result.point >= 0: stone_played.emit()
			clear_analysis()
	changed.emit()

func _failed(id: String, message: String):
	if request_context.is_empty() or id != request_context.id: return
	request_context.clear()
	busy = false
	error = message
	changed.emit()

static func apply_move(g, p: int) -> bool:
	return g.pass_turn() if p == -1 else bool(g.play(p).ok)

static func clone(g):
	return Rules.from_data(g.to_data().duplicate(true))

static func parse_line(data: Dictionary, g) -> Dictionary:
	var validated: Dictionary = KataGo.validate_result(data, g)
	if validated.has("error"): return validated
	var choice: Dictionary = {}
	for item in data.moveInfos:
		if item is Dictionary and item.get("order", -1) == 0: choice = item
	for field in ["scoreLead", "winrate", "visits"]:
		if not (choice.get(field) is float or choice.get(field) is int) or not is_finite(float(choice[field])):
			return {"error": "AI 的变化评价不完整，请重试。"}
	if choice.winrate < 0 or choice.winrate > 1 or choice.visits < 1: return {"error": "AI 的变化评价超出范围。"}
	if not choice.get("pv") is Array or choice.pv.is_empty(): return {"error": "AI 未返回参考变化，请重试。"}
	var sandbox = clone(g)
	var points: Array = []
	for value in choice.pv:
		if not value is String: break
		var p: int = KataGo.point(value, g.size)
		if p < -1 or not apply_move(sandbox, p): break
		points.append(p)
		# Never continue a PV past two passes or relax superko for a diagram.
		if sandbox.phase != "play" or points.size() >= 12: break
	if points.is_empty() or points[0] != validated.point: return {"error": "AI 变化未通过本局规则校验。"}
	return {"point": validated.point, "pv": points, "black_lead": float(choice.scoreLead),
		"black_winrate": float(choice.winrate), "visits": int(choice.visits), "trimmed": points.size() < choice.pv.size()}

static func score_loss(recommended: Dictionary, proposed: Dictionary, color: int) -> float:
	# Both are moveInfos values from the SAME root, fixed BLACK perspective.
	return (recommended.black_lead - proposed.black_lead) * (1.0 if color == 1 else -1.0)

func comparison() -> String:
	if best.is_empty() or mine.is_empty(): return ""
	if best.point == mine.point: return "与 AI 本次首选相同。"
	var loss: float = score_loss(best, mine, game.turn)
	if absf(loss) < 0.5: return "本次估计差距不足 0.5 目，可重点比较后续应对。"
	if loss < 0: return "单独搜索后，你的下法估计好 %.1f 目；有限搜索的排序可能变化。" % -loss
	return "相对 AI 本次首选，你的下法估计少 %.1f 目。" % loss

func show_line(kind: String):
	if busy: return
	var choice: Dictionary = best if kind == "best" else mine
	if choice.is_empty(): return
	line_kind = kind
	line = choice.pv.duplicate()
	set_step(1)

func set_step(value: int):
	if line.is_empty(): return
	step = clampi(value, 0, line.size())
	preview = clone(game)
	observation = "变化起点。先想一想，对手最紧要的应对在哪里？"
	for i in range(step):
		if i == step-1: observation = explain(preview, line[i])
		if not apply_move(preview, line[i]):
			error = "变化已停止：该手未通过规则校验。"
			step = i
			break
	changed.emit()

func close_line():
	preview = null
	changed.emit()

func annotations() -> Dictionary:
	var marks: Dictionary = {}
	if preview != null:
		for i in range(step):
			var p: int = line[i]
			if p >= 0 and preview.board[p] != 0: marks[str(p)] = str(i+1)
	else:
		if not best.is_empty() and best.point >= 0: marks[str(best.point)] = "A"
		if proposal >= 0: marks[str(proposal)] = "A" if not best.is_empty() and best.point == proposal else "我"
	return marks

func adopt(kind: String):
	if not active or busy or preview != null or game.phase != "play" or game.turn != human: return
	var choice: Dictionary = best if kind == "best" else mine
	if choice.is_empty() or not apply_move(game, choice.point): return
	if choice.point >= 0: stone_played.emit()
	clear_analysis()
	if game.phase == "play": _request("reply")
	else: changed.emit()

func undo():
	cancel()
	if game.undo() and game.turn != human and not game.moves.is_empty(): game.undo()
	clear_analysis()
	changed.emit()

static func explain(g, p: int) -> String:
	var color: String = "黑" if g.turn == 1 else "白"
	if p == -1: return color + "棋停着。停着不等于全盘死活已定；连续两次停着后仍需确认死子。"
	var result: Dictionary = g.probe(p)
	if not result.ok: return result.reason
	var facts: Array[String] = []
	var friends: Dictionary = {}
	var saved: int = 0
	for q in g.neighbors(p):
		if g.board[q] != g.turn: continue
		var group: Dictionary = g.group(q)
		var first: int = group.stones.min()
		if friends.has(first): continue
		friends[first] = true
		if group.liberties.size() == 1: saved += group.stones.size()
	var own: Dictionary = g.group(p, result.board)
	if not result.captured.is_empty(): facts.append("提掉对方 %d 子" % result.captured.size())
	if friends.size() >= 2: facts.append("把相邻的 %d 块棋连在一起" % friends.size())
	if saved > 0 and own.liberties.size() > 1: facts.append("相连的 %d 子脱离打吃" % saved)
	var enemies: Dictionary = {}
	for stone in own.stones:
		for q in g.neighbors(stone):
			if result.board[q] != 3-g.turn: continue
			var enemy: Dictionary = g.group(q, result.board)
			# Only report newly-created atari, not a pre-existing remote atari.
			if enemy.liberties.size() == 1 and g.group(q).liberties.size() > 1: enemies[enemy.stones.min()] = true
	if not enemies.is_empty(): facts.append("使对方 %d 块棋只剩一口气（打吃）" % enemies.size())
	if own.liberties.size() == 1: facts.append("落子后自身只剩一口气，留意对手能否提取")
	if facts.is_empty():
		var edge: int = mini(mini(p % g.size, g.size-1-p % g.size), mini(p / g.size, g.size-1-p / g.size)) + 1
		facts.append("落在距最近边线第 %d 线上，相连棋块有 %d 口气" % [edge, own.liberties.size()])
	return "%s %s：%s。" % [color, g.coord(p), "；".join(facts)]
