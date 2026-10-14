extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Content = preload("res://scripts/content.gd")
const Session = preload("res://scripts/puzzle_session.gd")
var checks: int = 0
var failures: Array = []
var nodes_checked: int = 0
var conclusions: int = 0

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize():
	var puzzles: Array = Content.puzzles()
	check(puzzles.size() == 430, "ten starter shapes plus 420 sourced problems")
	var ids: Dictionary = {}
	var difficulties: Dictionary = {}
	for item in puzzles:
		check(not ids.has(item.id), "unique stable id " + str(item.id))
		ids[item.id] = true
		difficulties[item.difficulty] = int(difficulties.get(item.difficulty, 0)) + 1
		if not item.has("nodes"): continue
		var tag: String = item.id
		var path: String = "res://assets/problems/gogameguru/" + str(item.source_path)
		check(FileAccess.get_sha256(path) == item.source_sha256, "unaltered attributed SGF " + tag)
		check(item.size == 19 and item.board.size() == 361, "full source board preserved " + tag)
		var g = Rules.new(int(item.size))
		g.setup(item.board, int(item.turn))
		var seen: Array = []
		for p in range(g.board.size()):
			if g.board[p] == 0 or seen.has(p): continue
			var group: Dictionary = g.group(p)
			check(not group.liberties.is_empty(), "setup group has liberties " + tag)
			seen.append_array(group.stones)
		var visited: Dictionary = {}
		audit_tree(item, 0, g, visited)
		check(visited.size() == item.nodes.size(), "all delivered nodes reachable " + tag)
		check(g.moves.is_empty() and g.board == item.board, "traversal restores board " + tag)
		var session = Session.new(item)
		var depth: int = 0
		while not session.complete and depth < 300:
			var answers: Array = session.answers()
			check(not answers.is_empty(), "annotated continuation available " + tag)
			if answers.is_empty(): break
			var result: Dictionary = session.submit(answers[0])
			check(result.status in ["continue", "complete"], "session plays legal solution " + tag)
			check(session.complete == bool(session.node().correct), "only explicit correct conclusion completes " + tag)
			if result.status not in ["continue", "complete"]: break
			depth += 1
		check(session.complete, "entire solution playable " + tag)
	check(difficulties == {"basic":10,"easy":140,"intermediate":140,"hard":140}, "difficulty counts")
	test_session(puzzles)
	print("PUZZLES: %d checks, %d failures; %d source nodes, %d annotated conclusions" % [checks, failures.size(), nodes_checked, conclusions])
	var file = FileAccess.open("res://evidence/puzzles-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"puzzles":420,"source_nodes":nodes_checked,"annotated_conclusions":conclusions}, "\t"))
	quit(0 if failures.is_empty() else 1)

func audit_tree(item: Dictionary, idx: int, g, visited: Dictionary):
	check(not visited.has(idx), "acyclic tree " + str(item.id))
	if visited.has(idx): return
	visited[idx] = true
	nodes_checked += 1
	var n: Dictionary = item.nodes[idx]
	var good: bool = bool(n.correct)
	if n.correct: conclusions += 1
	for p in n.labels:
		check(int(p) >= 0 and int(p) < 361 and not str(n.labels[p]).is_empty(), "valid source annotation " + str(item.id))
	var child_moves: Dictionary = {}
	for child_value in n.children:
		var child: int = int(child_value)
		check(child >= 0 and child < item.nodes.size(), "valid tree edge " + str(item.id))
		var next: Dictionary = item.nodes[child]
		good = good or bool(next.good)
		# Some source refutations duplicate a first move. Only accepted moves
		# must have one continuation tree; never collapse authored bad branches.
		if next.good:
			check(not child_moves.has(int(next.point)), "unambiguous accepted sibling move " + str(item.id))
			child_moves[int(next.point)] = true
		check(g.turn == int(next.color), "alternating source turns " + str(item.id))
		var ok: bool = g.pass_turn() if int(next.point) == -1 else bool(g.play(int(next.point)).ok)
		check(ok, "legal source move with superko " + str(item.id) + " node " + str(child))
		if not ok: continue
		audit_tree(item, child, g, visited)
		check(g.undo(), "variation rollback " + str(item.id))
	check(bool(n.good) == good, "success flags derived from author conclusions " + str(item.id))

func test_session(puzzles: Array):
	var item: Dictionary = puzzles[10] # GGG easy 001: R1, S2, N1/P1.
	var s = Session.new(item)
	var before: Dictionary = s.game.snapshot()
	check(s.submit(0).status == "unlisted" and s.game.snapshot() == before, "unlisted legal move is not asserted wrong or committed")
	var bad: int = -1
	for child in s.node().children:
		if not item.nodes[int(child)].good:
			bad = int(item.nodes[int(child)].point)
			break
	check(bad >= 0 and s.submit(bad).status == "refuted" and s.game.snapshot() == before, "recorded refutation leaves current state intact")
	var occupied: int = item.board.find(1.0)
	check(s.submit(occupied).status == "illegal" and s.game.snapshot() == before, "illegal move atomic")
	check(s.submit(s.answers()[0]).status == "continue" and s.game.moves.size() == 2 and not s.complete, "first correct move is not early success; automatic reply")
	check(s.answers().size() == 2, "all authored correct alternatives accepted")
	var alternative: int = s.answers()[1]
	check(s.submit(alternative).status == "complete", "secondary correct variation completes")
	before = s.game.snapshot()
	check(s.submit(0).status == "complete" and s.game.snapshot() == before, "completed session cannot mutate")
	var a = Session.new(puzzles[11], 0)
	var b = Session.new(puzzles[11], 1)
	a.submit(a.answers()[0])
	b.submit(b.answers()[0])
	check(a.game.moves[1].point != b.game.moves[1].point, "retry cycles authored opponent replies")
	check(a.submit(a.answers()[0]).status == "complete" and b.submit(b.answers()[0]).status == "complete", "both reply variations solve")
	var pass_problem: Dictionary = {"size":9,"board":Content.empty(9),"turn":1,"nodes":[
		{"point":-2,"color":0,"children":[1],"good":true,"correct":false},
		{"point":-1,"color":1,"children":[],"good":true,"correct":true}]}
	s = Session.new(pass_problem)
	check(s.answers() == [-1] and s.submit(-1).status == "complete", "explicit authored pass supported")
