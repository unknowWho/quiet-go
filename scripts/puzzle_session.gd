extends RefCounted
## Follow the author's annotated variations. Unlisted moves are not a proof of failure.
const Rules = preload("res://scripts/rules.gd")
var item: Dictionary
var game
var node_index: int = 0
var path: Array = [0]
var complete: bool = false
var reply_variant: int = 0

func _init(problem: Dictionary, variant: int = 0):
	item = problem
	reply_variant = variant
	game = Rules.new(int(item.size))
	game.setup(item.board, int(item.turn))

func node() -> Dictionary:
	return item.nodes[node_index]

func options() -> Array:
	var out: Array = []
	if complete: return out
	for child in node().children:
		if item.nodes[int(child)].good: out.append(int(child))
	return out

func answers() -> Array:
	var out: Array = []
	for child in options(): out.append(int(item.nodes[child].point))
	return out

func _advance(child: int) -> bool:
	var next: Dictionary = item.nodes[child]
	if int(next.color) != game.turn: return false
	var p: int = int(next.point)
	if p == -1:
		if not game.pass_turn(): return false
	elif not game.play(p).ok: return false
	node_index = child
	path.append(child)
	complete = next.correct
	return true

func submit(p: int) -> Dictionary:
	if complete: return {"status": "complete", "moves": []}
	if game.turn != int(item.turn): return {"status": "error", "reason": "题谱回合不一致。"}
	if p < -1: return {"status": "illegal", "reason": "请选择交叉点。"}
	if p >= 0:
		var legality: Dictionary = game.probe(p)
		if not legality.ok: return {"status": "illegal", "reason": legality.reason}
	var chosen: int = -1
	var listed: bool = false
	for child in node().children:
		var n: Dictionary = item.nodes[int(child)]
		if int(n.point) == p:
			listed = true
			if n.good:
				chosen = int(child)
				break
	if chosen < 0:
		return {"status": "refuted" if listed else "unlisted", "reason": "这手在原题中属于非正确变化。保留当前局面，请换个思路。" if listed else "原题解未收录这手。请按参考变化继续；未收录不等于已证明错误。"}
	var before: int = game.moves.size()
	if not _advance(chosen): return {"status": "error", "reason": "题谱着手校验失败。"}
	while not complete and game.turn != int(item.turn):
		var replies: Array = options()
		if replies.is_empty(): return {"status": "error", "reason": "题谱缺少后续应手。"}
		var choice: int = reply_variant % replies.size()
		reply_variant = reply_variant / replies.size()
		if not _advance(replies[choice]): return {"status": "error", "reason": "题谱应手校验失败。"}
	return {"status": "complete" if complete else "continue", "moves": game.moves.slice(before)}

func annotations() -> Dictionary:
	# SGF markup belongs to its exact node, not every subsequent position.
	return node().get("labels", {})

func commentary() -> String:
	var text: String = ""
	for idx in path:
		if idx == 0: continue # The problem's Chinese prompt is already visible beside the board.
		var n: Dictionary = item.nodes[int(idx)]
		if str(n.comment).is_empty(): continue
		var heading: String = "题面" if idx == 0 else ("黑 " if int(n.color) == 1 else "白 ") + game.coord(int(n.point))
		text += heading + "\n" + str(n.comment) + "\n\n"
	return text.strip_edges()
