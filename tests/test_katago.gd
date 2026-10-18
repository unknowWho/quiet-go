extends SceneTree
const KataGo = preload("res://scripts/katago.gd")
const Rules = preload("res://scripts/rules.gd")
const Content = preload("res://scripts/content.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func reply(g, move: String = "pass") -> Dictionary:
	var ownership: Array = []
	ownership.resize(g.size*g.size)
	ownership.fill(0.0)
	return {"turnNumber": g.moves.size(), "rootInfo": {"currentPlayer": "B" if g.turn == 1 else "W", "winrate": 0.7, "scoreLead": 5.5, "visits": 128},
		"moveInfos": [{"move": "A1", "order": 1}, {"move": move, "order": 0}], "ownership": ownership}

func _initialize():
	for n in [9,13,19]:
		for p in range(n*n): check(KataGo.point(KataGo.coordinate(p,n),n) == p, "coordinate round trip %d/%d" % [n,p])
	check(KataGo.coordinate(8,19) == "J19" and KataGo.coordinate(360,19) == "T1", "GTP skips I and has north-up rows")
	check(KataGo.coordinate(-1,19) == "pass" and KataGo.point("PASS",19) == -1, "pass mapping")
	for s in ["", "I5", "A0", "T20", "U1", "A01", "A-1", "resign", "K0", "D4x"]:
		check(KataGo.point(s,19) == -2, "malformed coordinate " + s)
	var g = Rules.new(9)
	g.setup(Content.position(9, [[1,2],[3,2],[2,1]], [[2,2],[1,3],[3,3],[2,4]]))
	g.play(29)
	var q: Dictionary = KataGo.query(g, "ko", 1)
	check(q.initialStones.size() == 7 and q.moves == [["B", "C6"]], "initial setup and true move history retained")
	check(q.initialPlayer == "B" and q.komi == 7.5 and q.boardXSize == 9, "initial player size and komi explicit")
	check(q.rules.ko == "POSITIONAL" and q.rules.scoring == "AREA" and not q.rules.suicide and q.rules.tax == "NONE" and q.rules.whiteHandicapBonus == "0", "all rule settings explicit")
	check(q.overrideSettings.reportAnalysisWinratesAs == "BLACK", "score and ownership use fixed black perspective")
	check(KataGo.validate_result(reply(g, "C7"), g).has("error"), "ko recapture from AI rejected")
	check(KataGo.validate_result(reply(g, "C6"), g).has("error"), "occupied AI move rejected")
	check(KataGo.validate_result(reply(g, "resign"), g).has("error"), "unsupported token not mistaken for pass")
	var parsed: Dictionary = KataGo.validate_result(reply(g), g)
	check(parsed.point == -1 and parsed.black_lead == 5.5 and parsed.black_winrate == 0.7, "select order zero; white to play does not invert black score")
	var before: Dictionary = g.snapshot()
	var data: Dictionary = reply(g)
	data.rootInfo.winrate = NAN
	check(KataGo.validate_result(data,g).has("error"), "nonfinite winrate rejected")
	data = reply(g)
	data.ownership = [1.0]
	check(KataGo.validate_result(data,g).has("error"), "partial territory rejected")
	data = reply(g)
	data.ownership[0] = 2.0
	check(KataGo.validate_result(data,g).has("error"), "out of range territory rejected")
	data = reply(g)
	data.turnNumber = 2
	check(KataGo.validate_result(data,g).has("error"), "wrong turn rejected")
	data = reply(g)
	data.rootInfo.currentPlayer = "B"
	check(KataGo.validate_result(data,g).has("error"), "wrong player rejected")
	check(g.snapshot() == before, "analysis parsing does not mutate game")
	var key: String = KataGo.position_key(g)
	g.pass_turn()
	check(KataGo.position_key(g) != key and KataGo.query(g,"p").moves[-1] == ["W","pass"], "pass changes request identity and history")
	g.pass_turn()
	g.resume_play()
	check(KataGo.query(g,"r").moves.size() == 3, "resume retains both passes for real history")
	g = Rules.new(9)
	g.setup(Content.position(9, [], [[1,0],[0,1]]))
	check(KataGo.validate_result(reply(g,"A9"),g).has("error"), "suicide candidate rejected")
	print("KATAGO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
