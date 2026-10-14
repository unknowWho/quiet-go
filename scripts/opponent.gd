extends RefCounted
## Small transparent heuristic for beginner practice. Not a ranked/strong Go engine.
func choose(g) -> int:
	var best: int = -1
	var best_value: float = -100000.0
	var color: int = g.turn
	var groups: Array = []
	var scanned: Dictionary = {}
	for p in range(g.board.size()):
		if g.board[p] != 0 and not scanned.has(p):
			var group: Dictionary = g.group(p)
			group.color = g.board[p]
			groups.append(group)
			for q in group.stones: scanned[q] = true
	for p in range(g.board.size()):
		if g.board[p] != 0: continue
		var r: Dictionary = g.probe(p)
		if not r.ok: continue
		var adjacent: Array = g.neighbors(p)
		var own_count: int = 0
		var enemy_count: int = 0
		for q in adjacent:
			if g.board[q] == color: own_count += 1
			elif g.board[q] != 0: enemy_count += 1
		# Do not fill true one-point eyes voluntarily. Edge/corner require all diagonals friendly.
		if own_count == adjacent.size():
			var bad_diagonals: int = 0
			var diagonal_count: int = 0
			for dx in [-1, 1]:
				for dy in [-1, 1]:
					var x: int = p % g.size + dx
					var y: int = p / g.size + dy
					if x >= 0 and x < g.size and y >= 0 and y < g.size:
						diagonal_count += 1
						if g.board[y * g.size + x] != color: bad_diagonals += 1
			if bad_diagonals == 0 or (diagonal_count == 4 and bad_diagonals <= 1): continue
		var own_after: Dictionary = g.group(p, r.board)
		var libs: int = own_after.liberties.size()
		var value: float = r.captured.size() * 28.0 + minf(libs, 5) * 0.6
		if libs == 1: value -= 65.0 + own_after.stones.size() * 8.0
		for group in groups:
			if not group.liberties.has(p): continue
			if group.color == color and group.liberties.size() == 1 and libs > 1:
				value += 24.0 + group.stones.size() * 9.0
			elif group.color != color and group.liberties.size() == 2:
				value += 9.0 + group.stones.size() * 2.0
		if own_count >= 3: value -= 10.0
		var distance: int = 100
		for q in range(g.board.size()):
			if g.board[q] != 0: distance = mini(distance, absi(p % g.size - q % g.size) + absi(p / g.size - q / g.size))
		var edge: int = mini(mini(p % g.size, g.size - 1 - p % g.size), mini(p / g.size, g.size - 1 - p / g.size))
		if distance in [2, 3]: value += 5.0
		if distance == 1: value += 0.4
		if edge == 0: value -= 3.0
		elif edge in [2, 3]: value += 2.5
		# Reproducible tiny tie-break, avoiding a fixed first-legal move bot.
		value += sin(float(p * 17 + g.moves.size() * 31)) * 0.45
		if g.moves.size() > g.size * g.size * 0.7 and enemy_count == 0 and own_count >= 2: value -= 8.0
		if value > best_value:
			best_value = value
			best = p
	if best_value < 0: return -1
	return best
