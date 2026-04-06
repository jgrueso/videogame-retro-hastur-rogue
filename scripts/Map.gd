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
const ROOM_MIMIC    = "mimic"
const ROOM_VOID_COMBAT = "void_combat"
const ROOM_VOID_BOSS   = "void_boss"
const ROOM_FRAGMENT  = "fragment"
const ROOM_FINAL_W3  = "final_w3"
const ROOM_VAULT_W3  = "vault_w3"

# ── Diálogos de NPCs del mapa ─────────────────────────────────────────────────
const NPC_DIALOGUES: Dictionary = {
	"caminante": {
		"portrait": "👁",
		"name": "El Caminante del Umbral",
		"lines": [
			{
				"id": "start",
				"text": "Llevas ciclos buscando algo que ya no existe.",
				"choices": [
					{"label": "¿Qué sabes de Hastur?", "next": "hastur_info"},
					{"label": "No me interesan tus palabras.", "next": "end"},
				]
			},
			{
				"id": "hastur_info",
				"text": "Hastur no es un dios. Es una deuda pendiente del tablero. El Rey Amarillo no reina — espera. Y tú te acercas.",
				"effect": {"lore_progress": 10},
				"choices": [
					{"label": "Dame algo útil.", "next": "offer"},
					{"label": "Suficiente.", "next": "end"},
				]
			},
			{
				"id": "offer",
				"text": "Puedo mostrarte el camino hacia Carcosa. Pero el tablero siempre cobra su precio.",
				"choices": [
					{"label": "Sacrifica una reliquia (-1 reliquia, +15 lore)", "next": "end", "effect": {"sacrifice_relic": true, "lore_progress": 15}},
					{"label": "Rechazar.", "next": "end"},
				]
			},
		]
	},
	"mensajero": {
		"portrait": "♔",
		"name": "El Mensajero Amarillo",
		"lines": [
			{
				"id": "start",
				"text": "El Príncipe de Carcosa ya conoce tu nombre. Ha esperado cada una de tus muertes.",
				"choices": [
					{"label": "¿Quién te envía?", "next": "origen"},
					{"label": "No me importa.", "next": "end"},
				]
			},
			{
				"id": "origen",
				"text": "El umbral entre lo que fue y lo que será. Llevo su mensaje desde antes de que comenzaras a recordar.",
				"effect": {"sanity": -15},
				"choices": [
					{"label": "¿Qué mensaje?", "next": "mensaje"},
					{"label": "Retrocede.", "next": "end"},
				]
			},
			{
				"id": "mensaje",
				"text": "«Ha llegado la hora de Carcosa. El jugador que eres ahora será el último que recuerdes haber sido.»",
				"effect": {"lore_progress": 20, "sanity": -10},
				"choices": [
					{"label": "Aceptar el mensaje.", "next": "end"},
				]
			},
		]
	},
	"sombra": {
		"portrait": "◉",
		"name": "La Sombra Archivada",
		"lines": [
			{
				"id": "start",
				"text": "Recuerdo cada vez que moriste aquí. La primera vez fue la más ruidosa.",
				"choices": [
					{"label": "¿Qué eres?", "next": "identidad"},
					{"label": "No quiero saber.", "next": "end"},
				]
			},
			{
				"id": "identidad",
				"text": "Soy lo que el tablero archiva de cada partida perdida. Vuestros patrones, vuestros errores, vuestros últimos pensamientos.",
				"choices": [
					{"label": "¿Puedes ayudarme?", "next": "ayuda"},
					{"label": "Déjame en paz.", "next": "end"},
				]
			},
			{
				"id": "ayuda",
				"text": "He guardado algo de una run anterior. Una carta que encontraste una vez y perdiste antes del final.",
				"effect": {"secret_card": true, "lore_progress": 5},
				"choices": [
					{"label": "Tomar la carta.", "next": "end"},
					{"label": "Rechazar.", "next": "end"},
				]
			},
		]
	},
}

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
	ROOM_MIMIC:    Color(0.8, 0.6, 0.1),
	ROOM_VOID_COMBAT: Color(0.1, 0.4, 0.6),
	ROOM_VOID_BOSS: Color(0.2, 0.8, 1.0),
	ROOM_FRAGMENT:  Color(0.5, 0.1, 0.8),
	ROOM_FINAL_W3:  Color(0.35, 0.0, 0.6),
	ROOM_VAULT_W3:  Color(0.6, 0.1, 0.9),
}

const ROOM_DESCRIPTIONS: Dictionary = {
	"combat":      ["⚔ ECO DE BATALLA",       "Un fragmento del pasado combate por sobrevivir.",       ["Las piezas muertas nunca descansan.", "Cada victoria es una deuda pendiente.", "El tablero recuerda cada golpe."]],
	"elite":       ["☠ PRESENCIA VORAZ",       "Una entidad corrompida. Recompensa mayor, riesgo letal.", ["No todos los que entran comprenden lo que enfrentan.", "Su hambre no tiene origen. Solo destino.", "Ha visto morir a mejores."]],
	"event":       ["♄ AUGURIO",               "El tablero te ofrece una elección. Nada es gratis.",    ["Las elecciones aquí pesan más que las espadas.", "Cada favor tiene un nombre grabado en el reverso.", "El tablero no regala nada."]],
	"shop":        ["☤ EL BUHONERO",           "Monedas por poder. Reliquias, cartas, magia menor.",    ["¿Cuánto vale lo que aún no sabes que necesitas?", "Compra con cuidado. Lo que no se compra, se cobra.", "El buhonero siempre vende lo que el siguiente comprador necesitará."]],
	"boss":        ["★ JEFE DE MUNDO",         "El guardián del piso. Derrótalo para avanzar.",         ["Fue creado para detenerte. Lleva haciéndolo desde antes de que nacieras.", "No guarda el camino por lealtad. Lo hace por necesidad.", "Matar al guardián no abre la puerta. Solo la desbloquea."]],
	"rest":        ["🕯 HOGUERA DE CENIZA",    "Descansa, forja o sacrifica. Un momento de tregua.",   ["La hoguera no calienta. Solo postpone el frío.", "Incluso aquí, algo observa desde las sombras.", "El descanso en Valdris es mentira. Pero es la única mentira útil."]],
	"treasure":    ["📦 COFRE OLVIDADO",       "Algo brilla entre la ceniza. ¿Carta o reliquia?",       ["Quien lo dejó aquí ya no puede reclamarlo.", "El brillo no es señal de valor. A veces es señal de trampa.", "Lleva aquí esperando más tiempo del que imaginas."]],
	"mimic":       ["📦 COFRE OLVIDADO",       "Algo brilla entre la ceniza. ¿Carta o reliquia?",       ["Quien lo dejó aquí ya no puede reclamarlo.", "El brillo no es señal de valor. A veces es señal de trampa.", "Lleva aquí esperando más tiempo del que imaginas."]],
	"void_combat": ["🌀 GRIETA DEL VACÍO",     "Camino secreto. Combate en el umbral del olvido.",      ["El vacío no te invita. Te tolera.", "Pocas piezas regresan de aquí con la misma forma.", "El umbral tiene memoria. Y te ha visto antes."]],
	"void_boss":   ["✦ CENTINELA DEL ABISMO", "El guardián del paso secreto. Alta recompensa.",         ["Existe para cerrar puertas. La tuya incluida.", "Lo que custodia no puede nombrarse. Aún.", "Venció a los anteriores. ¿Qué te hace diferente?"]],
	"final":       ["♔ EL REY SIN CORONA",    "El final del primer tablero te aguarda.",                ["El trono siempre estuvo vacío. Eso no lo hace menos peligroso.", "No busca ganar. Busca que tú pierdas.", "Su nombre fue borrado. Solo queda el hambre."]],
	"final_w2":    ["♔ EL REY AMARILLO",      "El trono vacío reclama su deuda.",                       ["Carcosa lo espera a él. Y a través de él, a ti.", "El Rey Amarillo no olvida ninguna partida.", "Has llegado demasiado lejos para fingir que no lo sabías."]],
	"secret":      ["✦ FRAGMENTO DE REALIDAD","Una pieza que no debería existir aquí.",                  ["Este objeto no pertenece a ningún inventario conocido.", "Tómalo. O déjalo. El tablero ya tomó nota.", "Su presencia aquí no es accidental."]],
	"fragment":    ["◈ FRAGMENTO DE CARCOSA", "Poder del umbral. El Príncipe gana resonancia. Otros pierden cordura máxima.", ["La verdad tiene un precio. Este es uno de sus recibos.", "Cada fragmento es una promesa que no hiciste.", "Carcosa se construye de pedazos como este."]],
	"final_w3":    ["◉ EL TESTIGO PRIMORDIAL","La entidad hecha de tus muertes acumuladas te aguarda.", ["No puede ser derrotado. Solo puede ser sobrevivido.", "Te conoce mejor que tú mismo. Ha visto cada error.", "Eres la suma de todos los que fallaron antes que tú."]],
	"vault_w3":    ["⬡ BOVEDA DEL UMBRAL",    "Tres fragmentos reunidos abren este pasaje. Reliquia única dentro.", ["Lo que se guarda aquí fue sellado con razón.", "La bóveda no protege el tesoro. Te protege a ti de él.", "Tres fragmentos de Carcosa te han llevado hasta aquí. Pregúntate por qué."]],
}

const ROOM_CORRUPTED_DESCRIPTIONS: Array = [
	["ᚠᛒᚱ ᛈᛇᚦ", "ᛟᛗᚾᛁ ᛖᚷᛃ ᚹᚫ"],
	["☠ ACECHANDO", "ya están dentro"],
	["✦ ERROR", "no deberías ver esto"],
	["◉ ....", "siempre fue así"],
	["⚔ INEVITABLE", "lo sabes, ¿verdad?"],
	["♔ TE VE", "el tablero te conoce"],
]

const ROOM_LABELS = {
	ROOM_COMBAT:   "⚔ Eco de Batalla",
	ROOM_ELITE:    "☠ Presencia Voraz",
	ROOM_EVENT:    "♄ Augurio",
	ROOM_SHOP:     "☤ El Telonero",
	ROOM_BOSS:     "★ JEFE DE MUNDO",
	ROOM_FINAL:    "♔ EL REY SIN CORONA",
	ROOM_FINAL_W2: "♔ EL REY AMARILLO",
	ROOM_SECRET:   "✦ Fragmento de Realidad",
	ROOM_REST:     "🕯 Hoguera de Ceniza",
	ROOM_TREASURE: "📦 Cofre Olvidado",
	ROOM_VOID_COMBAT: "🌀 Grieta del Vacío",
	ROOM_VOID_BOSS: "✦ Centinela del Abismo",
	ROOM_FRAGMENT:  "◈ Fragmento de Carcosa",
	ROOM_FINAL_W3:  "◉ EL TESTIGO PRIMORDIAL",
	ROOM_VAULT_W3:  "⬡ Boveda del Umbral",
}

# ── Constantes de nodos visuales del mapa ────────────────────────────
const NODE_W       : float = 90.0
const NODE_ILLUS_H : float = 62.0
const NODE_BADGE_H : float = 22.0
const NODE_H       : float = NODE_ILLUS_H + 5.0 + NODE_BADGE_H  # ~89

const ROOM_BIG_ICONS : Dictionary = {
	"combat":      "⚔",
	"elite":       "☠",
	"event":       "♄",
	"shop":        "☤",
	"boss":        "★",
	"final":       "♔",
	"final_w2":    "♔",
	"final_w3":    "◉",
	"rest":        "🕯",
	"treasure":    "◆",
	"mimic":       "◆",
	"void_combat": "🌀",
	"void_boss":   "✦",
	"secret":      "✦",
	"fragment":    "◈",
	"vault_w3":    "⬡",
}

func _ready() -> void:
	if get_node_or_null("/root/AudioManager"):
		# 1. Limpieza de sonidos persistentes del menú o glitches
		AudioManager.stop_loop("Glith_distorsion_noised_sound")
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		AudioManager.stop_loop("intro_title_song")
		
		# 2. Control de música por Mundo (0:Mundo1, 1:Mundo2, 2:Mundo3)
		match GameManager.current_world:
			0: # MUNDO I: Búsqueda de la Verdad
				# IMPORTANTE: Detenemos la canción del W2 si existe por error
				AudioManager.stop_loop("ES_Lost in Time - Aiyo")
				# Transición suave de la hoguera (si viene de ella) al ambiente del mapa
				AudioManager.crossfade_loop("resting_song", "map_ambient_song", 1.5)
				
			1, 2: # MUNDO II (Carcosa) y MUNDO III (Abismo)
				# Aquí es donde realmente queremos que suene "Lost in Time"
				AudioManager.stop_loop("resting_song")
				# Hacemos crossfade del ambiente base a la canción temática
				AudioManager.crossfade_loop("map_ambient_song", "ES_Lost in Time - Aiyo", 1.5)
			
			_: # Caso por defecto (por seguridad)
				AudioManager.stop_loop("ES_Lost in Time - Aiyo")
				AudioManager.play_loop("map_ambient_song")

	# Audio de baja cordura en el mapa
	var _hb = "ES_Human, Heartbeat, Cinematic, 58 BPM - Epidemic Sound"
	AudioManager.stop_loop(_hb)  # limpiar si venía de combate
	if GameManager.sanity < 40:
		AudioManager.play_loop(_hb)
		AudioManager.update_loop_params(_hb, lerp(-22.0, -14.0, clamp((40.0 - GameManager.sanity) / 40.0, 0.0, 1.0)), 1.0)
		# Bajar música ambiente según profundidad de baja cordura
		var _music_vol = lerp(-10.0, -22.0, clamp((40.0 - GameManager.sanity) / 40.0, 0.0, 1.0))
		AudioManager.set_music_volume(_music_vol)

	# 3. Lógica de generación y guardado (se mantiene igual)
	if GameManager.map_graph.is_empty():
		GameManager.map_graph = _generate_map()
		
	if GameManager.came_from_room:
		if GameManager.current_map_col >= 0:
			GameManager.save_path_node(GameManager.current_map_floor - 1, GameManager.current_map_col)
		GameManager.save_run()
		GameManager.came_from_room = false
		
		if GameManager.rift_combat_pending and GameManager.player_hp > 0:
			GameManager.rift_combat_pending = false
			get_tree().create_timer(0.2).timeout.connect(func(): GameManager.enter_void_path())
			return
		GameManager.rift_combat_pending = false

	modulate.a = 0.0
	build_ui()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	_spawn_map_npcs()
# ─── Generacion procedural del mapa ──────────────────────────────────────────
func _generate_map() -> Array:
	var graph: Array = []
	var num_floors = randi_range(15, 18)
	var is_w2 = GameManager.current_world == 1
	var is_w3 = GameManager.current_world == 2
	var final_room = ROOM_FINAL_W3 if is_w3 else (ROOM_FINAL_W2 if is_w2 else ROOM_FINAL)

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
			var node_data = {"type": t, "connections": []}
			floor_nodes.append(node_data)

		graph.append(floor_nodes)

	# Generar conexiones entre pisos
	for f in range(graph.size() - 1):
		_connect_floors(graph, f)

	# Colocar objetos misteriosos — 1 fragmento por mundo, restringido al mundo actual
	var world_fragment := ""
	if GameManager.current_world == 0: world_fragment = "simbolo_amarillo"
	elif GameManager.current_world == 1: world_fragment = "cancion_amarilla"
	elif GameManager.current_world == 2: world_fragment = "carta_carcosa"

	var missing_items: Array = []
	if not world_fragment.is_empty() and not GameManager.has_secret_item(world_fragment):
		missing_items = [world_fragment]

	if not missing_items.is_empty():
		var fixed_types = [ROOM_SHOP, ROOM_BOSS, ROOM_FINAL, ROOM_FINAL_W2, ROOM_FINAL_W3, ROOM_FRAGMENT, ROOM_VAULT_W3]
		var eligible: Array = []
		for f in range(2, graph.size() - 2):
			if graph[f][0].type not in fixed_types:
				eligible.append(f)

		eligible.shuffle()
		var to_place = min(1, missing_items.size())

		for i in range(to_place):
			if eligible.is_empty(): break
			var fi = eligible.pop_back()
			var ci = randi() % graph[fi].size()
			graph[fi][ci].type = ROOM_SECRET
			graph[fi][ci]["item_id"] = missing_items[i]

	# Colocar Fragmentos de Carcosa (solo en W3)
	if is_w3:
		var frag_fixed_types = [ROOM_SHOP, ROOM_BOSS, ROOM_FINAL_W3, ROOM_REST, ROOM_FRAGMENT, ROOM_VAULT_W3]
		var frag_eligible: Array = []
		var third = num_floors / 3
		for f in range(third, num_floors - 3):
			for c in range(graph[f].size()):
				if graph[f][c].type not in frag_fixed_types:
					frag_eligible.append({"f": f, "c": c})
		frag_eligible.shuffle()
		var placed = 0
		for slot in frag_eligible:
			if placed >= 2: break
			graph[slot.f][slot.c].type = ROOM_FRAGMENT
			placed += 1
		# Boveda del Umbral si se acumularon 3+ fragmentos entre runs
		if GameManager.fragment_count_w3 >= 3:
			var vault_eligible: Array = []
			for f in range(third, num_floors - 3):
				for c in range(graph[f].size()):
					if graph[f][c].type not in frag_fixed_types:
						vault_eligible.append({"f": f, "c": c})
			if not vault_eligible.is_empty():
				vault_eligible.shuffle()
				var vs = vault_eligible[0]
				graph[vs.f][vs.c].type = ROOM_VAULT_W3

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

	# 20% de los cofres son mímicos — indistinguibles en el mapa
	if t == ROOM_TREASURE and randf() < 0.20:
		t = ROOM_MIMIC

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
var lbl_info: Control  # apunta al HUDBar Panel (guard para update_ui)
var dev_panel: Panel

func build_ui() -> void:
	var vp = get_viewport_rect().size

	# ── FONDO: pergamino por mundo + overlay oscuro ───────────────────
	var bg_paths: Array[String] = [
		"res://assets/mapbg.png",               # Mundo 1 — pergamino/eclipse
		"res://assets/map_background_w2.png",   # Mundo 2 — vórtice Carcosa
		"res://assets/map_background_w3.png",   # Mundo 3 — abismo púrpura
	]
	var bg_overlays: Array[Color] = [
		Color(0.02, 0.01, 0.04, 0.50),
		Color(0.0,  0.02, 0.04, 0.45),
		Color(0.04, 0.0,  0.08, 0.50),
	]
	var world_idx: int = clamp(GameManager.current_world, 0, 2)
	var bg_path: String = bg_paths[world_idx]

	var bg_tex = TextureRect.new()
	bg_tex.texture = load(bg_path) if ResourceLoader.exists(bg_path) else null
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tex.size = vp
	bg_tex.position = Vector2.ZERO
	bg_tex.z_index = -100
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_tex)

	if bg_tex.texture == null:
		var bg_fallback = ColorRect.new()
		bg_fallback.color = Color(0.06, 0.04, 0.08)
		bg_fallback.size = vp
		bg_fallback.z_index = -101
		bg_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_fallback)

	var bg_overlay = ColorRect.new()
	bg_overlay.color = bg_overlays[world_idx]
	bg_overlay.size = vp
	bg_overlay.position = Vector2.ZERO
	bg_overlay.z_index = -99
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_overlay)

	var map_dark = ColorRect.new()
	map_dark.color = Color(0.0, 0.0, 0.0, 0.55)
	map_dark.position = Vector2(0, 108)
	map_dark.size = Vector2(vp.x, vp.y - 108)
	map_dark.z_index = -1
	map_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_dark)

	# ── CAPA UI (HUD fijo, no hace scroll) ───────────────────────────
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# ── BARRA HUD ────────────────────────────────────────────────────
	var hud_bar = Panel.new()
	hud_bar.name = "HUDBar"
	hud_bar.position = Vector2.ZERO
	hud_bar.size = Vector2(vp.x, 50)
	var hud_style = StyleBoxFlat.new()
	hud_style.bg_color = Color(0.04, 0.03, 0.06, 0.88)
	hud_style.border_width_bottom = 1
	hud_style.border_color = Color(0.28, 0.22, 0.38, 0.5)
	hud_bar.add_theme_stylebox_override("panel", hud_style)
	ui_layer.add_child(hud_bar)

	var graph = GameManager.map_graph
	var stat_defs = [
		["StatHP",     "❤ %d/%d" % [GameManager.player_hp, GameManager.player_max_hp],   Color(0.95, 0.3, 0.35),  vp.x * 0.13],
		["StatCoins",  "◆ %d" % GameManager.coins,                                        Color(0.95, 0.78, 0.2),  vp.x * 0.28],
		["StatSanity", "⬤ %d/%d" % [GameManager.sanity, GameManager.max_sanity],         Color(0.55, 0.3, 0.88),  vp.x * 0.44],
		["StatLore",   "📖 %d" % GameManager.lore_progress,                               Color(0.5, 0.72, 0.52),  vp.x * 0.60],
		["StatFloor",  "Piso %d/%d" % [GameManager.current_map_floor + 1, graph.size()], Color(0.58, 0.65, 0.82), vp.x * 0.74],
	]
	for sd in stat_defs:
		var sl = Label.new()
		sl.name = sd[0]
		sl.text = sd[1]
		sl.modulate = sd[2]
		sl.add_theme_font_size_override("font_size", 15)
		sl.position = Vector2(sd[3], 14)
		sl.size = Vector2(170, 24)
		hud_bar.add_child(sl)

	lbl_info = hud_bar  # guard para update_ui

	# Separadores verticales del HUD
	for sep_x in [vp.x * 0.22, vp.x * 0.38, vp.x * 0.54, vp.x * 0.68]:
		var sep = ColorRect.new()
		sep.size = Vector2(1, 24)
		sep.position = Vector2(sep_x, 13)
		sep.color = Color(0.3, 0.25, 0.4, 0.4)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_bar.add_child(sep)

	# ── TÍTULO Y SUBTÍTULO DE MUNDO ───────────────────────────────────
	var world_name: String
	if GameManager.current_world == 2:
		world_name = "Mundo III — La Grieta Sin Fondo"
	elif GameManager.current_world == 1:
		world_name = "Mundo II — El Tablero Dorado"
	else:
		world_name = "Mundo I — La Caida del Rey"

	var title = Label.new()
	title.text = "Elige tu camino"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 54)
	title.size = Vector2(vp.x, 32)
	ui_layer.add_child(title)

	var world_lbl = Label.new()
	world_lbl.text = world_name
	world_lbl.add_theme_font_size_override("font_size", 12)
	if GameManager.current_world == 2:
		world_lbl.modulate = Color(0.6, 0.2, 0.9)
	elif GameManager.current_world == 1:
		world_lbl.modulate = Color(0.95, 0.8, 0.1)
	else:
		world_lbl.modulate = Color(0.6, 0.7, 0.9)
	world_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_lbl.position = Vector2(0, 86)
	world_lbl.size = Vector2(vp.x, 18)
	ui_layer.add_child(world_lbl)

	# ── BOTONES TOP-RIGHT ─────────────────────────────────────────────
	var btn_w := 148; var btn_h := 36; var btn_y := 7

	var deck_btn = Button.new()
	deck_btn.text = "▣  VER MAZO"
	deck_btn.position = Vector2(vp.x - btn_w - 8, btn_y)
	deck_btn.size = Vector2(btn_w, btn_h)
	deck_btn.add_theme_font_size_override("font_size", 13)
	_style_top_button(deck_btn, Color(0.5, 0.32, 0.08))
	ui_layer.add_child(deck_btn)
	deck_btn.pressed.connect(func(): GameManager.show_deck_overlay(self))

	var codex_btn = Button.new()
	codex_btn.text = "📜  CÓDICE"
	codex_btn.position = Vector2(vp.x - btn_w * 2 - 18, btn_y)
	codex_btn.size = Vector2(btn_w, btn_h)
	codex_btn.add_theme_font_size_override("font_size", 13)
	_style_top_button(codex_btn, Color(0.28, 0.42, 0.18))
	ui_layer.add_child(codex_btn)
	codex_btn.pressed.connect(func(): GameManager.show_codex_overlay(self))

	# Botón Destilados (visible solo si llevas alguno)
	if not GameManager.destilados.is_empty():
		var dest_btn = Button.new()
		dest_btn.text = "◈  DESTILADOS"
		dest_btn.position = Vector2(vp.x - btn_w * 3 - 28, btn_y)
		dest_btn.size = Vector2(btn_w, btn_h)
		dest_btn.add_theme_font_size_override("font_size", 13)
		_style_top_button(dest_btn, Color(0.3, 0.15, 0.45))
		ui_layer.add_child(dest_btn)
		dest_btn.pressed.connect(_show_destilados_overlay)

	# ── BOTÓN DEV ─────────────────────────────────────────────────────
	var dev_toggle = Button.new()
	dev_toggle.text = "[DEV]"
	dev_toggle.position = Vector2(8, btn_y + 4)
	dev_toggle.size = Vector2(56, 28)
	dev_toggle.add_theme_font_size_override("font_size", 9)
	_style_top_button(dev_toggle, Color(0.3, 0.3, 0.3))
	dev_toggle.z_index = 10
	ui_layer.add_child(dev_toggle)

	dev_panel = _build_dev_panel(vp)
	dev_panel.visible = false
	ui_layer.add_child(dev_panel)
	dev_toggle.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)

	# ── RELIQUIAS ACTIVAS ─────────────────────────────────────────────
	if not GameManager.relics.is_empty():
		var relic_label = Label.new()
		relic_label.text = "Reliquias:"
		relic_label.add_theme_font_size_override("font_size", 11)
		relic_label.modulate = Color(0.8, 0.7, 0.4)
		relic_label.position = Vector2(6, 108)
		ui_layer.add_child(relic_label)

		var relic_scene = preload("res://scenes/ui/RelicIcon.tscn")
		for i in range(GameManager.relics.size()):
			var icon = relic_scene.instantiate()
			icon.position = Vector2(6 + i * 48, 120)
			ui_layer.add_child(icon)
			icon.setup(GameManager.relics[i])

	# ── INDICADOR DE FRAGMENTOS ───────────────────────────────────────
	if GameManager.secret_items.size() > 0 or _map_has_secret_rooms():
		var si_container = Panel.new()
		var count = GameManager.secret_items.size()
		si_container.position = Vector2(vp.x - 104, 54)
		si_container.size = Vector2(90, 28)
		var s_style = StyleBoxFlat.new()
		s_style.bg_color = Color(0, 0, 0, 0)
		si_container.add_theme_stylebox_override("panel", s_style)
		ui_layer.add_child(si_container)

		var si_lbl = Label.new()
		si_lbl.text = "✦ " + str(count) + " / 3"
		si_lbl.add_theme_font_size_override("font_size", 13)
		si_lbl.modulate = Color(0.85, 0.72, 0.1) if count > 0 else Color(0.45, 0.42, 0.15)
		si_lbl.size = si_container.size
		si_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		si_container.add_child(si_lbl)

		si_container.mouse_entered.connect(func(): _show_secret_items_tooltip(si_container))
		si_container.mouse_exited.connect(_hide_secret_items_tooltip)

	draw_map()

var _si_tooltip: Panel
var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label = null
var _tooltip_hide_timer: SceneTreeTimer = null
var _tooltip_gen: int = 0  # generación para cancelar timers obsoletos

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
	scroll.position = Vector2(0, 108) # Debajo del header (HUD 50 + título/mundo ~58)
	scroll.size = Vector2(vp.x, vp.y - 108)
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
			if is_obfuscated and (room_type == ROOM_BOSS or room_type == ROOM_FINAL or room_type == ROOM_FINAL_W2 or room_type == ROOM_FINAL_W3):
				if f > GameManager.current_map_floor + 1: # Si faltan más de 2 pisos, ocultar incluso al jefe
					is_obfuscated = true
				else:
					is_obfuscated = false # Revelar jefe cuando estás a punto de llegar
			
			var fi = f
			var ci = c
			var node_data = graph[f][c]

			# ── Nodo visual de sala ──────────────────────────────────
			var visual_state: String
			if is_current:         visual_state = "current"
			elif was_visited:      visual_state = "visited"
			elif already_done:     visual_state = "past"
			elif reachable:        visual_state = "reachable"
			elif is_obfuscated:    visual_state = "obfuscated"
			else:                  visual_state = "future"

			var node_ctrl = Control.new()
			node_ctrl.position = Vector2(pos.x - NODE_W / 2.0, pos.y - NODE_H / 2.0)
			node_ctrl.size = Vector2(NODE_W, NODE_H)
			node_ctrl.pivot_offset = Vector2(NODE_W / 2.0, NODE_H / 2.0)
			node_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS

			var eff_type: String = "" if is_obfuscated else room_type
			var illus = _build_illus_panel(eff_type, visual_state)
			node_ctrl.add_child(illus)

			var badge = _build_badge_panel(eff_type, visual_state)
			node_ctrl.add_child(badge)

			if is_obfuscated and GameManager.sanity < 25:
				_start_shaking_node(node_ctrl)

			if is_current:
				var tw_pulse = illus.create_tween().set_loops()
				tw_pulse.tween_property(illus, "modulate:a", 0.72, 0.65)
				tw_pulse.tween_property(illus, "modulate:a", 1.0, 0.65)

			# Botón invisible para manejar clics
			var btn = Button.new()
			btn.flat = true
			btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.disabled = (not reachable) or already_done
			var empty_style = StyleBoxEmpty.new()
			btn.add_theme_stylebox_override("normal", empty_style)
			btn.add_theme_stylebox_override("hover", empty_style)
			btn.add_theme_stylebox_override("pressed", empty_style)
			btn.add_theme_stylebox_override("disabled", empty_style)
			btn.add_theme_stylebox_override("focus", empty_style)
			btn.pressed.connect(func(): _on_room_selected(fi, ci))
			node_ctrl.add_child(btn)

			# Tooltip y hover — conectar al btn (confiable) no al Control padre
			if not is_obfuscated:
				var tip_type = node_data["type"]
				btn.mouse_entered.connect(func(): _show_tooltip(tip_type, node_ctrl.get_global_rect()))
				btn.mouse_exited.connect(func(): _hide_tooltip())

			if reachable and not already_done:
				btn.mouse_entered.connect(func():
					node_ctrl.create_tween().tween_property(node_ctrl, "scale", Vector2(1.07, 1.07), 0.1)
				)
				btn.mouse_exited.connect(func():
					node_ctrl.create_tween().tween_property(node_ctrl, "scale", Vector2(1.0, 1.0), 0.1)
				)

			map_content.add_child(node_ctrl)

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
	var hud = lbl_info  # lbl_info apunta al HUDBar Panel
	var graph = GameManager.map_graph
	var hp_l = hud.get_node_or_null("StatHP")
	if hp_l: hp_l.text = "❤ %d/%d" % [GameManager.player_hp, GameManager.player_max_hp]
	var coin_l = hud.get_node_or_null("StatCoins")
	if coin_l: coin_l.text = "◆ %d" % GameManager.coins
	var san_l = hud.get_node_or_null("StatSanity")
	if san_l: san_l.text = "⬤ %d/%d" % [GameManager.sanity, GameManager.max_sanity]
	var lore_l = hud.get_node_or_null("StatLore")
	if lore_l: lore_l.text = "📖 %d" % GameManager.lore_progress
	var floor_l = hud.get_node_or_null("StatFloor")
	if floor_l: floor_l.text = "Piso %d/%d" % [GameManager.current_map_floor + 1, graph.size()]

func _build_dev_panel(vp: Vector2) -> Panel:
	var p = Panel.new()
	p.position = Vector2(20, 50)
	p.size = Vector2(210, vp.y - 60)
	p.z_index = 100
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.1, 0.1, 0.92)
	st.set_border_width_all(2)
	st.border_color = Color(0.5, 0.5, 0.5)
	p.add_theme_stylebox_override("panel", st)

	# ScrollContainer ocupa todo el panel con margen interno
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_left",  6)
	scroll.add_theme_constant_override("margin_right", 6)
	scroll.add_theme_constant_override("margin_top",   6)
	scroll.add_theme_constant_override("margin_bottom",6)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	var btns = [
		["+100 Oro",       func(): GameManager.add_coins(100); update_ui()],
		["-20 Cordura",    func(): GameManager.sanity = max(0, GameManager.sanity - 20); update_ui()],
		["+20 Cordura",    func(): GameManager.sanity = min(100, GameManager.sanity + 20); update_ui()],
		["Curar Todo",     func(): GameManager.player_hp = GameManager.player_max_hp; update_ui()],
		["Ir a Tesoro",    func(): GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")],
		["Ir a Mímico",    func():
			GameManager.is_mimic_chest = true
			GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")],
		["Ir a Tienda",    func(): GameManager.go_to_scene("res://scenes/ui/Shop.tscn")],
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
			var target_f = clamp(GameManager.current_map_floor + 2, 0, GameManager.map_graph.size() - 1)
			var target_floor_nodes = GameManager.map_graph[target_f]
			target_floor_nodes[target_floor_nodes.size()-1]["has_rift"] = true
			get_tree().reload_current_scene()],
		["⚄ Evento Dado",  func():
			GameManager.dev_force_dice_event = true
			GameManager.go_to_scene("res://scenes/ui/Event.tscn")],
		["Reset Mapa",     func(): GameManager.map_graph = []; get_tree().reload_current_scene()],
		["⟁ Frag: Símbolo", func():
			if not GameManager.has_secret_item("simbolo_amarillo"):
				GameManager.add_secret_item("simbolo_amarillo")],
		["♪ Frag: Canción", func():
			if not GameManager.has_secret_item("cancion_amarilla"):
				GameManager.add_secret_item("cancion_amarilla")],
		["✉ Frag: Carcosa", func():
			if not GameManager.has_secret_item("carta_carcosa"):
				GameManager.add_secret_item("carta_carcosa")],
		["♟ REY AMARILLO",  func():
			GameManager.is_final_boss = true
			GameManager.current_world = 1
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")],
		["◉ W3: TESTIGO",   func():
			GameManager.is_final_boss = true
			GameManager.current_world = 2
			GameManager.map_graph = []
			GameManager.map_path = {}
			GameManager.current_map_floor = 0
			GameManager.current_map_col = -1
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")],
		["◈ IR A MUNDO III", func():
			GameManager.current_world = 2
			GameManager.map_graph = []
			GameManager.map_path = {}
			GameManager.current_map_floor = 0
			GameManager.current_map_col = -1
			GameManager.go_to_scene("res://scenes/ui/Map.tscn")],
	]

	for b_data in btns:
		var b = Button.new()
		b.text = b_data[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 10)
		b.custom_minimum_size = Vector2(0, 24)
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
	var runes = ["ᚠ", "ᛒ", "ᚱ", "ᛈ", "ᛇ", "ᚦ", "ᛟ", "ᛗ", "ᚾ", "ᛁ", "ᛖ", "ᚷ", "ᛃ", "ᚹ", "ᚫ", "ᛤ", "ᛞ", "ᚣ", "ᛝ", "ᚪ", "ᛠ", "ᚩ", "ᛡ", "ᚢ", "ᛣ"]
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

# ─── Destilados (uso fuera de combate) ───────────────────────────────────────
func _show_destilados_overlay() -> void:
	var vp = get_viewport_rect().size
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 300
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(overlay)

	var panel = Panel.new()
	panel.size = Vector2(400, 320)
	panel.position = (vp - panel.size) / 2.0
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.1)
	ps.set_border_width_all(2); ps.border_color = Color(0.45, 0.3, 0.7)
	ps.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "◈  DESTILADOS  ◈"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.7, 0.5, 0.9)
	title.position = Vector2(0, 16); title.size = Vector2(400, 28)
	panel.add_child(title)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 54); vbox.size = Vector2(360, 210)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	for dest_id in GameManager.destilados:
		var data = GameManager.DESTILADO_DATA.get(dest_id, {})
		var can_use_outside = data.get("out_of_combat", false)

		var slot_panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(360, 64)
		var sp_style = StyleBoxFlat.new()
		sp_style.bg_color = Color(0.08, 0.06, 0.13)
		sp_style.set_border_width_all(1)
		sp_style.border_color = Color(0.35, 0.25, 0.55)
		sp_style.set_corner_radius_all(3)
		slot_panel.add_theme_stylebox_override("panel", sp_style)
		vbox.add_child(slot_panel)

		var lbl_name = Label.new()
		lbl_name.text = data.get("name", dest_id)
		lbl_name.position = Vector2(8, 6); lbl_name.size = Vector2(260, 20)
		lbl_name.add_theme_font_size_override("font_size", 12)
		slot_panel.add_child(lbl_name)

		var lbl_desc = Label.new()
		lbl_desc.text = data.get("desc", "")
		lbl_desc.position = Vector2(8, 26); lbl_desc.size = Vector2(260, 34)
		lbl_desc.add_theme_font_size_override("font_size", 9)
		lbl_desc.modulate = Color(0.75, 0.72, 0.8)
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		slot_panel.add_child(lbl_desc)

		var use_btn = Button.new()
		use_btn.size = Vector2(80, 28)
		use_btn.position = Vector2(272, 18)
		use_btn.add_theme_font_size_override("font_size", 11)
		if can_use_outside:
			use_btn.text = "USAR"
			use_btn.disabled = false
			var _id = dest_id
			var _ov = overlay
			use_btn.pressed.connect(func():
				_ov.queue_free()
				_use_destilado_out_of_combat(_id))
		else:
			use_btn.text = "COMBATE"
			use_btn.disabled = true
			use_btn.modulate = Color(0.5, 0.5, 0.5)
		slot_panel.add_child(use_btn)

	# Cerrar
	var close_btn = Button.new()
	close_btn.text = "CERRAR"
	close_btn.position = Vector2(150, 278); close_btn.size = Vector2(100, 30)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(overlay.queue_free)
	panel.add_child(close_btn)

func _use_destilado_out_of_combat(dest_id: String) -> void:
	match dest_id:
		"lucidez_prestada":
			GameManager.sanity = min(GameManager.max_sanity, GameManager.sanity + 35)
			var deuda = {"name": "Deuda de Cordura", "attack": 0, "defense": 0, "cost": 0,
				"curse": true, "sanity_cost": 15, "innate": true, "exhaust": true}
			GameManager.player_deck.append(deuda)
			GameManager.remove_destilado(dest_id)
			_show_map_flash("Lucidez Prestada: +35 Cordura. El vacío anota tu deuda.")

		"ultimo_vial":
			GameManager.player_hp = GameManager.player_max_hp
			GameManager.sanity = GameManager.max_sanity
			GameManager.destilados_blocked = true
			GameManager.remove_destilado(dest_id)
			_show_map_flash("El Último Vial: curación total. Los Destilados se han sellado.")

		"olvido_puro":
			_show_olvido_puro_selector(dest_id)
			return  # El selector maneja la remoción del destilado

	update_ui()

func _show_olvido_puro_selector(dest_id: String) -> void:
	var vp = get_viewport_rect().size
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 350
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(overlay)

	var panel = Panel.new()
	panel.size = Vector2(500, 400)
	panel.position = (vp - panel.size) / 2.0
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.08)
	ps.set_border_width_all(2); ps.border_color = Color(0.55, 0.45, 0.2)
	ps.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "Olvido Puro — Elige una carta para olvidar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(0.8, 0.75, 0.5)
	title.position = Vector2(0, 14); title.size = Vector2(500, 24)
	panel.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 48); scroll.size = Vector2(480, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	for card_data in GameManager.player_deck:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var lbl = Label.new()
		lbl.text = "%s  (ATK:%d DEF:%d)" % [card_data.get("name","?"), card_data.get("attack",0), card_data.get("defense",0)]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.85, 0.8, 0.75) if not card_data.get("curse", false) else Color(0.8, 0.3, 0.3)
		row.add_child(lbl)

		var del_btn = Button.new()
		del_btn.text = "OLVIDAR +10◆"
		del_btn.custom_minimum_size = Vector2(120, 24)
		del_btn.add_theme_font_size_override("font_size", 10)
		var _cd = card_data; var _ov = overlay; var _dest = dest_id
		del_btn.pressed.connect(func():
			GameManager.player_deck.erase(_cd)
			GameManager.coins += 10
			GameManager.remove_destilado(_dest)
			_ov.queue_free()
			_show_map_flash("Olvido Puro: '" + _cd.get("name","?") + "' olvidada. +10 oro.")
			update_ui())
		row.add_child(del_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "CANCELAR"
	cancel_btn.position = Vector2(195, 350); cancel_btn.size = Vector2(110, 30)
	cancel_btn.add_theme_font_size_override("font_size", 12)
	cancel_btn.pressed.connect(overlay.queue_free)
	panel.add_child(cancel_btn)

func _show_map_flash(text: String) -> void:
	var vp = get_viewport_rect().size
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.8, 0.7, 1.0)
	lbl.position = Vector2(0, vp.y * 0.45); lbl.size = Vector2(vp.x, 30)
	lbl.z_index = 200
	ui_layer.add_child(lbl)
	var tw = create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)

# ─── Helpers visuales de nodos ───────────────────────────────────────────────
func _style_top_button(btn: Button, accent: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.1, 0.9)
	s.set_border_width_all(1)
	s.border_color = accent.lightened(0.1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = accent.darkened(0.15)
	sh.border_color = accent.lightened(0.35)
	btn.add_theme_stylebox_override("hover", sh)
	var sp = s.duplicate()
	sp.bg_color = accent.darkened(0.05)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", s)

func _build_illus_panel(room_type: String, visual_state: String) -> Panel:
	var p = Panel.new()
	p.position = Vector2.ZERO
	p.size = Vector2(NODE_W, NODE_ILLUS_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(7)
	s.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	s.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)

	if room_type.is_empty():
		s.bg_color = Color(0.05, 0.04, 0.08, 0.82)
		s.set_border_width_all(1)
		s.border_color = Color(0.2, 0.18, 0.28, 0.4)
	else:
		var base = ROOM_COLORS[room_type]
		match visual_state:
			"current":
				s.bg_color = base.darkened(0.18)
				s.set_border_width_all(2)
				s.border_color = Color(1.0, 0.88, 0.25)
				s.shadow_color = Color(1.0, 0.88, 0.25, 0.55)
				s.shadow_size = 7
			"reachable":
				s.bg_color = base.darkened(0.3)
				s.set_border_width_all(2)
				s.border_color = base.lightened(0.28)
				s.shadow_color = base
				s.shadow_size = 4
			"visited":
				s.bg_color = Color(0.07, 0.06, 0.03, 0.88)
				s.set_border_width_all(1)
				s.border_color = Color(0.7, 0.62, 0.2, 0.55)
			"past":
				s.bg_color = Color(0.03, 0.02, 0.04, 0.4)
				s.set_border_width_all(0)
			_:  # future / obfuscated
				s.bg_color = base.darkened(0.55)
				s.set_border_width_all(1)
				s.border_color = base.darkened(0.18)

	p.add_theme_stylebox_override("panel", s)

	var icon_lbl = Label.new()
	if room_type.is_empty():
		var _r = ["ᚠ","ᛒ","ᚱ","ᛈ","ᛇ","ᚦ","ᛟ","ᛗ","ᚾ","ᛁ","ᛖ","ᚷ","ᛃ","ᚹ","ᚫ","ᛤ","ᛞ","ᚣ","ᛝ","ᚪ","ᛠ","ᚩ","ᛡ","ᚢ","ᛣ"]
		icon_lbl.text = _r[randi()%_r.size()] + " " + _r[randi()%_r.size()] + " " + _r[randi()%_r.size()]
	else:
		icon_lbl.text = ROOM_BIG_ICONS.get(room_type, "ᛒ")
	icon_lbl.add_theme_font_override("font", ThemeDB.fallback_font)  # garantiza glifos unicode
	icon_lbl.add_theme_font_size_override("font_size", 20 if room_type.is_empty() else 34)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match visual_state:
		"past":    icon_lbl.modulate.a = 0.3
		"future":  icon_lbl.modulate.a = 0.5
		"visited": icon_lbl.modulate.a = 0.6
	p.add_child(icon_lbl)

	if not room_type.is_empty() and visual_state not in ["past"]:
		_add_corner_decorations(p, ROOM_COLORS[room_type])

	match visual_state:
		"past":   p.modulate.a = 0.55
		"future": p.modulate.a = 0.75

	return p

func _build_badge_panel(room_type: String, visual_state: String) -> Panel:
	var badge_w := NODE_W * 0.72
	var p = Panel.new()
	p.position = Vector2((NODE_W - badge_w) / 2.0, NODE_ILLUS_H + 5.0)
	p.size = Vector2(badge_w, NODE_BADGE_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.06, 0.09, 0.92)
	s.set_corner_radius_all(11)
	s.set_border_width_all(1)

	if room_type.is_empty():
		s.border_color = Color(0.2, 0.18, 0.28, 0.3)
	else:
		var base = ROOM_COLORS[room_type]
		match visual_state:
			"current":
				s.border_color = Color(1.0, 0.88, 0.25, 0.9)
				s.bg_color = Color(0.12, 0.1, 0.04, 0.96)
			"reachable":
				s.border_color = base.lightened(0.3)
			"visited":
				s.border_color = Color(0.62, 0.55, 0.2, 0.5)
			_:
				s.border_color = base.darkened(0.12)

	p.add_theme_stylebox_override("panel", s)

	var icon_lbl = Label.new()
	if room_type.is_empty():
		var _r = ["ᚠ","ᛒ","ᚱ","ᛈ","ᛇ","ᚦ","ᛟ","ᛗ","ᚾ","ᛁ","ᛖ","ᚷ","ᛃ","ᚹ","ᚫ","ᛤ","ᛞ","ᚣ","ᛝ","ᚪ","ᛠ","ᚩ","ᛡ","ᚢ","ᛣ"]
		icon_lbl.text = _r[randi()%_r.size()] + " " + _r[randi()%_r.size()]
	else:
		icon_lbl.text = ROOM_BIG_ICONS.get(room_type, "ᛡ")
	icon_lbl.add_theme_font_override("font", ThemeDB.fallback_font)  # garantiza glifos unicode
	icon_lbl.add_theme_font_size_override("font_size", 14)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not room_type.is_empty():
		var base = ROOM_COLORS[room_type]
		icon_lbl.modulate = base.lightened(0.5) if visual_state in ["current", "reachable"] else base.lightened(0.15)
	p.add_child(icon_lbl)

	match visual_state:
		"past":    p.modulate.a = 0.55
		"future":  p.modulate.a = 0.75
		"visited": p.modulate.a = 0.62

	return p

func _add_corner_decorations(parent: Panel, color: Color) -> void:
	var sz := parent.size
	var corners := [
		{"pos": Vector2(3.0, 2.0),          "text": "⌜"},
		{"pos": Vector2(sz.x - 13.0, 2.0),  "text": "⌝"},
		{"pos": Vector2(3.0, sz.y - 15.0),  "text": "⌞"},
		{"pos": Vector2(sz.x - 13.0, sz.y - 15.0), "text": "⌟"},
	]
	for cd in corners:
		var lbl = Label.new()
		lbl.text = cd["text"]
		lbl.position = cd["pos"]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = color.lightened(0.1)
		lbl.modulate.a = 0.3
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)

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
		ROOM_MIMIC:
			GameManager.is_mimic_chest = true
			GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")
		ROOM_BOSS:
			GameManager.is_boss_fight = true
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
		ROOM_FINAL, ROOM_FINAL_W2:
			GameManager.is_final_boss = true
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
		ROOM_FINAL_W3:
			GameManager.is_final_boss = true
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
		ROOM_FRAGMENT:
			_show_fragment_w3_overlay(floor_idx, col_idx)
		ROOM_VAULT_W3:
			_show_vault_w3_overlay()
		ROOM_SECRET:
			var item_id = GameManager.map_graph[floor_idx][col_idx].get("item_id", "")
			_show_secret_item_overlay(item_id)

func _map_has_secret_rooms() -> bool:
	for floor_nodes in GameManager.map_graph:
		for node in floor_nodes:
			if node.type == ROOM_SECRET:
				return true
	return false

func _show_fragment_w3_overlay(floor_idx: int, col_idx: int) -> void:
	var vp = get_viewport_rect().size
	var layer = CanvasLayer.new(); layer.layer = 300; add_child(layer)
	var overlay = ColorRect.new(); overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP; layer.add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.88, 0.3)

	var panel = Panel.new(); panel.size = Vector2(min(vp.x * 0.65, 540), 280)
	panel.position = (vp - panel.size) / 2; panel.modulate.a = 0.0
	var s = StyleBoxFlat.new(); s.bg_color = Color(0.04, 0.0, 0.1)
	s.set_border_width_all(2); s.border_color = Color(0.5, 0.1, 0.85); s.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", s); overlay.add_child(panel)
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)

	var title = Label.new(); title.text = "◈ FRAGMENTO DE CARCOSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.7, 0.2, 1.0); title.position = Vector2(0, 20)
	title.size = Vector2(panel.size.x, 36); panel.add_child(title)

	var is_prince = GameManager.selected_character == "prince"
	var desc_text: String
	if is_prince:
		desc_text = "La grieta te reconoce.\n+1 RESONANCIA (permanente esta run)\nEl abismo amplifica tu poder."
	else:
		desc_text = "El fragmento quema tu mente.\n-15 CORDURA MÁXIMA (permanente esta run)\nCosto del conocimiento prohibido."

	var desc = Label.new(); desc.text = desc_text
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 16)
	desc.modulate = Color(0.85, 0.75, 0.95)
	desc.position = Vector2(30, 75); desc.size = Vector2(panel.size.x - 60, 120); panel.add_child(desc)

	var collect_btn = Button.new(); collect_btn.text = "ABSORBER FRAGMENTO"
	collect_btn.custom_minimum_size = Vector2(220, 44)
	collect_btn.position = Vector2(panel.size.x / 2 - 110, 200); panel.add_child(collect_btn)
	collect_btn.pressed.connect(func():
		GameManager.collect_fragment_w3()
		GameManager.map_graph[floor_idx][col_idx].type = ROOM_COMBAT  # Marcar como visitada
		var tw_out = create_tween(); tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
		tw_out.finished.connect(func(): layer.queue_free(); GameManager.go_to_scene("res://scenes/ui/Map.tscn"))
	)

func _show_vault_w3_overlay() -> void:
	var vp = get_viewport_rect().size
	var layer = CanvasLayer.new(); layer.layer = 300; add_child(layer)
	var overlay = ColorRect.new(); overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP; layer.add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.92, 0.3)

	var panel = Panel.new(); panel.size = Vector2(min(vp.x * 0.65, 540), 300)
	panel.position = (vp - panel.size) / 2; panel.modulate.a = 0.0
	var s = StyleBoxFlat.new(); s.bg_color = Color(0.05, 0.0, 0.12)
	s.set_border_width_all(3); s.border_color = Color(0.65, 0.1, 1.0); s.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", s); overlay.add_child(panel)
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)

	var title = Label.new(); title.text = "⬡ BÓVEDA DEL UMBRAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.8, 0.3, 1.0); title.position = Vector2(0, 18)
	title.size = Vector2(panel.size.x, 36); panel.add_child(title)

	var desc = Label.new()
	desc.text = "Has reunido los fragmentos.\nEl Testigo ha abierto su tercer ojo para ti.\n\nRELIQUIA: Ojo del Testigo\nVe el patron completo de todos los enemigos W3.\nCosto: -20 Cordura maxima permanente."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 15)
	desc.modulate = Color(0.85, 0.75, 0.95)
	desc.position = Vector2(30, 70); desc.size = Vector2(panel.size.x - 60, 150); panel.add_child(desc)

	var take_btn = Button.new(); take_btn.text = "TOMAR EL OJO DEL TESTIGO"
	take_btn.custom_minimum_size = Vector2(240, 44)
	take_btn.position = Vector2(panel.size.x / 2 - 120, 230); panel.add_child(take_btn)
	take_btn.pressed.connect(func():
		GameManager.add_relic("ojo_testigo")
		GameManager.max_sanity = max(20, GameManager.max_sanity - 20)
		GameManager.sanity = min(GameManager.sanity, GameManager.max_sanity)
		var tw_out = create_tween(); tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
		tw_out.finished.connect(func(): layer.queue_free(); GameManager.go_to_scene("res://scenes/ui/Map.tscn"))
	)

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
	if _tooltip_panel and is_instance_valid(_tooltip_panel):
		_tooltip_panel.queue_free()
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.z_index = 200
	_tooltip_panel.visible = false
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.05, 0.04, 0.08, 0.95)
	sbox.set_border_width_all(1)
	sbox.border_color = Color(0.4, 0.35, 0.15)
	sbox.set_corner_radius_all(5)
	sbox.content_margin_left = 10
	sbox.content_margin_right = 10
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	_tooltip_panel.add_theme_stylebox_override("panel", sbox)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tooltip_label.custom_minimum_size = Vector2(220, 0)
	_tooltip_panel.add_child(_tooltip_label)
	add_child(_tooltip_panel)

func _show_tooltip(room_type: String, btn_rect: Rect2) -> void:
	_tooltip_gen += 1              # invalida cualquier timer de hide pendiente
	_tooltip_hide_timer = null
	if not _tooltip_label or not ROOM_DESCRIPTIONS.has(room_type):
		return
	var desc = ROOM_DESCRIPTIONS[room_type]

	# Sanity corruption: at < 30 sanity, non-current rooms show garbled text
	var title_text: String
	var flavor_text: String
	if GameManager.sanity < 30 and randf() < 0.5:
		var corrupted = ROOM_CORRUPTED_DESCRIPTIONS[randi() % ROOM_CORRUPTED_DESCRIPTIONS.size()]
		title_text = corrupted[0]
		flavor_text = corrupted[1]
	else:
		title_text = desc[0]
		flavor_text = desc[1]
		# Append a rotating omen from the 3rd element if present
		if desc.size() > 2:
			var omens: Array = desc[2]
			if not omens.is_empty():
				flavor_text += "\n\n« " + omens[randi() % omens.size()] + " »"

	_tooltip_label.text = title_text + "\n" + flavor_text
	_tooltip_panel.position = Vector2(-9999, -9999)
	_tooltip_panel.visible = true

	await get_tree().process_frame
	if not is_instance_valid(_tooltip_panel): return

	var vp = get_viewport_rect().size
	var panel_w = _tooltip_panel.size.x
	var tx = btn_rect.position.x + btn_rect.size.x + 8
	if tx + panel_w > vp.x:
		tx = btn_rect.position.x - panel_w - 8
	var panel_h = _tooltip_panel.size.y
	var ty = btn_rect.position.y
	if ty + panel_h > vp.y - 8:
		ty = vp.y - panel_h - 8
	ty = max(8.0, ty)
	_tooltip_panel.position = Vector2(tx, ty)

func _hide_tooltip() -> void:
	var gen := _tooltip_gen  # captura la generación actual
	_tooltip_hide_timer = get_tree().create_timer(0.7)
	_tooltip_hide_timer.timeout.connect(func():
		if gen != _tooltip_gen:  # _show_tooltip se llamó de nuevo — no ocultar
			return
		_tooltip_hide_timer = null
		if _tooltip_panel:
			_tooltip_panel.visible = false
	)

# ── NPCs del Mapa ─────────────────────────────────────────────────────────────
func _spawn_map_npcs() -> void:
	var vp = get_viewport_rect().size
	var npc_layer = CanvasLayer.new()
	npc_layer.layer = 10
	add_child(npc_layer)
	# El Caminante del Umbral
	if GameManager.lore_progress >= 15 and not GameManager.npc_met.get("caminante", false):
		_create_npc_node("caminante", Vector2(vp.x - 120, vp.y * 0.45), npc_layer)
	# El Mensajero Amarillo (post-boss, lore alto)
	if GameManager.lore_progress >= 30 and not GameManager.npc_met.get("mensajero", false):
		_create_npc_node("mensajero", Vector2(10, vp.y * 0.55), npc_layer)
	# La Sombra Archivada — evento automático al cargar el mapa
	if GameManager.total_runs >= 3 and not GameManager.sombra_met:
		get_tree().create_timer(0.5).timeout.connect(func(): _open_npc_dialogue("sombra"), CONNECT_ONE_SHOT)

func _create_npc_node(npc_id: String, pos: Vector2, parent: Node) -> void:
	var data = NPC_DIALOGUES[npc_id]
	var btn = Button.new()
	btn.name = "NPC_" + npc_id
	btn.text = data["portrait"] + "\n" + data["name"]
	btn.position = pos
	btn.size = Vector2(100, 70)
	btn.z_index = 20
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.05, 0.04, 0.08, 0.88)
	sbox.set_border_width_all(1)
	sbox.border_color = Color(0.55, 0.45, 0.12)
	sbox.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sbox)
	btn.add_theme_stylebox_override("hover", sbox)
	btn.add_theme_stylebox_override("pressed", sbox)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func(): _open_npc_dialogue(npc_id))
	parent.add_child(btn)
	# Animación de pulso idle DESPUÉS de add_child
	var tw = create_tween().set_loops()
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.9).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(btn, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

func _open_npc_dialogue(npc_id: String) -> void:
	var data = NPC_DIALOGUES[npc_id]
	var vp = get_viewport_rect().size

	var layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	# Fondo semitransparente
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.82, 0.3)

	# Panel principal
	var panel = Panel.new()
	panel.size = Vector2(min(vp.x * 0.68, 580), min(vp.y * 0.65, 480))
	panel.position = (vp - panel.size) / 2
	panel.modulate.a = 0.0
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.03)
	s.set_border_width_all(2)
	s.border_color = Color(0.55, 0.45, 0.12)
	s.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", s)
	overlay.add_child(panel)
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.35)

	# Retrato y nombre
	var portrait_lbl = Label.new()
	portrait_lbl.text = data["portrait"]
	portrait_lbl.add_theme_font_size_override("font_size", 42)
	portrait_lbl.position = Vector2(20, 14)
	portrait_lbl.size = Vector2(60, 56)
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(portrait_lbl)

	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = Color(0.9, 0.78, 0.2)
	name_lbl.position = Vector2(86, 24)
	name_lbl.size = Vector2(panel.size.x - 100, 36)
	panel.add_child(name_lbl)

	var sep = ColorRect.new()
	sep.color = Color(0.5, 0.4, 0.1, 0.5)
	sep.size = Vector2(panel.size.x - 40, 1)
	sep.position = Vector2(20, 76)
	panel.add_child(sep)

	# Texto de diálogo
	var text_lbl = Label.new()
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.size = Vector2(panel.size.x - 40, 120)
	text_lbl.position = Vector2(20, 88)
	text_lbl.add_theme_font_size_override("font_size", 15)
	text_lbl.modulate = Color(0.88, 0.84, 0.76)
	panel.add_child(text_lbl)

	# Contenedor de opciones
	var choices_vbox = VBoxContainer.new()
	choices_vbox.position = Vector2(20, 220)
	choices_vbox.size = Vector2(panel.size.x - 40, panel.size.y - 240)
	choices_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(choices_vbox)

	# Función para navegar líneas del diálogo
	var lines: Array = data["lines"]
	var _show_line_ref: Array = [Callable()]
	_show_line_ref[0] = func(line_id: String) -> void:
		# Encontrar la línea por id
		var line: Dictionary = {}
		for l in lines:
			if l.get("id", "start") == line_id:
				line = l
				break
		if line.is_empty():
			return

		# Limpiar opciones previas
		for ch in choices_vbox.get_children():
			ch.queue_free()

		# Mostrar texto con efecto typewriter
		var full_text: String = line["text"]
		text_lbl.text = ""
		var tw_type = create_tween()
		tw_type.tween_method(func(n: int): text_lbl.text = full_text.substr(0, n),
			0, full_text.length(), float(full_text.length()) * 0.04)

		# Aplicar efectos si existen
		if line.has("effect"):
			var eff: Dictionary = line["effect"]
			if eff.has("lore_progress"):
				GameManager.lore_progress += int(eff["lore_progress"])
			if eff.has("sanity"):
				GameManager.sanity = clamp(GameManager.sanity + int(eff["sanity"]), 0, GameManager.max_sanity)
			if eff.get("sacrifice_relic", false):
				if not GameManager.relics.is_empty():
					GameManager.relics.pop_back()
			if eff.get("secret_card", false):
				# Añadir carta especial de la Sombra
				GameManager.player_deck.append({"name": "Eco Archivado", "attack": 3, "defense": 3, "cost": 2})

		# Generar botones de elección
		var choices: Array = line.get("choices", [])
		if choices.is_empty() or (choices.size() == 1 and choices[0].get("next", "end") == "end"):
			# Sin elección real — botón de cierre
			var close_btn = Button.new()
			close_btn.text = "Partir."
			close_btn.custom_minimum_size = Vector2(200, 38)
			choices_vbox.add_child(close_btn)
			close_btn.pressed.connect(func():
				GameManager.npc_met[npc_id] = true
				if npc_id == "sombra":
					GameManager.sombra_met = true
					GameManager.save_meta()
				GameManager.save_run()
				# Eliminar el nodo NPC del mapa
				var npc_btn = find_child("NPC_" + npc_id, true, false)
				if npc_btn:
					npc_btn.queue_free()
				var tw_out = create_tween()
				tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
				tw_out.finished.connect(layer.queue_free)
			)
		else:
			for choice in choices:
				var cbtn = Button.new()
				cbtn.text = choice["label"]
				cbtn.custom_minimum_size = Vector2(panel.size.x - 40, 38)
				cbtn.autowrap_mode = TextServer.AUTOWRAP_WORD
				choices_vbox.add_child(cbtn)
				var next_id: String = choice.get("next", "end")
				# Aplicar efecto de la elección si tiene
				var choice_effect: Dictionary = choice.get("effect", {})
				cbtn.pressed.connect(func():
					if not choice_effect.is_empty():
						if choice_effect.has("lore_progress"):
							GameManager.lore_progress += int(choice_effect["lore_progress"])
						if choice_effect.has("sanity"):
							GameManager.sanity = clamp(GameManager.sanity + int(choice_effect["sanity"]), 0, GameManager.max_sanity)
						if choice_effect.get("sacrifice_relic", false):
							if not GameManager.relics.is_empty():
								GameManager.relics.pop_back()
						if choice_effect.get("secret_card", false):
							GameManager.player_deck.append({"name": "Eco Archivado", "attack": 3, "defense": 3, "cost": 2})
					if next_id == "end":
						GameManager.npc_met[npc_id] = true
						if npc_id == "sombra":
							GameManager.sombra_met = true
							GameManager.save_meta()
						GameManager.save_run()
						for ch in get_children():
							if ch is Button and ch.text.begins_with(data["portrait"]):
								ch.queue_free()
						var tw_out = create_tween()
						tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
						tw_out.finished.connect(layer.queue_free)
					else:
						_show_line_ref[0].call(next_id)
				)

	_show_line_ref[0].call("start")
