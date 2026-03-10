extends Node

var player_deck: Array = [
	{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
	{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
	{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
	{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2},
	{"name": "Cabalgante del Vacio", "attack": 4, "defense": 0, "cost": 2},
]

var player_hp: int = 40
var player_max_hp: int = 40
var player_max_energy: int = 3
var sanity: int = 100
var sanity_notified: bool = false
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
var selected_character: String = "conquistador"
var lore_progress: int = 0       # avanza con cada combate ganado, persiste entre runs
var total_runs: int = 0          # cuantas runs completas ha hecho el jugador
var current_world: int = 0       # 0 = Mundo I, 1 = Mundo II
var map_graph: Array = []        # [{type, connections:[col_idx,...]}] por piso
var current_map_col: int = -1    # columna elegida en el piso anterior (-1 = inicio)

var relics: Array = []           # lista de nombres de reliquias activas
var secret_items: Array = []     # objetos misteriosos recogidos en esta run
var is_hastur_fight: bool = false
var player_won: bool = false

# --- PROGRESO PERMANENTE ---
# Estructura: {"conquistador": [{"name": "Siervo Quebrado+1", ...}], "estratega": [], ...}
var permanent_deck_upgrades: Dictionary = {
	"conquistador": [],
	"estratega": [],
	"guardian": []
}
var has_eternal_fragment: bool = false # El objeto misterioso de esta run

# DEBUG
var dev_force_avatar: bool = false
var dev_force_penitente: bool = false

const SAVE_PATH = "user://meta_progress.save"

func save_meta_progress() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"upgrades": permanent_deck_upgrades,
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
		if data.has("upgrades"): permanent_deck_upgrades = data["upgrades"]
		if data.has("lore"): lore_progress = data["lore"]
		if data.has("runs"): total_runs = data["runs"]
		file.close()

func _ready() -> void:
	load_meta_progress()

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

func add_secret_item(item_id: String) -> void:
	if not has_secret_item(item_id):
		secret_items.append(item_id)

func has_all_secret_items() -> bool:
	return ("simbolo_amarillo" in secret_items and
		"cancion_amarilla" in secret_items and
		"carta_carcosa" in secret_items)

# ─── Reliquias disponibles ────────────────────────────────────────────────────
const RELIC_DATA = {
	"ficha_marfil": {
		"name": "Ficha de Marfil",
		"desc": "+1 energia al inicio de cada combate.",
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
	},
	"reloj_negro": {
		"name": "Reloj de Arena Negra",
		"desc": "Cada 3 cartas jugadas, recuperas 1 de Energia.",
	},
	"caliz_olvido": {
		"name": "Caliz del Olvido",
		"desc": "Al vencer un Elite, +1 Energia maxima permanentemente.",
	},
	"velo_dama": {
		"name": "Velo de la Dama",
		"desc": "Una vez por combate, niegas la muerte (quedas en 1 HP).",
	},
	"espejo_fragmentado": {
		"name": "Espejo Fragmentado",
		"desc": "Tu primera carta cada turno se juega dos veces.",
	},
	"corona_espinas": {
		"name": "Corona de Espinas",
		"desc": "+10 HP maximo.\nTodas las cartas cuestan +1 energia.",
	},
	"reloj_roto": {
		"name": "Reloj de Arena Roto",
		"desc": "Robas 1 carta extra al inicio de cada turno.",
	},
	"lengua_tablero": {
		"name": "Lengua del Tablero",
		"desc": "Entiendes a los enemigos que hablan en idioma desconocido.\nMaldicion: una carta 'Peso de la Verdad' aparece en tu mano cada combate.",
	},
}

func has_relic(relic_id: String) -> bool:
	return relic_id in relics

func add_relic(relic_id: String) -> void:
	if not has_relic(relic_id):
		relics.append(relic_id)
		_apply_passive_relic(relic_id)

func _apply_passive_relic(relic_id: String) -> void:
	match relic_id:
		"corona_espinas":
			player_max_hp += 10
			player_hp += 10

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

var siervo_atk_bonus_perm: int = 0 # Bono permanente del Conquistador

func reset_run() -> void:
	sanity = 100
	sanity_notified = false
	siervo_atk_bonus_perm = 0
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
	selected_character = "conquistador"
	total_runs += 1
	relics = []
	secret_items = []
	is_hastur_fight = false
	player_won = false
	current_world = 0
	map_graph = []
	current_map_col = -1
