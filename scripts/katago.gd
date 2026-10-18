extends Node
## Persistent, non-blocking JSON-lines connection to the official local engine.
signal completed(id: String, result: Dictionary)
signal failed(id: String, message: String)
signal status_changed

const MODEL_NAME = "kata1-b18c384nbt-s9996604416-d4316597426"
const LEVELS = [
	{"name": "快速", "visits": 128, "seconds": 1.5},
	{"name": "标准", "visits": 512, "seconds": 4.0},
	{"name": "深入", "visits": 2048, "seconds": 10.0},
]
var engine_path: String = ""
var model_path: String = ""
var process: Dictionary = {}
var state: String = "idle"
var error_text: String = ""
var diagnostics: String = ""
var pending: Dictionary = {}
var sequence: int = 0
var deadline: int = 0
var output_bytes: PackedByteArray = PackedByteArray()
var error_bytes: PackedByteArray = PackedByteArray()
var started_at: int = 0

func _ready():
	var base: String = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	engine_path = base.path_join("engines/katago/runtime/katago.exe")
	model_path = base.path_join("engines/katago/runtime/model.bin.gz")
	set_process(false)

func installed() -> bool:
	return FileAccess.file_exists(engine_path) and FileAccess.file_exists(model_path)

static func coordinate(p: int, n: int) -> String:
	if p == -1: return "pass"
	return "ABCDEFGHJKLMNOPQRST"[p % n] + str(n - p / n)

static func point(value: String, n: int) -> int:
	if value.to_lower() == "pass": return -1
	if value.length() < 2 or value.length() > 3: return -2
	var x: int = "ABCDEFGHJKLMNOPQRST".find(value[0].to_upper())
	var row: String = value.substr(1)
	if x < 0 or x >= n or not row.is_valid_int(): return -2
	var y: int = n - int(row)
	if y < 0 or y >= n or str(int(row)) != row: return -2
	return y * n + x

static func position_key(g) -> String:
	# Full history matters for positional superko, even when stones match.
	return str(g.get_instance_id()) + JSON.stringify([g.size, g.komi, g.initial, g.initial_turn, g.moves, g.phase, g.turn])

static func query(g, id: String, level: int = 1, forced_point: int = -2) -> Dictionary:
	var stones: Array = []
	for p in range(g.initial.size()):
		if g.initial[p] != 0: stones.append(["B" if g.initial[p] == 1 else "W", coordinate(p, g.size)])
	var moves: Array = []
	for move in g.moves:
		moves.append(["B" if move.color == 1 else "W", coordinate(int(move.point), g.size)])
	var budget: Dictionary = LEVELS[clampi(level, 0, LEVELS.size()-1)]
	var payload: Dictionary = {"id": id, "initialStones": stones, "initialPlayer": "B" if g.initial_turn == 1 else "W",
		"moves": moves, "boardXSize": g.size, "boardYSize": g.size, "komi": g.komi,
		"rules": {"ko": "POSITIONAL", "scoring": "AREA", "suicide": false, "tax": "NONE",
			"hasButton": false, "whiteHandicapBonus": "0", "friendlyPassOk": true},
		"maxVisits": budget.visits, "includeOwnership": true, "analysisPVLen": 12,
		"overrideSettings": {"maxTime": budget.seconds, "reportAnalysisWinratesAs": "BLACK"}}
	# Supported by the installed 1.18.1 protocol. Only constrain the root;
	# subsequent moves remain a normal search, with the original ko history.
	if forced_point >= -1:
		payload["allowMoves"] = [{"player": "B" if g.turn == 1 else "W", "moves": [coordinate(forced_point, g.size)], "untilDepth": 1}]
	return payload

static func validate_result(data: Dictionary, g) -> Dictionary:
	if data.get("turnNumber", -1) != g.moves.size(): return {"error": "AI 返回的手数不匹配。"}
	var info = data.get("rootInfo")
	if not info is Dictionary: return {"error": "AI 没有返回形势数据。"}
	if info.get("currentPlayer", "") != ("B" if g.turn == 1 else "W"): return {"error": "AI 返回的行棋方不匹配。"}
	for field in ["winrate", "scoreLead", "visits"]:
		if not (info.get(field) is float or info.get(field) is int) or not is_finite(float(info[field])):
			return {"error": "AI 的形势数据不完整。"}
	if info.winrate < 0 or info.winrate > 1 or info.visits < 1: return {"error": "AI 的形势数据超出范围。"}
	var ownership = data.get("ownership")
	if not ownership is Array or ownership.size() != g.size * g.size: return {"error": "AI 的地域数据不完整。"}
	for value in ownership:
		if not (value is float or value is int) or not is_finite(float(value)) or absf(value) > 1.001:
			return {"error": "AI 的地域数据超出范围。"}
	var choices = data.get("moveInfos")
	if not choices is Array or choices.is_empty(): return {"error": "AI 没有返回着手。"}
	var best: Dictionary = {}
	for choice in choices:
		if choice is Dictionary and choice.get("order", -1) == 0: best = choice
	if best.is_empty() or not best.get("move") is String: return {"error": "AI 没有返回首选着手。"}
	var p: int = point(best.move, g.size)
	if p < -1 or (p >= 0 and not g.probe(p).ok): return {"error": "AI 着手未通过本局规则校验，请重试。"}
	return {"point": p, "black_winrate": float(info.winrate), "black_lead": float(info.scoreLead),
		"visits": int(info.visits), "ownership": ownership.duplicate(), "move": best.move}

func request(g, level: int = 1, forced_point: int = -2) -> String:
	cancel()
	sequence += 1
	var id: String = "quiet-go-%d" % sequence
	pending = query(g, id, level, forced_point)
	if process.is_empty():
		if not _start():
			call_deferred("_fail_request", id, error_text)
	elif state == "ready":
		_submit()
	return id

func _start() -> bool:
	error_text = ""
	if not installed():
		error_text = "尚未安装本地 AI。请双击游戏文件夹中的 SetupAI.cmd，完成后重试。"
		return false
	var cache: String = ProjectSettings.globalize_path("user://katago")
	if DirAccess.make_dir_recursive_absolute(cache) != OK:
		error_text = "无法创建 AI 缓存，请检查游戏存档目录。"
		return false
	# Copy the packaged config to a real path, so exported PCKs work too.
	var config = FileAccess.open(cache.path_join("analysis.cfg"), FileAccess.WRITE)
	if not config:
		error_text = "无法写入 AI 配置。"
		return false
	config.store_string(FileAccess.get_file_as_string("res://engines/katago/analysis.cfg"))
	config.close()
	process = OS.execute_with_pipe(engine_path, PackedStringArray(["analysis", "-config", cache.path_join("analysis.cfg"),
		"-model", model_path, "-override-config", "homeDataDir=" + cache.replace("\\", "/"), "-quit-without-waiting"]), false)
	if process.is_empty():
		error_text = "本地 AI 启动失败。请检查引擎文件与显卡驱动。"
		return false
	output_bytes.clear()
	error_bytes.clear()
	diagnostics = ""
	state = "starting"
	started_at = Time.get_ticks_msec()
	deadline = started_at + 300000 # First OpenCL tuning can take several minutes.
	set_process(true)
	_send({"id": "ready", "action": "query_version"})
	status_changed.emit()
	return true

func _send(data: Dictionary) -> bool:
	if process.is_empty(): return false
	var ok: bool = process.stdio.store_buffer((JSON.stringify(data) + "\n").to_utf8_buffer())
	if not ok: call_deferred("_fail_request", str(pending.get("id", "")), "AI 通信中断，请重试。")
	return ok

func _submit():
	if pending.is_empty(): return
	deadline = Time.get_ticks_msec() + 45000
	_send(pending)

func cancel():
	if not pending.is_empty() and state == "ready":
		_send({"id": "cancel-" + str(pending.id), "action": "terminate", "terminateId": pending.id})
	pending.clear()

func _process(_delta: float):
	if process.is_empty(): return
	for i in range(8):
		var bytes: PackedByteArray = process.stderr.get_buffer(8192)
		if bytes.is_empty(): break
		error_bytes.append_array(bytes)
		var end: int = error_bytes.find(10)
		while end >= 0:
			diagnostics = (diagnostics + error_bytes.slice(0, end+1).get_string_from_utf8()).right(16000)
			error_bytes = error_bytes.slice(end+1)
			end = error_bytes.find(10)
		if error_bytes.size() > 65536: error_bytes.clear()
	for i in range(8):
		var bytes: PackedByteArray = process.stdio.get_buffer(65536)
		if bytes.is_empty(): break
		output_bytes.append_array(bytes)
		if output_bytes.size() > 2097152:
			_fail("AI 返回的数据异常，请重试。")
			return
		var end: int = output_bytes.find(10)
		while end >= 0:
			var line: String = output_bytes.slice(0, end).get_string_from_utf8()
			output_bytes = output_bytes.slice(end+1)
			_receive(line)
			if process.is_empty(): return
			end = output_bytes.find(10)
	if not OS.is_process_running(int(process.pid)):
		_fail("本地 AI 已退出。请重试；详细原因可查看 AI 日志。")
	elif (state == "starting" or not pending.is_empty()) and Time.get_ticks_msec() > deadline:
		_fail("本地 AI 响应超时。请重试或降低思考强度。")

func _receive(line: String):
	var data = JSON.parse_string(line)
	if not data is Dictionary:
		_fail("AI 返回了无法识别的数据。")
		return
	if data.has("error") and not data.has("id"):
		diagnostics += "\n" + JSON.stringify(data)
		_fail("AI 报告运行错误，请查看 AI 日志。")
		return
	if data.get("id", "") == "ready" and data.has("version"):
		state = "ready"
		_submit()
		status_changed.emit()
		return
	if pending.is_empty() or data.get("id", "") != pending.id: return # Includes late cancelled responses.
	if data.has("error") or data.has("warning"):
		diagnostics += "\n" + JSON.stringify(data)
		_fail("AI 拒绝了当前配置或局面，请查看 AI 日志。") # Never silently accept a different ruleset.
		return
	if data.get("isDuringSearch", true): return
	var id: String = pending.id
	pending.clear()
	completed.emit(id, data)

func _fail_request(id: String, message: String):
	if str(pending.get("id", "")) == id: _fail(message)

func _fail(message: String):
	var id: String = str(pending.get("id", ""))
	pending.clear()
	error_text = message
	var log = FileAccess.open("user://katago-error.log", FileAccess.WRITE)
	if log: log.store_string(message + "\n" + diagnostics)
	stop()
	state = "error"
	failed.emit(id, message)
	status_changed.emit()

func stop():
	pending.clear()
	set_process(false)
	if not process.is_empty():
		var pid: int = process.pid
		process.stdio.close()
		process.stderr.close()
		if OS.is_process_running(pid): OS.kill(pid)
		process.clear()
	state = "idle"

func _exit_tree():
	stop()
