extends Node
class_name LoreData

# ─── ESTADO LORE ───────────────────────────────────────────────────────────────
static func get_lore_stage() -> int:
	var p = GameManager.lore_progress
	if p < 8:   return 0  # Ignorancia heroica
	if p < 18:  return 1  # Primeras dudas
	if p < 30:  return 2  # Inquietud
	if p < 45:  return 3  # La verdad
	return 4              # Confrontacion

# ─── PENSAMIENTOS DEL JUGADOR al entrar en combate ────────────────────────────
static func get_player_thought(enemy_name: String) -> String:
	var stage = get_lore_stage()

	if stage == 0:
		match enemy_name:
			"Siervo Rebelde":   return "Otro corrompido. Le dare descanso rapido."
			"Peon Maldito":     return "Se mueve como si algo tirara de sus huesos desde dentro."
			"Torre Rota":       return "Una fortaleza caida. Nada que mi acero no pueda terminar."
			"Alfil Caido":      return "Un creyente pervertido. Su fe ya no le protege."
			"Caballero Roto":   return "Fue como yo, una vez. Ya no."
			"Inquisidor Ciego": return "Busca algo que no encontrara. Yo tampoco se que es."
			"El Penitente":     return "Parece que quiere decirme algo. Seguramente una trampa."
			"EL CARCELERO":     return "Un guardian imponente. Pero todos los guardas tienen una llave."
			"EL REY SIN CORONA":return "El Rey al que sirvo. Debo... debo protegerle. ¿Verdad?"
		return "Siento el peso de mi mision. Adelante."

	if stage == 1:
		match enemy_name:
			"El Penitente": return "Lleva marcas en la piel. Numeros. Como un inventario."
			"EL CARCELERO": return "No me mira como a un enemigo. Me mira como a una pieza en el tablero."
		return "Hay algo extraño en el aire. Como si ya hubiera pasado por aqui."

	if stage == 2:
		match enemy_name:
			"El Penitente":      return "Sus ojos... reconocen los mios. ¿Nos hemos visto antes?"
			"EL CARCELERO":      return "Si es el carcelero... ¿de que prision soy yo el preso?"
			"EL REY SIN CORONA": return "No tiene corona. Nunca la tuvo. ¿A quien he estado sirviendo?"
		return "El tablero se repite. Estoy seguro. Ya estuve aqui."

	# stage 3+
	match enemy_name:
		"El Penitente":      return "Es lo que yo sere despues de suficientes intentos."
		"EL CARCELERO":      return "Guarda la jaula en la que yo mismo me encerre."
		"EL REY SIN CORONA": return "No es el Rey. Es el vacio con forma de Rey."
		"EL REY AMARILLO":   return "Aqui esta. La cosa que ha movido mis manos todo este tiempo."
	return "Mis manos tiemblan. Pero no de miedo. De reconocimiento."

# ─── DIALOGOS DE MUERTE ────────────────────────────────────────────────────────
static func get_death_dialogue(enemy_name: String) -> String:
	var stage = get_lore_stage()
	var has_translator = GameManager.has_relic("lengua_tablero")

	# Jefes: siempre tienen dialogo, sin importar el stage
	match enemy_name:
		"EL CARCELERO":
			if stage <= 1:
				return "Eres... mas persistente... de lo esperado.\nPero volveras. Siempre volveras."
			return "Crees que me has matado.\nYo soy la jaula. La jaula no muere."
		"EL REY SIN CORONA":
			if GameManager.has_all_secret_items():
				return "Bien jugado... pieza.\nPero el verdadero tablero... aun no lo has visto."
			elif stage <= 2:
				return "El... otro... te espera.\nEn el siguiente... tablero."
			return "No soy el Rey. Nunca lo fui.\nSoy el hueco donde estaba el Rey."
		"EL REY AMARILLO":
			if GameManager.has_all_secret_items():
				return "Los has reunido...\nLos tres fragmentos del signo...\nYo era solo el muro.\nAhora... el que esta detras... despierta."
			return "¿Crees que esto termina aqui?\nSiempre vuelves. Siempre pierdes.\nY aun asi... vuelves. Eso me divierte."
		"EL VERDADERO HASTUR":
			return "H A S T U R   N O   M U E R E\nH A S T U R   E S P E R A\nH A S T U R   R E C U E R D A"
		"LA DAMA DE CENIZA":
			return "Mi fuego... era lo unico real... en este mundo de madera..."
		"El Penitente":
			return "Gracias... por darme... el castigo que merecia..."

	# Enemigos normales: pueden hablar garbled sin traductor
	const GARBLED_ENEMIES = ["Siervo Rebelde", "Peon Maldito", "Espectro", "Alfil Caido"]
	if enemy_name in GARBLED_ENEMIES and not has_translator and stage <= 1:
		return GARBLED_NARRATIVE.get(enemy_name, "")

	match enemy_name:
		"Siervo Rebelde":
			match stage:
				0: return "Libre... al fin... libre..."
				1: return "Gracias... por romper... mis hilos."
				2: return "El Rey te tallara... de nuevo... igual que a mi."
				_: return "Somos el mismo error. Una y otra vez."

		"Peon Maldito":
			match stage:
				0: return "No era... mi culpa..."
				1: return "No recuerdo... mi nombre. ¿Tu recuerdas el tuyo?"
				_: return "El tablero nos comera a los dos."

		"Alfil Caido":
			match stage:
				0: return "Mi fe... fue real... alguna vez..."
				1: return "Rece a algo que ya nos habia devorado."
				_: return "No hay dioses aqui. Solo el juego."

		"Espectro":
			match stage:
				0: return "..."
				1: return "Fui... como tu..."
				_: return "No muero. Me... reciclan."

		"El Penitente":
			match stage:
				0: return "Escucha... tienes que escuchar... el tablero no es real..."
				1: return "Ya lo sabes. En algun lugar de ti, ya lo sabes. Huye."
				2: return "No puedes ganar. Solo puedes... recordar mas rapido que la vez anterior."
				_: return "Esta es mi run numero... ya no recuerdo. Y la tuya tambien lleva mas de las que crees."

		"Torre Rota":
			match stage:
				0: return "La oscuridad... no morira..."
				_: return "Soy lo que queda cuando las reglas se rompen. Igual que tu."

		"Caballero Roto":
			match stage:
				0: return "Falle... en proteger..."
				_: return "Mi juramento era a algo que no existe. Como el tuyo."

		"Inquisidor Ciego":
			match stage:
				0: return "La verdad... duele..."
				_: return "Buscaba la herejia. Era yo. Siempre fui yo."

		"EL CARCELERO":
			if stage <= 1:
				return "Eres... mas persistente... de lo esperado. Pero volveras."
			return "Crees que me has matado. Yo soy la jaula. La jaula no muere."

		"EL REY SIN CORONA":
			if GameManager.has_all_secret_items():
				return "Bien jugado... pieza. Pero el verdadero tablero... aun no lo has visto."
			elif stage <= 2:
				return "El... otro... te espera. En el siguiente... tablero."
			return "No soy el Rey. Nunca lo fui. Soy el hueco donde estaba el Rey."

		"EL REY AMARILLO":
			return "¿Crees... que esto termina aqui? Eres mi jugada favorita.\nSiempre vuelves. Siempre pierdes. Y aun asi... vuelves."

		"EL VERDADERO HASTUR":
			return "H̷A̵S̷T̷U̵R̷ N̵O̶ M̷U̵E̷R̵E̴\nH̷A̵S̷T̷U̵R̷ E̵S̸P̷E̵R̷A̵\nH̷A̵S̷T̷U̵R̷ R̵E̶C̵U̷E̵R̷D̵A̷"

	return ""

# ─── GARBLED (sin traductor) ───────────────────────────────────────────────────
const GARBLED = {
	"Siervo Rebelde": "▓░▒ ▓▓░...",
	"Peon Maldito":   "◌◍● ◌●◍◌",
	"Espectro":       "░░▒▓ ░▒...",
	"Alfil Caido":    "✦◈✦ ◈◆✦◈",
}

const GARBLED_NARRATIVE = {
	"Siervo Rebelde": "Se retuerce con un dolor que parece mas metalico que humano. Sus labios forman palabras sin sonido.",
	"Peon Maldito":   "Algo dentro de el se rompe con un sonido humedo. Sus ojos miran un punto que no existe en este mundo.",
	"Espectro":       "Se disuelve en el aire como humo frio. Donde estaba queda un olor a tierra mojada y tiempo viejo.",
	"Alfil Caido":    "Cae de rodillas. Sus manos buscan algo en el suelo. Un altar que ya no esta.",
}

static func is_garbled(text: String) -> bool:
	for cipher in GARBLED.values():
		if cipher in text: return true
	return false

# ─── FRAGMENTOS POST-COMBATE ───────────────────────────────────────────────────
static func get_post_combat_fragment() -> String:
	var p = GameManager.lore_progress
	match p:
		8:
			return "[ Cronica del Heroe ]\n\n'He llegado a los limites de Valdris. La corrupcion es fuerte, pero el Rey me guia.\nSiento una fuerza invisible empujandome hacia adelante.\nEs el honor. Debe ser el honor.'"
		18:
			return "[ Fragmento de un diario ]\n\n'Dia 40. He matado a cien enemigos.\nPero no puedo recordar el nombre de mi madre.\n¿Es este el precio de la gloria? ¿Olvidadlo todo para salvarlo todo?'"
		30:
			return "[ Inscripcion en una piedra vieja ]\n\n'EL REY AMARILLO NO CREO EL MUNDO.\nENCONTRO EL MUNDO Y DECIDIO QUE SERIA SU TABLERO.\nNOSOTROS SOMOS LAS ASTILLAS QUE QUEDARON TRAS TALLAR LAS PIEZAS.'"
	return ""

static func get_random_thought(_type: String = "general") -> String:
	var stage = get_lore_stage()
	var sanity = GameManager.sanity
	
	if sanity < 25:
		var critical = [
			"¡SÁCAME DE AQUÍ! ¡SÁCAME DE AQUÍ!",
			"Mis ojos... no son mis ojos...",
			"El Rey... me esta tallando la cara...",
			"¿Donde estan mis manos? No las veo...",
			"La cancion... no para... me duele el alma...",
			"Todo es madera. Todo es madera y sangre.",
		]
		return critical[randi() % critical.size()]

	if stage == 0:
		return "Debo seguir. Por el Rey. Por Valdris."
	var pool = [
		"El aire sabe a cobre y metal viejo.",
		"Siento hilos invisibles tirando de mis munecas.",
		"Mi sombra se mueve un segundo despues que yo.",
		"¿Cuantas veces he cruzado este mismo pasillo?",
		"El suelo tiene marcas de pasos. Son mis pasos.",
	]
	return pool[randi() % pool.size()]

static func get_yellow_king_whisper() -> String:
	var stage = get_lore_stage()
	if stage == 0:
		return "'Bien hecho, campeon mio. Sigue adelante.'"
	return "'¿Sabias que esta es la vez numero " + str(GameManager.total_runs + 1) + " que mueres por mi entretenimiento?'"
