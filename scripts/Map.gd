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
const ROOM_TREASURE = "treasure"
const ROOM_VOID_COMBAT = "void_combat"
const ROOM_VOID_BOSS   = "void_boss"

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
	ROOM_TREASURE: Color(0.8, 0.6, 0.1),
	ROOM_VOID_COMBAT: Color(0.1, 0.4, 0.6),
	ROOM_VOID_BOSS: Color(0.2, 0.8, 1.0),
}

const ROOM_DESCRIPTIONS: Dictionary = {
	"combat":      ["⚔ ECO DE BATALLA",       "Un fragmento del pasado combate por sobrevivir."],
	"elite":       ["☠ PRESENCIA VORAZ",       "Una entidad corrompida. Recompensa mayor, riesgo letal."],
	"event":       ["♄ AUGURIO",               "El tablero te ofrece una elección. Nada es gratis."],
	"shop":        ["☤ EL BUHONERO",           "Monedas por poder. Reliquias, cartas, magia menor."],
	"boss":        ["★ JEFE DE MUNDO",         "El guardián del piso. Derrótalo para avanzar."],
	"rest":        ["🕯 HOGUERA DE CENIZA",    "Descansa, forja o sacrifica. Un momento de tregua."],
	"treasure":    ["📦 COFRE OLVIDADO",       "Algo brilla entre la ceniza. ¿Carta o reliquia?"],
	"void_combat": ["🌀 GRIETA DEL VACÍO",     "Camino secreto. Combate en el umbral del olvido."],
	"void_boss":   ["✦ CENTINELA DEL ABISMO", "El guardián del paso secreto. Alta recompensa."],
	"final":       ["♔ EL REY SIN CORONA",    "El final del primer tablero te aguarda."],
	"final_w2":    ["♔ EL REY AMARILLO",      "El trono vacío reclama su deuda."],
	"secret":      ["✦ FRAGMENTO DE REALIDAD","Una pieza que no debería existir aquí."],
}

const ROOM_LABELS = {
	ROOM_COMBAT:   "⚔ Eco de Batalla",
	ROOM_ELITE:    "☠ Presencia Voraz",
	ROOM_EVENT:    "♄ Augurio",
	ROOM_SHOP:     "☤ El Buhonero",
	ROOM_BOSS:     "★ JEFE DE MUNDO",
	ROOM_FINAL:    "♔ EL REY SIN CORONA",
	ROOM_FINAL_W2: "♔ EL REY AMARILLO",
	ROOM_SECRET:   "✦ Fragmento de Realidad",
	ROOM_REST:     "🕯 Hoguera de Ceniza",
	ROOM_TREASURE: "📦 Cofre Olvidado",
	ROOM_VOID_COMBAT: "🌀 Grieta del Vacío",
	ROOM_VOID_BOSS: "✦ Centinela del Abismo",
}

func _ready() -> void:
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Glith_distorsion_noised_sound")
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		AudioManager.stop_loop("intro_title_song")
		AudioManager.stop_loop("ES_Lost in Time - Aiyo")
		if GameManager.current_world == 1:
			# Mundo 2: piano atmosférico (misma pista que CharacterSelect)
			AudioManager.crossfade_loop("map_ambient_song", "ES_Lost in Time - Aiyo", 1.5)
		else:
			# Mundo 1: mapa oscuro habitual
			AudioManager.crossfade_loop("resting_song", "map_ambient_song", 1.5)
	if GameManager.map_graph.is_empty():
		GameManager.map_graph = _generate_map()
	# Guardar solo al volver de una sala completada (nunca al cargar partida guardada)
	if GameManager.came_from_room:
		if GameManager.current_map_col >= 0:
			GameManager.save_path_node(GameManager.current_map_floor - 1, GameManager.current_map_col)
		GameManager.save_run()
		GameManager.came_from_room = false
	modulate.a = 0.0
	build_ui()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

# ─── Generacion procedural del mapa ──────────────────────────────────────────
func _generate_map() -> Array:
	var graph: Array = []
	var num_floors = randi_range(15, 18)
	var is_w2 = GameManager.current_world == 1
	var final_room = ROOM_FINAL_W2 if is_w2 else ROOM_FINAL

	# 2 tiendas: una temprana (piso 4-6) y una en la zona media-tardía
	var s1 = randi_range(4, 6)
	var s2 = randi_range(int(num_floors * 0.52), num_floors - 5)
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
		
		# MEJORA: Penúltimo piso siempre con 2-3 Hogueras (Rest)
		if f == num_floors - 2:
			var n_rests = randi_range(2, 3)
			for i in range(n_rests):
				floor_nodes.append({"type": ROOM_REST, "connections": []})
			graph.append(floor_nodes)
			continue
			
		if f == num_floors - 3:
			floor_nodes.append({"type": ROOM_BOSS, "connections": []})
			floor_nodes.append({"type": ROOM_TREASURE if randf() < 0.5 else ROOM_ELITE, "connections": []})
			if randf() < 0.5:
				floor_nodes.append({"type": ROOM_EVENT, "connections": []})
			if randf() < 0.3:
				floor_nodes.append({"type": ROOM_REST, "connections": []})
			graph.append(floor_nodes)
			continue
		if f == num_floors - 4:
			# Otro descanso antes del tramo final
			floor_nodes.append({"type": ROOM_REST, "connections": []})
			graph.append(floor_nodes)
			continue
		if f in shop_floors:
			floor_nodes.append({"type": ROOM_SHOP, "connections": []})
			# Siempre un nodo bypass: el buhonero es perdible por diseño
			floor_nodes.append({"type": ROOM_COMBAT if randf() < 0.6 else ROOM_EVENT, "connections": []})
			graph.append(floor_nodes)
			continue

		# Pisos normales: 1-4 nodos
		var num_cols = randi_range(1, 4)
		if f == 0:
			num_cols = randi_range(2, 4)  # Inicio: siempre 2-4 caminos

		var prev_type = ""
		for c in range(num_cols):
			var t = _pick_room_type(f, num_floors, prev_type)
			prev_type = t
			var node_data = {"type": t, "connections": [], "has_rift": false}
			
			# Probabilidad de generar una GRIETA (Camino secreto lateral)
			var has_relics = GameManager.relics.size() > 0
			# La grieta aparece 2 pisos por delante de donde se descubre
			var is_target_floor = (f == GameManager.current_map_floor + 2)
			if not GameManager.rift_visited and is_target_floor and c == num_cols - 1:
				if randf() < 0.25 and GameManager.lore_progress >= 25 and has_relics:
					node_data["has_rift"] = true
					
			floor_nodes.append(node_data)

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
	# Primer piso: solo combate/evento (intro suave)
	if f_idx == 0:
		return ROOM_COMBAT if randf() < 0.7 else ROOM_EVENT

	# Progresión normalizada 0.0–1.0 sobre los pisos jugables
	var progress = float(f_idx) / float(total - 1)
	var roll = randf()
	var t: String

	if progress < 0.30:
		# ── Zona temprana (30%) — aprender combate, poca elite ──
		# Combat 55% | Event 25% | Elite 12% | Treasure 8%
		if roll < 0.55:        t = ROOM_COMBAT
		elif roll < 0.80:      t = ROOM_EVENT
		elif roll < 0.92:      t = ROOM_ELITE
		else:                  t = ROOM_TREASURE

	elif progress < 0.62:
		# ── Zona media (32%) — elites frecuentes, alto riesgo/recompensa ──
		# Elite 38% | Event 28% | Combat 22% | Treasure 12%
		if roll < 0.38:        t = ROOM_ELITE
		elif roll < 0.66:      t = ROOM_EVENT
		elif roll < 0.88:      t = ROOM_COMBAT
		else:                  t = ROOM_TREASURE

	else:
		# ── Zona tardía (38%) — presión máxima, descanso esporádico ──
		# Elite 42% | Event 28% | Combat 18% | Treasure 8% | Rest 4%
		if roll < 0.42:        t = ROOM_ELITE
		elif roll < 0.70:      t = ROOM_EVENT
		elif roll < 0.88:      t = ROOM_COMBAT
		elif roll < 0.96:      t = ROOM_TREASURE
		else:                  t = ROOM_REST  # Descanso raro pero posible

	# Nunca dos elites adyacentes en el mismo piso
	if t == ROOM_ELITE and prev_type == ROOM_ELITE:
		t = ROOM_COMBAT
	return t

func _connect_floors(graph: Array, f: int) -> void:
	var curr: Array = graph[f]
	var nxt: Array  = graph[f + 1]
	var cn: int = curr.size()
	var nn: int = nxt.size()

	# Grid virtual de MAX_COLS columnas para comparar pisos con distinto num de nodos.
	# Ejemplo: 2 nodos → posiciones [0, 3]; 4 nodos → [0, 1, 2, 3]
	# Así col 0 (de 2) solo puede tocar col 0-1 (de 4), nunca col 3 cruzando el mapa.
	const MAX_COLS = 4
	const ADJ_DIST = 1.5  # máxima distancia virtual entre columnas conectables

	var vpos_c: Array = []  # posición virtual de cada nodo en curr
	for c in range(cn):
		vpos_c.append(float(c) * float(MAX_COLS - 1) / float(max(cn - 1, 1)))

	var vpos_n: Array = []  # posición virtual de cada nodo en nxt
	for nc in range(nn):
		vpos_n.append(float(nc) * float(MAX_COLS - 1) / float(max(nn - 1, 1)))

	# Paso 1: cada curr[c] → el nxt más cercano en posición virtual
	for c in range(cn):
		var best_nc = 0
		var best_dist = 9999.0
		for nc in range(nn):
			var d = abs(vpos_c[c] - vpos_n[nc])
			if d < best_dist:
				best_dist = d
				best_nc = nc
		if not best_nc in curr[c].connections:
			curr[c].connections.append(best_nc)

	# Paso 2: todo nxt[nc] tiene al menos 1 entrada desde su vecino virtual más cercano
	for nc in range(nn):
		var has_entry = false
		for c in range(cn):
			if nc in curr[c].connections:
				has_entry = true
				break
		if not has_entry:
			var best_c = 0
			var best_dist = 9999.0
			for c in range(cn):
				var d = abs(vpos_c[c] - vpos_n[nc])
				if d < best_dist:
					best_dist = d
					best_c = c
			if not nc in curr[best_c].connections:
				curr[best_c].connections.append(nc)

	# Paso 3: bonus connection (35%) SOLO a nodos dentro de ADJ_DIST — sin cruces
	for c in range(cn):
		if curr[c].connections.size() < 2 and randf() < 0.35:
			var candidates: Array = []
			for nc in range(nn):
				if nc in curr[c].connections: continue
				if abs(vpos_c[c] - vpos_n[nc]) <= ADJ_DIST:
					candidates.append(nc)
			candidates.shuffle()
			if not candidates.is_empty():
				curr[c].connections.append(candidates[0])

# ─── UI ──────────────────────────────────────────────────────────────────────
var ui_layer: CanvasLayer
var lbl_info: Label
var dev_panel: Panel

func build_ui() -> void:
	var vp = get_viewport_rect().size

	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08)
	bg.position = Vector2.ZERO
	bg.size = vp
	bg.z_index = -100 # Muy al fondo
	add_child(bg)

	# Capa superior para que el HUD no haga scroll y los tooltips funcionen
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var world_name = "Mundo II — El Tablero Dorado" if GameManager.current_world == 1 else "Mundo I — La Caida del Rey"

	var title = Label.new()
	title.text = "Elige tu camino"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(vp.x, 34)
	ui_layer.add_child(title)

	var world_lbl = Label.new()
	world_lbl.text = world_name
	world_lbl.add_theme_font_size_override("font_size", 12)
	world_lbl.modulate = Color(0.95, 0.8, 0.1) if GameManager.current_world == 1 else Color(0.6, 0.7, 0.9)
	world_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_lbl.position = Vector2(0, 38)
	world_lbl.size = Vector2(vp.x, 20)
	ui_layer.add_child(world_lbl)

	var graph = GameManager.map_graph
	lbl_info = Label.new()
	update_ui()
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info.position = Vector2(0, 56)
	lbl_info.size = Vector2(vp.x, 24)
	ui_layer.add_child(lbl_info)

	# Boton DEV
	var dev_toggle = Button.new()
	dev_toggle.text = "[DEV]"
	dev_toggle.position = Vector2(10, 10); dev_toggle.size = Vector2(60, 30)
	dev_toggle.add_theme_font_size_override("font_size", 10)
	ui_layer.add_child(dev_toggle)
	
	dev_panel = _build_dev_panel(vp)
	dev_panel.visible = false
	ui_layer.add_child(dev_panel)
	dev_toggle.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)

	# Reliquias activas
	if not GameManager.relics.is_empty():
		var relic_label = Label.new()
		relic_label.text = "Reliquias:"
		relic_label.add_theme_font_size_override("font_size", 11)
		relic_label.modulate = Color(0.8, 0.7, 0.4)
		relic_label.position = Vector2(6, 82)
		ui_layer.add_child(relic_label)

		var relic_scene = preload("res://scenes/ui/RelicIcon.tscn")
		for i in range(GameManager.relics.size()):
			var icon = relic_scene.instantiate()
			icon.position = Vector2(6 + i * 48, 96)
			ui_layer.add_child(icon)
			icon.setup(GameManager.relics[i])

	# Boton Visor de Mazo
	var deck_btn = Button.new()
	deck_btn.text = " ▣ VER MAZO "
	deck_btn.position = Vector2(vp.x - 160, 10); deck_btn.size = Vector2(150, 40)
	deck_btn.add_theme_font_size_override("font_size", 14)
	ui_layer.add_child(deck_btn)
	deck_btn.pressed.connect(func(): GameManager.show_deck_overlay(self))

	# Boton Códice
	var codex_btn = Button.new()
	codex_btn.text = "📜 CÓDICE"
	codex_btn.position = Vector2(vp.x - 320, 10); codex_btn.size = Vector2(150, 40)
	codex_btn.add_theme_font_size_override("font_size", 14)
	ui_layer.add_child(codex_btn)
	codex_btn.pressed.connect(func(): GameManager.show_codex_overlay(self))

	# Indicador de objetos misteriosos
	if GameManager.secret_items.size() > 0 or _map_has_secret_rooms():
		var si_container = Panel.new()
		var count = GameManager.secret_items.size()
		si_container.position = Vector2(vp.x - 100, 56)
		si_container.size = Vector2(90, 30)
		var s_style = StyleBoxFlat.new()
		s_style.bg_color = Color(0,0,0,0)
		si_container.add_theme_stylebox_override("panel", s_style)
		ui_layer.add_child(si_container)

		var si_lbl = Label.new()
		si_lbl.text = "✦ " + str(count) + " / 3"
		si_lbl.add_theme_font_size_override("font_size", 14)
		si_lbl.modulate = Color(0.85, 0.72, 0.1) if count > 0 else Color(0.45, 0.42, 0.15)
		si_lbl.size = si_container.size
		si_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		si_container.add_child(si_lbl)

		# Tooltip logic
		si_container.mouse_entered.connect(func(): _show_secret_items_tooltip(si_container))
		si_container.mouse_exited.connect(_hide_secret_items_tooltip)

	draw_map()

var _si_tooltip: Panel
var _tooltip_label: Label = null

func _show_secret_items_tooltip(target: Control) -> void:
	if _si_tooltip: _si_tooltip.queue_free()
	
	_si_tooltip = Panel.new()
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.04, 0.02, 0.95)
	ts.border_width_left = 2; ts.border_color = Color(0.8, 0.7, 0.2)
	ts.set_corner_radius_all(4)
	_si_tooltip.add_theme_stylebox_override("panel", ts)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	_si_tooltip.add_child(vbox)
	
	var title = Label.new()
	title.text = "FRAGMENTOS DE REALIDAD"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.9, 0.8, 0.3)
	vbox.add_child(title)
	
	if GameManager.secret_items.is_empty():
		var empty = Label.new()
		empty.text = "No has recolectado fragmentos aún."
		empty.add_theme_font_size_override("font_size", 11)
		vbox.add_child(empty)
	else:
		for item_id in GameManager.secret_items:
			var data = GameManager.SECRET_ITEM_DATA[item_id]
			var il = Label.new()
			il.text = "• " + data["name"]
			il.add_theme_font_size_override("font_size", 12)
			il.modulate = data["color"]
			vbox.add_child(il)
			
			var dl = Label.new()
			dl.text = data["desc"]
			dl.add_theme_font_size_override("font_size", 10)
			dl.modulate = Color(0.7, 0.7, 0.7)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD
			dl.custom_minimum_size.x = 200
			vbox.add_child(dl)
	
	_si_tooltip.size = Vector2(220, vbox.get_child_count() * 35 + 20)
	_si_tooltip.position = target.global_position + Vector2(-230, 0)
	add_child(_si_tooltip)
	
	_si_tooltip.modulate.a = 0
	create_tween().tween_property(_si_tooltip, "modulate:a", 1.0, 0.2)

func _hide_secret_items_tooltip() -> void:
	if _si_tooltip:
		_si_tooltip.queue_free()
		_si_tooltip = null

func draw_map() -> void:
	_build_tooltip_label()
	var vp = get_viewport_rect().size
	var graph = GameManager.map_graph
	var num_floors = graph.size()

	# --- SCROLL CONTAINER ---
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 85) # Debajo del header
	scroll.size = Vector2(vp.x, vp.y - 85)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	
	var map_content = Control.new()
	var floor_h: float = 170.0
	var total_h: float = num_floors * floor_h + 120.0
	map_content.custom_minimum_size = Vector2(vp.x, total_h)
	scroll.add_child(map_content)

	# --- ELEMENTOS DECORATIVOS DE FONDO ---
	_add_map_decorations(map_content, total_h, vp.x)

	var map_w: float    = vp.x * 0.85
	var map_start_x: float = (vp.x - map_w) / 2.0
	var map_start_y: float = total_h - 100.0

	# Pre-calcular posiciones X de cada nodo
	var positions: Array = []   # positions[f][c] = Vector2
	for f in range(num_floors):
		var floor_nodes: Array = graph[f]
		var nc = floor_nodes.size()
		var row_pos: Array = []
		for c in range(nc):
			# Variación lateral aleatoria para que no sea una rejilla perfecta
			var jitter = randf_range(-15, 15)
			var x = map_start_x + (map_w / (nc + 1)) * (c + 1) + jitter
			var y = map_start_y - f * floor_h
			row_pos.append(Vector2(x, y))
		positions.append(row_pos)

	# Dibujar lineas de conexion (Abismo entre nodos)
	for f in range(num_floors - 1):
		var floor_nodes: Array = graph[f]
		for c in range(floor_nodes.size()):
			for nc in floor_nodes[c].connections:
				var p0 = positions[f][c]
				var p1 = positions[f + 1][nc]
				
				# Una linea es del camino recorrido si ambos nodos están en map_path
				var is_taken_path = false
				if GameManager.map_path.has(f) and GameManager.map_path.has(f+1):
					if int(GameManager.map_path[f]) == c and int(GameManager.map_path[f+1]) == nc:
						is_taken_path = true

				# Una linea es reachable si sale del nodo actual del jugador
				var is_player_node = (f == GameManager.current_map_floor - 1 and c == GameManager.current_map_col)
				if f == 0 and GameManager.current_map_col == -1: is_player_node = true
				if GameManager.current_map_col == -1 and f < GameManager.current_map_floor: # Salida de grieta
					if GameManager.map_path.get(f) == c: is_player_node = true

				var reachable = is_player_node and _is_node_reachable(f + 1, nc)

				var line_node = Line2D.new()
				line_node.add_point(p0)
				line_node.add_point(p1)

				if is_taken_path:
					line_node.width = 4.0
					line_node.default_color = Color(0.95, 0.82, 0.2, 0.95)
					line_node.z_index = -5
					map_content.add_child(line_node)
				elif reachable:
					_add_dashed_line(map_content, p0, p1, Color(0.85, 0.75, 0.25, 0.75), 3.0)
				else:
					line_node.width = 1.2
					line_node.default_color = Color(0.28, 0.28, 0.38, 0.18)
					line_node.z_index = -10
					map_content.add_child(line_node)

	# Dibujar nodos
	for f in range(num_floors):
		var floor_nodes: Array = graph[f]
		for c in range(floor_nodes.size()):
			var room_type = floor_nodes[c].type
			var pos = positions[f][c]
			var reachable = _is_node_reachable(f, c)
			var already_done = f < GameManager.current_map_floor
			var is_current = (f == GameManager.current_map_floor - 1 and c == GameManager.current_map_col)
			if f == 0 and GameManager.current_map_col == -1: is_current = false
			
			var was_visited = GameManager.map_path.get(f) == c

			# Lógica de Desorientación por Locura (MÁXIMA)
			# Si cordura < 40, TODO lo que no sea el nodo actual o el pasado se vuelve un misterio
			var is_obfuscated = GameManager.sanity < 40 and not is_current and not was_visited and not already_done
			# Los jefes solo se revelan si estás cerca o tienes cordura
			if is_obfuscated and (room_type == ROOM_BOSS or room_type == ROOM_FINAL or room_type == ROOM_FINAL_W2):
				if f > GameManager.current_map_floor + 1: # Si faltan más de 2 pisos, ocultar incluso al jefe
					is_obfuscated = true
				else:
					is_obfuscated = false # Revelar jefe cuando estás a punto de llegar
			
			var btn = Button.new()
			btn.text = "??? (¿...)" if is_obfuscated else ROOM_LABELS[room_type]
			btn.position = Vector2(pos.x - 52, pos.y - 20)
			btn.size = Vector2(104, 40)
			btn.disabled = not reachable or already_done
			btn.add_theme_font_size_override("font_size", 11)

			var style = StyleBoxFlat.new()
			style.set_corner_radius_all(6)
			style.content_margin_left = 4
			style.content_margin_right = 4

			if is_current:
				style.bg_color = ROOM_COLORS[room_type].lightened(0.15)
				style.set_border_width_all(2)
				style.border_color = Color(1.0, 0.92, 0.35)
				style.shadow_color = Color(1.0, 0.92, 0.35, 0.35)
				style.shadow_size = 5
				btn.text = "● " + btn.text + " ●"
				var tw = btn.create_tween().set_loops()
				tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.55)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.55)
			elif was_visited:
				style.bg_color = Color(0.08, 0.06, 0.02, 0.9)
				style.set_border_width_all(1)
				style.border_color = Color(0.85, 0.75, 0.2, 0.7)
				btn.modulate.a = 0.75
			elif already_done:
				style.bg_color = Color(0.02, 0.02, 0.04, 0.5)
				style.set_border_width_all(0)
				btn.modulate.a = 0.35
			else:
				if is_obfuscated:
					style.bg_color = Color(0.05, 0.05, 0.07)
					style.set_border_width_all(1)
					style.border_color = Color(0.25, 0.25, 0.3, 0.4)
					btn.modulate.a = 0.5
					if GameManager.sanity < 25:
						_start_shaking_node(btn)
				else:
					var base_col = ROOM_COLORS[room_type]
					style.bg_color = base_col.darkened(0.25)
					style.set_border_width_all(2)
					if reachable:
						style.border_color = base_col.lightened(0.3)
						style.shadow_color = base_col
						style.shadow_size = 4
						btn.modulate.a = 1.0
					else:
						style.border_color = base_col.darkened(0.1)
						style.set_border_width_all(1)
						btn.modulate.a = 0.65
				if reachable:
					_add_dashed_rect(btn, Color(1, 1, 1, 0.6), 1.5)

			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("disabled", style)

			var fi = f
			var ci = c
			var node_data = graph[f][c] # Declarar node_data aquí
			btn.pressed.connect(func(): _on_room_selected(fi, ci))
			map_content.add_child(btn)

			# Tooltip hover (solo nodos futuros alcanzables y no ofuscados)
			if not is_obfuscated and (is_current or reachable):
				var tip_type = node_data["type"]
				btn.mouse_entered.connect(func(): _show_tooltip(tip_type, btn.get_global_rect()))
				btn.mouse_exited.connect(func(): _hide_tooltip())

			if reachable and not already_done:
				btn.mouse_entered.connect(func():
					if not btn.disabled:
						btn.create_tween().tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12)
				)
				btn.mouse_exited.connect(func():
					btn.create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
				)

			# RENDERIZAR GRIETA (Camino Secreto de 4 salas)
			if node_data.get("has_rift", false):

					var rift_pos = Vector2(pos.x + 140, pos.y)
					var rift_btn = Button.new()
					rift_btn.text = "✦ GRIETA"
					rift_btn.size = Vector2(100, 40)
					rift_btn.position = rift_pos - Vector2(50, 20)
					rift_btn.add_theme_font_size_override("font_size", 10)
					var rs = StyleBoxFlat.new(); rs.bg_color = Color(0.05, 0.2, 0.3); rs.set_border_width_all(2); rs.border_color = Color(0.2, 0.8, 1.0)
					rift_btn.add_theme_stylebox_override("normal", rs)
					map_content.add_child(rift_btn)
					_add_glow_effect(rift_btn, Color(0.2, 0.6, 1.0))

					# Dibujar linea de conexion a la grieta
					var l = Line2D.new()
					l.add_point(pos)
					l.add_point(rift_pos)
					l.width = 2.0
					l.default_color = Color(0.2, 0.8, 1.0, 0.4)
					l.z_index = -1
					map_content.add_child(l)

					rift_btn.disabled = not reachable or already_done
					rift_btn.pressed.connect(func():
						_show_rift_confirmation()
					)

	# Auto-scroll al piso actual
	await get_tree().process_frame
	var scroll_target = total_h - (GameManager.current_map_floor * floor_h) - (vp.y / 2.0)
	scroll.set_v_scroll(clamp(scroll_target, 0, total_h))
	
	_start_void_mist(ui_layer, vp) # Capa de niebla sobre el mapa
	
	# EVENTO: Descubrimiento de Grieta
	_check_rift_discovery_event(vp)

func _check_rift_discovery_event(vp: Vector2) -> void:
	if GameManager.rift_notified or GameManager.rift_visited: return
	
	# Verificar condiciones (Misma lógica que el generador)
	var has_relics = GameManager.relics.size() > 0
	if GameManager.lore_progress >= 25 and has_relics:
		GameManager.rift_notified = true
		
		# 1. Esperar un momento tras cargar
		await get_tree().create_timer(0.8).timeout
		
		# 2. Sonido de derrumbe profundo (usando defeat ralentizado)
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("defeat")
			# Bajamos el tono para que suene a terremoto/escombros
			# Nota: el AudioManager usará el pitch_scale si lo permitimos
		
		# 3. Temblor de pantalla VIOLENTO
		var tw = create_tween().set_parallel(false)
		for i in range(20):
			var intensity = 15 - i * 0.5 # Empieza fuerte, baja poco a poco
			var off = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tw.tween_property(self, "position", off, 0.04)
		tw.tween_property(self, "position", Vector2.ZERO, 0.1)
		
		# 4. Pensamiento del personaje (Personalizado)
		await get_tree().create_timer(0.5).timeout
		var char_id = GameManager.selected_character
		var char_col = Color(0.8, 0.8, 0.8)
		var msg = ""

		match char_id:
			"conquistador":
				char_col = Color(0.9, 0.4, 0.4)
				msg = "[CONQUISTADOR]: Un estruendo... el tablero se quiebra ante mi paso. ¿Acaso el Vacío intenta desafiarme?"
			"estratega":
				char_col = Color(0.4, 0.6, 1.0)
				msg = "[ESTRATEGA]: Interesante... la estática ha fracturado la geometría del mapa. Se ha abierto una anomalía."
			"guardian":
				char_col = Color(0.4, 0.9, 0.4)
				msg = "[GUARDIÁN]: He escuchado un derrumbe. El tablero ya no es seguro... algo antiguo está emergiendo."
			"prince":
				char_col = Color(0.7, 0.4, 1.0)
				msg = "[PRÍNCIPE]: Esa vibración... conozco este pulso. Es el aliento de Carcosa filtrándose por una grieta."
			_:
				msg = "[HÉROE]: He escuchado un estruendo... juraría que el tablero se ha fracturado en alguna parte."

		_show_map_thought(msg, char_col, vp)


func _show_map_thought(text: String, col: Color, vp: Vector2) -> void:
	# Contenedor con fondo
	var panel = Panel.new()
	panel.size = Vector2(600, 80)
	panel.position = Vector2(vp.x/2 - 300, vp.y - 140)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.02, 0.04, 0.85) # Fondo oscuro
	s.set_border_width_all(2); s.border_color = col; s.border_color.a = 0.5
	s.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", s)
	panel.modulate.a = 0
	ui_layer.add_child(panel)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size = panel.size - Vector2(40, 20)
	lbl.position = Vector2(20, 10)
	lbl.modulate = col
	panel.add_child(lbl)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw.tween_property(panel, "position:y", panel.position.y - 20, 0.5)
	
	await get_tree().create_timer(4.5).timeout
	
	var tw2 = create_tween().set_parallel(true)
	tw2.tween_property(panel, "modulate:a", 0.0, 1.0)
	tw2.tween_property(panel, "position:y", panel.position.y - 20, 1.0)
	await tw2.finished
	panel.queue_free()

func _show_rift_confirmation() -> void:
	var vp = get_viewport_rect().size
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9); overlay.size = vp; overlay.z_index = 500
	ui_layer.add_child(overlay)
	
	var panel = Panel.new()
	panel.size = Vector2(500, 300); panel.position = (vp - panel.size) / 2
	var s = StyleBoxFlat.new(); s.bg_color = Color(0.05, 0.08, 0.1); s.set_border_width_all(2); s.border_color = Color(0.2, 0.7, 1.0)
	panel.add_theme_stylebox_override("panel", s)
	overlay.add_child(panel)
	
	var title = Label.new(); title.text = "✦ LA GRIETA ABISAL ✦"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30); title.size = Vector2(500, 40); title.modulate = Color(0.4, 0.9, 1.0)
	panel.add_child(title)
	
	var desc = Label.new()
	desc.text = "Este camino no pertenece a este mundo. Las piezas que entren aquí podrían no regresar jamás. El aire vibra con estática y peligro.\n\n¿Deseas adentrarte en el Vacío?"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD; desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.position = Vector2(40, 80); desc.size = Vector2(420, 120); desc.add_theme_font_size_override("font_size", 14)
	panel.add_child(desc)
	
	var btn_enter = Button.new(); btn_enter.text = "ADENTRARSE"; btn_enter.size = Vector2(180, 45)
	btn_enter.position = Vector2(50, 220); panel.add_child(btn_enter)
	btn_enter.pressed.connect(func(): GameManager.enter_void_path())
	
	var btn_leave = Button.new(); btn_leave.text = "MARCHARSE"; btn_leave.size = Vector2(180, 45)
	btn_leave.position = Vector2(270, 220); panel.add_child(btn_leave)
	btn_leave.pressed.connect(overlay.queue_free)

func update_ui() -> void:
	if not lbl_info: return
	var graph = GameManager.map_graph
	lbl_info.text = "HP: %d/%d   " % [GameManager.player_hp, GameManager.player_max_hp]
	lbl_info.text += "%s: %d/%d   " % [GameManager.get_sanity_label(), GameManager.sanity, GameManager.max_sanity]
	lbl_info.text += "📖 LORE: %d   " % GameManager.lore_progress
	lbl_info.text += "◈: %d   " % GameManager.coins
	lbl_info.text += "Piso: %d/%d" % [GameManager.current_map_floor + 1, graph.size()]

func _build_dev_panel(vp: Vector2) -> Panel:
	var p = Panel.new()
	p.position = Vector2(20, 50)
	p.size = Vector2(200, 430)
	p.z_index = 100
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	st.set_border_width_all(2)
	st.border_color = Color(0.5, 0.5, 0.5)
	p.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	p.add_child(vbox)
	
	var btns = [
		["+100 Oro", func(): GameManager.add_coins(100); update_ui()],
		["-20 Cordura", func(): GameManager.sanity = max(0, GameManager.sanity - 20); update_ui()],
		["+20 Cordura", func(): GameManager.sanity = min(100, GameManager.sanity + 20); update_ui()],
		["Curar Todo", func(): GameManager.player_hp = GameManager.player_max_hp; update_ui()],
		["Ir a Tesoro", func(): GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")],
		["Ir a Tienda", func(): GameManager.go_to_scene("res://scenes/ui/Shop.tscn")],
		["GRIETA MUNDO I", func(): 
			GameManager.current_world = 0
			GameManager.enter_void_path()],
		["GRIETA MUNDO II", func(): 
			GameManager.current_world = 1
			GameManager.enter_void_path()],
		["TEST: EVENTO GRIETA", func():
			GameManager.add_relic("ficha_marfil")
			GameManager.lore_progress = 25
			GameManager.rift_notified = false
			# Forzar que el piso actual + 2 tenga una grieta
			var target_f = clamp(GameManager.current_map_floor + 2, 0, GameManager.map_graph.size() - 1)
			var target_floor_nodes = GameManager.map_graph[target_f]
			target_floor_nodes[target_floor_nodes.size()-1]["has_rift"] = true
			get_tree().reload_current_scene()],
		["Reset Mapa", func(): GameManager.map_graph = []; get_tree().reload_current_scene()],
		["⟁ Frag: Símbolo", func():
			if not GameManager.has_secret_item("simbolo_amarillo"):
				GameManager.add_secret_item("simbolo_amarillo")],
		["♪ Frag: Canción", func():
			if not GameManager.has_secret_item("cancion_amarilla"):
				GameManager.add_secret_item("cancion_amarilla")],
		["✉ Frag: Carcosa", func():
			if not GameManager.has_secret_item("carta_carcosa"):
				GameManager.add_secret_item("carta_carcosa")],
		["⚔ REY AMARILLO", func():
			GameManager.is_final_boss = true
			GameManager.current_world = 1
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")],
	]
	
	for b_data in btns:
		var b = Button.new()
		b.text = b_data[0]
		b.pressed.connect(b_data[1])
		vbox.add_child(b)
		
	return p

func _add_glow_effect(target: Control, col: Color) -> void:
	var g = ColorRect.new()
	g.size = target.size + Vector2(10, 10)
	g.position = Vector2(-5, -5)
	g.color = col
	g.color.a = 0.3
	g.show_behind_parent = true
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(g)
	
	var tw = g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.6, 1.0)
	tw.tween_property(g, "modulate:a", 0.1, 1.0)

func _start_shaking_node(node: Control) -> void:
	var base_pos = node.position
	var tw = node.create_tween().set_loops()
	tw.tween_callback(func():
		var offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		node.position = base_pos + offset
	)
	tw.tween_interval(0.05)

func _start_void_mist(container: Node, vp: Vector2) -> void:
	if GameManager.sanity > 50: return
	
	var intensity = clamp((50.0 - GameManager.sanity) / 50.0, 0.0, 1.0)
	var count = int(35 * intensity) # Un poco más de densidad
	
	for i in range(count):
		var mist = ColorRect.new()
		mist.size = Vector2(randf_range(150, 400), randf_range(150, 400))
		# Usar un color púrpura/negro muy oscuro
		mist.color = Color(0.02, 0.0, 0.03, 0.0) 
		mist.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		mist.mouse_filter = Control.MOUSE_FILTER_IGNORE # ¡CRÍTICO: No bloquear clics!
		container.add_child(mist)
		
		# Animación de deriva y pulsación
		var tw = mist.create_tween().set_loops()
		var next_pos = mist.position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		var dur = randf_range(5.0, 10.0)
		
		tw.parallel().tween_property(mist, "position", next_pos, dur).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(mist, "modulate:a", 0.4 * intensity, dur/2.0)
		tw.chain().tween_property(mist, "modulate:a", 0.1 * intensity, dur/2.0)

func _add_dashed_line(container: Control, p0: Vector2, p1: Vector2, color: Color, width: float) -> void:
	var dist = p0.distance_to(p1)
	var dir = (p1 - p0).normalized()
	var dash_len = 6.0
	var gap_len = 4.0
	var current_dist = 0.0
	
	while current_dist < dist:
		var segment_end = min(current_dist + dash_len, dist)
		var line = Line2D.new()
		line.add_point(p0 + dir * current_dist)
		line.add_point(p0 + dir * segment_end)
		line.width = width
		line.default_color = color
		container.add_child(line)
		current_dist += dash_len + gap_len

func _add_dashed_rect(btn: Button, color: Color, width: float) -> void:
	var sz = btn.size
	var points = [
		Vector2(0,0), Vector2(sz.x, 0),
		Vector2(sz.x, 0), Vector2(sz.x, sz.y),
		Vector2(sz.x, sz.y), Vector2(0, sz.y),
		Vector2(0, sz.y), Vector2(0, 0)
	]
	
	var container = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container)
	
	for i in range(0, points.size(), 2):
		_add_dashed_line(container, points[i], points[i+1], color, width)
	
	# Efecto de animacion para el borde punteado
	var tw = container.create_tween().set_loops()
	tw.tween_property(container, "modulate:a", 0.3, 0.8)
	tw.tween_property(container, "modulate:a", 1.0, 0.8)

func _add_map_decorations(container: Control, total_h: float, vp_x: float) -> void:
	var is_w2 = GameManager.current_world == 1
	var decor_color = Color(0.9, 0.7, 0.1, 0.05) if is_w2 else Color(0.4, 0.4, 0.6, 0.05)
	
	# Ojos del Vacio esporadicos
	for i in range(15):
		var eye = Label.new()
		eye.text = "⦿"
		eye.add_theme_font_size_override("font_size", randi_range(20, 60))
		eye.modulate = decor_color
		eye.position = Vector2(randf_range(0, vp_x), randf_range(100, total_h - 100))
		container.add_child(eye)
		
		# Animacion de parpadeo muy lenta
		var tw = eye.create_tween().set_loops()
		tw.tween_property(eye, "modulate:a", 0.15, randf_range(2.0, 5.0))
		tw.tween_property(eye, "modulate:a", 0.02, randf_range(2.0, 5.0))

	# Runas y susurros visuales
	var runes = ["᚛", "ᚙ", " Holden", " King", " Yellow", "⟁", "⌬"]
	for i in range(30):
		var r = Label.new()
		r.text = runes[randi() % runes.size()]
		r.add_theme_font_size_override("font_size", 14)
		r.modulate = decor_color
		r.position = Vector2(randf_range(0, vp_x), randf_range(0, total_h))
		r.rotation = randf_range(-0.5, 0.5)
		container.add_child(r)

	# Particulas de ceniza (estaticas pero muchas)
	for i in range(100):
		var p = ColorRect.new()
		p.size = Vector2(2, 2)
		p.color = decor_color
		p.position = Vector2(randf_range(0, vp_x), randf_range(0, total_h))
		container.add_child(p)

# ─── Logica de rutas ─────────────────────────────────────────────────────────
func _is_node_reachable(floor_idx: int, col_idx: int) -> bool:
	# Solo el piso inmediatamente siguiente al actual es elegible
	if floor_idx != GameManager.current_map_floor:
		return false

	# Caso 1: Inicio del juego o salida de grieta (col_idx -1)
	# Todo el piso actual es elegible
	if GameManager.current_map_col < 0:
		return true

	# Caso 2: Navegación normal
	# Buscar si este nodo (floor_idx, col_idx) está conectado desde nuestra posición actual
	var prev_floor_idx = floor_idx - 1
	var prev_col = GameManager.current_map_col
	var graph = GameManager.map_graph

	if prev_floor_idx >= 0 and prev_floor_idx < graph.size():
		var p_nodes = graph[prev_floor_idx]
		if prev_col >= 0 and prev_col < p_nodes.size():
			var connections = p_nodes[prev_col].get("connections", [])
			return col_idx in connections

	return false

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

	# Resetear todos los flags antes de setear el correcto
	GameManager.is_boss_fight  = false
	GameManager.is_elite_fight = false
	GameManager.is_final_boss  = false
	GameManager.is_hastur_fight = false

	# Avanzar el piso para que al volver al mapa se muestren los nodos correctos
	GameManager.current_map_floor = floor_idx + 1
	GameManager.current_map_col   = col_idx

	# Marcar que venimos de una sala: Map._ready() guardará al regresar
	GameManager.came_from_room = true
	match room_type:
		ROOM_COMBAT:
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
		ROOM_ELITE:
			GameManager.is_elite_fight = true
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
		ROOM_EVENT:
			GameManager.go_to_scene("res://scenes/ui/Event.tscn")
		ROOM_SHOP:
			GameManager.go_to_scene("res://scenes/ui/Shop.tscn")
		ROOM_REST:
			GameManager.go_to_scene("res://scenes/ui/Rest.tscn")
		ROOM_TREASURE:
			GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")
		ROOM_BOSS:
			GameManager.is_boss_fight = true
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
		ROOM_FINAL, ROOM_FINAL_W2:
			GameManager.is_final_boss = true
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
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
		GameManager.go_to_scene("res://scenes/ui/Map.tscn")
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
		GameManager.go_to_scene("res://scenes/ui/Map.tscn")
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
		GameManager.go_to_scene("res://scenes/ui/Map.tscn")
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

func _build_tooltip_label() -> void:
	if _tooltip_label:
		_tooltip_label.queue_free()
	_tooltip_label = Label.new()
	_tooltip_label.z_index = 200
	_tooltip_label.visible = false
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.05, 0.04, 0.08, 0.95)
	sbox.set_border_width_all(1)
	sbox.border_color = Color(0.4, 0.35, 0.15)
	sbox.set_corner_radius_all(5)
	sbox.content_margin_left = 10
	sbox.content_margin_right = 10
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	_tooltip_label.add_theme_stylebox_override("normal", sbox)
	add_child(_tooltip_label)

func _show_tooltip(room_type: String, btn_rect: Rect2) -> void:
	if not _tooltip_label or not ROOM_DESCRIPTIONS.has(room_type):
		return
	var desc = ROOM_DESCRIPTIONS[room_type]
	_tooltip_label.text = desc[0] + "\n" + desc[1]
	_tooltip_label.size = Vector2(240, 0)
	_tooltip_label.visible = true
	# Posicionar a la derecha del nodo, ajustar si sale de pantalla
	var vp = get_viewport_rect().size
	var tx = btn_rect.position.x + btn_rect.size.x + 8
	if tx + 240 > vp.x:
		tx = btn_rect.position.x - 248
	_tooltip_label.position = Vector2(tx, btn_rect.position.y)

func _hide_tooltip() -> void:
	if _tooltip_label:
		_tooltip_label.visible = false
