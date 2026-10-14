extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Content = preload("res://scripts/content.gd")
const Opponent = preload("res://scripts/opponent.gd")
var checks: int = 0
var failures: Array = []

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize():
	test_core()
	test_scoring()
	test_persistence()
	test_content()
	test_random()
	test_ai()
	print("RULES: %d checks, %d failures" % [checks, failures.size()])
	var file = FileAccess.open("res://evidence/rules-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	quit(0 if failures.is_empty() else 1)

func fixture(n: int, black: Array, white: Array, turn: int = 1):
	var g = Rules.new(n)
	g.setup(Content.position(n, black, white), turn)
	return g

func test_core():
	var g = Rules.new(9)
	check(g.board.size() == 81 and g.turn == 1, "empty board black first")
	check(g.neighbors(0).size() == 2 and g.neighbors(4).size() == 3 and g.neighbors(40).size() == 4, "corner/edge/center adjacency")
	check(not g.play(-2).ok and not g.play(81).ok, "out of board rejected")
	check(g.play(40).ok and g.turn == 2, "alternating turns")
	var prior: Dictionary = g.snapshot()
	check(not g.play(40).ok and g.snapshot() == prior, "occupied rejected without mutation")
	check(g.group(40).liberties.size() == 4, "four liberties in center")
	g = fixture(5, [[1,1],[2,2]], [])
	check(g.group(6).stones.size() == 1, "diagonal not connected")
	g = fixture(5, [[1,1],[2,1],[1,2],[2,2]], [])
	check(g.group(6).stones.size() == 4 and g.group(6).liberties.size() == 8, "shared liberties counted once")
	g = fixture(5, [[0,1],[1,0],[1,2]], [[1,1]])
	check(g.play(7).ok and g.board[6] == 0 and g.captures[1] == 1, "single capture")
	check(g.undo() and g.board[6] == 2 and g.captures[1] == 0 and g.turn == 1, "capture undo")
	g = fixture(5, [[0,1],[1,0],[1,2],[2,0],[2,2]], [[1,1],[2,1]])
	var r: Dictionary = g.play(8)
	check(r.ok and r.captured.size() == 2, "connected multi-stone capture")
	g = fixture(5, [[0,1],[1,0],[1,2],[4,1],[3,0],[3,2]], [[1,1],[3,1]])
	r = g.play(7)
	check(r.ok and r.captured.size() == 2, "two distinct chains captured simultaneously")
	g = fixture(5, [], [[1,0],[0,1]])
	prior = g.snapshot()
	check(not g.play(0).ok and g.snapshot() == prior, "suicide rejected atomically")
	g = fixture(5, [[0,0]], [[1,0],[1,1],[0,2]])
	check(not g.play(5).ok, "multi-stone self capture rejected")
	g = fixture(9, [[2,0],[1,1]], [[1,0],[0,1],[0,2]])
	r = g.play(0)
	check(r.ok and r.captured == [1] and g.group(0).liberties == [1], "capture before suicide evaluation")
	g = fixture(9, [[1,2],[3,2],[2,1]], [[2,2],[1,3],[3,3],[2,4]])
	check(g.play(29).ok and g.captures[1] == 1, "ko initial capture")
	prior = g.snapshot()
	check(not g.play(20).ok and g.snapshot() == prior, "immediate ko recapture rejected")
	check(g.play(60).ok and g.play(61).ok and g.play(20).ok, "ko recapture after changed elsewhere board")
	g = fixture(5, [[1,1],[2,0],[2,2],[4,1],[3,0],[3,2]], [[3,1],[0,1],[1,0],[1,2]], 2)
	check(g.play(7).ok and g.captures[2] == 1, "snapback first capture")
	check(g.play(6).ok and g.captures[1] == 2, "snapback immediate recapture legal: whole board differs")
	g = Rules.new(19)
	var triple: Array = Content.empty(19)
	for spec in [[3,3,1],[9,3,2],[15,3,1]]:
		var x: int = spec[0]
		var y: int = spec[1]
		var color: int = spec[2]
		for xy in [[x-1,y],[x+1,y],[x,y-1]]: triple[xy[1]*19+xy[0]] = color
		for xy in [[x,y],[x-1,y+1],[x+1,y+1],[x,y+2]]: triple[xy[1]*19+xy[0]] = 3-color
	g.setup(triple)
	for p in [79,85,91,60,66]: check(g.play(p).ok, "triple ko first five non-repeating moves")
	check(not g.play(72).ok and g.moves.size() == 5, "real six-move triple-ko recurrence prohibited by preset")
	g = Rules.new(5)
	var hypothetical: Array = g.board.duplicate()
	hypothetical[12] = 1
	g.history.append(g.key(hypothetical))
	check(not g.play(12).ok, "older repetition rejected by full board superko")
	g = Rules.new(5)
	check(g.pass_turn() and g.pass_turn() and g.phase == "scoring", "passes exempt repetition and enter scoring")
	check(not g.play(0).ok, "cannot place during scoring")
	var old_history: Array = g.history.duplicate()
	check(g.resume_play() and g.phase == "play" and g.passes == 0 and g.history == old_history, "resume keeps full history")
	check(g.play(0).ok and g.passes == 0, "play clears pass streak")
	g.pass_turn()
	g.undo()
	check(g.passes == 0 and g.turn == 2, "undo pass restores turn")
	g.resign()
	check(g.phase == "finished" and g.resigned == 2 and not g.pass_turn(), "resignation ends game")
	check(g.coord(0) == "A5" and g.coord(24) == "E1" and g.coord(-1) == "停着", "coordinates")
	var a = Rules.new(19)
	check(a.coord(8) == "J19" and a.coord(360) == "T1", "skip I coordinate")

func test_scoring():
	var g = Rules.new(5)
	var s: Dictionary = g.score()
	check(s.neutral == 25 and s.black == 12.5 and s.white == 12.5, "empty regions neutral without boundaries")
	var black: Array = []
	var white: Array = []
	for y in range(5):
		black.append([1,y])
		white.append([3,y])
	g = fixture(5, black, white)
	s = g.score()
	check(s.stones[1] == 5 and s.territory[1] == 5 and s.territory[2] == 5 and s.neutral == 5, "territory edge and shared dame")
	check(s.black == 12.5 and s.white == 12.5 and s.margin_zi == -3.75, "neutral split and komi zi conversion")
	check(s.black + s.white == 25, "board area conservation")
	g.captures = [0, 99, 3]
	check(g.score() == s, "captures not counted twice")
	g.pass_turn()
	g.pass_turn()
	g.approve(1)
	check(g.phase == "scoring", "one approval insufficient")
	g.mark_dead(1)
	check(g.dead.size() == 5 and not g.approvals[1], "group dead marking resets approvals")
	g.mark_dead(1)
	check(g.dead.is_empty(), "dead toggle restores group")
	g.mark_dead(3)
	check(g.score().stones[2] == 0 and g.board[3] == 2, "scoring removes only virtual dead stones")
	g.resume_play()
	check(g.board[3] == 2 and g.dead.is_empty(), "resume restores marked group")
	g.pass_turn()
	g.pass_turn()
	g.approve(1)
	g.approve(2)
	check(g.phase == "finished" and not g.mark_dead(1), "two confirmations finish and freeze result")
	var area: Array = []
	area.resize(361)
	area.fill(2)
	for i in range(185): area[i] = 1
	g = Rules.new(19)
	g.setup(area)
	check(g.score().margin_zi == 0.75, "Chinese reference: black 185 is win by .75 zi")
	area[184] = 2
	g.setup(area)
	check(g.score().margin_zi == -0.25, "Chinese reference: black 184 loses by .25 zi")
	g = Rules.new(5,0)
	s = g.score()
	check(s.winner == 0, "zero komi tie")
	# A genuine one-eye-each seki: neither side can safely take the shared liberty.
	var seki: Array = [1,1,1,1,2, 1,0,1,1,2, 1,1,1,1,2, 2,2,0,2,2, 2,2,2,2,0]
	g = Rules.new(5)
	g.setup(seki)
	s = g.score()
	check(s.owner[6] == 1 and s.owner[24] == 2 and s.owner[17] == 0, "seki private eyes count; shared liberty neutral")
	check(s.black == 12.5 and s.white == 12.5, "seki area counting splits neutral point")
	g.play(17)
	g.play(6)
	check(g.board.count(1) == 0, "seki black cannot safely fill common liberty")
	g.setup(seki,2)
	g.play(17)
	g.play(24)
	check(g.board.count(2) == 0, "seki white cannot safely fill common liberty")

func test_persistence():
	var g = Rules.new(9)
	for p in [20,21,29,30,38,39]: g.play(p)
	g.pass_turn()
	var copy = Rules.from_data(JSON.parse_string(JSON.stringify(g.to_data())))
	check(copy != null and copy.snapshot() == g.snapshot(), "save round trip full move history")
	if copy == null: return
	check(copy.undo() and copy.passes == 0, "loaded game supports undo")
	g.pass_turn()
	g.mark_dead(21)
	g.approve(1)
	copy = Rules.from_data(JSON.parse_string(JSON.stringify(g.to_data())))
	check(copy != null and copy.dead == g.dead and copy.approvals == g.approvals, "scoring state round trip")
	g.approve(2)
	copy = Rules.from_data(JSON.parse_string(JSON.stringify(g.to_data())))
	check(copy != null and copy.phase == "finished" and copy.score() == g.score(), "finished score round trip")
	check(g.sgf().contains("SZ[9]KM[7.5]") and g.sgf().contains(";B[cc];W[dc]") and g.sgf().contains(";B[];W[]"), "SGF coordinates komi pass export")
	g = Rules.new(9)
	g.play(40)
	g.resign()
	copy = Rules.from_data(JSON.parse_string(JSON.stringify(g.to_data())))
	check(copy != null and copy.resigned == 2 and copy.sgf().contains("RE[B+R]"), "resignation persistence and SGF")
	var corrupt: Dictionary = g.to_data().duplicate(true)
	corrupt.moves.append({"color":1,"point":40})
	check(Rules.from_data(corrupt) == null, "illegal save rejected")
	check(Rules.from_data({"version":1,"size":999}) == null, "invalid board size rejected")

func eye_regions(g) -> int:
	# Independent empty-region enumeration, counting only regions wholly bounded by the connected black wall.
	var seen: Dictionary = {}
	var count: int = 0
	for p in range(81):
		if g.board[p] != 0 or seen.has(p): continue
		var stack: Array = [p]
		seen[p] = true
		var borders: Dictionary = {}
		while not stack.is_empty():
			var q: int = stack.pop_back()
			for r in g.neighbors(q):
				if g.board[r] == 0:
					if not seen.has(r): seen[r] = true; stack.append(r)
				else: borders[g.board[r]] = true
		if borders.size() == 1 and borders.has(1): count += 1
	return count

func test_content():
	for lesson in Content.lessons():
		var g = Rules.new(9)
		g.setup(lesson.board, lesson.turn)
		for p in lesson.get("preplay", []): check(g.play(p).ok, "lesson legal prelude " + lesson.title)
		if lesson.has("preplay"): check(not g.probe(20).ok, "ko lesson actually prohibits recapture")
		for p in lesson.answer: check(p == -1 or g.probe(p).ok, "lesson legal answer " + lesson.title)
	for puzzle in Content.original_puzzles():
		var g = Rules.new(9)
		g.setup(puzzle.board, puzzle.turn)
		for p in range(81):
			if g.board[p] != 0: check(not g.group(p).liberties.is_empty(), "puzzle no zero-liberty setup " + puzzle.title)
		if puzzle.turn == 1:
			var found: Array = []
			for p in range(81):
				var r: Dictionary = g.probe(p)
				if not r.ok: continue
				g.play(p)
				if eye_regions(g) >= 2: found.append(p)
				g.undo()
			check(found == puzzle.answer, "complete one-move two-eye answer set " + puzzle.title + " actual " + str(found))
		else:
			for branch in puzzle.branches:
				g.setup(puzzle.board, puzzle.turn)
				check(g.play(puzzle.answer[0]).ok, "attack answer legal " + puzzle.title)
				for p in branch: check(g.play(p).ok, "attack continuation legal " + puzzle.title)
				check(g.board.count(1) == 0, "attack variation really captures black " + puzzle.title)
			# Each non-key move inside the chamber permits black to make two eyes at key.
			for p in range(81):
				g.setup(puzzle.board, puzzle.turn)
				if g.board[p] != 0: continue
				if p == puzzle.answer[0] or not g.probe(p).ok: continue
				g.play(p)
				if g.probe(puzzle.answer[0]).ok:
					g.play(puzzle.answer[0])
					# Only local chamber moves matter; outside can likewise be answered by making eyes.
					check(eye_regions(g) >= 2 or g.board.count(2) < puzzle.board.count(2)+1, "non-key attack does not kill " + puzzle.title)

func reference_move(b: Array, n: int, p: int, color: int, previous: Array) -> Array:
	# Alternative oracle: recompute every connected component globally using label propagation,
	# not only neighbors of the new stone. Return [] for an illegal move.
	if b[p] != 0: return []
	var next: Array = b.duplicate()
	next[p] = color
	var components: Array = []
	var seen: Dictionary = {}
	for i in range(n*n):
		if next[i] == 0 or seen.has(i): continue
		var chain: Array = [i]
		var liberties: Dictionary = {}
		seen[i] = true
		var cursor: int = 0
		while cursor < chain.size():
			var at: int = chain[cursor]
			var adjacent: Array = []
			for other in range(n*n):
				if absi(at%n-other%n)+absi(at/n-other/n) == 1: adjacent.append(other)
			for q in adjacent:
				if next[q] == 0: liberties[q] = true
				elif next[q] == next[i] and not seen.has(q): seen[q] = true; chain.append(q)
			cursor += 1
		components.append({"color":next[i],"stones":chain,"libs":liberties})
	for component in components:
		if component.color == 3-color and component.libs.is_empty():
			for q in component.stones: next[q] = 0
	# Only the placed stone's chain can become suicidal.
	var connected: Dictionary = {p:true}
	var changed: bool = true
	var has_liberty: bool = false
	while changed:
		changed = false
		for at in connected.keys():
			for q in range(n*n):
				if absi(at%n-q%n)+absi(at/n-q/n) != 1: continue
				if next[q] == 0: has_liberty = true
				elif next[q] == color and not connected.has(q): connected[q] = true; changed = true
	if not has_liberty: return []
	var key: String = ""
	for value in next: key += str(value)
	if previous.has(key): return []
	return next

func test_random():
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261011
	for run in range(12):
		var g = Rules.new(5)
		for step in range(100):
			var p: int = rng.randi_range(0,24)
			var expected: Array = reference_move(g.board,5,p,g.turn,g.history)
			var prior: Dictionary = g.snapshot()
			var result: Dictionary = g.play(p)
			check(result.ok == not expected.is_empty(), "differential legality %d/%d" % [run,step])
			if result.ok:
				check(g.board == expected, "differential board %d/%d" % [run,step])
				for q in range(25):
					if g.board[q]: check(not g.group(q).liberties.is_empty(), "no zero-liberty live chains")
				check(is_equal_approx(g.score().black+g.score().white,25), "random scoring conservation")
			else: check(g.snapshot() == prior, "illegal random move does not mutate")

func test_ai():
	var g = fixture(9, [[1,2],[2,1],[2,3]], [[2,2]])
	var p: int = Opponent.new().choose(g)
	check(p == 21, "AI captures in atari")
	g = Rules.new(9)
	for i in range(120):
		if g.phase != "play": break
		p = Opponent.new().choose(g)
		if p < 0: g.pass_turn()
		else: check(g.play(p).ok, "AI only makes legal moves")
	check(g.moves.size() > 20, "AI playable game sequence")
