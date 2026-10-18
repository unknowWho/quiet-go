extends SceneTree
const Main = preload("res://scripts/main.gd")
const Content = preload("res://scripts/content.gd")
var app
var failures: Array = []
var checks: int = 0
var render: bool = false

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL UI: " + message)

func _initialize():
	render = OS.get_cmdline_user_args().has("--render")
	call_deferred("run")

func settle():
	for i in range(5): await process_frame

func click_at(pos: Vector2):
	# push_input consumes window coordinates; the root canvas stretches on resize.
	pos = root.get_final_transform() * pos
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = pos
	down.global_position = pos
	down.pressed = true
	root.push_input(down)
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	root.push_input(up)
	await settle()

func click_button(node: Button):
	await click_at(node.get_global_rect().get_center())

func click_point(p: int):
	var pos: Vector2 = app.board_view.camera.unproject_position(app.board_view.point_position(p))
	var container = app.viewport.get_parent()
	await click_at(container.global_position + pos)

func capture(name_value: String):
	if not render: return
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	check(img.save_png("res://evidence/" + name_value + ".png") == OK, "save screenshot " + name_value)

func validate_layout():
	for panel in [app.left, app.right]:
		if not panel.is_visible_in_tree(): continue
		check(panel.size.x > 100 and panel.size.x < 300, "sidebar width bounded")
		for child in panel.get_children():
			if child is Label:
				check(child.size.x <= panel.size.x+1, "label within sidebar " + child.text.left(12))
	check(app.viewport.size.x >= 420 and app.viewport.size.y >= 400, "board remains usable")

func run():
	root.size = Vector2i(1440,900)
	app = Main.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await settle()
	check(app.section == "home", "home opens")
	check(app.board_view.top_view and app.board_view.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "fresh launch defaults to top-down camera")
	check(not app.nav_row.visible and not app.dock_panel.visible, "home has one set of navigation entries")
	check(app.home_preview.moves.size() == 32 and app.game.moves.is_empty(), "home illustration is a legal sequence isolated from player match")
	validate_layout()
	await capture("01-home")
	await click_button(app.find_child("rules_button",true,false))
	var rules_dialog: AcceptDialog = app.find_child("rules_dialog",true,false)
	check(rules_dialog.visible, "rules dialog opens from home")
	await click_at(Vector2(rules_dialog.position)+rules_dialog.get_ok_button().get_global_rect().get_center())
	check(not is_instance_valid(rules_dialog) or not rules_dialog.visible, "rules dialog closes through its actual button")
	await click_button(app.find_child("home_start",true,false))
	check(app.section == "play", "navigation actual mouse input")
	check(app.mode_bar.visible and app.find_child("local_mode",true,false).button_pressed, "opponent choices visible without opening settings")
	await click_button(app.find_child("ai_mode",true,false))
	check(app.mode == "katago" and app.game.moves.is_empty(), "visible AI choice starts KataGo on an empty board")
	await click_button(app.find_child("local_mode",true,false))
	check(app.mode == "local" and app.game.moves.is_empty(), "visible human choice starts same-screen play")
	check(not app.left_panel.visible and app.dock_panel.visible, "settings collapsed and play controls available")
	await click_button(app.find_child("settings_button",true,false))
	check(app.left_panel.visible, "settings open through overlay")
	await click_button(app.find_child("settings_button",true,false))
	check(not app.left_panel.visible, "settings close through overlay")
	await click_button(app.find_child("history_button",true,false))
	check(app.history_open and app.game.moves.is_empty(), "history expands without changing match")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await settle()
	check(not app.history_open, "Escape closes secondary controls")
	var prior_sound: bool = app.sound_on
	await click_button(app.sound_button)
	check(app.sound_on != prior_sound and app.sound_button.text.ends_with("关"), "mute state is visible")
	await click_button(app.sound_button)
	await click_point(3*19+3)
	check(app.game.board[60] == 1 and app.game.turn == 2, "projected mouse click places black")
	await click_point(15*19+15)
	check(app.game.board[300] == 2 and app.game.turn == 1, "mouse click places white")
	var history_before: int = app.game.history.size()
	await click_point(60)
	check(app.game.history.size() == history_before, "occupied click rejected")
	for p in [72,288,59,301,78,269,97,250]:
		await click_point(p)
	await capture("02-match-19")
	await click_button(app.find_child("undo_button",true,false))
	check(app.game.moves.size() == 9, "UI undo")
	await click_button(app.find_child("pass_button",true,false))
	await click_button(app.find_child("pass_button",true,false))
	check(app.game.phase == "scoring", "UI two passes scoring")
	await click_point(60)
	check(not app.game.dead.is_empty(), "UI dead group toggle")
	await click_button(app.find_child("approve_black",true,false))
	check(app.game.approvals[1], "first player confirms")
	await click_point(60)
	check(not app.game.approvals[1] and app.game.dead.is_empty(), "mark changes invalidate confirmation")
	await click_button(app.find_child("resume_button",true,false))
	check(app.game.phase == "play" and app.game.board[60] == 1, "UI resume restores original board")
	var original_game = app.game
	await click_button(app.nav_buttons.lessons)
	check(app.section == "lessons" and app.exercise != app.game, "lesson isolated from match")
	check(not app.left_panel.visible, "lesson opens with catalog tucked away")
	await click_button(app.find_child("catalog_button",true,false))
	check(app.left_panel.visible, "catalog opens from lesson")
	await click_button(app.find_child("exercise_2",true,false))
	check(app.lesson_index == 2, "catalog entry selects lesson with mouse")
	await click_button(app.find_child("exercise_0",true,false))
	await click_button(app.find_child("catalog_button",true,false))
	check(not app.left_panel.visible and app.lesson_index == 0, "catalog closes and selected lesson stays active")
	await click_point(40)
	check(app.solved and app.progress.get("lesson_0","") == "independent", "interactive lesson completion")
	app.lesson_index = 1
	app._load_exercise()
	await settle()
	await capture("03-lesson-liberties")
	await click_point(41)
	check(app.exercise.board[40] == 0 and app.solved, "teaching uses actual capture engine")
	app.lesson_index = 5
	app._load_exercise()
	await settle()
	await click_point(20)
	check(not app.solved and app.feedback_text.contains("同形"), "ko tutorial rejects recapture")
	await click_point(40)
	check(app.solved, "ko tutorial legal elsewhere move")
	app.lesson_index = 7
	app._load_exercise()
	await settle()
	await click_button(app.find_child("lesson_pass",true,false))
	check(app.solved, "pass tutorial")
	await click_button(app.nav_buttons.puzzles)
	await click_point(1)
	check(not app.solved and app.exercise.moves.is_empty(), "wrong puzzle attempt does not alter board")
	app._show_answer()
	await settle()
	await capture("04-puzzle")
	await click_point(2)
	check(app.solved and app.progress.get("puzzle_0","") == "guided", "hint completion recorded separately")
	app._load_exercise()
	await settle()
	await click_point(2)
	check(app.progress.get("puzzle_0","") == "independent", "independent retry upgrades completion")
	app.puzzle_index = 1
	app._load_exercise()
	await settle()
	await click_point(2)
	app._show_branch(0)
	check(app.exercise.board.count(1) == 0, "puzzle branch really captures group")
	await test_library()
	await click_button(app.nav_buttons.play)
	check(app.game == original_game and app.game.board[60] == 1, "match persists across learning")
	app.new_game(9,"local")
	await settle()
	await click_point(40)
	app.board_view.set_camera(false)
	await click_point(41)
	check(app.game.board[41] == 2, "optional angled camera picking")
	app.board_view.set_camera(true)
	app._pass()
	app._pass()
	app._approve(1)
	app._approve(2)
	check(app.game.phase == "finished", "UI final result")
	await settle()
	await capture("05-scoring")
	app.new_game(13,"local")
	await settle()
	await click_point(84)
	check(app.game.board[84] == 1 and app.board_view.size == 13, "13x13 input mapping")
	check(app.recorded_sounds.size() == 5, "five real stone recordings loaded")
	for clip in app.recorded_sounds: check(clip != null and clip.get_length() > 0.3, "audio sample nonempty")
	app.save_path = "res://.runtime/save-fixture.json"
	app.test_mode = false
	app._save()
	app.game.play(85)
	app._save()
	app.game.play(86)
	app._load_save()
	check(app.game.moves.size() == 2 and app.game.board[86] == 0, "atomic disk save replaces existing and restores match")
	check(app.progress.get("puzzle_ggg-easy-001", "") == "independent" and app.mistakes.has("ggg-easy-002"), "stable source progress and mistake list survive disk save")
	app.test_mode = true
	app._export_sgf()
	await settle()
	app.export_dialog.file_selected.emit(ProjectSettings.globalize_path("res://.runtime/export-fixture.sgf"))
	check(FileAccess.get_file_as_string("res://.runtime/export-fixture.sgf").contains("SZ[13]"), "file-dialog SGF export writes actual file")
	await settle()
	app.new_game(9,"ai")
	app.ai_wait = 0.01
	await settle()
	await click_point(40)
	await create_timer(0.6).timeout
	check(app.game.moves.size() == 2 and app.game.turn == 1 and not app.busy, "AI replies and returns human turn")
	app._undo()
	check(app.game.moves.is_empty(), "AI undo removes whole pair")
	app.ai_wait = 0.2
	app._on_point(40)
	app._navigate("lessons")
	await create_timer(0.3).timeout
	check(app.game.moves.size() == 1, "stale AI turn canceled on navigation")
	app._navigate("play")
	await create_timer(0.7).timeout
	check(app.game.moves.size() == 2 and app.game.turn == 1, "AI resumes pending turn when returning")
	app.new_game(13,"local")
	app._on_point(84)
	await settle()
	var restart_snapshot: Dictionary = app.game.snapshot()
	await click_button(app.find_child("restart_button",true,false))
	var restart_dialog: ConfirmationDialog = app.find_child("new_game_dialog",true,false)
	check(restart_dialog != null and restart_dialog.visible, "restart is available before game ends")
	await click_at(Vector2(restart_dialog.position) + restart_dialog.get_cancel_button().get_global_rect().get_center())
	check(app.game.snapshot() == restart_snapshot, "cancel restart preserves current game")
	await click_button(app.find_child("restart_button",true,false))
	restart_dialog = app.find_child("new_game_dialog",true,false)
	await click_at(Vector2(restart_dialog.position) + restart_dialog.get_ok_button().get_global_rect().get_center())
	check(app.game.moves.is_empty() and app.game.size == 13 and app.mode == "local" and app.game.turn == 1, "mid-game restart keeps size and opponent and starts black")
	app._on_point(84)
	app.game.resign()
	app._refresh()
	await settle()
	await click_button(app.find_child("restart_button",true,false))
	check(app.game.phase == "play" and app.game.moves.is_empty() and app.find_child("new_game_dialog",true,false) == null, "finished game restarts immediately without replacement prompt")
	if render:
		root.size = Vector2i(1100,720)
		await settle()
		validate_layout()
		app.new_game(19,"local")
		app.board_view.set_camera(true)
		await settle()
		for p in [0,18,342,360,180]:
			await click_point(p)
			check(app.game.board[p] != 0, "small-window board corners and center remain clickable: " + str(p))
		await capture("06-small-window")
		app.puzzle_index = 10
		app._navigate("puzzles")
		await settle()
		await click_point(app.puzzle_session.answers()[0])
		check(app.exercise.moves.size() == 2, "small-window zoomed source puzzle accepts actual mouse move")
		await capture("11-library-small-window")
	print("UI: %d checks, %d failures" % [checks,failures.size()])
	var file = FileAccess.open("res://evidence/ui-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"render":render},"\t"))
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func test_library():
	await settle()
	check(app.puzzles.size() == 430, "expanded library loaded")
	await click_button(app.find_child("catalog_button", true, false))
	check(app.catalog_open, "source catalog actually opens")
	var difficulty: OptionButton = app.find_child("difficulty_filter", true, false)
	difficulty.select(2)
	difficulty.item_selected.emit(2)
	await settle()
	check(app._filtered_puzzles().size() == 140 and app.puzzle_page == 0, "difficulty filter limits source problems")
	check(app.left.find_children("exercise_*", "Button", false, false).size() == 8, "only current eight-row page instantiated")
	await click_button(app.find_child("catalog_next", true, false))
	check(app.puzzle_page == 1 and app.find_child("exercise_18", true, false) != null, "actual page click changes rows")
	await click_button(app.find_child("catalog_previous", true, false))
	await click_button(app.find_child("exercise_10", true, false))
	check(app.puzzle_index == 10 and app.exercise.size == 19 and app.exercise.board == app.puzzles[10].board, "source selection preserves full board")
	validate_layout()
	await capture("07-library-catalog")
	await click_button(app.find_child("catalog_button", true, false))
	var before: Dictionary = app.exercise.snapshot()
	app._answer(0)
	check(app.exercise.snapshot() == before and app.feedback_text.contains("未收录"), "UI distinguishes unlisted move without mutation")
	await click_point(app.puzzle_session.answers()[0])
	check(not app.solved and app.exercise.moves.size() == 2, "source first answer and auto reply do not complete early")
	await capture("08-library-continuation")
	check(app.puzzle_session.answers().size() == 2, "source alternative answers reach UI")
	await click_point(app.puzzle_session.answers()[1])
	check(app.solved and app.progress.get("puzzle_ggg-easy-001", "") == "independent", "source secondary solution saved by stable id")
	await click_button(app.find_child("puzzle_source", true, false))
	var source_dialog: AcceptDialog = app.find_child("puzzle_source_dialog", true, false)
	check(source_dialog != null and source_dialog.visible, "attribution and original solution commentary accessible")
	await capture("09-library-source")
	await click_at(Vector2(source_dialog.position) + source_dialog.get_ok_button().get_global_rect().get_center())
	await click_button(app.find_child("next_puzzle", true, false))
	check(app.puzzle_index == 11, "next puzzle follows filtered collection")
	var item: Dictionary = app.puzzles[11]
	for child in app.puzzle_session.node().children:
		if not item.nodes[int(child)].good:
			app._answer(int(item.nodes[int(child)].point))
			break
	check(app.mistakes.has(item.id) and app.exercise.moves.is_empty(), "recorded wrong branch enters mistake list")
	app._show_answer()
	await settle()
	await click_point(app.hint_point)
	check(not app.solved and app.hint_point == -1, "first-move hint clears after automatic reply")
	app._show_answer()
	check(app.puzzle_session.answers().has(app.hint_point) and app.hint_point != int(item.answer[0]), "hint follows current tree node")
	await settle()
	await click_point(app.hint_point)
	check(app.solved and app.progress.get("puzzle_ggg-easy-002", "") == "guided", "multi-step hints record assisted completion")
	await click_button(app.find_child("catalog_button", true, false))
	var search: LineEdit = app.find_child("puzzle_search", true, false)
	search.text = "140"
	search.text_submitted.emit("140")
	await settle()
	check(app._filtered_puzzles().size() == 1 and app.find_child("exercise_149", true, false) != null, "search by original number")
	await click_button(app.find_child("exercise_149", true, false))
	check(app.puzzle_index == 149, "search result actual mouse selection")
	search = app.find_child("puzzle_search", true, false)
	search.text_submitted.emit("no-match")
	await settle()
	check(app._filtered_puzzles().is_empty(), "empty search state")
	app._random_puzzle()
	check(app.puzzle_index == 149 and app.feedback_text.contains("没有"), "empty random request safe")
	app.puzzle_search = ""
	app.puzzle_status = "mistakes"
	app._refresh()
	await settle()
	check(app._filtered_puzzles() == [11], "mistake filter excludes solved independent problems")
	await click_button(app.find_child("random_puzzle", true, false))
	check(app.puzzle_index == 11, "random practice respects filters")
	app.puzzle_status = "all"
	app.puzzle_difficulty = "all"
	app.catalog_open = false
	var mark_game = app.Rules.new(19)
	mark_game.play(60)
	app.board_view.refresh(mark_game, false, false, -1, {"60":"A"})
	check(app.board_view.marks.get_child_count() == 1 and app.board_view.marks.get_child(0).text == "A", "source letter replaces last-move dot at same point")
	app.board_view.refresh(mark_game, true, false, -1, {"60":"A"})
	check(app.board_view.marks.get_child_count() == 1 and app.board_view.marks.get_child(0).text == "A", "source letter takes precedence over move number")
	app._refresh()
	await settle()
