extends Node
class_name CombatData

# ── Datos de Personajes ────────────────────────────────────────────────────────
const CHAR_DATA = {
	"mahar":     {"symbol": "♜", "color": Color(0.8, 0.3, 0.3)},
	"estratega": {"symbol": "♝", "color": Color(0.3, 0.5, 0.8)},
	"guardian":  {"symbol": "♞", "color": Color(0.4, 0.75, 0.4)},
	"prince":    {"symbol": "♔", "color": Color(0.5, 0.2, 0.8)},
}

const PASSIVE_DESCRIPTIONS = {
	"mahar":     "FERVOR: Cordura >= 60: tu primer ataque de cada turno inflige +4 de daño (el golpe guiado). Cordura < 40: pierdes 2 HP por turno, todos los ataques infligen +2 de daño (fe rota).",
	"estratega": "PRESION TACTICA: Cada carta jugada genera 1 Presion (max 5). La Presion reduce el ATK de todos los enemigos en 1 por punto este turno. Al inicio del turno enemigo, la Presion se resetea. Robas 1 carta extra al inicio de combate.",
	"guardian":  "RESILIENCIA: Cada vez que generas 6 o mas Escudo en un turno, ganas 1 Furia. A las 3 cargas: tu siguiente ataque hace dano doble O el proximo golpe recibido refleja el dano absorbido al atacante.",
	"prince":    "RESONANCIA: Cartas de Escala x1.5 (Cordura < 60) | x2 (Cordura < 35). Inicio de combate: -8 Cordura. Daño de Demencia recibido → Escudo parcial.",
}

# ── Pools de encuentros ────────────────────────────────────────────────────────
const NORMAL_POOLS = [
	[{"name": "Siervo Rebelde", "hp": 28, "pattern": [{"type": "attack", "value": 7}]}],
	[{"name": "Peon Maldito",   "hp": 24, "pattern": [{"type": "attack", "value": 9}]}],
	[{"name": "Susurrador del Vacio", "hp": 32, "pattern": [{"type": "insanity", "value": 8}, {"type": "attack", "value": 4}]}],
	[{"name": "Idolo Corrupto", "hp": 50, "pattern": [{"type": "attack", "value": 6}, {"type": "insanity", "value": 6}]}],
	[{"name": "Alfil Caido",    "hp": 38, "pattern": [{"type": "attack", "value": 6}, {"type": "insanity", "value": 4}]}],
	[{"name": "Espectro",       "hp": 18, "pattern": [{"type": "attack", "value": 12}]}],
	[{"name": "El Penitente",   "hp": 35, "pattern": [{"type": "attack", "value": 7}], "peaceful": true, "peaceful_turns": 3}],
	[
		{"name": "Siervo Rebelde", "hp": 20, "pattern": [{"type": "attack", "value": 5}]},
		{"name": "Siervo Rebelde", "hp": 20, "pattern": [{"type": "attack", "value": 5}]},
	],
]

const ELITE_POOLS = [
	[{"name": "Avatar de Hastur", "hp": 350, "pattern": [{"type": "attack", "value": 15}, {"type": "insanity", "value": 10}, {"type": "shield", "value": 15}]}],
	[{"name": "Torre Rota",       "hp": 65, "pattern": [{"type": "attack", "value": 12}]}],
	[{"name": "Caballero Roto",   "hp": 55, "pattern": [{"type": "attack", "value": 8}, {"type": "shield", "value": 12}, {"type": "attack", "value": 14}]}],
	[{"name": "Inquisidor Ciego", "hp": 70, "pattern": [{"type": "attack", "value": 8}, {"type": "attack", "value": 8}, {"type": "shield", "value": 15}]}],
]

const MIMIC_POOL = [
	{"name": "La Forma Sin Nombre", "hp": 65, "pattern": [
		{"type": "attack",   "value": 11},
		{"type": "shield",   "value": 10},
		{"type": "insanity", "value": 13},
	]}
]

const BOSS_POOLS_W1 = [
	[{"name": "EL CARCELERO",    "hp": 120, "pattern": [{"type": "attack", "value": 12}, {"type": "shield", "value": 12}]}],
	[{"name": "LA DAMA DE CENIZA", "hp": 100, "pattern": [{"type": "attack", "value": 10}, {"type": "attack", "value": 16}]}],
]

const BOSS_POOLS_W2 = [
	[{"name": "EL ARCHIVERO DE CENIZA", "hp": 160, "pattern": [{"type": "insanity", "value": 12}, {"type": "attack", "value": 14}]}],
	[{"name": "EL HERALDO DE ORO",      "hp": 185, "pattern": [{"type": "attack", "value": 18}, {"type": "shield", "value": 20}]}],
]

# ── Diálogos y barks ───────────────────────────────────────────────────────────
const ENEMY_COMBAT_BANTER = {
	"La Forma Sin Nombre": ["...reconóceme...", "...el tablero no recuerda mi forma...", "...era un cofre... era una pieza...", "...ya no sé qué soy..."],
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

const PRINCE_MYTH_60 = ["EL ECO DEL ABISMO RESPONDE", "LA CORONA RECUERDA", "EL VELO SE ADELGAZA"]
const PRINCE_MYTH_35 = ["RESONANCIA TOTAL", "EL ABISMO TE LIBERA", "CARCOSA DESPIERTA"]
const PRINCE_MYTH_20 = ["YA ERES EL ABISMO", "EL PRINCIPE HA MUERTO. QUEDA CARCOSA", "LA CORONA ES TUYA"]

# ── Mundo III — La Grieta Sin Fondo ───────────────────────────────────────────
const NORMAL_POOLS_W3 = [
	[{"name": "Eco Fragmentado", "hp": 30, "pattern": [{"type": "attack", "value": 6}, {"type": "attack", "value": 8}]}],
	[{"name": "Servidor del Umbral", "hp": 35, "pattern": [{"type": "insanity", "value": 10}, {"type": "attack", "value": 5}]}],
	[{"name": "Carne del Tablero", "hp": 45, "pattern": [{"type": "attack", "value": 8}, {"type": "shield", "value": 10}, {"type": "insanity", "value": 6}]}],
	[{"name": "Dama Dividida", "hp": 40, "pattern": [{"type": "attack", "value": 7}, {"type": "attack", "value": 7}]}],
	[{"name": "Eco del Centinela", "hp": 38, "pattern": [{"type": "attack", "value": 10}, {"type": "insanity", "value": 8}]}],
	[{"name": "Arquitecto Menor", "hp": 50, "pattern": [{"type": "insanity", "value": 12}, {"type": "attack", "value": 5}, {"type": "shield", "value": 8}]}],
	[
		{"name": "Eco Fragmentado", "hp": 22, "pattern": [{"type": "attack", "value": 5}]},
		{"name": "Servidor del Umbral", "hp": 22, "pattern": [{"type": "insanity", "value": 8}]},
	],
]

const ELITE_POOLS_W3 = [
	[{"name": "La Dama Sin Forma", "hp": 80, "pattern": [{"type": "attack", "value": 14}, {"type": "insanity", "value": 12}, {"type": "attack", "value": 10}]}],
	[{"name": "El Receptor", "hp": 75, "pattern": [{"type": "insanity", "value": 15}, {"type": "attack", "value": 10}, {"type": "attack", "value": 10}]}],
	[{"name": "Fragmento Animado", "hp": 65, "pattern": [{"type": "attack", "value": 12}, {"type": "shield", "value": 15}, {"type": "insanity", "value": 10}]}],
]

const BOSS_POOLS_W3 = [
	[{"name": "EL CARTOGRAFO DEL ABISMO", "hp": 140, "pattern": [{"type": "insanity", "value": 14}, {"type": "attack", "value": 12}, {"type": "shield", "value": 12}, {"type": "attack", "value": 18}]}],
	[{"name": "LA GUARDIA OLVIDADA", "hp": 170, "pattern": [{"type": "attack", "value": 12}, {"type": "shield", "value": 10}, {"type": "insanity", "value": 10}, {"type": "attack", "value": 18}, {"type": "insanity", "value": 12}]}],
]

const BOSS_POOLS_W3_FINAL = [
	{"name": "EL TESTIGO PRIMORDIAL", "hp": 280, "pattern": [{"type": "insanity", "value": 16}, {"type": "attack", "value": 14}, {"type": "shield", "value": 20}, {"type": "attack", "value": 20}, {"type": "insanity", "value": 8}, {"type": "attack", "value": 18}]}
]

const ENEMY_COMBAT_BANTER_W3 = {
	"Eco Fragmentado":        ["...yo tambien llegue hasta aqui...", "¿cuantas veces has muerto ya?"],
	"Servidor del Umbral":    ["No hay victoria. Solo... continuacion.", "El umbral no se cruza. Se convierte en ti."],
	"Carne del Tablero":      ["Eres una pieza que aprendio a caminar. Eso te hace interesante."],
	"Dama Dividida":          ["¿Me recuerdas? Yo no te recuerdo. Ya eres otro."],
	"Eco del Centinela":      ["El centinela que eras no sobrevivio al umbral."],
	"Arquitecto Menor":       ["Carcosa te esta leyendo. Eres un texto muy corto.", "El Rey Amarillo subrayó tu nombre."],
	"EL CARTOGRAFO DEL ABISMO": ["Llevas mucho tiempo buscando algo sin nombre. Dejame darte las coordenadas.", "Conozco tu ruta. He visto como termina.", "Cada run tuya es un punto en mi mapa. Tengo muchos puntos."],
	"LA GUARDIA OLVIDADA":    ["Fuimos barreras. Fuimos jefes. Fuimos la misma cosa repetida.", "Ahora somos el umbral."],
	"EL TESTIGO PRIMORDIAL":  ["Cuantas veces he visto este momento. Tuyo es siempre el mismo gesto de esperanza.", "¿Sabes cuantas versiones tuyas estan aqui dentro? Todas fracasaron.", "No eres el primero. No seras el ultimo. Pero quizas... seas el mas interesante.", "El Rey Amarillo no te espera. Te tiene. Desde antes de que empezaras."],
}

const VICTORY_PHRASES_W3 = ["EL UMBRAL RECUERDA TU PASO", "UNA PIEZA QUE CAMINA SOLA", "LA GRIETA TE HA MEDIDO", "EL TESTIGO CIERRA UN OJO"]

const MYTH_W3_60 = ["EL TABLERO SE DOBLA BAJO TUS PIES", "LOS ECOS TE RECONOCEN", "LA GRIETA TE HA ABIERTO"]
const MYTH_W3_40 = ["ESTE LUGAR TE ESTA RECORDANDO", "TUS RUNS ANTERIORES TE OBSERVAN", "EL UMBRAL APRENDE DE TI"]
const MYTH_W3_20 = ["YA NO ERES UN VISITANTE", "ERES PARTE DE LA GRIETA", "CARCOSA TE PUEDE OLER"]
