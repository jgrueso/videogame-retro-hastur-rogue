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
static func get_player_thought(char_id: String, sanity: int, enemy_name: String) -> String:
	if sanity < 30:
		return _get_low_sanity_thought(char_id, enemy_name)
	elif sanity < 70:
		return _get_mid_sanity_thought(char_id, enemy_name)
	else:
		return _get_high_sanity_thought(char_id, enemy_name)

static func _get_high_sanity_thought(char_id: String, enemy_name: String) -> String:
	var has_trans = GameManager.has_relic("lengua_tablero")
	
	match char_id:
		"conquistador":
			match enemy_name:
				"El Penitente":
					if has_trans: return "Habla de perdón, pero yo solo escucho el eco de un peón quebrado. No habrá piedad en mi tablero."
					return "Un cobarde que se rinde ante el tablero. Mi acero no conoce la piedad."
				"EL CARCELERO": return "Un obstáculo digno. Tomaré sus llaves y su corona de ceniza."
				"Avatar de Hastur": return "¿Un dios? He quemado templos más grandes que este ser."
				_: return ["Otra pieza que se interpone en mi conquista.", "El tablero se teñirá de rojo hoy.", "Mi nombre será ley en Carcosa."].pick_random()
		
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
	
	match char_id:
		"conquistador":
			if enemy_name == "El Penitente" and has_trans: return "Dice que ya he muerto mil veces. Que mi gloria es solo una repetición de su dolor."
			return ["El aire sabe a metal oxidado... ¿He matado a este ser antes?", "Mis cicatrices pican bajo la armadura. ¿Son mías o del tablero?", "Mis victorias se sienten huecas. Como si ganara en un mundo de cartón."].pick_random()
		"estratega":
			if enemy_name == "El Penitente" and has_trans: return "El Penitente afirma que los datos se resetean, pero el trauma permanece en el código."
			return ["Hay un error en la suma total de este universo. Los números no mienten.", "Las variables están cambiando de forma no lineal. El tablero parece respirar.", "¿Quién mueve mi lógica? Mi mente procesa pensamientos ajenos."].pick_random()
		"guardian":
			if enemy_name == "El Penitente" and has_trans: return "Susurra que el Rey Amarillo me talló a partir de un recuerdo olvidado."
			return ["Este escudo pesa más que ayer. Siento el dolor de todos los que han caído.", "¿Soy el guardián de este mundo o el carcelero de mi propia alma?", "Hay un susurro bajo la lluvia que conoce mi nombre real."].pick_random()
	
	return "Algo no encaja en esta realidad. Las sombras se mueven solas."

static func _get_low_sanity_thought(char_id: String, enemy_name: String) -> String:
	var has_trans = GameManager.has_relic("lengua_tablero")
	if enemy_name == "El Penitente" and has_trans:
		return "¡EL PENITENTE TIENE MI CARA! ¡DICE QUE ÉL ES YO EN LA PRÓXIMA PARTIDA!"

	var common = ["¡NO SON MIS MANOS! ¡SON MADERA!", "El Rey... me mira desde mis propios ojos.", "¿Cuántas veces he muerto ya?", "TODO ES UNA BROMA TALLADA EN HUESO."]
	match char_id:
		"conquistador": return ["¡SANGRE PARA EL TABLERO DORADO!", "¡MI CORONA ESTÁ HECHA DE DIENTES!"].pick_random()
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
		_: return "Se desintegra en el vacío."

# ─── GARBLED ──────────────────────────────────────────────────────────────────
const GARBLED = {
	"Siervo Rebelde": "▓░▒ ▓▓░...",
	"Peon Maldito":   "◌◍● ◌●◍◌",
	"Espectro":       "░░▒▓ ░▒...",
	"Alfil Caido":    "✦◈✦ ◈◆✦◈",
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
		8: return "[ Cronica ]\n'El Rey me guia.'"
		18: return "[ Diario ]\n'No recuerdo el nombre de mi madre.'"
		30: return "[ Inscripcion ]\n'EL REY AMARILLO ENCONTRO EL MUNDO.'"
	return ""
