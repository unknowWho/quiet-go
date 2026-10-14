extends SceneTree
const Main=preload("res://scripts/main.gd")
var app
func _initialize():
	call_deferred("run")
func shot(path: String):
	for i in range(45): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	root.size=Vector2i(1440,900)
	app=Main.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await shot("res://evidence/art-home.png")
	app.new_game(19,"local")
	for move in app.home_preview.moves: app.game.play(move.point)
	app.feedback_text="白棋落在 J4。"
	app._refresh()
	await shot("res://evidence/art-match.png")
	app.settings_open=true
	app._refresh()
	await shot("res://evidence/art-settings.png")
	app._navigate("puzzles")
	await shot("res://evidence/art-puzzle.png")
	app.catalog_open=true
	app._refresh()
	await shot("res://evidence/art-catalog.png")
	app._show_rules()
	await shot("res://evidence/art-rules.png")
	print("ART CAPTURE COMPLETE")
	quit()
