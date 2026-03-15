extends Node
class_name CardData

const ALL_CARDS = [
	# Conquistador
	{"name": "Cabalgante del Vacio", "attack": 4, "defense": 0, "cost": 2, "char": "conquistador"},
	{"name": "Ofrenda de Carne", "attack": 8, "defense": 0, "cost": 2, "char": "conquistador"},
	{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2, "char": "conquistador"},
	
	# Estratega
	{"name": "Inquisidor Ciego", "attack": 2, "defense": 0, "cost": 2, "char": "estratega"},
	{"name": "Dama del Tablero", "attack": 6, "defense": 2, "cost": 3, "char": "estratega"},
	{"name": "Analisis Profundo", "attack": 0, "defense": 0, "cost": 1, "char": "estratega", "draw": 2},
	
	# Guardian
	{"name": "Idolo Inerte", "attack": 0, "defense": 8, "cost": 3, "char": "guardian"},
	{"name": "Muro de Ceniza", "attack": 0, "defense": 12, "cost": 4, "char": "guardian", "description": "Otorga 12 de [Escudo]."},
	{"name": "Contraataque", "attack": 4, "defense": 4, "cost": 2, "char": "guardian"},
	
	# Cartas de Evento
	{"name": "Ceniza Preventiva", "attack": 0, "defense": 0, "cost": 1, "discard_for_shield": true, "description": "Descarta tu mano. Ganas 3 de [Escudo] por cada carta descartada."},
	{"name": "Incision Precisa",  "attack": 0, "defense": 0, "cost": 2, "max_hp_fraction_dmg": 0.25, "exhaust": true, "description": "Inflige daño equivalente al 25% de la Vida Máxima del enemigo (ignora escudo). AGOTAR [color=#c380f0][solo se puede usar 1 vez por combate][/color]"},
	{"name": "Mirada que Devora", "attack": 0, "defense": 0, "cost": 0, "apply_bleed": 3, "description": "Aplica 3 de [Sangrado] a un enemigo. El sangrado inflige daño al inicio de su turno."},

	# Legendarias (Solo via Grieta)
	{"name": "Apocalipsis", "attack": 30, "defense": 0, "cost": 4, "legendary": true},
	{"name": "Signo Amarillo", "attack": 0, "defense": 0, "cost": 0, "legendary": true, "sanity_gain": 50},
	{"name": "Trono de Carcosa", "attack": 10, "defense": 12, "cost": 3, "legendary": true},
]

const PRINCE_DECK = [
	{"name": "Susurro del Vacio", "attack": 4, "defense": 0, "cost": 1, "scaling_sanity": true},
	{"name": "Daga de Cristal", "attack": 2, "defense": 0, "cost": 0},
	{"name": "Espejo Roto", "attack": 0, "defense": 5, "cost": 1, "scaling_sanity": true},
	{"name": "Abrazo de la Locura", "attack": 8, "defense": 0, "cost": 2, "sanity_cost": 10},
]

static func get_random_cards(count: int) -> Array:
	var pool = ALL_CARDS.duplicate()
	pool.shuffle()
	return pool.slice(0, count)
