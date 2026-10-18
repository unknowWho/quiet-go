extends SceneTree
const KataGo = preload("res://scripts/katago.gd")
const Rules = preload("res://scripts/rules.gd")
const Content = preload("res://scripts/content.gd")
var engine
var response: Dictionary = {}
var failure: String = ""
var checks: int = 0
var failures: int = 0

func _initialize():
	call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL KATAGO: " + message)

func analyze(g, level: int = 0) -> Dictionary:
	response = {}
	failure = ""
	var start: int = Time.get_ticks_msec()
	engine.request(g, level)
	while response.is_empty() and failure.is_empty() and Time.get_ticks_msec()-start < 330000:
		await create_timer(0.02).timeout
	check(not response.is_empty(), "local engine responds: " + failure)
	var parsed: Dictionary = KataGo.validate_result(response, g) if not response.is_empty() else {"error": failure}
	check(not parsed.has("error"), "valid engine response " + str(parsed.get("error", "")))
	print("KataGo %d x %d, %d ms, %s" % [g.size, g.size, Time.get_ticks_msec()-start, JSON.stringify(parsed.duplicate().merged({"ownership": "omitted"}, true))])
	return parsed

func run():
	engine = KataGo.new()
	root.add_child(engine)
	engine.completed.connect(func(_id, data): response = data)
	engine.failed.connect(func(_id, message): failure = message)
	check(engine.installed(), "official engine and model installed")
	if not engine.installed():
		quit(1)
		return
	for n in [19, 13, 9]:
		var g = Rules.new(n)
		g.play(3 * n + 3)
		var result: Dictionary = await analyze(g)
		if not result.has("error"):
			if result.point < 0: g.pass_turn()
			else: check(g.play(result.point).ok, "engine move accepted by authoritative rules")
		else: break
	if not failures:
		var g = Rules.new(19)
		for p in [60,300,72,288,249,268,250,309,111,51,52,71,53,70,32,50]: g.play(p)
		await analyze(g, 1)
		g = Rules.new(9)
		g.setup(Content.position(9, [[1,2],[3,2],[2,1]], [[2,2],[1,3],[3,3],[2,4]]))
		g.play(29)
		var result: Dictionary = await analyze(g)
		check(result.get("point",20) != 20, "native engine respects immediate ko")
		g.pass_turn()
		g.pass_turn()
		g.resume_play()
		g.play(60)
		await analyze(g)
		# Cancellation followed by a new request must discard the old ID.
		var discarded: String = engine.request(Rules.new(19), 2)
		engine.cancel()
		await analyze(Rules.new(9))
		check(response.get("id", "") != discarded, "only newest result delivered after cancellation")
		g = Rules.new(19)
		var cells: Array = Content.empty(19)
		for p in range(76): cells[p] = 1
		for p in range(323,361): cells[p] = 2
		g.setup(cells, 2)
		result = await analyze(g)
		if not result.has("error"):
			check(result.black_lead > 0 and result.black_winrate > 0.5, "actual white-to-play result reports black advantage without inversion")
			check(result.ownership[20] > 0.9 and result.ownership[340] < -0.9, "actual ownership signs and north-south orientation")
	var pid: int = int(engine.process.get("pid", -1))
	engine.stop()
	check(pid < 0 or not OS.is_process_running(pid), "owned process exits on stop")
	print("KATAGO LIVE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
