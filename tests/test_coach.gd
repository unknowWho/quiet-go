extends SceneTree
const Coach = preload("res://scripts/coach.gd")
const Rules = preload("res://scripts/rules.gd")
const KataGo = preload("res://scripts/katago.gd")
const Content = preload("res://scripts/content.gd")
var checks: int = 0
var failures: int = 0

class FakeEngine extends Node:
	signal completed(id: String, data: Dictionary)
	signal failed(id: String, message: String)
	var sequence: int = 0
	var forced: int = -2
	var cancelled: int = 0
	func request(_g, _level: int, point: int = -2) -> String:
		sequence += 1
		forced = point
		return str(sequence)
	func cancel(): cancelled += 1

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func reply(g, pv: Array, lead: float = 1.5) -> Dictionary:
	var ownership: Array = []
	ownership.resize(g.size*g.size)
	ownership.fill(0.0)
	return {"turnNumber": g.moves.size(), "rootInfo": {"currentPlayer": "B" if g.turn == 1 else "W", "winrate": 0.5, "scoreLead": 99.0, "visits": 128},
		"moveInfos": [{"move": pv[0], "pv": pv, "order": 0, "scoreLead": lead, "winrate": 0.55, "visits": 120}], "ownership": ownership}

func _initialize():
	var g = Rules.new(9)
	var before: Dictionary = g.to_data().duplicate(true)
	var parsed: Dictionary = Coach.parse_line(reply(g, ["E5", "D5", "D4"]), g)
	check(parsed.pv == [40,39,48] and parsed.black_lead == 1.5, "PV coordinates and candidate evaluation, not root aggregate")
	check(g.to_data() == before, "validating a variation leaves the actual position unchanged")
	check(Coach.score_loss({"black_lead": 5.0}, {"black_lead": 2.0}, 1) == 3.0, "black loss perspective")
	check(Coach.score_loss({"black_lead": -5.0}, {"black_lead": -2.0}, 2) == 3.0, "white loss perspective")
	check(Coach.score_loss({"black_lead": 1.0}, {"black_lead": 3.0}, 1) == -2.0, "separate search may improve the proposed move, no clamping or false blunder")
	parsed = Coach.parse_line(reply(g,["E5","E5","D4"]),g)
	check(parsed.pv == [40] and parsed.trimmed, "truncate illegal occupied continuation")
	parsed = Coach.parse_line(reply(g,["pass","pass","E5"]),g)
	check(parsed.pv == [-1,-1], "two passes stop a variation at scoring")
	var invalid: Dictionary = reply(g,["E5"])
	invalid.moveInfos[0].move = "D4"
	check(Coach.parse_line(invalid,g).has("error"), "PV must start with the evaluated move")
	invalid = reply(g,["E5"])
	invalid.moveInfos[0].scoreLead = NAN
	check(Coach.parse_line(invalid,g).has("error"), "invalid candidate score rejected")
	invalid.moveInfos[0].scoreLead = 1.0
	invalid.moveInfos[0].pv = []
	check(Coach.parse_line(invalid,g).has("error"), "missing PV cannot become a fabricated line")
	g.setup(Content.position(9, [[1,2],[3,2],[2,1]], [[2,2],[1,3],[3,3],[2,4]]))
	g.play(29)
	check(not Coach.clone(g).probe(20).ok, "copy retains superko rather than setting up just the current stones")
	check(Coach.parse_line(reply(g,["C7"]),g).has("error"), "ko recapture cannot be recommended")
	var query: Dictionary = KataGo.query(g,"forced",0,-1)
	check(query.allowMoves == [{"player":"W","moves":["pass"],"untilDepth":1}], "force white pass only at root with installed engine protocol")
	check(query.moves == [["B","C6"]] and query.rules.ko == "POSITIONAL", "forced analysis retains history and exact rules")
	g = Rules.new(9)
	g.setup(Content.position(9, [[0,1],[2,1],[1,0]], [[1,1]]))
	check(Coach.explain(g,19).contains("提掉对方 1 子"), "capture explained from authoritative rules")
	check(Coach.explain(g,19).contains("黑 B7"), "observation identifies mover and coordinate")
	g.setup(Content.position(9, [[0,1],[2,1]], []))
	check(Coach.explain(g,10).contains("2 块棋连在一起"), "connection observes distinct groups")
	g.setup(Content.position(9, [[0,1],[1,0]], [[1,1]]))
	check(Coach.explain(g,19).contains("打吃"), "new atari explained")
	check(Coach.explain(g,-1).contains("仍需确认死子"), "pass explanation does not imply adjudication")
	var fake = FakeEngine.new()
	var c = Coach.new()
	c.connect_engine(fake)
	c.enter()
	c.choose(0)
	check(c.busy and c.game.moves.is_empty(), "selecting a proposal does not place a stone")
	var first_id: String = c.request_context.id
	fake.completed.emit(first_id, reply(c.game,["E5","D5"]))
	check(c.busy and fake.forced == 0 and c.best.point == 40, "recommendation followed by independent restricted-root search")
	fake.completed.emit(c.request_context.id,reply(c.game,["A9","B8"],-3.0))
	check(not c.busy and c.mine.point == 0 and c.comparison().contains("4.5 目"), "own proposal comparison uses both candidate scores")
	before = c.game.to_data().duplicate(true)
	c.show_line("best")
	check(c.step == 1 and c.preview.moves.size() == 1 and c.game.to_data() == before, "stepping into recommendation is isolated")
	c.set_step(2)
	check(c.preview.moves.size() == 2 and c.annotations().get("39") == "2", "PV has local move numbers")
	c.choose(5)
	check(c.proposal == 0, "board clicks cannot alter the practice while previewing")
	c.set_step(0)
	check(c.preview.board == c.game.board and c.preview.history == c.game.history, "rewind reproduces original history")
	c.close_line()
	c.adopt("mine")
	check(c.game.moves.size() == 1 and c.game.board[0] == 1 and c.busy, "adopt chosen move, then request AI reply")
	var obsolete: String = c.request_context.id
	var old_reply: Dictionary = reply(c.game,["E5"])
	c.undo()
	fake.completed.emit(obsolete,old_reply)
	check(c.game.moves.is_empty() and not c.busy, "undo cancels reply, ignores late result")
	c.recommend()
	obsolete = c.request_context.id
	c.leave()
	fake.completed.emit(obsolete,reply(c.game,["E5"]))
	check(c.best.is_empty() and not c.busy, "navigation cancels and rejects late analysis")
	c.enter()
	c.recommend()
	fake.failed.emit(c.request_context.id,"unavailable")
	check(not c.busy and c.error == "unavailable", "engine failure leaves recoverable state")
	c.retry()
	fake.completed.emit(c.request_context.id,reply(c.game,["E5","D5"]))
	c.choose(40)
	check(not c.busy and c.mine == c.best and c.comparison().contains("相同"), "matching AI choice reuses same evaluation")
	c.adopt("best")
	fake.completed.emit(c.request_context.id,reply(c.game,["D5","D4"]))
	check(c.game.moves.size() == 2 and c.game.turn == c.human and c.best.is_empty(), "AI reply returns to next human learning turn")
	c.undo()
	check(c.game.moves.is_empty(), "paired undo returns before human move")
	c.game.pass_turn()
	c.game.pass_turn()
	c.show_line("best")
	check(c.preview == null and c.game.phase == "scoring", "no nonexistent variation at end of practice")
	c.reset(9)
	c.choose(0)
	fake.completed.emit(c.request_context.id,reply(c.game,["E5"]))
	obsolete = c.request_context.id
	c.leave()
	fake.completed.emit(obsolete,reply(c.game,["A9"]))
	check(c.mine.is_empty(), "leaving while comparing rejects a late selected-move result")
	c.enter()
	check(c.busy and fake.forced == 0, "returning resumes the interrupted comparison")
	fake.completed.emit(c.request_context.id,reply(c.game,["B9"]))
	check(not c.error.is_empty() and c.mine.is_empty(), "a forced search cannot return a different proposed move")
	c.retry()
	fake.completed.emit(c.request_context.id,reply(c.game,["A9"]))
	c.adopt("mine")
	obsolete = c.request_context.id
	old_reply = reply(c.game,["E5"])
	c.reset(13)
	fake.completed.emit(obsolete,old_reply)
	check(c.game.size == 13 and c.game.moves.is_empty() and not c.busy, "restart during AI reply cancels old work")
	c.recommend()
	fake.completed.emit(c.request_context.id,reply(c.game,["pass","pass"]))
	c.adopt("best")
	fake.completed.emit(c.request_context.id,reply(c.game,["pass"]))
	check(c.game.phase == "scoring" and not c.game.approvals[1] and not c.game.approvals[2], "AI double pass never auto-approves the result")
	c.game.approve(1)
	c.game.approve(2)
	check(c.game.phase == "finished", "coach retains two-party scoring confirmation")
	c.free()
	fake.free()
	print("COACH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
