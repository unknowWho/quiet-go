extends RefCounted
## Original lessons and starter shapes, plus separately licensed Go Game Guru data.
static func empty(n: int) -> Array:
	var b: Array = []
	b.resize(n * n)
	b.fill(0)
	return b

static func position(n: int, black: Array, white: Array) -> Array:
	var b: Array = empty(n)
	for p in black: b[p[1] * n + p[0]] = 1
	for p in white: b[p[1] * n + p[0]] = 2
	return b

static func lessons() -> Array:
	return [
		{"title": "棋盘与落子", "tag": "01 / 开始", "text": "黑先白后，轮流落一子。棋子放在线的交叉点上；下定后不能移动。\n\n先用九路盘认识围棋。在中央的天元落一颗黑子。", "hint": "寻找棋盘最中央的星位 E5。", "board": empty(9), "turn": 1, "answer": [40], "success": "落在交叉点上了。棋子今后只有被提走，不会像象棋那样移动。"},
		{"title": "棋子的气", "tag": "02 / 生存", "text": "上下左右紧邻的空点叫作“气”，斜角不算。\n\n中央这颗白子只有右边一口气。黑棋占住它，就能提走白子。", "hint": "白子 E5 的最后一气在 F5。", "board": position(9, [[3,4],[4,3],[4,5]], [[4,4]]), "turn": 1, "answer": [41], "success": "白子无气，被提离棋盘。先看对方的气，再决定落点。"},
		{"title": "连接成一块", "tag": "03 / 连接", "text": "直线相邻的同色棋子连成一块，共享所有的气。同一空点只算一口气。\n\n请把左右两颗黑子连接起来。", "hint": "下在两颗黑子之间的 E5。", "board": position(9, [[3,4],[5,4]], []), "turn": 1, "answer": [40], "success": "三子连在一起，共有 8 口不同的气。斜着挨着仍不算直接连接。"},
		{"title": "整块提子", "tag": "04 / 提取", "text": "一块棋所有的气耗尽时，整块一起被提走。\n\n这两颗白子共享最后一口气。请一手提掉它们。", "hint": "在 G5 落子，封住白棋整块的最后一气。", "board": position(9, [[3,4],[4,3],[4,5],[5,3],[5,5]], [[4,4],[5,4]]), "turn": 1, "answer": [42], "success": "两颗白子一起被提走。提子看的是整块棋，而不是逐颗判断。"},
		{"title": "禁入与提子优先", "tag": "05 / 合法落子", "text": "不能下出一块没有气的己方棋。\n\n但如果落子能先提掉对方，提子后自己有气，就合法。试着在左上角 A9 落黑子，提掉 B9 的白子。", "hint": "A9 看似被包围，但落子先提白棋，再检查黑棋的气。", "board": position(9, [[2,0],[1,1]], [[1,0],[0,1],[0,2]]), "turn": 1, "answer": [0], "success": "正确：提掉 B9 后，A9 获得一口气。这不是自杀。"},
		{"title": "劫不能立即回提", "tag": "06 / 打劫", "text": "单劫不能刚被提就立即提回，否则盘面原样重复。要先在别处下棋，等对方回应后再考虑提劫。\n\n这里黑棋刚提了劫。试点 C7 看禁手提示，再在 E5 找一个劫外落点。", "hint": "C7 立即回提不合法。练习目标是 E5。", "board": position(9, [[1,2],[3,2],[2,1]], [[2,2],[1,3],[3,3],[2,4]]), "turn": 1, "preplay": [29], "answer": [40], "success": "已在别处落子。实战中劫材还需要能迫使对手应答，并非随便下哪里都有用。"},
		{"title": "两只真眼", "tag": "07 / 做活", "text": "互相连通的一块棋，如果有两只独立的真眼，通常就能活。对手不能同时填掉两只眼。\n\n黑棋的眼位是一条三点长的空间。黑先，落在中间，把它分成两只眼。", "hint": "落在 C9；两侧 B9、D9 各成为一只真眼。", "board": eye_position([[1,0],[2,0],[3,0]]), "turn": 1, "answer": [2], "success": "两边各留下一个眼。不要为了多围一个空点而漏掉做活的要点。"},
		{"title": "停着与数子", "tag": "08 / 终局", "text": "目标是占有更多的盘面，不是单纯吃子最多。\n\n双方连续停着后，先共同确认死子，再数活子和围住的空点。公气平分；本游戏黑贴 3¾ 子（双方分差相当于 7.5 点）。\n\n请点下方“练习停着”。计分时若死活有争议，应继续对弈。", "hint": "点击下方的练习停着按钮。", "board": position(9, [[1,1],[2,1],[1,2],[2,3],[3,2]], [[6,5],[5,6],[6,7],[7,6]]), "turn": 1, "answer": [-1], "success": "会停着，也要会继续下。对弈页中双方停着会进入死子确认，不会直接猜测胜负。"}
	]

static func eye_position(inside: Array) -> Array:
	# The upper board edge bounds the chamber. Solid connected black wall, then white exterior.
	var max_x: int = 0
	var max_y: int = 0
	for xy in inside:
		max_x = maxi(max_x, xy[0])
		max_y = maxi(max_y, xy[1])
	var b: Array = empty(9)
	for y in range(max_y + 3):
		for x in range(max_x + 3):
			b[y * 9 + x] = 2 if x == max_x + 2 or y == max_y + 2 else 1
	for xy in inside: b[xy[1] * 9 + xy[0]] = 0
	return b

static func transform(b: Array, mirror_x: bool, mirror_y: bool) -> Array:
	var out: Array = empty(9)
	for y in range(9):
		for x in range(9): out[(8-y if mirror_y else y)*9 + (8-x if mirror_x else x)] = b[y*9+x]
	return out

static func original_puzzles() -> Array:
	var p: Array = [
		{"title": "直三 · 做活", "type": "做活", "level": "基础 01", "inside": [[1,0],[2,0],[3,0]], "turn": 1, "answer": [2], "hint": "三点眼位的中央，是一分为二的要点。", "explain": "C9 分开两眼：B9 和 D9。外侧黑棋彼此连通，两只眼都是真眼。"},
		{"title": "直三 · 破眼", "type": "杀棋", "level": "基础 02", "inside": [[1,0],[2,0],[3,0]], "turn": 2, "answer": [2], "hint": "不要从两端挤，先占眼位正中。", "explain": "白占 C9，黑无法分成两眼。若黑挤 B9，白 D9 提净；黑挤 D9，白 B9 提净。", "branches": [[1,3],[3,1]]},
		{"title": "曲三 · 做活", "type": "做活", "level": "基础 03", "inside": [[1,0],[2,0],[1,1]], "turn": 1, "answer": [1], "hint": "找到同时连接两个末端的转折点。", "explain": "B9 是转折点。落黑后，C9 与 B8 成为两只分开的真眼。"},
		{"title": "曲三 · 破眼", "type": "杀棋", "level": "基础 04", "inside": [[1,0],[2,0],[1,1]], "turn": 2, "answer": [1], "hint": "弯曲的三个空点仍然只有一个分眼要点。", "explain": "白占 B9。黑若填 C9，白 B8 提净；黑若填 B8，白 C9 提净。", "branches": [[2,10],[10,2]]},
		{"title": "直四 · 分眼", "type": "做活", "level": "基础 05", "inside": [[1,0],[2,0],[3,0],[4,0]], "turn": 1, "answer": [2,3], "hint": "两个中间点都能把眼位分成两部分。", "explain": "C9、D9 均正确。中间落一子后，一侧是单点眼，另一侧是两点眼。"},
		{"title": "丁四 · 做活", "type": "做活", "level": "基础 06", "inside": [[1,0],[2,0],[3,0],[2,1]], "turn": 1, "answer": [2], "hint": "找到丁字形的交汇点。", "explain": "C9 是交汇点。一手分开 B9、D9、C8 三处眼位，黑棋活。"},
		{"title": "角上直三", "type": "做活", "level": "基础 07", "inside": [[1,0],[2,0],[3,0]], "turn": 1, "answer": [78], "flip_y": true, "flip_x": true, "hint": "换了方向，仍然要下在三个空点的中央。", "explain": "G1 把下边的眼位分成 F1 与 H1 两眼。"},
		{"title": "下边曲三", "type": "杀棋", "level": "基础 08", "inside": [[1,0],[2,0],[1,1]], "turn": 2, "answer": [73], "flip_y": true, "hint": "先找转折点，防止黑棋在那里做眼。", "explain": "白占 B1。黑填 C1 则白 B2 提净；黑填 B2 则白 C1 提净。", "branches": [[74,64],[64,74]]},
		{"title": "直五 · 留两眼", "type": "做活", "level": "基础 09", "inside": [[1,0],[2,0],[3,0],[4,0],[5,0]], "turn": 1, "answer": [2,3,4], "hint": "只要左右都留出独立眼位即可，多解都接受。", "explain": "C9、D9、E9 都能把空点分成两个独立的眼区。这里练的是一步做出两眼。"},
		{"title": "右上曲三", "type": "做活", "level": "基础 10", "inside": [[1,0],[2,0],[1,1]], "turn": 1, "answer": [7], "flip_x": true, "hint": "右上眼形的转折点在 H9。", "explain": "H9 落子后，G9 与 H8 各是一眼。方向改变不影响气和连接的规则。"}
	]
	for item in p:
		item.id = str(p.find(item))
		item.difficulty = "basic"
		item.source = "静枰原创"
		item.board = transform(eye_position(item.inside), item.get("flip_x", false), item.get("flip_y", false))
		item.text = ("黑先，一手做出至少两只独立真眼。" if item.turn == 1 else "白先，找到破眼要点，杀掉被包围的黑棋。") + "\n\n外侧白棋视为活棋。每题都是局部练习，空旷外部不属于作答范围。"
	return p

static func puzzles() -> Array:
	var out: Array = original_puzzles()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/problems/library.json"))
	if data is Dictionary and data.get("version", 0) == 1 and data.get("puzzles") is Array:
		out.append_array(data.puzzles)
	else: push_error("Could not load the offline puzzle library.")
	return out
