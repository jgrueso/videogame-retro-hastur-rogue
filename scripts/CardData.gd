extends Node
class_name CardData

const ALL_CARDS = [
	# Mahar, el Cruzado
	{"name": "Golpe del Cruzado", "attack": 6, "defense": 0, "cost": 1, "char": "mahar", "rarity": "common",
		"flavor": "No es venganza. Es correccion."},
	{"name": "Escudo de la Fe", "attack": 0, "defense": 8, "cost": 1, "char": "mahar", "rarity": "common",
		"flavor": "Resistir no es cobardia. Es oracion en movimiento."},
	{"name": "Marcha Sangrienta", "attack": 7, "defense": 0, "cost": 2, "char": "mahar", "rarity": "common", "hp_cost": 5,
		"description": "7 ATK. Cuesta ademas 5 HP.",
		"flavor": "El camino al objeto sagrado esta pavimentado de cicatrices propias."},
	# Mahar — poco comunes
	{"name": "Reliquia Rota", "attack": 4, "defense": 4, "cost": 2, "char": "mahar", "rarity": "uncommon",
		"flavor": "Rota o entera, una reliquia guarda el recuerdo de lo que prometio."},
	{"name": "Sentencia del Palido", "attack": 5, "defense": 0, "cost": 2, "char": "mahar", "rarity": "uncommon", "apply_vulnerable": 1,
		"description": "5 ATK + aplica Vulnerable (enemigo recibe +25% dano 1 turno).",
		"flavor": "No juzga el cruzado. Ejecuta el juicio que ya fue dictado."},
	{"name": "Grito de la Cofradia", "attack": 0, "defense": 0, "cost": 0, "char": "mahar", "rarity": "uncommon", "enemy_atk_debuff": 2,
		"description": "Todos los enemigos pierden 2 ATK este turno.",
		"flavor": "No los asusta el grito. Los asusta que alguien todavia crea en algo."},
	# Mahar — raras
	{"name": "Purga Sagrada", "attack": 2, "defense": 0, "cost": 3, "char": "mahar", "rarity": "rare", "atk_per_enemy": true,
		"description": "2 ATK x numero de enemigos vivos.",
		"flavor": "La sala no se limpio. Solo dejo de recordar que estaba sucia."},
	{"name": "Nombre Sin Pronunciar", "attack": 0, "defense": 0, "cost": 4, "char": "mahar", "rarity": "rare", "kill_all": true, "sanity_cost": 15,
		"description": "Mata a todos los enemigos. Pierde 15 Cordura.",
		"flavor": "Hay palabras que el cruzado tiene prohibido decir. Las lleva talladas en la lengua de todas formas."},

	# Estratega
	{"name": "Inquisidor Ciego", "attack": 7, "defense": 0, "cost": 2, "char": "estratega", "rarity": "common", "presion": 1,
		"description": "7 ATK. +1 Presion al jugar.",
		"flavor": "Buscaba la anomalia. La encontro en el espejo."},
	{"name": "Dama del Tablero", "attack": 8, "defense": 3, "cost": 3, "char": "estratega", "rarity": "uncommon", "presion": 2,
		"description": "8 ATK + 3 DEF. +2 Presion al jugar.",
		"flavor": "La pieza mas poderosa del tablero. Eso no la protegió."},
	{"name": "Analisis Profundo", "attack": 0, "defense": 0, "cost": 1, "char": "estratega", "draw": 2, "rarity": "uncommon",
		"flavor": "Leer mas no cambia lo que dicen las paginas."},
	# Estratega — nuevas
	{"name": "Jaque Perpetuo", "attack": 5, "defense": 0, "cost": 2, "char": "estratega", "rarity": "common", "draw": 1,
		"description": "5 ATK + roba 1 carta.",
		"flavor": "La presion constante no busca resolver — busca agotar."},
	{"name": "Posicion Ventajosa", "attack": 4, "defense": 0, "cost": 1, "char": "estratega", "rarity": "uncommon", "or_defense": 4,
		"description": "4 ATK O 4 DEF (el jugador elige).",
		"flavor": "Toda posicion tiene su opuesto. Elegir uno es negarse el otro."},
	{"name": "Tactica Calculada", "attack": 0, "defense": 0, "cost": 1, "char": "estratega", "rarity": "uncommon", "draw": 1, "gain_energy": 1,
		"description": "Roba 1 carta + gana 1 energia.",
		"flavor": "El tiempo extra es el unico recurso que el tablero no puede restar."},
	{"name": "Contraofensiva", "attack": 8, "defense": 0, "cost": 2, "char": "estratega", "rarity": "rare", "conditional_enemy_attacked": true,
		"description": "8 ATK si el enemigo ataco el turno anterior.",
		"flavor": "Dejar que golpeen primero no es debilidad. Es informacion."},
	{"name": "Mente Fria", "attack": 0, "defense": 0, "cost": 1, "char": "estratega", "rarity": "rare", "exhaust": true, "draw": 3,
		"description": "Exhaust: roba 3 cartas.",
		"flavor": "Hay un momento entre el caos y la respuesta. Ahi vive el estratega."},

	# Guardian
	{"name": "Idolo Inerte", "attack": 0, "defense": 12, "cost": 3, "char": "guardian", "rarity": "uncommon",
		"flavor": "Alguien lo tallo para que algo no pasara. Ese algo llego de todas formas."},
	{"name": "Muro de Ceniza", "attack": 0, "defense": 17, "cost": 4, "char": "guardian", "rarity": "rare",
		"description": "Otorga 17 de [Escudo].",
		"flavor": "Ceniza, no piedra. Aguanta igual. Por ahora."},
	{"name": "Contraataque", "attack": 5, "defense": 5, "cost": 2, "char": "guardian", "rarity": "common",
		"flavor": "El escudo y la espada son la misma mano. El tablero nunca lo entendio."},
	# Guardian — nuevas
	{"name": "Bastion", "attack": 0, "defense": 6, "cost": 1, "char": "guardian", "rarity": "common",
		"flavor": "Alguien construyo esto. Ya no esta. El muro, si."},
	{"name": "Trinchera", "attack": 0, "defense": 5, "cost": 2, "char": "guardian", "rarity": "uncommon", "bonus_def_if_shield": 4,
		"description": "5 DEF. Si ya tienes escudo, +4 DEF adicional (total 9).",
		"flavor": "La segunda linea siempre es mas solida. La primera ya sabe cuanto duele."},
	{"name": "Represalia", "attack": 5, "defense": 0, "cost": 2, "char": "guardian", "rarity": "uncommon", "cost_reduction_if_shield": 1,
		"description": "5 ATK. -1 coste si tienes escudo activo.",
		"flavor": "Hay rabia en el escudo. La guardo para el momento correcto."},
	{"name": "Fortaleza Interior", "attack": 0, "defense": 0, "cost": 3, "char": "guardian", "rarity": "rare", "shield_from_max_hp": 0.20, "gain_furia": 1,
		"description": "Escudo = 20% de HP maximo. Gana 1 Furia directamente.",
		"flavor": "No todo el escudo esta en las manos. Algo viene de mas adentro."},
	{"name": "Espejo de Acero", "attack": 0, "defense": 0, "cost": 2, "char": "guardian", "rarity": "rare", "exhaust": true, "reflect_damage": 0.6, "reflect_cap": 15,
		"description": "Exhaust: el proximo golpe recibido inflige 60% de su dano al atacante (max 15).",
		"flavor": "Convertirte en lo que te ataca no es victoria. Es supervivencia. Tiene que ser suficiente."},
	{"name": "Tormenta de Hierro", "attack": 0, "defense": 0, "cost": 2, "char": "guardian", "rarity": "uncommon",
		"dmg_equals_shield": true, "cost_free_at_max_furia": true, "consumes_furia": true,
		"description": "Inflige [ESCUDO] de dano al enemigo. Consume todas las cargas de Furia.",
		"flavor": "El escudo no es solo proteccion. Es el peso acumulado de todo lo que resististe."},

	# Universal — Cartas de Evento originales
	{"name": "Ceniza Preventiva", "attack": 0, "defense": 0, "cost": 1, "discard_for_shield": true, "rarity": "uncommon",
		"description": "Descarta tu mano. Ganas 3 de [Escudo] por cada carta descartada.",
		"flavor": "Quemar lo que tienes para construir lo que necesitas. El tablero llama a esto sabiduria."},
	{"name": "Incision Precisa", "attack": 0, "defense": 0, "cost": 2, "max_hp_fraction_dmg": 0.25, "exhaust": true, "rarity": "rare",
		"description": "Inflige dano equivalente al 25% de la Vida Maxima del enemigo (ignora escudo). AGOTAR [color=#c380f0][solo se puede usar 1 vez por combate][/color]",
		"flavor": "Saber donde duele mas que saber cuanto duele."},
	{"name": "Mirada que Devora", "attack": 0, "defense": 0, "cost": 0, "apply_bleed": 3, "rarity": "common",
		"description": "Aplica 3 de [Sangrado] a un enemigo. El sangrado inflige dano al inicio de su turno.",
		"flavor": "No son los dientes lo que mata. Es el no saber cuando parar de sangrar."},
	# Universal — nuevas
	{"name": "Golpe Certero", "attack": 5, "defense": 0, "cost": 2, "rarity": "common",
		"flavor": "Sin adornos. Sin historia. Solo el peso del brazo y la intencion."},
	{"name": "Escudo Improvisado", "attack": 0, "defense": 4, "cost": 1, "rarity": "common",
		"flavor": "No es un escudo real. Pero es lo que habia."},
	{"name": "Impulso de Desesperacion", "attack": 0, "defense": 0, "cost": 1, "rarity": "uncommon", "draw": 2, "sanity_cost": 8,
		"description": "Roba 2 cartas, pierde 8 sanidad.",
		"flavor": "El conocimiento tiene precio. Aqui esta la factura."},
	{"name": "Recuerdo de Luz", "attack": 0, "defense": 0, "cost": 1, "rarity": "uncommon", "sanity_gain": 20,
		"description": "Restaura 20 sanidad.",
		"flavor": "Hubo un momento. Antes del tablero. Todavia puedes alcanzarlo."},

	# Príncipe — Comunes
	{"name": "Eco del Abismo", "attack": 5, "defense": 0, "cost": 1, "char": "prince", "rarity": "common",
		"scaling_sanity": true,
		"description": "5 ATK (x1.5 si Cordura < 60 | x2 si < 35).",
		"flavor": "No es un eco. Es lo que queda cuando el silencio decide hablar."},
	{"name": "Velo de Demencia", "attack": 0, "defense": 0, "cost": 1, "char": "prince", "rarity": "common",
		"draw": 2, "sanity_cost": 10,
		"description": "Roba 2 cartas. Pierde 10 Cordura.",
		"flavor": "Ver mas no cuesta la vista. Cuesta lo que eras antes de ver."},

	# Príncipe — Poco comunes
	{"name": "Manto de Sombras", "attack": 0, "defense": 6, "cost": 1, "char": "prince", "rarity": "uncommon",
		"scaling_sanity": true, "sanity_cost": 5,
		"description": "6 Escudo (x1.5 si Cordura < 60 | x2 si < 35). Cuesta 5 Cordura.",
		"flavor": "No te cubre de los golpes. Te cubre del miedo a recibirlos."},
	{"name": "Locura Canalizada", "attack": 0, "defense": 0, "cost": 0, "char": "prince", "rarity": "uncommon",
		"gain_energy": 1, "sanity_cost": 15,
		"description": "Gana 1 Energia. Pierde 15 Cordura.",
		"flavor": "El tablero llama locura a lo que no puede predecir."},

	# Príncipe — Raras
	{"name": "Heredero del Vacio", "attack": 9, "defense": 9, "cost": 3, "char": "prince", "rarity": "rare",
		"scaling_sanity": true,
		"description": "9 ATK + 9 Escudo (x1.5 si Cordura < 60 | x2 si < 35).",
		"flavor": "La herencia no era el trono. Era lo que habia debajo del trono."},
	{"name": "Fragmento de Carcosa", "attack": 0, "defense": 0, "cost": 2, "char": "prince", "rarity": "rare",
		"exhaust": true, "draw": 3, "sanity_cost": 30,
		"description": "AGOTAR: Roba 3 cartas. Pierde 30 Cordura.",
		"flavor": "Cada fragmento recuerda la forma del todo. El todo no era algo que debias recordar."},

	# Legendarias (Solo via Grieta)
	{"name": "Apocalipsis", "attack": 35, "defense": 0, "cost": 4, "legendary": true, "rarity": "rare", "exhaust": true,
		"description": "35 ATK a TODOS los enemigos. AGOTAR.",
		"flavor": "No una carta. Un argumento final."},
	{"name": "Signo Amarillo", "attack": 0, "defense": 0, "cost": 0, "legendary": true, "sanity_cost": 40, "gain_energy_this_turn": 2, "rarity": "rare",
		"description": "-40 Cordura, +1 Marca, +2 Energía este turno.",
		"flavor": "La cordura que restaura no es la que tenias. Es la que necesitas para ver lo que viene."},
	{"name": "Trono de Carcosa", "attack": 10, "defense": 10, "cost": 3, "legendary": true, "rarity": "rare", "trono_power": true,
		"description": "10 ATK + 10 Escudo. Cada turno ganas 1 Escudo por carta en mano.",
		"flavor": "El trono no tiene rey. Sientate. Eso ya te hace mas rey que el."},
]

const PRINCE_DECK = [
	{"name": "Susurro del Vacio", "attack": 4, "defense": 0, "cost": 1, "scaling_sanity": true, "sanity_cost": 5,
		"description": "4 ATK (x1.5 si Cordura < 60 | x2 si < 35). Cuesta 5 Cordura.",
		"flavor": "El vacio no susurra. Eres tu quien empieza a escuchar."},
	{"name": "Daga de Cristal", "attack": 2, "defense": 0, "cost": 0, "scaling_sanity": true,
		"description": "2 ATK (x1.5 si Cordura < 60 | x2 si < 35).",
		"flavor": "Fabricada con el primer espejo de Carcosa. Todavia muestra algo."},
	{"name": "Espejo Roto", "attack": 0, "defense": 5, "cost": 1, "scaling_sanity": true,
		"flavor": "Lo que no puedes ver en un espejo roto es exactamente lo que necesitas ver."},
	{"name": "Abrazo de la Locura", "attack": 8, "defense": 0, "cost": 2, "sanity_cost": 10,
		"flavor": "La locura no es el fin. Es el ultimo idioma que el tablero no ha aprendido a controlar."},
]

# Pesos por rareza para el draft
const RARITY_WEIGHTS = {"common": 70, "uncommon": 22, "rare": 8}

static func get_random_cards(count: int) -> Array:
	var pool = ALL_CARDS.duplicate()
	pool.shuffle()
	return pool.slice(0, count)

# Draft con pesos de rareza y filtro por personaje
static func get_draft_cards(count: int, char_name: String = "") -> Array:
	var pool = ALL_CARDS.filter(func(c):
		if c.get("legendary", false):
			return false
		var c_char = c.get("char", "")
		return c_char == "" or c_char == char_name
	)
	var weighted: Array = []
	for c in pool:
		var w = RARITY_WEIGHTS.get(c.get("rarity", "common"), 70)
		for i in range(w):
			weighted.append(c)
	weighted.shuffle()
	var result = []
	var seen = []
	for c in weighted:
		if c["name"] not in seen:
			seen.append(c["name"])
			result.append(c)
		if result.size() >= count:
			break
	return result
