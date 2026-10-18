extends Node3D
signal point_clicked(point: int)
signal point_hovered(point: int)
var camera: Camera3D
var board_root: Node3D
var pieces: Node3D
var marks: Node3D
var props: Node3D
var ghost: MeshInstance3D
var size: int = 19
var pitch: float = 0.36
var span: float = 6.5
var last_hover: int = -2
var cells: Array = []
var turn: int = 1
var active: bool = true
var top_view: bool = true
var training_view: bool = false
var focus_bounds: Array = []
var black_mat: ShaderMaterial
var white_mat: ShaderMaterial
var wood: ShaderMaterial
var bowl_mat: ShaderMaterial
var label_font: SystemFont
var last_model_id: int = 0
var last_move_count: int = 0
var visual_signature: String = ""
var piece_mesh: SphereMesh
var territory: Node3D
var ownership_signature: String = ""

func _ready():
	label_font = SystemFont.new()
	label_font.font_names = PackedStringArray(["Georgia","Microsoft YaHei UI"])
	black_mat = ShaderMaterial.new()
	black_mat.shader = load("res://assets/stone.gdshader")
	black_mat.set_shader_parameter("black",true)
	white_mat = ShaderMaterial.new()
	white_mat.shader = load("res://assets/stone.gdshader")
	wood = ShaderMaterial.new()
	wood.shader = load("res://assets/kaya.gdshader")
	wood.set_shader_parameter("grain",load("res://assets/fine_wood/color.jpg"))
	wood.set_shader_parameter("normal_tex",load("res://assets/fine_wood/normal.jpg"))
	bowl_mat = ShaderMaterial.new()
	bowl_mat.shader = load("res://assets/bowl.gdshader")
	bowl_mat.set_shader_parameter("grain",load("res://assets/fine_wood/color.jpg"))
	bowl_mat.set_shader_parameter("rough_tex",load("res://assets/fine_wood/rough.jpg"))
	piece_mesh = SphereMesh.new()
	piece_mesh.radius = 1.0
	piece_mesh.height = 2.0
	piece_mesh.radial_segments = 64
	piece_mesh.rings = 32
	_lighting()
	var cloth: ShaderMaterial = ShaderMaterial.new()
	cloth.shader = load("res://assets/linen.gdshader")
	box(self,Vector3(40,0.2,40),Vector3(0,-0.65,0),cloth)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.1
	camera.far = 70.0
	add_child(camera)
	set_camera(true)
	board_root = Node3D.new()
	add_child(board_root)
	pieces = Node3D.new()
	add_child(pieces)
	marks = Node3D.new()
	add_child(marks)
	territory = Node3D.new()
	add_child(territory)
	props = Node3D.new()
	add_child(props)
	make_bowl(Vector3(-4.85,-0.55,-2.4),1)
	make_bowl(Vector3(4.85,-0.55,1.65),2)
	make_lid(Vector3(4.65,-0.55,3.75))
	make_tea(Vector3(-4.8,-0.55,2.0))
	ghost = stone(1,0.17)
	ghost.visible = false
	var gm: StandardMaterial3D = material(Color(0.35,0.50,0.39,0.32))
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.material_override = gm
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	get_viewport().size_changed.connect(_fit_camera)

func _lighting():
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("898374")
	var sky: Sky = Sky.new()
	var sky_mat: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/studio/environment.hdr")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_512
	e.sky = sky
	e.sky_rotation = Vector3(0,0.5,0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.ambient_light_energy = 0.40
	e.background_energy_multiplier = 0.48
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.ssao_enabled = true
	e.ssao_radius = 0.22
	e.ssao_intensity = 2.1
	e.ssao_power = 1.5
	e.ssao_detail = 0.7
	e.ssao_light_affect = 0.25
	env.environment = e
	add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48,-32,0)
	key.light_color = Color("fff5e6")
	key.light_energy = 1.25
	key.light_angular_distance = 5.0
	key.shadow_enabled = true
	key.shadow_bias = 0.1
	key.shadow_normal_bias = 0.6
	key.directional_shadow_max_distance = 26.0
	add_child(key)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(4,5,-5)
	fill.omni_range = 18
	fill.light_color = Color("e6edff")
	fill.light_energy = 0.5
	fill.light_size = 3.0
	add_child(fill)

func set_camera(overhead: bool):
	top_view = overhead
	_fit_camera()

func set_training(enabled: bool):
	training_view = enabled
	if props: props.visible = not enabled
	_fit_camera()

func set_focus(bounds: Array):
	if focus_bounds == bounds: return
	focus_bounds = bounds.duplicate()
	_fit_camera()

func _fit_camera():
	if not camera: return
	var aspect: float = float(get_viewport().size.x)/maxf(1.0,get_viewport().size.y)
	var shift: float = 0.0 if training_view else 1.45
	var target: Vector3 = Vector3(shift,0,0.35)
	var zoom: float = 1.0
	if training_view and focus_bounds.size() == 4:
		var width: float = float(focus_bounds[2]) - float(focus_bounds[0]) + 1
		var height: float = float(focus_bounds[3]) - float(focus_bounds[1]) + 1
		zoom = clampf((maxf(width, height) + 4.0) / size, 0.48, 1.0)
		if zoom < 1.0:
			target = Vector3((float(focus_bounds[0])+float(focus_bounds[2]))*0.5*pitch-span*0.5, 0,
				(float(focus_bounds[1])+float(focus_bounds[3]))*0.5*pitch*1.04-span*0.52+0.35*zoom)
	if top_view:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = (10.0 if aspect > 1.45 else 10.5) * zoom
		camera.position = target+Vector3(0,16,0.001)
		camera.look_at(target,Vector3.FORWARD)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 35.0 if aspect > 1.45 else 38.0
		camera.position = target+Vector3(0.55,12.4,9.5)*zoom
		camera.look_at(target)

func clear_children(node: Node):
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func material(color: Color,roughness: float=0.65) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func box(parent: Node,dimensions: Vector3,pos: Vector3,mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func refresh(g,numbers: bool=false,show_score: bool=false,hint: int=-1,annotations: Dictionary={}):
	var animate: bool = g.get_instance_id()==last_model_id and g.moves.size()==last_move_count+1
	last_model_id = g.get_instance_id()
	last_move_count = g.moves.size()
	if size!=g.size or board_root.get_child_count()==0:
		size = g.size
		pitch = span/(size-1)
		build_board()
	var signature: String = str(g.get_instance_id())+g.key(g.board)+str(g.moves.size())+str(g.dead)+str(numbers)+str(show_score)+str(hint)+str(annotations)
	turn = g.turn
	if signature==visual_signature: return
	visual_signature = signature
	cells = g.board.duplicate()
	clear_children(pieces)
	clear_children(marks)
	var move_numbers: Dictionary = {}
	for i in range(g.moves.size()):
		var m: Dictionary = g.moves[i]
		for removed in m.get("captured",[]): move_numbers.erase(removed)
		if m.point>=0: move_numbers[m.point]=i+1
	for p in range(cells.size()):
		if cells[p]==0: continue
		var node: MeshInstance3D = stone(cells[p],pitch*0.478)
		node.position = point_position(p)+Vector3(0,pitch*0.208,0)
		node.rotation.y = float(p)*2.39996
		pieces.add_child(node)
		if animate and not g.moves.is_empty() and g.moves[-1].point==p:
			var destination: Vector3 = node.position
			node.position.y+=pitch*0.9
			node.create_tween().tween_property(node,"position",destination,0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if g.dead.has(p): marker(p,Color("ac4d35"),"×")
		elif numbers and move_numbers.has(p) and not annotations.has(str(p)): marker(p,Color("e8e4d8") if cells[p]==1 else Color("39372f"),str(move_numbers[p]))
	if not numbers and not g.moves.is_empty() and g.moves[-1].point>=0 and not annotations.has(str(g.moves[-1].point)):
		marker(g.moves[-1].point,Color("ba4d30"),"·")
	if show_score:
		var s: Dictionary = g.score()
		for p in range(cells.size()):
			if s.owner[p] and (cells[p]==0 or g.dead.has(p)):
				box(marks,Vector3(pitch*0.21,0.008,pitch*0.21),point_position(p)+Vector3(0,0.035,0),material(Color("242d27") if s.owner[p]==1 else Color("fff7e2")))
	if hint>=0: marker(hint,Color("476c4b"),"◎")
	for p in annotations:
		var q: int = int(p)
		marker(q, Color("e6d5a7") if cells[q] == 1 else Color("713c2b"), str(annotations[p]))
	ghost.visible=false

func show_ownership(values: Array):
	var signature: String = str(size) + str(cells) + str(values)
	if signature == ownership_signature: return
	ownership_signature = signature
	clear_children(territory)
	if values.size() != size * size: return
	for p in range(values.size()):
		var confidence: float = absf(float(values[p]))
		if confidence < 0.15: continue
		# Only mark occupied points when the predicted owner differs from the stone.
		if (cells[p] == 1 and values[p] > 0) or (cells[p] == 2 and values[p] < 0): continue
		var color: Color = Color("242d27") if values[p] > 0 else Color("fff7e2")
		var mat: StandardMaterial3D = material(color)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var width: float = pitch * (0.10 + 0.22 * confidence)
		var height: float = pitch * 0.45 if cells[p] != 0 else 0.04
		var node = box(territory, Vector3(width, 0.008, width), point_position(p) + Vector3(0, height, 0), mat)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func point_position(p: int) -> Vector3:
	return Vector3((p%size)*pitch-span*0.5,0.012,(p/size)*pitch*1.04-span*0.52)

func _rounded_ring(hx: float,hz: float,r: float,y: float) -> Array:
	var points: Array = []
	for corner in range(4):
		var center: Vector2 = [Vector2(hx-r,hz-r),Vector2(-hx+r,hz-r),Vector2(-hx+r,-hz+r),Vector2(hx-r,-hz+r)][corner]
		for step_index in range(9):
			var angle: float = float(corner)*PI*0.5+step_index*PI/16.0
			points.append(Vector3(center.x+cos(angle)*r,y,center.y+sin(angle)*r))
	return points

func build_board():
	clear_children(board_root)
	wood.set_shader_parameter("board_size",float(size))
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = [_rounded_ring(3.65,3.8,0.075,0),_rounded_ring(3.695,3.845,0.12,-0.045),_rounded_ring(3.695,3.845,0.12,-0.465),_rounded_ring(3.66,3.81,0.085,-0.50)]
	var count: int = rings[0].size()
	for i in range(count):
		for v in [Vector3.ZERO,rings[0][i],rings[0][(i+1)%count]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x/7.4+0.5,v.z/7.7+0.5))
			st.add_vertex(v)
	for layer in range(rings.size()-1):
		for i in range(count):
			var j: int = (i+1)%count
			var verts: Array = [rings[layer][i],rings[layer][j],rings[layer+1][i],rings[layer+1][j]]
			for index in [0,2,1,1,2,3]:
				var v: Vector3 = verts[index]
				var h: Vector3 = Vector3(v.x-signf(v.x)*3.575,0,v.z-signf(v.z)*3.725)
				if absf(v.x)<3.575: h.x=0
				if absf(v.z)<3.725: h.z=0
				h=h.normalized()
				var n: Vector3 = h
				if layer==0: n=(h+Vector3.UP).normalized()
				elif layer==2: n=(h+Vector3.DOWN).normalized()
				st.set_normal(n)
				st.set_uv(Vector2(v.x/7.4+0.5,v.z/7.7+0.5))
				st.add_vertex(v)
	var body: MeshInstance3D = MeshInstance3D.new()
	st.generate_tangents()
	body.mesh=st.commit()
	body.material_override=wood
	board_root.add_child(body)
	var pad_mat = material(Color("292721"),0.95)
	for x in [-2.8,2.8]:
		for z in [-3.0,3.0]:
			box(board_root,Vector3(0.4,0.05,0.4),Vector3(x,-0.525,z),pad_mat)
	for i in range(size):
		var x: float = i*pitch-span*0.5
		var z: float = i*pitch*1.04-span*0.52
		flat_label("ABCDEFGHJKLMNOPQRST"[i],Vector3(x,0.017,span*0.52+0.20),0.0037,Color("6f593b"))
		flat_label(str(size-i),Vector3(-span*0.5-0.20,0.017,z),0.0037,Color("6f593b"))

func flat_label(value: String,pos: Vector3,pixel: float,color: Color) -> Label3D:
	var node: Label3D = Label3D.new()
	node.text=value
	node.font=label_font
	node.font_size=40
	node.pixel_size=pixel
	node.modulate=color
	node.outline_size=0
	node.rotation_degrees.x=-90
	node.position=pos
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board_root.add_child(node)
	return node

func marker(p: int,color: Color,value: String):
	var node: Label3D = Label3D.new()
	node.text=value
	node.font=label_font
	node.font_size=56
	node.pixel_size=pitch*0.009
	node.modulate=color
	node.outline_size=0
	node.rotation_degrees.x=-90
	node.position=point_position(p)+Vector3(0,pitch*0.445,0)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(node)

func stone(color: int,radius: float) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh=piece_mesh
	node.scale=Vector3(radius,radius*0.43,radius)
	node.material_override=black_mat if color==1 else white_mat
	return node

func lathe(parent: Node,profile: Array,mat: Material) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals: Array = []
	for j in range(profile.size()):
		var tangent: Vector2 = profile[mini(j+1,profile.size()-1)]-profile[maxi(j-1,0)]
		normals.append(Vector2(tangent.y,-tangent.x).normalized())
	for j in range(profile.size()-1):
		for i in range(128):
			for spec in [[j,i],[j,i+1],[j+1,i],[j,i+1],[j+1,i+1],[j+1,i]]:
				var row: int = spec[0]
				var angle: float = TAU*spec[1]/128.0
				var v: Vector3 = Vector3(cos(angle)*profile[row].x,profile[row].y,sin(angle)*profile[row].x)
				st.set_normal(Vector3(cos(angle)*normals[row].x,normals[row].y,sin(angle)*normals[row].x))
				st.set_uv(Vector2(float(spec[1])/128.0,float(row)/profile.size()))
				st.add_vertex(v)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh=st.commit()
	mesh.material_override=mat
	parent.add_child(mesh)
	return mesh

func make_bowl(pos: Vector3,color: int):
	var bowl: Node3D = Node3D.new()
	bowl.position=pos
	props.add_child(bowl)
	var profile: Array = [Vector2(0.0,0.025),Vector2(0.42,0.025),Vector2(0.47,0.055),Vector2(0.56,0.10),Vector2(0.69,0.18),Vector2(0.83,0.31),Vector2(0.94,0.46),Vector2(1.0,0.62),Vector2(1.015,0.76),Vector2(1.0,0.81),Vector2(0.965,0.825),Vector2(0.93,0.795),Vector2(0.924,0.73),Vector2(0.906,0.60),Vector2(0.85,0.46),Vector2(0.75,0.33),Vector2(0.60,0.22),Vector2(0.39,0.16),Vector2(0.0,0.14)]
	lathe(bowl,profile,bowl_mat)
	for layer in range(3):
		for row in range(-2,3):
			for col in range(-2,3):
				var x: float = col*0.347+(0.1735 if (row+layer)%2==0 else 0)
				var z: float = row*0.303
				if Vector2(x,z).length()>0.72-layer*0.018: continue
				var node: MeshInstance3D = stone(color,0.171)
				node.position=Vector3(x,0.37+layer*0.145,z)
				node.rotation_degrees=Vector3(sin(row*5+col*7)*5,col*41+row*59+layer*83,cos(col*4+row)*4)
				bowl.add_child(node)

func make_lid(pos: Vector3):
	var lid: Node3D = Node3D.new()
	lid.position=pos
	props.add_child(lid)
	lathe(lid,[Vector2(0,0.025),Vector2(0.76,0.025),Vector2(0.9,0.055),Vector2(0.96,0.11),Vector2(0.97,0.16),Vector2(0.94,0.185),Vector2(0.9,0.16),Vector2(0.82,0.105),Vector2(0.62,0.065),Vector2(0,0.045)],bowl_mat)

func make_tea(pos: Vector3):
	var tea: Node3D = Node3D.new()
	tea.position=pos
	props.add_child(tea)
	var ceramic = material(Color("718779"),0.29)
	ceramic.metallic_specular=0.3
	lathe(tea,[Vector2(0,0.025),Vector2(0.55,0.025),Vector2(0.66,0.075),Vector2(0.68,0.11),Vector2(0.63,0.12),Vector2(0.4,0.075),Vector2(0,0.065)],ceramic)
	lathe(tea,[Vector2(0,0.075),Vector2(0.24,0.075),Vector2(0.27,0.10),Vector2(0.31,0.2),Vector2(0.37,0.43),Vector2(0.405,0.58),Vector2(0.41,0.625),Vector2(0.385,0.637),Vector2(0.362,0.595),Vector2(0.32,0.39),Vector2(0.27,0.22),Vector2(0,0.17)],ceramic)
	var liquid: StandardMaterial3D = material(Color("62542d"),0.15)
	liquid.metallic_specular=0.65
	var disk: CylinderMesh = CylinderMesh.new()
	disk.top_radius=0.356
	disk.bottom_radius=0.356
	disk.height=0.002
	disk.radial_segments=96
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh=disk
	mesh.position.y=0.49
	mesh.material_override=liquid
	tea.add_child(mesh)

func point_at(screen: Vector2) -> int:
	var origin: Vector3=camera.project_ray_origin(screen)
	var direction: Vector3=camera.project_ray_normal(screen)
	if absf(direction.y)<0.001: return -1
	var at: Vector3=origin+direction*((0.012-origin.y)/direction.y)
	var x: int=roundi((at.x+span*0.5)/pitch)
	var y: int=roundi((at.z+span*0.52)/(pitch*1.04))
	if x<0 or x>=size or y<0 or y>=size: return -1
	if absf(at.x-(x*pitch-span*0.5))>pitch*0.46 or absf(at.z-(y*pitch*1.04-span*0.52))>pitch*0.48: return -1
	return y*size+x

func _input(event: InputEvent):
	if not camera or not active: return
	if event is InputEventMouseMotion:
		var p: int=point_at(event.position)
		if p!=last_hover:
			last_hover=p
			point_hovered.emit(p)
		ghost.visible=p>=0 and not cells.is_empty() and cells[p]==0
		if ghost.visible:
			ghost.position=point_position(p)+Vector3(0,pitch*0.208,0)
			ghost.scale=Vector3(pitch*0.478,pitch*0.478*0.43,pitch*0.478)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var p: int=point_at(event.position)
		if p>=0: point_clicked.emit(p)
