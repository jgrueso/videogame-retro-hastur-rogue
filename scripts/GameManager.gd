extends Node

var player_deck: Array = [
	{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
	{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
	{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
	{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2},
	{"name": "Cabalgante del Vacio", "attack": 4, "defense": 0, "cost": 2},
]

var run_seed: int = 0

var player_hp: int = 40
var player_max_hp: int = 40
var player_max_energy: int = 3
var sanity: int = 100
var max_sanity: int = 100
var sanity_notified: bool = false
var velo_broken: bool = false # Se rompe una vez por run
var coins: int = 0
var combat_count: int = 0
var current_map_floor: int = 0
var map_path: Dictionary = {}    # {floor_idx: col_idx} guarda el camino recorrido

func save_path_node(floor_idx: int, col_idx: int) -> void:
	map_path[floor_idx] = col_idx
var is_boss_fight: bool = false
var is_miniboss_fight: bool = false
var is_final_boss: bool = false
var is_elite_fight: bool = false
var selected_character: String = "mahar"
var lore_progress: int = 0       # avanza con cada combate ganado, persiste entre runs
var total_runs: int = 0          # cuantas runs completas ha hecho el jugador
var current_world: int = 0       # 0 = Mundo I, 1 = Mundo II
var map_graph: Array = []        # [{type, connections:[col_idx,...]}] por piso
var current_map_col: int = -1
var unlocked_lore: Array = [] # IDs de lore encontrados (pergaminos, capítulos)
var prince_unlocked: bool = false # Personaje secreto
var is_vault_room: bool = false # Si entramos via Grieta
var mark_level: int = 0 # Nivel del Signo Amarillo (+25% daño y +1 Energía por nivel)
var is_in_void_path: bool = false # Si estamos en la mini-mazmorra secreta
var rift_visited: bool = false # Si ya entramos a una grieta en esta run
var rift_notified: bool = false # Si ya ocurrió el evento de descubrimiento en el mapa
var rift_map_destroyed: bool = false # DEPRECATED — mantenido por compatibilidad
var rift_combat_pending: bool = false # Entrar a Grieta si ganamos el combate del Umbral
var rift_wanderer_offered: bool = false # Opción C del Umbral fue elegida en una run anterior
var void_path_step: int = 0 # 0-3 (Combate, Combate, Jefe Secreto, Tesoro)
var came_from_room: bool = false # True al salir de una sala hacia el mapa; Map._ready() guarda entonces
var fragment_count_w3: int = 0   # Fragmentos de Carcosa recogidos (acumulativo entre runs)
var resonancia_stacks: int = 0   # Solo Príncipe, reset por run

# ─── Destilados ───────────────────────────────────────────────────────────────
const MAX_DESTILADOS: int = 2
var destilados: Array = []           # IDs de destilados en inventario (máx MAX_DESTILADOS)
var destilados_blocked: bool = false # True tras usar El Último Vial (bloquea el resto del run)
var relic_fragments: int = 0         # Fragmentos de Reliquia (Conocimiento Prohibido)

func enter_void_path() -> void:
	is_in_void_path = true
	rift_visited = true
	void_path_step = 0
	go_to_scene("res://scenes/ui/VoidMap.tscn")

var _transitioning: bool = false
var _close_active_overlay: Callable = Callable()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _close_active_overlay.is_valid():
		_close_active_overlay.call()
		_close_active_overlay = Callable()
		get_viewport().set_input_as_handled()

func go_to_scene(path: String) -> void:
	if _transitioning: return
	_transitioning = true
	var layer = CanvasLayer.new()
	layer.layer = 500
	add_child(layer)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	var tree = get_tree()
	var tw = create_tween()
	tw.tween_property(overlay, "color:a", 1.0, 0.05)
	tw.tween_callback(func():
		tree.change_scene_to_file(path)
		var tw2 = create_tween()
		tw2.tween_property(overlay, "color:a", 0.0, 0.1)
		tw2.tween_callback(func():
			layer.queue_free()
			_transitioning = false
		)
	)

const META_SAVE_PATH = "user://meta_progression.dat"
const RUN_SAVE_PATH = "user://current_run.dat"

func _ready() -> void:
	load_meta() # Cargar personajes y lore al iniciar

# --- GUARDADO DE PROGRESO ETERNO (Personajes, Lore) ---
func save_meta() -> void:
	var data = {
		"prince_unlocked": prince_unlocked,
		"unlocked_lore": unlocked_lore,
		"total_runs": total_runs,
		"lore_progress_total": lore_progress # Opcional: lore acumulado
	}
	var file = FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_meta() -> void:
	if not FileAccess.file_exists(META_SAVE_PATH): return
	var file = FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_err = json.parse(file.get_as_text())
		if parse_err == OK:
			var data = json.get_data()
			prince_unlocked = data.get("prince_unlocked", false)
			unlocked_lore = data.get("unlocked_lore", [])
			total_runs = data.get("total_runs", 0)
		file.close()

# --- GUARDADO DE LA PARTIDA ACTUAL (Run) ---
func save_run() -> void:
	var data = {
		"hp": player_hp,
		"max_hp": player_max_hp,
		"deck": player_deck,
		"relics": relics,
		"coins": coins,
		"sanity": sanity,
		"max_sanity": max_sanity,
		"current_world": current_world,
		"map_graph": map_graph,
		"map_floor": current_map_floor,
		"map_col": current_map_col,
		"map_path": map_path,
		"mark_level": mark_level,
		"max_energy": player_max_energy,
		"char_id": selected_character,
		"rift_visited": rift_visited,
		"velo_broken": velo_broken,
		"secret_items": secret_items,
		"lore_progress": lore_progress,
		"run_seed": run_seed,
		"fragment_count_w3": fragment_count_w3
	}
	var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	save_meta() # Siempre asegurar el meta al guardar la run

func load_run() -> bool:
	if not FileAccess.file_exists(RUN_SAVE_PATH): return false
	var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_err = json.parse(file.get_as_text())
		if parse_err == OK:
			var data = json.get_data()
			player_hp = data["hp"]
			player_max_hp = data["max_hp"]
			player_deck = data["deck"]
			relics = data["relics"]
			coins = data["coins"]
			sanity = data["sanity"]
			max_sanity = data.get("max_sanity", 100)
			current_world = data["current_world"]
			map_graph = data["map_graph"]
			# Normalizar conexiones a int (JSON las convierte a float)
			for floor_nodes in map_graph:
				for node in floor_nodes:
					node["connections"] = node.get("connections", []).map(func(c): return int(c))
			current_map_floor = data["map_floor"]
			current_map_col = data["map_col"]

			# RECONVERTIR LLAVES DE MAP_PATH A ENTEROS (JSON las vuelve String)
			map_path = {}
			var raw_path = data.get("map_path", {})
			for k in raw_path.keys():
				map_path[int(k)] = raw_path[k]
				
			mark_level = data.get("mark_level", 0)
			player_max_energy = data.get("max_energy", 3)
			selected_character = data.get("char_id", "mahar")
			rift_visited = data.get("rift_visited", false)
			velo_broken = data.get("velo_broken", false)
			secret_items = data.get("secret_items", [])
			lore_progress = data.get("lore_progress", lore_progress)
			run_seed = data.get("run_seed", 0)
			fragment_count_w3 = data.get("fragment_count_w3", 0)
			file.close()
			return true
	return false

func delete_run_save() -> void:
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(RUN_SAVE_PATH)

func reset_all_progress() -> void:
	# Borrar archivos de guardado
	for path in [RUN_SAVE_PATH, META_SAVE_PATH, SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# Resetear estado en memoria
	prince_unlocked = false
	unlocked_lore = []
	total_runs = 0
	lore_progress = 0
	reset_run()

signal lore_popup_closed

const LORE_CHARACTER_REACTIONS: Dictionary = {
	"mahar": "«Otro fragmento. La Cofradia nunca me hablo de esto. Cuanto mas hay que no me dijeron.»",
	"estratega": "«El patrón se amplía. Cada dato es un eslabón de la cadena que me ata a este lugar.»",
	"guardian": "«Cargo con esto también. El peso no me dobla. Todavía no.»",
	"prince": "«Lo recuerdo. Siempre lo recordé. Tú aún no comprendes lo que eso significa para nosotros.»",
}

func unlock_lore(lore_id: String) -> void:
	if not lore_id in unlocked_lore:
		unlocked_lore.append(lore_id)
		save_meta()
		_show_lore_popup(lore_id)

func _show_lore_popup(lore_id: String) -> void:
	var data = LoreData.LORE_BOOK.get(lore_id, {})
	if data.is_empty(): return
	var scene = get_tree().current_scene
	if not scene: return

	var vp = scene.get_viewport_rect().size

	# Usar CanvasLayer para total aislamiento de entrada
	var layer = CanvasLayer.new()
	layer.layer = 200 # Muy por encima de todo
	scene.add_child(layer)

	# Fondo oscuro semitransparente
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	var tw_bg = scene.create_tween()
	tw_bg.tween_property(overlay, "color:a", 0.88, 0.35)

	# Panel central
	var panel = Panel.new()
	panel.size = Vector2(min(vp.x * 0.72, 620), min(vp.y * 0.72, 500))
	panel.position = (vp - panel.size) / 2
	panel.modulate.a = 0.0
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.03)
	s.set_border_width_all(2)
	s.border_color = Color(0.6, 0.5, 0.1)
	s.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", s)
	overlay.add_child(panel)

	var tw_p = scene.create_tween()
	tw_p.tween_property(panel, "modulate:a", 1.0, 0.35)

	# ... (resto de la configuración de labels igual)
	# Etiqueta "CÓDICE DESBLOQUEADO"
	var header = Label.new()
	header.text = "— CÓDICE DESBLOQUEADO —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = Color(0.55, 0.45, 0.1)
	header.position = Vector2(0, 18)
	header.size = Vector2(panel.size.x, 24)
	panel.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = ""
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.modulate = Color(0.9, 0.78, 0.2)
	title_lbl.position = Vector2(0, 50)
	title_lbl.size = Vector2(panel.size.x, 36)
	panel.add_child(title_lbl)
	var _full_title: String = data["title"]
	var tw_type = scene.create_tween()
	tw_type.tween_interval(0.2)
	tw_type.tween_method(func(n: int): title_lbl.text = _full_title.substr(0, n),
		0, _full_title.length(), float(_full_title.length()) * 0.055)

	var sep = ColorRect.new()
	sep.color = Color(0.5, 0.4, 0.1, 0.5)
	sep.size = Vector2(panel.size.x - 80, 1)
	sep.position = Vector2(40, 96)
	panel.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(30, 108)
	scroll.size = Vector2(panel.size.x - 60, panel.size.y - 185)
	panel.add_child(scroll)

	var text_lbl = Label.new()
	var _reaction: String = LORE_CHARACTER_REACTIONS.get(selected_character, "")
	text_lbl.text = (_reaction + "\n\n——\n\n" + data["text"]) if not _reaction.is_empty() else data["text"]
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.custom_minimum_size.x = scroll.size.x - 10
	text_lbl.add_theme_font_size_override("font_size", 15)
	text_lbl.modulate = Color(0.85, 0.82, 0.75, 0.0)
	scroll.add_child(text_lbl)

	var tw_txt = scene.create_tween()
	tw_txt.tween_interval(0.3)
	tw_txt.tween_property(text_lbl, "modulate:a", 1.0, 0.7)

	# Botón cerrar
	var close_btn = Button.new()
	close_btn.text = "GUARDAR EN EL CÓDICE"
	close_btn.custom_minimum_size = Vector2(240, 44)
	close_btn.position = Vector2(panel.size.x / 2 - 120, panel.size.y - 62)
	panel.add_child(close_btn)
	var _lore_close = func():
		_close_active_overlay = Callable()
		var tw_out = scene.create_tween()
		tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
		tw_out.finished.connect(func():
			layer.queue_free()
			lore_popup_closed.emit()
		)
	_close_active_overlay = _lore_close
	close_btn.pressed.connect(_lore_close)

	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("lore_reveal")

var relics: Array = []           # lista de nombres de reliquias activas
var secret_items: Array = []     # objetos misteriosos recogidos en esta run
var is_hastur_fight: bool = false
var player_won: bool = false
var has_eternal_fragment: bool = false # Objeto misterioso de esta run

# DEBUG
var dev_force_avatar: bool = false
var dev_force_penitente: bool = false

# --- PROGRESO PERMANENTE ---
# Ya no guardamos cartas, solo el progreso del lore y estadísticas
const SAVE_PATH = "user://meta_progress.save"

func save_meta_progress() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"lore": lore_progress,
			"runs": total_runs
		}
		file.store_var(data)
		file.close()

func load_meta_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		if data.has("lore"): lore_progress = data["lore"]
		if data.has("runs"): total_runs = data["runs"]
		file.close()

# --- Fin Progreso Permanente ---

const SECRET_ITEM_DATA = {
	"simbolo_amarillo": {
		"name": "El Simbolo Amarillo",
		"desc": "Un signo que no deberia existir.\nAl mirarlo demasiado tiempo, olvidas por que lo buscabas.",
		"icon": "⟁",
		"color": Color(0.95, 0.82, 0.1),
	},
	"cancion_amarilla": {
		"name": "La Cancion Amarilla",
		"desc": "Un pergamino con una melodia anotada.\nAl leerla, escuchas algo sin fuente.",
		"icon": "♪",
		"color": Color(0.88, 0.75, 0.05),
	},
	"carta_carcosa": {
		"name": "Carta de Invitacion a Carcosa",
		"desc": "Sellada con cera negra. El destinatario eres tu.\nSiempre fuiste tu.",
		"icon": "✉",
		"color": Color(0.82, 0.70, 0.12),
	},
}

func has_secret_item(item_id: String) -> bool:
	return item_id in secret_items

func get_sanity_label() -> String:
	if selected_character == "prince":
		if sanity < 35: return "RESONANCIA"
		if sanity < 60: return "ECO"
		return "CORDURA"
	return "LOCURA" if sanity < 40 else "CORDURA"

func add_secret_item(item_id: String) -> void:
	if not has_secret_item(item_id):
		secret_items.append(item_id)
		# Cada fragmento reduce el limite mental (mas verdad = mas locura)
		max_sanity = max(40, max_sanity - 15)
		sanity = min(sanity, max_sanity)
		if has_all_secret_items():
			unlock_lore("tres_sellos")

func has_all_secret_items() -> bool:
	return ("simbolo_amarillo" in secret_items and
		"cancion_amarilla" in secret_items and
		"carta_carcosa" in secret_items)

func collect_fragment_w3() -> void:
	fragment_count_w3 += 1
	if selected_character == "prince":
		resonancia_stacks += 1
	else:
		max_sanity = max(20, max_sanity - 15)
		sanity = min(sanity, max_sanity)

# ─── Reliquias disponibles ────────────────────────────────────────────────────
const RELIC_DATA = {
	"ficha_marfil": {
		"name": "Ficha de Marfil",
		"desc": "+1 Energía máxima permanente. Pierdes 1 HP al inicio de cada turno.",
	},
	"escudo_astillado": {
		"name": "Escudo Astillado",
		"desc": "Empiezas cada combate con 5 de escudo.",
	},
	"ojo_oraculo": {
		"name": "Ojo del Oraculo",
		"desc": "Revela el patron completo del enemigo al inicio del combate.",
	},
	"sangre_caido": {
		"name": "Sangre del Caido",
		"desc": "Al matar un enemigo, +1 ATK a todos los Siervos Quebrados permanentemente.",
	},
	"corona_dorada": {
		"name": "Corona de Espinas Doradas",
		"desc": "+1 Energia maxima. Pierdes 5 de Cordura al iniciar combate.",
		"flavor": "Una corona hecha para alguien que ya no tiene cabeza que coronar.",
	},
	"reloj_negro": {
		"name": "Reloj de Arena Negra",
		"desc": "Cada 3 cartas jugadas, recuperas 1 de Energia.",
	},
	"caliz_olvido": {
		"name": "Caliz del Olvido",
		"desc": "Al inicio del combate, sacrifica 1 pieza al azar para ganar +1 Energía y +2 de Robo ese turno.",
	},
	"velo_dama": {
		"name": "Velo de la Dama",
		"desc": "Anula la muerte una vez por RUN, recuperando 25% HP. Tras romperse, otorga +2 ATK permanente.",
		"flavor": "Pertenecio a alguien que supo ver el final antes de llegar a el.",
	},
	"espejo_fragmentado": {
		"name": "Espejo Fragmentado",
		"desc": "Duplica tu 1ra carta si cuesta 2 o menos. Si es una Maldición, recuperas 5 de Cordura.",
	},
	"reloj_roto": {
		"name": "Reloj Circular",
		"desc": "Cada 3 turnos, conservas tu mano actual al finalizar el turno.",
	},
	"lengua_tablero": {
		"name": "Lengua del Tablero",
		"desc": "Entiendes a los enemigos que hablan en idioma desconocido.\nMaldicion: una carta 'Peso de la Verdad' aparece en tu mano cada combate.",
		"flavor": "No es un don. Es una condena con mejor diccion.",
	},
	"ojo_grito": {
		"name": "Ojo del Grito",
		"desc": "Al inicio del combate con Cordura < 40, todos los enemigos pierden su primer ataque.",
	},
	"manual_anatomista": {
		"name": "Manual del Anatomista",
		"desc": "Al inicio de cada combate, las intenciones enemigas son visibles desde el primer turno.",
	},
	"ojo_arrancado": {
		"name": "Ojo Arrancado",
		"desc": "Cada vez que recibes daño de un enemigo, ese enemigo sufre 2 de daño de retorno.",
	},
	"ojo_testigo": {
		"name": "Ojo del Testigo",
		"desc": "Ve el patron completo de todos los enemigos W3. Costo: -20 Cordura maxima permanente.",
	},
	"fragmento_mascara_palida": {
		"name": "Fragmento de la Mascara",
		"desc": "+2 Energia al inicio de combate. Con Cordura < 40, revela el patron completo del enemigo.",
		"flavor": "Todavia frio. Tallado con una precision que las manos humanas no deberian tener.",
	},
	"fragmento_mapa": {
		"name": "Fragmento de Mapa",
		"desc": "-10% HP enemigos W3. Costo: +1 combate forzado antes de cada descanso.",
	},
	"ceniza_guardia": {
		"name": "Ceniza de la Guardia",
		"desc": "+2 Energia maxima en W3 unicamente.",
	},
}

# ─── Destilados disponibles ───────────────────────────────────────────────────
# target: "auto" | "enemy" | "all_enemies" | "card"
# out_of_combat: puede usarse fuera de combate
const DESTILADO_DATA = {
	# COMUNES
	"sangre_ejecutor": {
		"name": "Sangre del Ejecutor",
		"desc": "Tu próximo ataque inflige +50% de daño.",
		"flavor": "Extraída de la vena de una pieza que ejecutó a tres reyes. Caliente todavía.",
		"rarity": "comun",
		"target": "auto",
		"out_of_combat": false,
	},
	"recuerdo_robado": {
		"name": "Recuerdo Robado",
		"desc": "Roba 3 cartas. Descarta 1 carta al azar.",
		"flavor": "La memoria de alguien más. Parcialmente intacta.",
		"rarity": "comun",
		"target": "auto",
		"out_of_combat": false,
	},
	"polvo_dama_ceniza": {
		"name": "Polvo de la Dama de Ceniza",
		"desc": "Aplica Sangrado a todos los enemigos (3 daño/turno × 3 turnos). Pierdes 5 de Cordura.",
		"flavor": "Ceniza de su pira funeraria. Todavía arde.",
		"rarity": "comun",
		"target": "all_enemies",
		"out_of_combat": false,
	},
	# POCO COMUNES
	"bruma_rey_caido": {
		"name": "Bruma del Rey Caído",
		"desc": "Inflige 15 de daño a todos los enemigos. Pierdes 10 de Cordura.",
		"flavor": "El último aliento de un rey que creyó merecer más.",
		"rarity": "poco_comun",
		"target": "all_enemies",
		"out_of_combat": false,
	},
	"chispa_efimera": {
		"name": "Chispa Efímera",
		"desc": "+2 energía este turno. El siguiente turno empiezas con -1 energía.",
		"flavor": "Energía que no te pertenece. Se cobra sola.",
		"rarity": "poco_comun",
		"target": "auto",
		"out_of_combat": false,
	},
	"susurro_abismo": {
		"name": "Susurro del Abismo",
		"desc": "Aplica Locura a 1 enemigo: -30% ATK por 2 turnos. Pierdes 10 de Cordura.",
		"flavor": "Un fragmento de la locura del vacío, brevemente contenido.",
		"rarity": "poco_comun",
		"target": "enemy",
		"out_of_combat": false,
	},
	"olvido_puro": {
		"name": "Olvido Puro",
		"desc": "Elimina una carta de tu mazo permanentemente. Ganas 10 de oro.",
		"flavor": "En Valdris, olvidar es una habilidad rara y codiciada.",
		"rarity": "poco_comun",
		"target": "card",
		"out_of_combat": true,
	},
	"lucidez_prestada": {
		"name": "Lucidez Prestada",
		"desc": "Restaura 35 de Cordura. Añade 'Deuda de Cordura' a tu mazo (−15 Cordura al inicio del próximo combate).",
		"flavor": "La cordura pedida al vacío. Siempre cobra intereses.",
		"rarity": "poco_comun",
		"target": "auto",
		"out_of_combat": true,
	},
	# RAROS
	"tinta_sacrificio": {
		"name": "Tinta del Sacrificio",
		"desc": "Elige una carta en mano. La agota (Exhaust) e inflige su ATK como daño a todos los enemigos.",
		"flavor": "Firmó el pergamino. No miró a quién.",
		"rarity": "raro",
		"target": "card",
		"out_of_combat": false,
	},
	"resonancia_cero": {
		"name": "Resonancia de Coste Cero",
		"desc": "Todas las cartas en mano cuestan 0 este turno. Las cartas jugadas se consumen (Exhaust).",
		"flavor": "Por un instante, el tablero te lo debe todo.",
		"rarity": "raro",
		"target": "auto",
		"out_of_combat": false,
	},
	"fragmento_principe": {
		"name": "Fragmento del Príncipe",
		"desc": "Sacrifica 25 de Cordura. Gana +30% de daño por 3 turnos.",
		"flavor": "Una astilla de la locura del Príncipe de Carcosa.",
		"rarity": "raro",
		"target": "auto",
		"out_of_combat": false,
	},
	"conocimiento_prohibido": {
		"name": "Conocimiento Prohibido",
		"desc": "Revela el patrón completo de todos los enemigos. Gana 1 Fragmento de Reliquia. Costo: −20 Cordura y −5 Cordura máxima permanente.",
		"flavor": "El conocimiento verdadero de Valdris siempre tiene precio.",
		"rarity": "raro",
		"target": "auto",
		"out_of_combat": false,
	},
	# MALDITOS
	"sangre_rey_amarillo": {
		"name": "Sangre del Rey Amarillo",
		"desc": "+3 energía este turno. Todos tus ataques hacen el doble de daño este turno. Costo: −20 HP máximo y −15 Cordura permanentes.",
		"flavor": "No es su sangre real. Nada de Hastur debería existir en esta forma.",
		"rarity": "maldito",
		"target": "auto",
		"out_of_combat": false,
	},
	"ultimo_vial": {
		"name": "El Último Vial",
		"desc": "Cura al máximo de HP y Cordura. No puedes usar Destilados por el resto del run.",
		"flavor": "Una sola oportunidad. Úsala bien.",
		"rarity": "maldito",
		"target": "auto",
		"out_of_combat": true,
	},
	"eco_grieta": {
		"name": "Eco de la Grieta",
		"desc": "Efecto desconocido.",
		"flavor": "La grieta no ofrece. Toma.",
		"rarity": "maldito",
		"target": "auto",
		"out_of_combat": false,
	},
}

func has_destilado(destilado_id: String) -> bool:
	return destilado_id in destilados

func can_carry_destilado() -> bool:
	return not destilados_blocked and destilados.size() < MAX_DESTILADOS

func add_destilado(destilado_id: String) -> bool:
	if not can_carry_destilado():
		return false
	destilados.append(destilado_id)
	return true

func remove_destilado(destilado_id: String) -> void:
	destilados.erase(destilado_id)

func has_relic(relic_id: String) -> bool:
	return relic_id in relics

func add_relic(relic_id: String) -> void:
	if not has_relic(relic_id):
		relics.append(relic_id)
		_apply_passive_relic(relic_id)

func _apply_passive_relic(relic_id: String) -> void:
	match relic_id:
		"ficha_marfil":
			player_max_energy += 1
		"corona_espinas":
			player_max_hp += 10
			player_hp += 10
		"lengua_tablero":
			unlock_lore("penitente_rendicion")

func add_card(card_data: Dictionary) -> void:
	player_deck.append(card_data)

func add_coins(amount: int) -> void:
	coins += amount

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		return true
	return false

func heal(amount: int) -> void:
	player_hp = min(player_hp + amount, player_max_hp)

# --- UI GLOBAL: VER MAZO ---
func show_deck_overlay(parent_node: Node) -> void:
	var vp = parent_node.get_viewport_rect().size
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 500
	parent_node.add_child(overlay)
	
	var tw_bg = parent_node.create_tween()
	tw_bg.tween_property(overlay, "color:a", 0.92, 0.3)
	
	var panel = Panel.new()
	panel.size = Vector2(vp.x * 0.85, vp.y * 0.8)
	panel.position = (vp - panel.size) / 2
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.98, 0.98)
	panel.pivot_offset = panel.size / 2
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.98)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.4, 0.6, 0.5)
	style.shadow_size = 40
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	
	var tw_p = parent_node.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw_p.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw_p.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.4)
	
	var title = Label.new()
	title.text = "TU MAZO ACTUAL (%d piezas)" % player_deck.size()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(0.7, 0.7, 0.9)
	title.position = Vector2(0, 25); title.size = Vector2(panel.size.x, 50)
	panel.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(40, 90)
	scroll.size = Vector2(panel.size.x - 80, panel.size.y - 180)
	panel.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 5 
	grid.add_theme_constant_override("h_separation", 65) # Aumentar aún más
	grid.add_theme_constant_override("v_separation", 70) 
	scroll.add_child(grid)
	
	# Margen de seguridad izquierdo para que no se corte la primera columna
	grid.position = Vector2(25, 20)
	
	var card_scene = load("res://scenes/combat/Card.tscn")
	for i in range(player_deck.size()):
		var card = card_scene.instantiate()
		var card_container = Control.new()
		card_container.custom_minimum_size = Vector2(130 * 0.85, 195 * 0.85) 
		grid.add_child(card_container)
		
		card_container.add_child(card)
		card.setup(player_deck[i])
		card.set_display_scale(Vector2(0.85, 0.85))
		card.hover_scale_enabled = false
		card.glow_enabled = true
		card.modulate.a = 0.0
		parent_node.create_tween().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(0.1 + i * 0.03)
	
	# Añadir un espaciador al final para que el scroll permita ver bien las últimas cartas
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(100, 150)
	grid.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = "CERRAR"
	close_btn.size = Vector2(200, 50)
	close_btn.position = Vector2(panel.size.x/2 - 100, panel.size.y - 75)
	panel.add_child(close_btn)
	
	var _deck_close = func():
		_close_active_overlay = Callable()
		var tw_out = parent_node.create_tween()
		tw_out.tween_property(overlay, "modulate:a", 0.0, 0.25)
		tw_out.finished.connect(overlay.queue_free)
	_close_active_overlay = _deck_close
	close_btn.pressed.connect(_deck_close)

func show_codex_overlay(parent_node: Node) -> void:
	var vp = parent_node.get_viewport_rect().size
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.95); overlay.size = vp; overlay.z_index = 600
	parent_node.add_child(overlay)
	
	var panel = Panel.new()
	panel.size = Vector2(vp.x * 0.8, vp.y * 0.8); panel.position = (vp - panel.size) / 2
	var s = StyleBoxFlat.new(); s.bg_color = Color(0.08, 0.07, 0.05); s.set_border_width_all(3); s.border_color = Color(0.5, 0.4, 0.1); s.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", s)
	overlay.add_child(panel)
	
	var title = Label.new(); title.text = "📜 CÓDICE DEL ABISMO"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32); title.modulate = Color(0.8, 0.7, 0.2)
	title.position = Vector2(0, 30); title.size = Vector2(panel.size.x, 50); panel.add_child(title)
	
	var hsplit = HBoxContainer.new()
	hsplit.position = Vector2(40, 100); hsplit.size = Vector2(panel.size.x - 80, panel.size.y - 200)
	hsplit.add_theme_constant_override("separation", 30)
	panel.add_child(hsplit)
	
	var list_scroll = ScrollContainer.new(); list_scroll.custom_minimum_size.x = 250; hsplit.add_child(list_scroll)
	var list_vbox = VBoxContainer.new(); list_scroll.add_child(list_vbox)
	
	var content_scroll = ScrollContainer.new(); content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hsplit.add_child(content_scroll)
	var content_text = Label.new(); content_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content_text.add_theme_font_size_override("font_size", 16)
	content_scroll.add_child(content_text)
	
	# Poblar lista
	for lore_id in LoreData.LORE_BOOK.keys():
		var data = LoreData.LORE_BOOK[lore_id]
		var is_unlocked = lore_id in unlocked_lore or lore_progress >= data["min_lore"]
		
		var btn = Button.new()
		btn.text = data["title"] if is_unlocked else "??? (Lore: " + str(data["min_lore"]) + ")"
		btn.disabled = not is_unlocked
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list_vbox.add_child(btn)
		
		if is_unlocked:
			btn.pressed.connect(func():
				content_text.modulate.a = 0.0
				content_text.text = data["text"]
				var tw_ct = parent_node.create_tween()
				tw_ct.tween_property(content_text, "modulate:a", 1.0, 0.5)
			)
	
	var close_btn = Button.new(); close_btn.text = "CERRAR"; close_btn.size = Vector2(200, 50)
	close_btn.position = Vector2(panel.size.x/2 - 100, panel.size.y - 70); panel.add_child(close_btn)
	var _codex_close = func():
		_close_active_overlay = Callable()
		overlay.queue_free()
	_close_active_overlay = _codex_close
	close_btn.pressed.connect(_codex_close)

func reset_run() -> void:
	run_seed = randi()
	seed(run_seed)
	sanity = 100
	max_sanity = 100
	sanity_notified = false
	velo_broken = false
	has_eternal_fragment = false

	player_deck = [
		{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
		{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
		{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
		{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2},
		{"name": "Cabalgante del Vacio", "attack": 4, "defense": 0, "cost": 2},
	]
	player_hp = 40
	player_max_hp = 40
	coins = 0
	combat_count = 0
	current_map_floor = 0
	map_path = {}
	is_boss_fight = false
	is_miniboss_fight = false
	is_final_boss = false
	is_elite_fight = false
	selected_character = "mahar"
	total_runs += 1
	relics = []
	secret_items = []
	is_hastur_fight = false
	player_won = false
	current_world = 0
	map_graph = []
	current_map_col = -1
	mark_level = 0
	player_max_energy = 3
	rift_visited = false
	rift_combat_pending = false
	resonancia_stacks = 0
	destilados = []
	destilados_blocked = false
	relic_fragments = 0
	# rift_wanderer_offered persiste entre runs (no se resetea aquí)
	# fragment_count_w3 persiste entre runs (no se resetea aquí)
