extends "res://tests/test_ui.gd"

func wait_engine():
	var started: int = Time.get_ticks_msec()
	while (app.busy or not app.engine_request.is_empty()) and Time.get_ticks_msec()-started < 330000:
		await create_timer(0.02).timeout
	await settle()
	check(not app.busy and app.engine_request.is_empty(), "AI request completes without locking interface")

func run():
	root.size = Vector2i(1440,900)
	app = Main.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await settle()
	check(app.katago.installed(), "local engine installed for integration suite")
	app.ai_level = 0
	app.new_game(9,"local")
	await settle()
	await click_button(app.find_child("settings_button",true,false))
	await click_button(app.find_child("katago_mode",true,false))
	check(app.mode == "katago" and not app.settings_open and app.board_view.top_view, "actual mode button starts top-down KataGo game")
	await click_point(40)
	check(app.busy and app.game.moves.size() == 1, "human move starts real local AI")
	app._on_point(41)
	app._pass()
	check(app.game.moves.size() == 1, "cannot place or pass for AI")
	await wait_engine()
	check(app.game.moves.size() == 2 and app.game.turn == 1 and app.engine_error.is_empty(), "real AI response played legally")
	await click_button(app.find_child("analysis_button",true,false))
	await wait_engine()
	check(not app.analysis_result.is_empty(), "actual analysis button returns real evaluation")
	if app.analysis_result.is_empty():
		printerr(app.engine_error)
		app.queue_free()
		quit(1)
		return
	var before: Dictionary = app.game.snapshot()
	await click_button(app.find_child("ownership_button",true,false))
	check(app.board_view.territory.get_child_count() > 0 and app.game.snapshot() == before and app.game.dead.is_empty(), "ownership overlays without changing rules or dead stones")
	app._toggle_analysis()
	check(app.board_view.territory.get_child_count() == 0, "collapse removes ownership overlay")
	app._on_point(30)
	check(app.busy, "second AI request begins")
	app._undo()
	check(app.game.moves.size() == 2 and app.game.turn == 1 and not app.busy, "undo during thinking cancels only pending human move")
	await create_timer(0.5).timeout
	check(app.game.moves.size() == 2, "late result after undo ignored")
	app._on_point(30)
	app._navigate("lessons")
	await create_timer(0.5).timeout
	check(app.game.moves.size() == 3 and app.section == "lessons", "late result after navigation ignored")
	app._navigate("play")
	await wait_engine()
	check(app.game.moves.size() == 4 and app.game.turn == 1, "unfinished white turn resumes on return")
	app._undo()
	check(app.game.moves.size() == 2, "completed AI turn undoes the pair")
	app._on_point(30)
	await settle()
	await click_button(app.find_child("local_mode",true,false))
	var change_dialog: ConfirmationDialog = app.find_child("new_game_dialog",true,false)
	await click_at(Vector2(change_dialog.position) + change_dialog.get_ok_button().get_global_rect().get_center())
	await create_timer(0.5).timeout
	check(app.mode == "local" and app.game.moves.is_empty(), "visible mode change cannot receive old AI move")
	app.new_game(9,"katago")
	app.ai_level = 2
	app._on_point(40)
	await settle()
	await click_button(app.find_child("restart_button",true,false))
	var restart_dialog: ConfirmationDialog = app.find_child("new_game_dialog",true,false)
	await click_at(Vector2(restart_dialog.position) + restart_dialog.get_ok_button().get_global_rect().get_center())
	await create_timer(0.5).timeout
	check(app.mode == "katago" and app.game.moves.is_empty() and not app.busy, "visible restart while AI thinks cancels old move and preserves AI mode")
	app.ai_level = 0
	# An actual killed process must unlock the interface and support a fresh retry.
	app.new_game(9,"katago")
	app._on_point(40)
	OS.kill(int(app.katago.process.pid))
	await wait_engine()
	check(not app.engine_error.is_empty() and app.game.moves.size() == 1, "process exit visible without automatic fake opponent")
	app._on_point(41)
	app._pass()
	check(app.game.moves.size() == 1 and not app.board_view.active, "AI turn stays protected on failure")
	await click_button(app.find_child("retry_engine",true,false))
	await wait_engine()
	check(app.engine_error.is_empty() and app.game.moves.size() == 2, "retry recovers real process and same game")
	# Missing installation is actionable, and does not cause an endless restart loop.
	var saved_path: String = app.katago.engine_path
	app.katago.stop()
	app.katago.engine_path = "res://.runtime/does-not-exist/katago.exe"
	app.new_game(9,"katago")
	app._on_point(40)
	await wait_engine()
	check(app.engine_error.contains("SetupAI.cmd") and not app.busy, "missing installation instruction")
	var sequence: int = app.katago.sequence
	await create_timer(0.2).timeout
	check(app.katago.sequence == sequence, "failed request is not resubmitted on refresh")
	app.katago.engine_path = saved_path
	await click_button(app.find_child("retry_engine",true,false))
	await wait_engine()
	check(app.game.moves.size() == 2 and app.engine_error.is_empty(), "recover from missing installation")
	app.new_game(9,"katago")
	var ended: Array = Content.empty(9)
	ended.fill(1)
	ended[10] = 0
	ended[70] = 0
	app.game.setup(ended)
	app._refresh()
	await settle()
	await click_button(app.find_child("pass_button",true,false))
	await wait_engine()
	check(app.game.phase == "scoring" and app.game.moves.size() == 2, "real AI passes when only pass is legal; two passes enter scoring")
	check(app.engine_request.is_empty() and app.analysis_result.is_empty() and not app.game.approvals[1], "AI never auto-approves final score")
	await click_button(app.find_child("approve_black",true,false))
	await click_button(app.find_child("approve_white",true,false))
	check(app.game.phase == "finished" and app.game.score().black == 81.0, "human confirmation controls actual final area score")
	app.save_path = "res://.runtime/katago-save-fixture.json"
	app.test_mode = false
	app.ai_level = 2
	app._save()
	app.mode = "local"
	app.ai_level = 0
	app._load_save()
	check(app.mode == "katago" and app.ai_level == 2, "AI mode and search budget survive save and restore")
	app.test_mode = true
	# Render a real analyzed middle game, never substitute fabricated statistics.
	app.new_game(19,"katago")
	app.ai_level = 1
	for p in [60,300,72,288,249,268,250,309,111,51,52,71,53,70,32,50,97,98,78,79,61,80,40,59,41,58,308,289,290,271,311,293]: app.game.play(p)
	app._refresh()
	await settle()
	await click_button(app.find_child("analysis_button",true,false))
	await wait_engine()
	check(not app.analysis_result.is_empty(), "19x19 middle game evaluated")
	app.ownership_visible = false
	app._refresh()
	await settle()
	validate_layout()
	await capture("12-katago-analysis")
	await click_button(app.find_child("ownership_button",true,false))
	check(app.right.get_combined_minimum_size().y <= app.right.get_parent().size.y, "expanded analysis and ownership fit without vertical scrolling")
	await capture("13-katago-ownership")
	if render:
		root.size = Vector2i(1100,720)
		await settle()
		validate_layout()
		await capture("14-katago-small-window")
	app._navigate("puzzles")
	check(app.board_view.territory.get_child_count() == 0 and app.engine_request.is_empty(), "analysis cleared in teaching and puzzle sections")
	var pid: int = int(app.katago.process.get("pid", -1))
	app.queue_free()
	await settle()
	check(pid < 0 or not OS.is_process_running(pid), "closing game cleans up its engine process")
	print("KATAGO UI: %d checks, %d failures" % [checks,failures.size()])
	var file = FileAccess.open("res://evidence/katago-ui-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks,"failures": failures,"render": render},"\t"))
	quit(0 if failures.is_empty() else 1)
