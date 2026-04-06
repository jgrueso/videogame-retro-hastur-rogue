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
static var _thought_history: Array = []

static func get_player_thought(char_id: String, sanity: int, enemy_name: String) -> String:
	var thought = ""
	if sanity < 30:
		thought = _get_low_sanity_thought(char_id, enemy_name)
	elif sanity < 70:
		thought = _get_mid_sanity_thought(char_id, enemy_name)
	else:
		thought = _get_high_sanity_thought(char_id, enemy_name)
	
	# Sistema anti-repetición: si la frase ya salió recientemente, buscar otra una vez
	if thought in _thought_history:
		if sanity < 30: thought = _get_low_sanity_thought(char_id, enemy_name)
		elif sanity < 70: thought = _get_mid_sanity_thought(char_id, enemy_name)
		else: thought = _get_high_sanity_thought(char_id, enemy_name)
	
	_thought_history.append(thought)
	if _thought_history.size() > 5:
		_thought_history.remove_at(0)
		
	return thought

static func _get_high_sanity_thought(char_id: String, enemy_name: String) -> String:
	var has_trans = GameManager.has_relic("lengua_tablero")
	var is_w2 = GameManager.current_world == 1
	
	match char_id:
		"mahar":
			match enemy_name:
				"El Penitente":
					if has_trans: return "Dice que lleva aqui mas tiempo que yo. Que todos los que buscaron algo llegaron aqui primero."
					return "Un hombre que cedio. La fe que no resiste la adversidad nunca fue fe."
				"EL CARCELERO": return "He cruzado muros mas altos que este. En nombre de algo mas grande que yo."
				"Avatar de Hastur": return "Esta entidad... lleva algo que reconozco. No. No puede ser."
				_:
					var pool = ["La Mascara esta cerca. Lo siento en el peso del acero.", "Esto no es una trampa. Es una prueba. Toda fe tiene su purgatorio.", "Los de la Cofradia llevamos siglos buscando. Este lugar es la respuesta."]
					return pool.pick_random()
		
		"estratega":
			match enemy_name:
				"El Penitente":
					if has_trans: return "Habla de 'runs' y 'ciclos'... ¿Acaso esta prisión tiene un arquitecto tan sádico como para repetir la misma jugada eternamente?"
					return "Su trayectoria desafía la lógica del tablero. Es una anomalía que exige ser corregida."
				"EL CARCELERO": return "Si él es el guarda, yo soy el teorema que descifrará las grietas de esta jaula."
				"Avatar de Hastur": return "Sus dimensiones se burlan de la geometría sagrada. Una paradoja viviente que debo diseccionar."
				_: return ["Este patrón es... elegante en su crueldad. Lo desarmaré pieza a pieza.", "Veo los hilos del movimiento antes de que ocurran. Pura matemática del caos.", "Un despliegue táctico lamentable. Procedo a la optimización del campo."].pick_random()

		
		"guardian":
			match enemy_name:
				"El Penitente":
					if has_trans: return "Dice que mi escudo es mi propia jaula. Que protejo un mundo que ya ha muerto."
					return "Siento su cansancio. Ojalá pudiera ofrecerle un refugio, pero el deber manda."
				"EL CARCELERO": return "Mi escudo contra su maza. No permitiré que nadie más sea encerrado."
				"Avatar de Hastur": return "Esta presencia... es la que juré detener. Por los caídos."
				_: return ["Mantener la formación. No dar ni un paso atrás.", "Mientras yo respire, el vacío no avanzará.", "Soy el muro entre ellos y el final."].pick_random()
	
	return "Adelante. El destino aguarda."

static func _get_mid_sanity_thought(char_id: String, enemy_name: String) -> String:
	var has_trans = GameManager.has_relic("lengua_tablero")
	var is_w2 = GameManager.current_world == 1

	match char_id:
		"mahar":
			if enemy_name == "El Penitente" and has_trans: return "El Penitente afirma que todos los que buscaron algo sagrado llegaron aqui antes que yo."
			if is_w2: return "Este lugar es demasiado perfecto. Como un escenario construido para que yo llegara exactamente aqui."
			return ["Los rituales que aprendi describian exactamente este lugar. Como lo sabian?", "La Cofradia me envio aqui. Me dijeron que el objeto sagrado estaba aqui. Como lo sabian?", "He matado en nombre de una fe que nadie me supo explicar del todo. Solo obedecer y buscar.", "Hay algo en la obra que cargamos como texto sagrado. Siempre me dijeron que no la leyera completa.", "La Cofradia nunca me dijo que la Mascara era para cubrir algo, no para revelar nada.", "Cuantos cruzados antes que yo? Cuantos llegaron hasta aqui y no volvieron a contar nada?", "El texto sagrado dice que el objeto tiene rostros. En plural."].pick_random()
		"estratega":
			if enemy_name == "El Penitente" and has_trans: return "El Penitente afirma que los datos se resetean, pero el trauma permanece en el código."
			return ["Hay un error en la suma total de este universo. Los números no mienten.", "Las variables están cambiando de forma no lineal. El tablero parece respirar.", "¿Quién mueve mi lógica? Mi mente procesa pensamientos ajenos."].pick_random()
		"guardian":
			if enemy_name == "El Penitente" and has_trans: return "Susurra que fui tallado a partir de un recuerdo que alguien no quiso conservar."
			return ["Este escudo pesa más que ayer. Siento el dolor de todos los que han caído.", "¿Soy el guardián de este mundo o el carcelero de mi propia alma?", "Hay un susurro bajo la lluvia que conoce mi nombre real."].pick_random()
	
	return "Algo no encaja en esta realidad. Las sombras se mueven solas."

static func _get_low_sanity_thought(char_id: String, enemy_name: String) -> String:
	var has_trans = GameManager.has_relic("lengua_tablero")
	if enemy_name == "El Penitente" and has_trans:
		return "¡EL PENITENTE TIENE MI CARA! ¡DICE QUE ÉL ES YO EN LA PRÓXIMA PARTIDA!"

	var common = ["¡NO SON MIS MANOS! ¡SON MADERA!", "El Rey... me mira desde mis propios ojos.", "¿Cuántas veces he muerto ya?", "TODO ES UNA BROMA TALLADA EN HUESO."]
	match char_id:
		"mahar": return ["¡MI CORONA ESTA HECHA DE DIENTES! ¡LOS DIENTES DE TODOS LOS QUE CREYERON ANTES QUE YO!", "¡El objeto sagrado es su ROSTRO! ¡SIEMPRE FUE SU ROSTRO!", "¡Decadas. Decadas buscando. Y era ESTO.", "¡LA COFRADIA SABIA! ¡SIEMPRE SUPO LO QUE HAY AQUI DENTRO!", "¡Soy el actor. Soy la obra. SOY LA MASCARA."].pick_random()
		"estratega": return ["¡LA ECUACIÓN ES CERO! ¡TODO ES CERO!", "¡ERROR DE SISTEMA! ¡HUMANO NO ENCONTRADO!"].pick_random()
		"guardian": return ["¡EL ESCUDO ES UNA LÁPIDA!", "¡PROTEJO UNA TUMBA VACÍA!"].pick_random()
	
	return common.pick_random()

# ─── DIALOGOS DE MUERTE ────────────────────────────────────────────────────────
static func get_death_dialogue(enemy_name: String) -> String:
	var stage = get_lore_stage()
	var has_translator = GameManager.has_relic("lengua_tablero")

	match enemy_name:
		"EL CARCELERO": return "Crees que me has matado. Yo soy la jaula. La jaula no muere."
		"EL REY SIN CORONA": return "No soy el Rey. Soy el hueco donde estaba el Rey."
		"EL REY AMARILLO": return "¿Crees que esto termina aqui? Siempre vuelves."
		"EL VERDADERO HASTUR": return "H A S T U R   R E C U E R D A"
		"El Penitente": return "Gracias... por darme... el castigo que merecia..."

	const GARBLED_ENEMIES = ["Siervo Rebelde", "Peon Maldito", "Espectro", "Alfil Caido"]
	if enemy_name in GARBLED_ENEMIES and not has_translator and stage <= 1:
		return GARBLED_NARRATIVE.get(enemy_name, "Se desvanece en ceniza.")

	match enemy_name:
		"Siervo Rebelde": return "Libre... al fin... libre..."
		"Peon Maldito": return "El tablero nos comera a los dos."
		"Alfil Caido": return "No hay dioses aqui. Solo el juego."
		"Torre Rota": return "Soy lo que queda cuando las reglas se rompen."
		"Inquisidor Ciego": return "Buscaba la herejia. Era yo. Siempre fui yo."
		"Espectro del Vacio": return ["Un principe... aun respira en el centro del vacio...", "La jaula del principe no tiene barrotes, solo olvido.", "Buscad al heredero... en el Mundo II..."].pick_random()
		"Caballero de Carcosa": return ["Serviamos a una corona... ahora solo a la estatica.", "Hay algo... en el centro del vacio... que espera.", "No nos mateis... liberadle a el..."].pick_random()
		"EL CENTINELA ABISAL": return "Mi vigilia termina... el secreto os pertenece..."
		_: return "Se desintegra en el vacío."

# ─── GARBLED ──────────────────────────────────────────────────────────────────
const GARBLED = {
	"Siervo Rebelde": "ᛈ ᛇ ᚦ ᛟ ᛗ ᚾ ᛁ ᛖ ...",
	"Peon Maldito":   "◌◍●  ᚹ ᚫ ᛤ ᛞ ᚣ ᛝ ᚪ ◌●◍◌",
	"Espectro":       "░ ᚩ ᛡ ᚢ ᛣ ᛈ ᛇ ᚦ ᛟ ᛗ...",
	"Alfil Caido":    "✦◈✦ ᚾ ᛁ ᛖ ᚷ ᛃ ᚹ ᚫ  ◈◆✦◈",
}

const GARBLED_NARRATIVE = {
	"Siervo Rebelde": "Se retuerce con un dolor que parece mas metalico que humano.",
	"Peon Maldito":   "Algo dentro de el se rompe con un sonido humedo.",
	"Espectro":       "Se disuelve en el aire como humo frio.",
	"Alfil Caido":    "Cae de rodillas. Sus manos buscan algo en el suelo.",
}

static func is_garbled(text: String) -> bool:
	for cipher in GARBLED.values():
		if cipher in text: return true
	return false

static func get_post_combat_fragment() -> String:
	var p = GameManager.lore_progress
	match p:
		8:  return "[ Cronica ]\n'El Rey me guia.'"
		18: return "[ Diario ]\n'No recuerdo el nombre de mi madre.'"
		30: return "[ Inscripcion ]\n'Algo encontró este mundo. O este mundo lo encontró a él.'"
	return ""

const LORE_BOOK = {
	"rey_marfil": {
		"title": "EL REY Y EL MARFIL",
		"text": "Se dice que el Rey Sin Corona no siempre fue un esqueleto. Antes de que el sol se volviera negro, gobernaba un reino de luz. Pero su obsesión por el juego perfecto lo llevó a apostar su alma contra el Silencio. El marfil de sus piezas se tornó hueso, y su trono, ceniza.",
		"min_lore": 5
	},
	"memorias_carcosa": {
		"title": "EL REINO DE LAS TORRES NEGRAS",
		"text": "Hubo un reino, antes. El mapa no lo nombra.\n\nSus torres eran negras como el basalto y sus mares reflejaban una luz que ya no existe. Sus habitantes jugaban al ajedrez no como ritual, sino como arte. No como guerra, sino como conversación.\n\nTenía un rey. El rey tenía un hijo. El hijo nunca perdía, no porque fuera invencible, sino porque entendía algo que los demás no: perder una pieza no es perder. Es abrir un espacio.\n\nUn día llegó algo desde afuera del tablero. El rey tomó una decisión.\n\nEl príncipe nunca se lo perdonó.",
		"min_lore": 35
	},
	"telonero_rey": {
		"title": "EL TELONERO Y EL REY",
		"text": "Hay una historia que nadie recuerda haber escuchado por primera vez:\n\nAntes de la primera función, cuando el escenario todavía olía a madera nueva, el Telonero se encontró con un Rey que no figuraba en ningún programa.\n\nEl Rey le preguntó qué vendería si pudiera vender cualquier cosa.\n\nEl Telonero reflexionó. Tocó los objetos de su puesto uno por uno, como buscando la respuesta entre ellos.\n\n\"No lo sé\", dijo al final. \"Nunca recuerdo qué tenía antes.\"\n\nEl Rey sonrió con una boca que tenía demasiados dientes: \"Eso es exactamente lo que necesitaba escuchar.\"\n\nEl Telonero todavía está pensando en esa respuesta.\nAunque no recuerda la pregunta.",
		"min_lore": 12
	},
	"telonero_asiento": {
		"title": "EL ASIENTO VACÍO",
		"text": "Hay una pregunta que ningún actor hace porque ninguno la nota:\n\n¿Para quién actúan?\n\nHastur construyó el escenario. Puso los actores, la música, las trampas. Diseñó cada mecanismo con la precisión de alguien que lleva siglos perfeccionando lo mismo.\n\nPero un teatro sin público no es un teatro. Es un ensayo.\n\nAlgo llegó antes que los actores. Antes que el escenario. Antes de que Hastur supiera que iba a construir algo.\n\nNo compró entrada. No necesitaba.\n\nSe sentó. Y el Telonero, sin saber por qué, a veces mira hacia ese lugar.\n\nSolo un momento. Sin recordar que lo hace.",
		"min_lore": 22
	},
	"telonero_idioma": {
		"title": "LO QUE EL IDIOMA NO NOMBRA",
		"text": "En el idioma del tablero hay una palabra para Hastur.\nHay una palabra para el Príncipe.\nHay una palabra para cada actor, cada función, cada final.\n\nNo hay palabra para lo que habita al Telonero.\n\nEl idioma fue construido por Hastur.\nHastur no nombró lo que no puede controlar.\n\nLo más cerca que existe es el silencio entre dos palabras.\n\nEso también es un nombre, si sabes escucharlo.",
		"min_lore": 38,
		"requires": "lengua_tablero"
	},
	"capitulo_prohibido": {
		"title": "EL CAPÍTULO PROHIBIDO",
		"text": "En un reino que el mapa no nombra, un Rey buscó la eternidad en el reflejo de una pieza de marfil. No entendió que el tablero no era su dominio, sino su celda.\n\nAhora aguarda en el tramo final del Tablero Dorado. Primer velo antes de algo que este códice no tiene permiso para nombrar.",
		"min_lore": 15
	},
	"grieta_habitantes": {
		"title": "LA GRIETA Y SUS HABITANTES",
		"text": "La Grieta no tiene nombre en el idioma del tablero porque el tablero se niega a reconocer que existe.\n\nPero los ecos que habitan en ella lo saben todo. Son los fragmentos de piezas que llegaron demasiado lejos, que entendieron demasiado, que el tablero no pudo reciclar limpiamente. Sus voces se oyen en los momentos de baja cordura.\n\nUn eco dijo una vez, a través de la boca de una pieza que cruzó la Grieta: \"El Príncipe respira. El Príncipe espera. El Príncipe sabe el nombre de cada uno de nosotros.\"\n\nNadie sabe el nombre del eco que lo dijo.",
		"min_lore": 25
	},
	"penitente_rendicion": {
		"title": "EL PENITENTE Y LA RENDICIÓN",
		"text": "En el idioma del tablero, \"rendición\" y \"pieza capturada\" son la misma palabra.\n\nHay una figura que los Siervos del tablero conocen como la Sombra Arrodillada. Aparece al final de los caminos imposibles, donde los héroes ya no pueden seguir. Les ofrece una tercera opción: no ganar, no morir, sino detenerse.\n\nLos que aceptan no desaparecen. Se convierten en parte del tablero.\n\nSi alguna vez enfrentas a un ser que te reconoce antes de atacar, que duda tres turnos antes de levantar la mano... ya sabes quién fue.",
		"min_lore": 999
	},
	"hastur_eco": {
		"title": "EL ARQUITECTO DEL TABLERO",
		"text": "Hay algo detrás del tablero. No dentro de él, detrás.\n\nNo tiene forma propia. Toma prestadas las formas de lo que el jugador espera ver. Vive en los espacios entre los cuadros, en el silencio entre un movimiento y el siguiente.\n\nNo busca ganar. Busca que el juego nunca termine.\n\nLa locura no es el castigo por jugar. Es simplemente la comprensión de sus reglas.",
		"min_lore": 45
	},
	"tres_sellos": {
		"title": "LOS TRES SELLOS",
		"text": "El sello original tenía tres partes: una firma, una canción y una invitación.\n\nFirma: para identificar quién jugaba.\nCanción: para mantener el juego en movimiento.\nInvitación: para asegurarse de que siempre llegara alguien a jugar.\n\nCuando el Príncipe de Carcosa rompió el sello, pensó que estaba liberando a las almas atrapadas en él. Lo que hizo fue dispersar sus piezas por el tablero, donde eventualmente serían encontradas por las piezas jugables.\n\nEl Príncipe no consideró que quizás el sello no era solo una trampa.\n\nQuizás era también la única forma de cerrarla.",
		"min_lore": 999
	},
	"carta_sin_destinatario": {
		"title": "CARTA SIN DESTINATARIO",
		"text": "Encontrado en las paredes de la Grieta, grabado con algo que no es una herramienta:\n\n\"Si lees esto, llegas tarde o llegas a tiempo, nunca los dos. El tablero tiene un defecto que Hastur no puede reparar sin destruirlo: en el espacio entre la última nota de la Canción y el primer movimiento del siguiente ciclo, hay un silencio.\n\nEn ese silencio, el tablero no sabe que existe.\n\nEse es el momento. Ese es el único momento.\n\n— P.C.\"",
		"min_lore": 40
	},
	"centinela_nombre": {
		"title": "EL CENTINELA Y SU NOMBRE",
		"text": "El Centinela Abisal no siempre fue un monstruo.\n\nEra el último caballero de Carcosa. Siguió a su príncipe hasta la Grieta, jurando que no volvería sin él.\n\nSiglos de estática abisal borraron casi todo. Quedó solo la función: guardar. Guardar el lugar donde estaba el príncipe. Guardar el recuerdo de que había algo que valía la pena guardar.\n\nSu nombre era Aldric. En el idioma de Carcosa: \"aquel que sostiene lo que los demás sueltan.\"\n\nNunca supo si su príncipe estaba a un metro o a un universo de donde él montaba guardia.",
		"min_lore": 999
	},
	"banquete_rey_olvidado": {
		"title": "EL BANQUETE DEL REY OLVIDADO",
		"text": "Antes de Yhtill, hubo otro reino. Su nombre no sobrevivio.\n\nSu rey era un gran patron de las artes. Comisiono la obra mas ambiciosa de su era y abrio las puertas del palacio a todo su pueblo para la premiere.\n\nLos artistas que escribieron la obra no la inventaron. La dictaron. Decian escuchar las escenas como si alguien las susurrara desde adentro de las paredes.\n\nLa obra se llamaba El Rey Amarillo. Nadie llego al Acto II con la mente intacta.\n\nEl rey fue el ultimo en entender lo que habia invitado a su propio hogar.",
		"min_lore": 8
	},
	"artista_y_la_dictadura": {
		"title": "EL ARTISTA Y LA DICTADURA",
		"text": "El autor de la obra no tiene nombre en los registros. Solo un titulo: El Primer Palido.\n\nFundo una cofradía alrededor de lo que sobrevivio del banquete: un objeto. Palido. Tallado por la ultima persona cuerda que vio lo que entro al salon.\n\nDijo que el objeto era sagrado. Que quien lo encontrara hablaria con El Anterior directamente.\n\nMurio sin decir como sabia que existia. Sin decir como sabia donde buscarlo.\n\nSus sucesores llevan siglos haciendo las mismas preguntas incorrectas.",
		"min_lore": 16
	},
	"promesa_palida": {
		"title": "LA PROMESA PALIDA",
		"text": "La Cofradia tiene dos doctrinas. Una para los cruzados. Otra para los que los envian.\n\nLos cruzados aprenden: busca el objeto sagrado, encuentra a El Anterior, recibe la verdad.\n\nLos que los envian saben: el objeto no da acceso a El Anterior. El objeto es El Anterior. Quien lo toque ya pertenece a el.\n\nNadie en la Cofradia ha preguntado en voz alta por que los cruzados que encuentran el objeto sagrado nunca regresan a contarlo.",
		"min_lore": 24
	},
	"primera_mascara": {
		"title": "LA PRIMERA MASCARA",
		"text": "La persona que la tallo no era un artista. Era un guardia de palacio que sobrevivio por estar en el pasillo cuando el Acto II comenzo.\n\nVio el rostro dos segundos antes de que su mente decidiera que era mas seguro no recordar.\n\nDos segundos fueron suficientes. Sus manos trabajaron solas durante tres dias. Cuando termino, no recordaba haber empezado.\n\nLa mascara es perfecta. Ese es el problema.\n\nNadie que solo vea una cara puede tallar asi. Tenia que haber algo guiando sus manos.",
		"min_lore": 35
	}
}
