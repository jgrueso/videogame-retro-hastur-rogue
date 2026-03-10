extends Node2D

const ROOM_COMBAT   = "combat"
const ROOM_ELITE    = "elite"
const ROOM_EVENT    = "event"
const ROOM_SHOP     = "shop"
const ROOM_BOSS     = "boss"
const ROOM_FINAL    = "final"
const ROOM_FINAL_W2 = "final_w2"
const ROOM_SECRET   = "secret"
const ROOM_REST     = "rest"

const ROOM_COLORS = {
	ROOM_COMBAT:   Color(0.3, 0.3, 0.7),
	ROOM_ELITE:    Color(0.6, 0.2, 0.2),
	ROOM_EVENT:    Color(0.2, 0.6, 0.4),
	ROOM_SHOP:     Color(0.6, 0.5, 0.1),
	ROOM_BOSS:     Color(0.5, 0.05, 0.05),
	ROOM_FINAL:    Color(0.5, 0.4, 0.0),
	ROOM_FINAL_W2: Color(0.55, 0.4, 0.0),
	ROOM_SECRET:   Color(0.45, 0.38, 0.04),
	ROOM_REST:     Color(0.4, 0.7, 0.8),
}

const ROOM_LABELS = {
	ROOM_COMBAT:   "⚔ Eco de Batalla",
	ROOM_ELITE:    "☠ Presencia Voraz",
	ROOM_EVENT:    "♄ Augurio",
	ROOM_SHOP:     "☤ El Buhonero",
	ROOM_BOSS:     "★ EL CARCELERO",
	ROOM_FINAL:    "♔ EL REY SIN CORONA",
	ROOM_FINAL_W2: "♔ EL REY AMARILLO",
	ROOM_SECRET:   "✦ Fragmento de Realidad",
	ROOM_REST:     "🕯 Hoguera de Ceniza",
}

func _ready() -> void:
	if GameManager.map_graph.is_empty():
		GameManager.map_graph = _generate_map()
	modulate.a = 0.0
	build_ui()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

# ─── Generacion procedural del mapa ──────────────────────────────────────────
func _generate_map() -> Array:
	var graph: Array = []
	var num_floors = randi_range(11, 15)
	var is_w2 = GameManager.current_world == 1
	var final_room = ROOM_FINAL_W2 if is_w2 else ROOM_FINAL

	# Elegir pisos para tiendas (2 tiendas, bien espaciadas)
	var s1 = randi_range(3, int(num_floors / 3.0))
	var s2 = randi_range(int(num_floors / 2.0), num_floors - 4)
	var shop_floors = [s1, s2]

	for f in range(num_floors):
		var floor_nodes: Array = []

		# Pisos fijos finales (de arriba a abajo en el grafo, pero f es el indice de piso)
		# f == num_floors - 1  --> JEFE FINAL (Rey)
		# f == num_floors - 2  --> HOGUERA (Descanso Pre-Final)
		# f == num_floors - 3  --> JEFE DE MUNDO (Carcelero) o ELITE (si el jugador elige otra ruta)
		
		if f == num_floors - 1:
			floor_nodes.append({"type": final_room, "connections": []})
			graph.append(floor_nodes)
			continue
		if f == num_floors - 2:
			# Siempre un descanso antes del final
			floor_nodes.append({"type": ROOM_REST, "connections": []})
			graph.append(floor_nodes)
			continue
		if f == num_floors - 3:
			# El Jefe de Mundo es una opcion, pero podria haber otros caminos
			floor_nodes.append({"type": ROOM_BOSS, "connections": []})
			if randf() < 0.5: # 50% de probabilidad de tener un camino alternativo (Elite o Evento)
				floor_nodes.append({"type": ROOM_ELITE if randf() < 0.5 else ROOM_EVENT, "connections": []})
			graph.append(floor_nodes)
			continue
		if f == num_floors - 4:
			# Otro descanso antes del tramo final
			floor_nodes.append({"type": ROOM_REST, "connections": []})
			graph.append(floor_nodes)
			continue
		if f in shop_floors:
			floor_nodes.append({"type": ROOM_SHOP, "connections": []})
			graph.append(floor_nodes)
			continue

		# Pisos normales: 1-3 nodos
		var num_cols = randi_range(1, 3)
		if f == 0:
			num_cols = randi_range(2, 3)  # Siempre dar opciones al inicio

		var prev_type = ""
		for c in range(num_cols):
			var t = _pick_room_type(f, num_floors, prev_type)
			prev_type = t
			floor_nodes.append({"type": t, "connections": []})

		graph.append(floor_nodes)

	# Generar conexiones entre pisos
	for f in range(graph.size() - 1):
		_connect_floors(graph, f)

	# Colocar objetos misteriosos de forma aleatoria y solo si faltan
	var missing_items: Array = []
	for item_id in GameManager.SECRET_ITEM_DATA.keys():
		if not GameManager.has_secret_item(item_id):
			missing_items.append(item_id)
	
	if not missing_items.is_empty():
		missing_items.shuffle()
		var fixed_types = [ROOM_SHOP, ROOM_BOSS, ROOM_FINAL, ROOM_FINAL_W2]
		var eligible: Array = []
		for f in range(2, graph.size() - 2):
			if graph[f][0].type not in fixed_types:
				eligible.append(f)
		
		eligible.shuffle()
		# Decidir cuantos colocar en este mapa (0 a 2, maximo los que falten)
		var to_place = min(randi_range(0, 2), missing_items.size())
		
		for i in range(to_place):
			if eligible.is_empty(): break
			var fi = eligible.pop_back()
			var ci = randi() % graph[fi].size()
			graph[fi][ci].type = ROOM_SECRET
			graph[fi][ci]["item_id"] = missing_items[i]

	return graph

func _pick_room_type(f_idx: int, total: int, prev_type: String) -> String:
	if f_idx == 0:
		var opts = [ROOM_COMBAT, ROOM_COMBAT, ROOM_EVENT]
		return opts[randi() % opts.size()]

	var mid_start = int(total / 3.0)
	var mid_end = int((2.0 * total) / 3.0)
	var roll = randf()

	var t: String
	if f_idx >= mid_start and f_idx < mid_end:
		# Zona media: mas elites y eventos
		if roll < 0.30:   t = ROOM_COMBAT
		elif roll < 0.60: t = ROOM_ELITE
		else:             t = ROOM_EVENT
	else:
		# Zona inicial/final: mas combate normal
		if roll < 0.50:   t = ROOM_COMBAT
		elif roll < 0.75: t = ROOM_EVENT
		elif roll < 0.90: t = ROOM_ELITE
		else:             t = ROOM_COMBAT

	# Evitar dos elites seguidas en el mismo piso
	if t == ROOM_ELITE and prev_type == ROOM_ELITE:
		t = ROOM_COMBAT
	return t

func _connect_floors(graph: Array, f: int) -> void:
	var curr: Array = graph[f]
	var nxt: Array  = graph[f + 1]
	var cn: int = curr.size()
	var nn: int = nxt.size()

	# Cada nodo actual conecta al nodo proporcionalmente equivalente en el siguiente
	for c in range(cn):
		var t = int(round(float(c) * float(nn - 1) / float(max(cn - 1, 1))))
		t = clamp(t, 0, nn - 1)
		if not t in curr[c].connections:
			curr[c].connections.append(t)

	# Asegurar que todos los nodos del siguiente piso sean alcanzables
	for nc in range(nn):
		var reached = false
		for c in range(cn):
			if nc in curr[c].connections:
				reached = true
				break
		if not reached:
			# Conectar el nodo actual mas cercano
			var best = 0
			var best_dist = 9999
			for c in range(cn):
				var dist = abs(float(c) / float(max(cn - 1, 1)) - float(nc) / float(max(nn - 1, 1)))
				if dist < best_dist and curr[c].connections.size() < 2:
					best_dist = dist
					best = c
			if not nc in curr[best].connections:
				curr[best].connections.append(nc)

	# Bonus: chance de conexion extra para dar mas ramificaciones
	for c in range(cn):
		if curr[c].connections.size() < 2 and randf() < 0.35:
			var candidates = range(nn)
			var cand_arr: Array = []
			for x in candidates:
				cand_arr.append(x)
			cand_arr.shuffle()
			for nc in cand_arr:
				if not nc in curr[c].connections:
					curr[c].connections.append(nc)
					break

# ─── UI ──────────────────────────────────────────────────────────────────────
func build_ui() -> void:
	var vp = get_viewport_rect().size

	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08)
	bg.position = Vector2.ZERO
	bg.size = vp
	add_child(bg)

	var world_name = "Mundo II — El Tablero Dorado" if GameManager.current_world == 1 else "Mundo I — La Caida del Rey"

	var title = Label.new()
	title.text = "Elige tu camino"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(vp.x, 34)
	add_child(title)

	var world_lbl = Label.new()
	world_lbl.text = world_name
	world_lbl.add_theme_font_size_override("font_size", 12)
	world_lbl.modulate = Color(0.95, 0.8, 0.1) if GameManager.current_world == 1 else Color(0.6, 0.7, 0.9)
	world_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_lbl.position = Vector2(0, 38)
	world_lbl.size = Vector2(vp.x, 20)
	add_child(world_lbl)

	var graph = GameManager.map_graph
	var info = Label.new()
	info.text = "HP: " + str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp) + \
		"   Energia: " + str(GameManager.player_max_energy) + \
		"   Monedas: " + str(GameManager.coins) + \
		"   Piso: " + str(GameManager.current_map_floor + 1) + "/" + str(graph.size())
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 56)
	info.size = Vector2(vp.x, 24)
	add_child(info)

	# Reliquias activas
	if not GameManager.relics.is_empty():
		var relic_label = Label.new()
		relic_label.text = "Reliquias:"
		relic_label.add_theme_font_size_override("font_size", 11)
		relic_label.modulate = Color(0.8, 0.7, 0.4)
		relic_label.position = Vector2(6, 82)
		add_child(relic_label)

		var relic_scene = preload("res://scenes/ui/RelicIcon.tscn")
		for i in range(GameManager.relics.size()):
			var icon = relic_scene.instantiate()
			icon.position = Vector2(6 + i * 48, 96)
			add_child(icon)
			icon.setup(GameManager.relics[i])

	# Boton Visor de Mazo
	var deck_btn = Button.new()
	deck_btn.text = " ▣ VER MAZO "
	deck_btn.position = Vector2(vp.x - 160, 10); deck_btn.size = Vector2(150, 40)
	deck_btn.add_theme_font_size_override("font_size", 14)
	add_child(deck_btn)
	deck_btn.pressed.connect(_show_deck_viewer)

	# Indicador de objetos misteriosos
	if GameManager.secret_items.size() > 0 or _map_has_secret_rooms():
		var si_lbl = Label.new()
		var count = GameManager.secret_items.size()
		si_lbl.text = "✦ " + str(count) + " / 3"
		si_lbl.add_theme_font_size_override("font_size", 12)
		si_lbl.modulate = Color(0.85, 0.72, 0.1) if count > 0 else Color(0.45, 0.42, 0.15)
		si_lbl.position = Vector2(vp.x - 70, 56)
		si_lbl.size = Vector2(64, 24)
		add_child(si_lbl)

	draw_map()

func draw_map() -> void:
	var vp = get_viewport_rect().size
	var graph = GameManager.map_graph
	var num_floors = graph.size()

	var top_margin: float  = 118.0   # espacio para header
	var bot_margin: float  = 14.0
	var map_height: float  = vp.y - top_margin - bot_margin
	var floor_height: float = map_height / num_floors

	var map_w: float    = vp.x * 0.78
	var map_start_x: float = (vp.x - map_w) / 2.0
	var map_start_y: float = vp.y - bot_margin - floor_height / 2.0

	# Pre-calcular posiciones X de cada nodo
	var positions: Array = []   # positions[f][c] = Vector2
	for f in range(num_floors):
		var floor_nodes: Array = graph[f]
		var nc = floor_nodes.size()
		var row_pos: Array = []
		for c in range(nc):
			var x = map_start_x + (map_w / (nc + 1)) * (c + 1)
			var y = map_start_y - f * floor_height
			row_pos.append(Vector2(x, y))
		positions.append(row_pos)

	# Dibujar lineas de conexion
	for f in range(num_floors - 1):
		var floor_nodes: Array = graph[f]
		for c in range(floor_nodes.size()):
			for nc in floor_nodes[c].connections:
				var p0 = positions[f][c]
				var p1 = positions[f + 1][nc]
				var on_path = _is_on_chosen_path(f, c)
				var line = Line2D.new()
				line.add_point(p0)
				line.add_point(p1)
				if on_path:
					line.default_color = Color(0.6, 0.6, 0.9, 0.55)
					line.width = 2.0
				else:
					line.default_color = Color(0.22, 0.22, 0.28, 0.6)
					line.width = 1.2
				add_child(line)
				move_child(line, 1)

	# Dibujar nodos
	for f in range(num_floors):
		var floor_nodes: Array = graph[f]
		for c in range(floor_nodes.size()):
			var room_type = floor_nodes[c].type
			var pos = positions[f][c]
			var reachable = _is_node_reachable(f, c)
			var already_done = f < GameManager.current_map_floor

			var btn = Button.new()
			btn.text = ROOM_LABELS[room_type]
			btn.position = Vector2(pos.x - 46, pos.y - 17)
			btn.size = Vector2(92, 34)
			btn.disabled = not reachable or already_done

			var style = StyleBoxFlat.new()
			style.set_corner_radius_all(7)
			if already_done:
				style.bg_color = Color(0.10, 0.10, 0.12)
				style.border_color = Color(0.18, 0.18, 0.20)
			elif reachable:
				style.bg_color = ROOM_COLORS[room_type]
				style.border_color = ROOM_COLORS[room_type].lightened(0.35)
				style.border_width_left   = 2
				style.border_width_right  = 2
				style.border_width_top    = 2
				style.border_width_bottom = 2
			else:
				style.bg_color = ROOM_COLORS[room_type].darkened(0.70)
				style.border_color = Color(0.14, 0.14, 0.17)
			btn.add_theme_stylebox_override("normal", style)

			if reachable and not already_done:
				var hover = style.duplicate()
				hover.bg_color = ROOM_COLORS[room_type].lightened(0.18)
				btn.add_theme_stylebox_override("hover", hover)

			var fi = f
			var ci = c
			btn.pressed.connect(func(): _on_room_selected(fi, ci))
			add_child(btn)

# ─── Logica de rutas ─────────────────────────────────────────────────────────
func _is_node_reachable(floor_idx: int, col_idx: int) -> bool:
	if floor_idx != GameManager.current_map_floor:
		return false
	if floor_idx == 0:
		return true  # Todo el primer piso es accesible
	var prev_col = GameManager.current_map_col
	if prev_col < 0:
		return false
	var prev_connections = GameManager.map_graph[floor_idx - 1][prev_col].connections
	return col_idx in prev_connections

# Devuelve true si este nodo fue parte del camino ya recorrido por el jugador
func _is_on_chosen_path(floor_idx: int, _col_idx: int) -> bool:
	if floor_idx >= GameManager.current_map_floor:
		return false
	# Para floor 0, si solo hay una columna o no hay historial, todo vale
	# Simplificacion: marcamos el nodo del piso anterior como "en ruta"
	# (no guardamos historial completo, solo el col actual)
	return false  # las lineas pasadas se muestran neutras; la ruta futura se ilumina al ser reachable

func _on_room_selected(floor_idx: int, col_idx: int) -> void:
	var room_type = GameManager.map_graph[floor_idx][col_idx].type
	GameManager.current_map_floor = floor_idx + 1
	GameManager.current_map_col   = col_idx

	# Resetear todos los flags antes de setear el correcto
	GameManager.is_boss_fight  = false
	GameManager.is_elite_fight = false
	GameManager.is_final_boss  = false
	GameManager.is_hastur_fight = false

	match room_type:
		ROOM_COMBAT:
			get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")
		ROOM_ELITE:
			GameManager.is_elite_fight = true
			get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")
		ROOM_EVENT:
			get_tree().change_scene_to_file("res://scenes/ui/Event.tscn")
		ROOM_SHOP:
			get_tree().change_scene_to_file("res://scenes/ui/Shop.tscn")
		ROOM_REST:
			get_tree().change_scene_to_file("res://scenes/ui/Rest.tscn")
		ROOM_BOSS:
			GameManager.is_boss_fight = true
			get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")
		ROOM_FINAL, ROOM_FINAL_W2:
			GameManager.is_final_boss = true
			get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")
		ROOM_SECRET:
			var item_id = GameManager.map_graph[floor_idx][col_idx].get("item_id", "")
			_show_secret_item_overlay(item_id)

func _map_has_secret_rooms() -> bool:
	for floor_nodes in GameManager.map_graph:
		for node in floor_nodes:
			if node.type == ROOM_SECRET:
				return true
	return false

func _typewrite(lbl: Label, text: String, base_delay: float = 0.04) -> void:
	lbl.text = ""
	for i in range(text.length()):
		lbl.text = text.substr(0, i + 1)
		var c = text[i]
		var wait = base_delay
		if c in [".", "!", "?"]:  wait = base_delay * 7.0
		elif c in [",", ";"]:     wait = base_delay * 3.0
		elif c == "\n":           wait = base_delay * 5.0
		await get_tree().create_timer(wait).timeout

func _show_secret_item_overlay(item_id: String) -> void:
	if item_id == "" or not GameManager.SECRET_ITEM_DATA.has(item_id):
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
		return

	var already_have = GameManager.has_secret_item(item_id)

	var situations = [
		{
			"header": "✦  CRIATURA AFERRADA  ✦",
			"text": "Una masa de carne palida abraza el objeto.\nSus cientos de bocas susurran tu nombre.\nDebes alimentarla con tu propia sangre para que lo suelte.",
			"cost_label": "Alimentar ( -20% HP )",
			"type": "blood"
		},
		{
			"header": "✦  EL VACIO DEL OLVIDO  ✦",
			"text": "El objeto flota en un portal de ceniza.\nSientes que si metes la mano,\nparte de lo que eres se perdera para siempre en el otro lado.",
			"cost_label": "Meter la mano ( -6 HP MAX )",
			"type": "max_hp"
		},
		{
			"header": "✦  EL SUSURRO PROHIBIDO  ✦",
			"text": "El artefacto vibra con una melodia que te hiela los huesos.\nSi decides tomarlo,\nsu verdad pesara en tu mente hasta el final.",
			"cost_label": "Escuchar ( + Maldicion )",
			"type": "curse"
		}
	]

	var sit = situations[randi() % situations.size()]
	var item_data = GameManager.SECRET_ITEM_DATA[item_id]
	var vp = get_viewport_rect().size

	# Oscurecer pantalla lentamente
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.position = Vector2.ZERO; dim.size = vp
	dim.z_index = 20; dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var dt = create_tween()
	dt.tween_property(dim, "color:a", 0.93, 0.7)
	await dt.finished

	var panel = Panel.new()
	panel.position = Vector2(276, 80); panel.size = Vector2(600, 430)
	panel.z_index = 21; panel.modulate.a = 0.0
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.03, 0.01, 0.98); ps.set_corner_radius_all(10)
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = item_data["color"]
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	var pt = create_tween()
	pt.tween_property(panel, "modulate:a", 1.0, 0.3)
	await pt.finished

	# Header typewriter
	var header = Label.new()
	header.text = ""
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = Color(0.6, 0.5, 0.2)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 18); header.size = Vector2(600, 24)
	panel.add_child(header)
	await _typewrite(header, sit["header"], 0.035)

	# Icono aparece con pulso de escala
	var icon_lbl = Label.new()
	icon_lbl.text = item_data["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 84)
	icon_lbl.modulate = Color(item_data["color"].r, item_data["color"].g, item_data["color"].b, 0.0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.position = Vector2(0, 50); icon_lbl.size = Vector2(600, 110)
	panel.add_child(icon_lbl)
	var it = create_tween()
	it.tween_property(icon_lbl, "modulate:a", 1.0, 0.5)
	await it.finished
	for _p in range(2):
		var p1 = create_tween()
		p1.tween_method(func(v): icon_lbl.add_theme_font_size_override("font_size", v), 84, 96, 0.18)
		await p1.finished
		var p2 = create_tween()
		p2.tween_method(func(v): icon_lbl.add_theme_font_size_override("font_size", v), 96, 84, 0.18)
		await p2.finished

	# Nombre del fragmento
	var name_lbl = Label.new()
	name_lbl.text = ""
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.modulate = Color(0.95, 0.85, 0.3)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 165); name_lbl.size = Vector2(600, 34)
	panel.add_child(name_lbl)
	await _typewrite(name_lbl, item_data["name"], 0.06)

	await get_tree().create_timer(0.3).timeout

	# Descripcion de la situacion
	var desc_lbl = Label.new()
	desc_lbl.text = ""
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.modulate = Color(0.7, 0.7, 0.75)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.position = Vector2(40, 210); desc_lbl.size = Vector2(520, 100)
	panel.add_child(desc_lbl)
	await _typewrite(desc_lbl, sit["text"], 0.028)

	# Botones aparecen solo cuando termina el texto
	var leave_btn = Button.new()
	leave_btn.text = "Retroceder"
	leave_btn.modulate = Color(1, 1, 1, 0.0)
	leave_btn.position = Vector2(80, 350); leave_btn.size = Vector2(210, 48)
	panel.add_child(leave_btn)

	var take_btn = Button.new()
	take_btn.text = sit["cost_label"]
	take_btn.modulate = Color(1.0, 0.4, 0.4, 0.0) if sit["type"] != "curse" else Color(0.8, 0.4, 1.0, 0.0)
	take_btn.position = Vector2(310, 350); take_btn.size = Vector2(210, 48)
	panel.add_child(take_btn)

	if already_have:
		take_btn.disabled = true; take_btn.text = "Ya lo posees"

	var bfade = create_tween()
	bfade.tween_property(leave_btn, "modulate:a", 1.0, 0.3)
	bfade.parallel().tween_property(take_btn, "modulate:a", 1.0, 0.3)
	await bfade.finished

	var state = {"picked": false}
	leave_btn.pressed.connect(func():
		if state["picked"]: return
		state["picked"] = true
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)

	take_btn.pressed.connect(func():
		if state["picked"]: return
		state["picked"] = true
		match sit["type"]:
			"blood": GameManager.player_hp = max(1, GameManager.player_hp * 0.8)
			"max_hp":
				GameManager.player_max_hp = max(10, GameManager.player_max_hp - 6)
				GameManager.player_hp = min(GameManager.player_hp, GameManager.player_max_hp)
			"curse":
				GameManager.add_card({"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true})
		GameManager.add_secret_item(item_id)
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)

func _show_deck_viewer() -> void:
	var vp = get_viewport_rect().size
	var overlay = ColorRect.new()
	overlay.size = vp; overlay.color = Color(0, 0, 0, 0.94); overlay.z_index = 200
	add_child(overlay)
	
	var title = Label.new()
	title.text = "TU COLECCION DE PIEZAS"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40); title.size = Vector2(vp.x, 50); overlay.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(100, 120); scroll.size = Vector2(vp.x - 200, vp.y - 250)
	overlay.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)
	
	var card_scene = preload("res://scenes/combat/Card.tscn")
	for c_data in GameManager.player_deck:
		var card = card_scene.instantiate()
		grid.add_child(card)
		card.setup(c_data)
		# En el visor las cartas no se juegan
		card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var close_btn = Button.new()
	close_btn.text = "CERRAR"
	close_btn.position = Vector2(vp.x/2 - 100, vp.y - 100); close_btn.size = Vector2(200, 50)
	overlay.add_child(close_btn)
	close_btn.pressed.connect(overlay.queue_free)
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("button_click")
