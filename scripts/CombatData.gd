extends Node
class_name CombatData

# ── Datos de Personajes ────────────────────────────────────────────────────────
const CHAR_DATA = {
	"conquistador": {"symbol": "♜", "color": Color(0.8, 0.3, 0.3)},
	"estratega":    {"symbol": "♝", "color": Color(0.3, 0.5, 0.8)},
	"guardian":     {"symbol": "♞", "color": Color(0.4, 0.75, 0.4)},
}

const PASSIVE_DESCRIPTIONS = {
	"conquistador": "CONQUISTA: Al matar a un enemigo, tus Siervos ganan +1 ATK permanente y recuperas 3 de vida.",
	"estratega":    "LOGICA: Tus cartas de Inquisidor Ciego cuestan -1 de energia. Robas 1 carta extra al inicio de cada combate.",
	"guardian":     "RESILIENCIA: Generas 1 de Furia por cada 5 de daño recibido. A las 3 cargas, tu siguiente ataque hace daño doble."
}

# ── Pools de encuentros ────────────────────────────────────────────────────────
const NORMAL_POOLS = [
	[{"name": "Siervo Rebelde", "hp": 22, "pattern": [{"type": "attack", "value": 5}]}],
	[{"name": "Peon Maldito",   "hp": 18, "pattern": [{"type": "attack", "value": 7}]}],
	[{"name": "Susurrador del Vacio", "hp": 25, "pattern": [{"type": "insanity", "value": 6}]}],
	[{"name": "Idolo Corrupto", "hp": 40, "pattern": [{"type": "attack", "value": 4}, {"type": "insanity", "value": 4}]}],
	[{"name": "Alfil Caido",    "hp": 30, "pattern": [{"type": "attack", "value": 4}, {"type": "shield", "value": 6}]}],
	[{"name": "Espectro",       "hp": 14, "pattern": [{"type": "attack", "value": 9}]}],
	[{"name": "El Penitente",   "hp": 26, "pattern": [{"type": "attack", "value": 5}], "peaceful": true, "peaceful_turns": 3}],
	[
		{"name": "Siervo Rebelde", "hp": 14, "pattern": [{"type": "attack", "value": 4}]},
		{"name": "Siervo Rebelde", "hp": 14, "pattern": [{"type": "attack", "value": 4}]},
	],
	[
		{"name": "Peon Maldito", "hp": 12, "pattern": [{"type": "attack", "value": 5}]},
		{"name": "Espectro",     "hp": 10, "pattern": [{"type": "attack", "value": 6}]},
	],
]

const ELITE_POOLS = [
	[{"name": "Avatar de Hastur", "hp": 150, "pattern": [{"type": "attack", "value": 15}, {"type": "insanity", "value": 10}, {"type": "shield", "value": 15}]}],
	[{"name": "Torre Rota",       "hp": 45, "pattern": [{"type": "attack", "value": 8}]}],
	[{"name": "Caballero Roto",   "hp": 38, "pattern": [{"type": "attack", "value": 6}, {"type": "shield", "value": 8}, {"type": "attack", "value": 10}]}],
	[{"name": "Inquisidor Ciego", "hp": 50, "pattern": [{"type": "attack", "value": 5}, {"type": "attack", "value": 5}, {"type": "shield", "value": 10}]}],
	[{"name": "Caballero Caido",  "hp": 55, "pattern": [{"type": "attack", "value": 12}, {"type": "attack", "value": 4}]}],
	[{"name": "Alfil Hereje",     "hp": 48, "pattern": [{"type": "insanity", "value": 8}, {"type": "attack", "value": 6}]}],
]

const BOSS_POOLS_W1 = [
	[{"name": "EL CARCELERO",    "hp": 100, "pattern": [{"type": "attack", "value": 10}, {"type": "shield", "value": 10}]}],
	[{"name": "LA DAMA DE CENIZA", "hp": 85,  "pattern": [{"type": "attack", "value": 8}, {"type": "attack", "value": 14}]}],
	[{"name": "EL MARISCAL",     "hp": 110, "pattern": [{"type": "attack", "value": 12}, {"type": "attack", "value": 6}]}],
]

# ── Diálogos y barks ───────────────────────────────────────────────────────────
const ENEMY_COMBAT_BANTER = {
	"Siervo Rebelde":   ["...muere...", "no... escapes...", "el tablero... te reclama..."],
	"Peon Maldito":     ["maldito seas...", "nadie sale...", "somos todos lo mismo..."],
	"Idolo Corrupto":   ["la ceniza llama...", "mira el sol negro...", "tu voz se apaga..."],
	"El Penitente":     ["...perdon...", "...el Rey observa...", "...aun no es tu hora..."],
	"Avatar de Hastur": [
		"Ese fragmento quema tu mano... porque no es tuya.",
		"Ladron de realidades. Devuelve lo que el Rey ha perdido.",
		"¿Crees que puedes cargar con la eternidad? Tus hombros ya se rompen.",
		"Viniste por ceniza y robaste oro. El Tablero Dorado reclama su deuda.",
		"Cada pieza que guardas es un grito que te encontrara.",
		"No eres un jugador. Eres solo un receptaculo para lo que nos pertenece."
	]
}

const VICTORY_PHRASES = ["EL ECO SE DESVANECE", "MOVIMIENTO COMPLETADO", "PIEZA ELIMINADA", "EL REY SONRIE"]

# ── Mensajes Míticos de Cordura ───────────────────────────────────────────────
const MYTH_60 = ["EL QUE OBSERVA TODO", "LAS SOMBRAS SE ALARGAN", "EL TABLERO RESPIRA"]
const MYTH_40 = ["TUS PENSAMIENTOS NO SON TUYOS", "LA CORDURA ES UNA JAULA", "EL REY TE HA ENCONTRADO"]
const MYTH_20 = ["EL FINAL DEL JUEGO SE ACERCA", "SOLO QUEDA EL VACIO", "YA NO ERES UNA PIEZA"]
