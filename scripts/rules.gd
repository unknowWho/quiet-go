extends RefCounted
## Explicit software rules: no suicide, positional superko, Chinese area counting.
## Pass is exempt from repetition. Dead stones require agreement; no heuristic adjudication.
var size: int = 19
var board: Array = []
var turn: int = 1
var komi: float = 7.5 # Difference in points; equivalent to black returning 3.75 zi.
var captures: Array = [0, 0, 0]
var passes: int = 0
var phase: String = "play"
var history: Array = []
var moves: Array = []
var snapshots: Array = []
var dead: Array = []
var approvals: Array = [false, false, false]
var resigned: int = 0
var initial: Array = []
var initial_turn: int = 1

func _init(n: int = 19, k: float = 7.5):
	size = n
	komi = k
	board.resize(n * n)
	board.fill(0)
	initial = board.duplicate()
	history = [key(board)]

func neighbors(p: int) -> Array:
	var out: Array = []
	if p % size > 0: out.append(p - 1)
	if p % size < size - 1: out.append(p + 1)
	if p >= size: out.append(p - size)
	if p < size * (size - 1): out.append(p + size)
	return out

func group(p: int, cells: Array = []) -> Dictionary:
	var b: Array = cells if not cells.is_empty() else board
	if p < 0 or p >= b.size() or b[p] == 0: return {"stones": [], "liberties": []}
	var stones: Array = [p]
	var liberties: Array = []
	var visited: Dictionary = {p: true}
	var i: int = 0
	while i < stones.size():
		for q in neighbors(stones[i]):
			if b[q] == 0:
				if not liberties.has(q): liberties.append(q)
			elif b[q] == b[p] and not visited.has(q):
				visited[q] = true
				stones.append(q)
		i += 1
	return {"stones": stones, "liberties": liberties}

func key(cells: Array) -> String:
	var out: String = ""
	for c in cells: out += str(c)
	return out

func probe(p: int, color: int = 0, check_history: bool = true) -> Dictionary:
	if color == 0: color = turn
	if p < 0 or p >= board.size(): return {"ok": false, "reason": "请落在棋盘交叉点上。"}
	if board[p] != 0: return {"ok": false, "reason": "这里已有棋子，请选择空交叉点。"}
	var next: Array = board.duplicate()
	next[p] = color
	var removed: Array = []
	for q in neighbors(p):
		if next[q] == 3 - color:
			var enemy: Dictionary = group(q, next)
			if enemy.liberties.is_empty():
				for r in enemy.stones:
					next[r] = 0
					removed.append(r)
	if group(p, next).liberties.is_empty():
		return {"ok": false, "reason": "禁入点：落子后己方无气，且不能提掉对方。"}
	if check_history and history.has(key(next)):
		return {"ok": false, "reason": "劫／全局同形：这手会重复已经出现过的盘面。请先在别处落子。"}
	return {"ok": true, "board": next, "captured": removed}

func snapshot() -> Dictionary:
	return {"board": board.duplicate(), "turn": turn, "captures": captures.duplicate(), "passes": passes,
		"phase": phase, "history": history.duplicate(), "moves": moves.duplicate(true), "resigned": resigned}

func play(p: int) -> Dictionary:
	if phase != "play": return {"ok": false, "reason": "当前正在确认终局。需要下棋时请点继续对弈。"}
	var result: Dictionary = probe(p)
	if not result.ok: return result
	snapshots.append(snapshot())
	board = result.board
	captures[turn] += result.captured.size()
	moves.append({"color": turn, "point": p, "captured": result.captured.duplicate()})
	turn = 3 - turn
	passes = 0
	history.append(key(board))
	return result

func pass_turn() -> bool:
	if phase != "play": return false
	snapshots.append(snapshot())
	moves.append({"color": turn, "point": -1, "captured": []})
	turn = 3 - turn
	passes += 1
	# Record unchanged positions too. Pass itself is always permitted.
	history.append(key(board))
	if passes >= 2:
		phase = "scoring"
		dead.clear()
		approvals = [false, false, false]
	return true

func undo() -> bool:
	if snapshots.is_empty(): return false
	var s: Dictionary = snapshots.pop_back()
	board = s.board
	turn = s.turn
	captures = s.captures
	passes = s.passes
	phase = s.phase
	history = s.history
	moves = s.moves
	resigned = s.resigned
	dead.clear()
	approvals = [false, false, false]
	return true

func mark_dead(p: int) -> bool:
	if phase != "scoring" or p < 0 or p >= board.size() or board[p] == 0: return false
	var stones: Array = group(p).stones
	var unmark: bool = dead.has(p)
	for q in stones:
		if unmark: dead.erase(q)
		elif not dead.has(q): dead.append(q)
	approvals = [false, false, false]
	return true

func approve(color: int) -> bool:
	if phase != "scoring" or color not in [1, 2]: return false
	approvals[color] = true
	if approvals[1] and approvals[2]: phase = "finished"
	return true

func resume_play() -> bool:
	if phase != "scoring": return false
	phase = "play"
	passes = 0
	dead.clear()
	approvals = [false, false, false]
	return true

func resign() -> bool:
	if phase != "play": return false
	resigned = turn
	phase = "finished"
	return true

func score() -> Dictionary:
	var b: Array = board.duplicate()
	for p in dead: b[p] = 0
	var stones: Array = [0, 0, 0]
	var territory: Array = [0, 0, 0]
	var owner: Array = []
	owner.resize(board.size())
	owner.fill(0)
	var visited: Dictionary = {}
	var neutral: int = 0
	for p in range(b.size()):
		if b[p] != 0:
			stones[b[p]] += 1
			continue
		if visited.has(p): continue
		var region: Array = [p]
		var borders: Dictionary = {}
		visited[p] = true
		var i: int = 0
		while i < region.size():
			for q in neighbors(region[i]):
				if b[q] == 0 and not visited.has(q):
					visited[q] = true
					region.append(q)
				elif b[q] != 0: borders[b[q]] = true
			i += 1
		if borders.size() == 1:
			var c: int = borders.keys()[0]
			territory[c] += region.size()
			for q in region: owner[q] = c
		else: neutral += region.size()
	var black: float = stones[1] + territory[1] + neutral * 0.5
	var white: float = stones[2] + territory[2] + neutral * 0.5
	var margin_points: float = black - white - komi
	return {"stones": stones, "territory": territory, "neutral": neutral, "owner": owner,
		"black": black, "white": white, "margin_points": margin_points, "margin_zi": margin_points / 2.0,
		"winner": 1 if margin_points > 0 else (2 if margin_points < 0 else 0)}

func setup(cells: Array, color: int = 1):
	assert(cells.size() == size * size)
	board = cells.duplicate()
	initial = cells.duplicate()
	initial_turn = color
	turn = color
	history = [key(board)]
	moves.clear()
	snapshots.clear()
	dead.clear()
	passes = 0
	phase = "play"
	captures = [0, 0, 0]
	approvals = [false, false, false]
	resigned = 0

func coord(p: int) -> String:
	if p < 0: return "停着"
	return "ABCDEFGHJKLMNOPQRST"[p % size] + str(size - p / size)

func to_data() -> Dictionary:
	return {"version": 1, "size": size, "komi": komi, "initial": initial, "initial_turn": initial_turn,
		"moves": moves, "phase": phase, "dead": dead, "approvals": approvals, "resigned": resigned, "passes": passes}

static func from_data(data: Dictionary):
	if data.get("version", 0) != 1 or int(data.get("size", 0)) not in [5, 7, 9, 13, 19]: return null
	var script = load("res://scripts/rules.gd")
	var g = script.new(int(data.size), float(data.get("komi", 7.5)))
	var cells: Array = data.get("initial", [])
	if cells.size() != g.size * g.size: return null
	for i in range(cells.size()):
		if not (cells[i] is float or cells[i] is int): return null
		if float(cells[i]) != float(int(cells[i])) or int(cells[i]) not in [0, 1, 2]: return null
		cells[i] = int(cells[i])
	var first: int = int(data.get("initial_turn", 1))
	if first not in [1, 2]: return null
	g.setup(cells, first)
	for m in data.get("moves", []):
		if not m is Dictionary or int(m.get("color", 0)) != g.turn: return null
		if g.phase == "scoring": g.resume_play()
		var p: int = int(m.get("point", -2))
		if p == -1: g.pass_turn()
		elif not g.play(p).ok: return null
	var phase_value: String = str(data.get("phase", "play"))
	if phase_value not in ["play", "scoring", "finished"]: return null
	if phase_value == "play" and g.phase == "scoring": g.resume_play()
	var resign_value: int = int(data.get("resigned", 0))
	if phase_value == "finished" and resign_value in [1, 2]:
		if g.turn != resign_value or g.phase != "play": return null
		g.resign()
	elif phase_value in ["scoring", "finished"]:
		if g.phase != "scoring": return null
		for p in data.get("dead", []):
			var q: int = int(p)
			if q < 0 or q >= g.board.size() or g.board[q] == 0: return null
			if not g.dead.has(q): g.mark_dead(q)
		var accepted: Array = data.get("approvals", [false, false, false])
		if accepted.size() != 3: return null
		for c in [1, 2]:
			if accepted[c]: g.approve(c)
		if g.phase != phase_value: return null
	return g

func sgf() -> String:
	var out: String = "(;GM[1]FF[4]CA[UTF-8]AP[QuietGo:0.1]SZ[%d]KM[%s]RU[Chinese area; positional superko]PB[Black]PW[White]" % [size, komi]
	if phase == "finished":
		if resigned: out += "RE[%s+R]" % ("W" if resigned == 1 else "B")
		else:
			var s: Dictionary = score()
			out += "RE[%s]" % ("0" if s.winner == 0 else ("B" if s.winner == 1 else "W") + "+" + str(absf(s.margin_points)))
	for color in [1, 2]:
		var points: String = ""
		for p in range(initial.size()):
			if initial[p] == color: points += "[%s]" % sgf_point(p)
		if not points.is_empty(): out += ("AB" if color == 1 else "AW") + points
	if initial_turn == 2: out += "PL[W]"
	for m in moves: out += ";%s[%s]" % ["B" if m.color == 1 else "W", sgf_point(m.point)]
	return out + ")"

func sgf_point(p: int) -> String:
	if p < 0: return ""
	return "abcdefghijklmnopqrstuvwxyz"[p % size] + "abcdefghijklmnopqrstuvwxyz"[p / size]
