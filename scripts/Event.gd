extends Node2D

const DICE_FACES: Array = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
const MAX_DICE_ROLLS: int = 3
const DICE_REROLL_COSTS: Array = [5, 10]  # costo del 1er y 2do relanzamiento

const EVENT_CHARACTER_REACTIONS: Dictionary = {
	"mahar": "«La Cofradia no me preparo para esto. Pero la fe no pide permiso para ser puesta a prueba.»",
	"estratega": "«Cada elección aquí es una variable más en el patrón.»",
	"guardian": "«Elijo con cuidado. Cada decisión pesa sobre las piezas que protejo.»",
	"prince": "«Ya lo vi antes. En otro tablero, con otro nombre.»",
}

const CORRUPTION_WORDS: Array = ["....", "el ojo", "Carcosa", " ᛞ ᚣ ᛝ ᚪ ᛠ ᚩ", "inevitable", "ya sabes"]

var _typewriter_done: bool = false
var _option_buttons: Array = []

var _font_title:     FontFile
var _font_narrative: FontFile
var _font_ui:        FontFile
var _font_corrupt:   FontFile

const UMBRAL_EVENT: Dictionary = {
	"title": "El Umbral",
	"text": "Está sentado contra la pared con la calma de alguien que ya no tiene miedo,\nporque ya no le queda nada que perder.\n\nSus ojos están al revés. Ves el interior de algo enorme a través de ellos.\n\n'Sabía que vendrías', dice. 'El Príncipe me envió a esperarte.\nSolo hay tres formas de llegar a donde él está.\nTú decides cuál puedes pagar.'",
	"options": [
		{"label": "Acepta su marca (sacrifica una reliquia)", "rift_relic_sacrifice": true},
		{"label": "Arrebátale el camino (combate)", "miniboss": true, "rift_on_win": true},
		{"label": "Déjalo descansar (sin Grieta esta run)", "rift_wanderer_rest": true},
	]
}

var events: Array = [
	{
		"title": "El Altar Roto",
		"text": "La pieza de ajedrez sobre el altar no es decoración. Es alguien.\n\nLas piezas aprenden, tarde, que los altares no detienen el reciclaje — solo lo posponen. Quien construyó este sabía que sería inútil. Lo construyó de todas formas. Las marcas de quemaduras en la piedra son de las manos que intentaron retenerla.\n\nLa pieza te mira. No con ojos. Con el peso de alguien que lleva demasiado tiempo esperando ser recordado.",
		"options": [
			{"label": "Tomarla. Alguien tiene que recordarla (-5 HP, Reliquia)", "hp": -5, "coins": 0, "heal": 0, "relic": true},
			{"label": "Destruirla. El tablero tendrá lo que siempre quiso (+8 monedas)", "hp": 0, "coins": 8, "heal": 0},
			{"label": "Dejarla donde está. No eres tú quien decide esto (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "El Comerciante de Ciclos",
		"text": "Vendió información al tablero durante ciclos. Nombres de piezas, patrones de movimiento, rutas hacia la Grieta. El precio que pidió era la libertad. El tablero aceptó — y le puso cadenas para que no se fuera antes de terminar de ser útil.\n\nTiene mercancía genuina. Todo viene de otros que pagaron por ella antes con algo que ya no tienen.\n\nTe mira con la ecuanimidad de quien lleva suficiente tiempo aquí para saber exactamente cuánto vales para el ciclo.",
		"options": [
			{"label": "Ignorar las cadenas. Solo comprar (+tienda)", "hp": 0, "coins": 0, "heal": 0, "goto_shop": true},
			{"label": "Romper las cadenas. El tablero lo reclama en el acto (Reliquia)", "hp": 0, "coins": 0, "heal": 0, "relic": true},
			{"label": "Tomar lo que necesitas. Ya pagó suficiente (-10 HP, +10 monedas)", "hp": -10, "coins": 10, "heal": 0},
		]
	},
	{
		"title": "El Pueblo Fantasma",
		"text": "No es un pueblo abandonado. Es un pueblo borrado.\n\nCarcosa existió aquí — en estas calles, con esta gente, con fogones que aún están tibios porque el tablero no dejó tiempo para que se enfriaran. Los superpuso cuando necesitó casillas. La escritura en las paredes no la dejaron los habitantes: es la marca que deja el ciclo en lo que aplasta.\n\n'Los héroes vinieron. Nosotros les abrimos las puertas.' La frase termina a mitad. El tablero no necesitó el resto.",
		"options": [
			{"label": "Buscar qué quedó de ellos (+8 monedas)", "hp": 0, "coins": 8, "heal": 0},
			{"label": "Arrodillarte ante lo que fue Carcosa (-10 HP max, Reliquia)", "hp": 0, "coins": 0, "heal": 0, "relic": true, "max_hp": -10},
			{"label": "Marcharte. El tablero no quiere que recuerdes esto (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "La Fuente Oscura",
		"text": "La fuente no refleja el techo. Refleja el cielo de Carcosa — el que existía antes de que Hastur se convirtiera en el tablero.\n\nEra un pozo de ofrenda. Los vecinos dejaban objetos en el fondo para que fueran devueltos transformados. El tablero cumplió esa promesa: los devolvió como otra cosa, en otro ciclo, sin que nadie los reconociera.\n\nEn el fondo, uno de los procesos del tablero toma forma. No tiene cuerpo todavía. Le estás dando tiempo.",
		"options": [
			{"label": "Beber. Que el ciclo procese lo que decides (+20 HP)", "hp": 0, "coins": 0, "heal": 20},
			{"label": "Meter la mano hasta encontrar qué hay abajo (-15 HP, Reliquia)", "hp": -15, "coins": 0, "heal": 0, "relic": true},
			{"label": "Rodearla. Hay procesos que es mejor no acelerar (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "El Caballero Sin Nombre",
		"text": "Fue uno de los Caballeros de Carcosa — élite de la guardia del Príncipe. Se ve en cómo se para, en la distancia calculada, en cómo su mano no toca la empuñadura pero sabe exactamente cuánto tardaría.\n\nEl tablero borró el nombre primero. La causa, después. Lo que quedó fue la función: desafiar. Lleva ciclos cumpliendo ese reflejo frente a piezas que ya no recuerda, en nombre de un señor que ya no puede nombrar.\n\n'Si me vences, soy tuyo.' Lleva siglos esperando que alguien lo libere de estar esperando.",
		"options": [
			{"label": "Aceptar el duelo (combate)", "hp": 0, "coins": 0, "heal": 0, "miniboss": true},
			{"label": "Pagar el peaje. No todo vale la pena (-8 monedas)", "hp": 0, "coins": -8, "heal": 0},
			{"label": "Retroceder. Hay otro camino (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "La Mesa del Destino",
		"text": "El dado es de hueso. No el hueso de un animal.\n\nHastur no necesita ganar. Necesita que el juego continúe. Por eso la primera tirada es siempre gratuita — la gratitud es la mecánica más eficiente para que una pieza vuelva a la mesa. Para cuando decides si tirar de nuevo, ya no estás decidiendo si juegas. Estás decidiendo cuánto.\n\nLa silla frente a ti lleva el peso de todo lo que se sentó aquí. Una voz sin boca: 'El tablero recuerda cada resultado. Tú, no.'",
		"options": [
			{"label": "Lanzar el dado (primer lanzamiento gratis)", "dice_game": true},
			{"label": "Levantarte sin tocar nada (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "La Biblioteca de los Susurros",
		"text": "Los libros están encuadernados en piel de pieza — hay una diferencia de textura con la piel animal, y quien lleva tiempo en el tablero puede notarla.\n\nEl Capítulo Prohibido no es un texto ocultista. Es el manual del ciclo, escrito por el Príncipe antes de entrar al tablero, para quien llegara después. Hastur lo copió aquí como trampa: que las piezas que lean demasiado se quiebren antes de poder actuar.\n\n'No eres el primero.' Todas las voces dicen lo mismo. Todas excepto una.",
		"options": [
			{"label": "Leer el Capítulo Prohibido (+15 Lore, -30 Cordura)", "hp": 0, "coins": 0, "heal": 0, "lore_hint_big": true, "sanity_loss": 30},
			{"label": "Quemarla. Que Hastur no tenga más trampas aquí (+10 HP, +15 Cordura)", "hp": 0, "coins": 0, "heal": 10, "sanity_gain": 15},
			{"label": "Escuchar sin leer. Dejar que entre sin procesarlo (Reliquia, +2 Maldiciones)", "hp": 0, "coins": 0, "heal": 0, "relic": true, "double_curse": true},
		]
	},
	{
		"title": "El Susurro en la Galería",
		"text": "La cadena que sostiene el lienzo es demasiado gruesa para un cuadro. No es una cadena de exhibición — es una cadena de contención.\n\nNadie encargó esta pintura. Apareció un ciclo, cubierta, en el lugar exacto donde debía estar para que alguien la encontrara. El tablero tampoco sabe qué hay debajo. Por eso dejó la cadena.\n\nLa tela se mueve. Lo que hay debajo lleva tiempo intentando salir por sus propios medios.",
		"options": [
			{"label": "Levantar la tela. Ver lo que el tablero no quiso ver (-20 Cordura, Reliquia)", "sanity_loss": 20, "specific_relic": "ojo_grito"},
			{"label": "Quemarla antes de ver. No todo conocimiento es deuda (-8 HP, carta Ceniza Preventiva)", "hp": -8, "add_specific_card": "Ceniza Preventiva"},
			{"label": "Marcharse sin mirar. Algunas cadenas existen por razón (+10 Cordura)", "sanity_gain": 10},
		]
	},
	{
		"title": "La Lección del Anatomista",
		"text": "La máscara de plumas doradas era símbolo de los Anatomistas de Carcosa — los que estudiaban el ajedrez como si fuera medicina del alma. Diseccionaban la forma en que las piezas se movían para entender qué las hacía humanas todavía.\n\nEso era antes. Ahora disecciona piezas del tablero para entender qué las hace funcionar. Sus notas son el relic más buscado por quienes saben leerlas.\n\n'Llevas tanto tiempo atravesando cuerpos. ¿Nunca quisiste saber lo que el tablero pone dentro, específicamente?'",
		"options": [
			{"label": "Extender el brazo. Que lo vea (-15 HP max, Reliquia + carta)", "max_hp": -15, "specific_relic": "manual_anatomista", "add_specific_card": "Incision Precisa"},
			{"label": "Ceder una carta como sujeto de estudio (+1 ATK en mazo)", "remove_card_event": true, "boost_attack_cards": true},
			{"label": "Tomar el bisturí antes de que él decida (combate)", "miniboss": true},
		]
	},
	{
		"title": "El Jardín de los Ojos",
		"text": "Era un jardín de esculturas en Carcosa — cada figura tenía ojos de vidrio para que los visitantes no se sintieran solos. El tablero lo recicló con sus habitantes dentro.\n\nEl vidrio encontró carne. La carne encontró función. Ahora el jardín cumple el propósito que el tablero siempre tuvo para él: observar y transmitir todo lo que ve.\n\nTodos los ojos apuntan al mismo lugar. Ese lugar eres tú. En el centro, la fuente que los alimenta parece agua clara.",
		"options": [
			{"label": "Beber de la fuente. Ver lo que ellos ven (-25 Cordura, carta Mirada que Devora)", "sanity_loss": 25, "add_specific_card": "Mirada que Devora"},
			{"label": "Arrancar uno. Que algo deje de mirar (-10 HP, Reliquia)", "hp": -10, "specific_relic": "ojo_arrancado"},
			{"label": "Cruzar sin tocar nada. Que no sepan que estuviste aquí (depende de Cordura)", "sanity_conditional": true},
		]
	},
	{
		"title": "El Espejo de las Vidas Pasadas",
		"text": "El espejo fue instalado por Hastur, no encontrado. Su función: mostrar a la pieza lo que fue, para que decida si quiere seguir siéndolo.\n\nNo ves tu rostro. Ves una iteración anterior — no una alucinación, sino un archivo. El tablero guarda registro de cada versión de ti que pasó por aquí. Este espejo es el acceso de consulta. Las sombras grabadas en el marco son las que vinieron antes y decidieron ceder.\n\nUna voz sin urgencia: 'Cede un registro. Tu mente tendrá menos peso. O menos tú. El tablero no distingue la diferencia.'",
		"options": [
			{"label": "Ceder un registro al archivo (Eliminar carta, -20 Cordura)", "remove_card_event": true, "sanity_loss": 20},
			{"label": "Romperlo. Que el tablero pierda este registro (-10 HP, +10 monedas)", "hp": -10, "coins": 10},
			{"label": "Darle la espalda. No eres lo que el tablero archivó (nada)", "hp": 0},
		]
	},
]

var current_event: Dictionary = {}
var relic_assignments: Dictionary = {}

# Dice game state
var _dice_panel: Panel = null
var _dice_face_lbl: Label = null
var _dice_result_lbl: Label = null
var _dice_detail_lbl: Label = null
var _dice_status_lbl: Label = null
var _dice_reroll_btn: Button = null
var _dice_roll_count: int = 0
var _dice_rolling: bool = false
var _dice_history: Array = []   # Array de {face, type}

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _trigger_option(0)
			KEY_2: _trigger_option(1)
			KEY_3: _trigger_option(2)

func _trigger_option(i: int) -> void:
	if not _typewriter_done: return
	if i < 0 or i >= _option_buttons.size(): return
	var btn = _option_buttons[i]
	if is_instance_valid(btn) and not btn.disabled:
		_on_option_selected(i)

func _ready() -> void:
	_font_title     = load("res://assets/fonts/CinzelDecorative-Bold.otf")
	_font_narrative = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	_font_ui        = load("res://assets/fonts/rajdhani.medium.ttf")
	_font_corrupt   = load("res://assets/fonts/RubikGlitch-Regular.ttf")

	# DEV: forzar evento del dado
	if GameManager.dev_force_dice_event:
		GameManager.dev_force_dice_event = false
		current_event = events.filter(func(e): return e.get("title") == "La Mesa del Destino")[0]
		_assign_relics()
		build_ui()
		return

	# Aparición de El Umbral
	var can_show_rift = (
		not GameManager.rift_visited
		and not GameManager.rift_notified
		and (GameManager.lore_progress >= 25 or GameManager.rift_wanderer_offered)
		and (GameManager.relics.size() > 0 or GameManager.rift_wanderer_offered)
	)
	if can_show_rift:
		GameManager.rift_notified = true
		current_event = UMBRAL_EVENT
		_assign_relics()
		build_ui()
		return

	var pool = events.duplicate()
	if GameManager.lore_progress >= 4 and not GameManager.has_relic("lengua_tablero"):
		pool.append({
			"title": "El Susurro Amarillo",
			"text": "Los caídos no están muertos. Están entre ciclos — el tablero aún no terminó de procesarlos.\n\nTe hablan en el idioma de Carcosa, que también es el idioma del tablero antes de que Hastur lo convirtiera en otra cosa. Entre los símbolos, una frase se repite: el nombre que el tablero usa para referirse a ti. No es el tuyo. Nunca fue el tuyo.\n\nAlguien al otro lado de esta frecuencia te busca. Lleva suficientes ciclos haciéndolo como para saber exactamente dónde mirar.",
			"options": [
				{"label": "Buscar quién puede traducir esto (Reliquia: Lengua del Tablero + maldición)", "hp": 0, "coins": 0, "heal": 0, "specific_relic": "lengua_tablero"},
				{"label": "Ignorarlo. Los héroes no necesitan preguntas.", "hp": 0, "coins": 0, "heal": 0},
				{"label": "Escuchar hasta que el ciclo duela (-8 HP, +1 Lore)", "hp": -8, "coins": 0, "heal": 0, "lore_hint": true},
			]
		})
	current_event = pool[randi() % pool.size()]
	_assign_relics()
	build_ui()

func _assign_relics() -> void:
	var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
	available.shuffle()
	var pool_idx = 0
	for i in range(current_event["options"].size()):
		var opt = current_event["options"][i]
		if opt.get("relic", false) and pool_idx < available.size():
			relic_assignments[i] = available[pool_idx]
			pool_idx += 1

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo abisal
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.size = vp
	add_child(bg)
	
	# Sol Negro sutil de fondo
	_create_background_sun(vp)
	_start_event_rain(vp)

	var stats_row = Node2D.new()
	stats_row.name = "InfoLabel"
	stats_row.z_index = 10
	add_child(stats_row)

	var stat_defs = [
		["StatHP",     "❤ %d/%d" % [GameManager.player_hp, GameManager.player_max_hp],   Color(0.95, 0.3, 0.35),  100.0],
		["StatCoins",  "◆ %d" % GameManager.coins,                                        Color(0.95, 0.78, 0.2),  320.0],
		["StatSanity", "⬤ %d/%d" % [GameManager.sanity, GameManager.max_sanity],         Color(0.55, 0.3, 0.88),  520.0],
		["StatFloor",  "Piso %d/16" % (GameManager.current_map_floor + 1),                Color(0.58, 0.65, 0.82), 730.0],
	]
	for sd in stat_defs:
		var lbl = Label.new()
		lbl.name = sd[0]
		lbl.text = sd[1]
		lbl.modulate = sd[2]
		lbl.add_theme_font_size_override("font_size", 15)
		if _font_ui: lbl.add_theme_font_override("font", _font_ui)
		lbl.position = Vector2(sd[3], 12)
		lbl.size = Vector2(200, 28)
		stats_row.add_child(lbl)

	var title = Label.new()
	title.text = current_event["title"].to_upper()
	title.add_theme_font_size_override("font_size", 34)
	if _font_ui: title.add_theme_font_override("font", _font_ui)
	title.modulate = Color(0.85, 0.75, 0.2, 0.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(100, 40)
	title.size = Vector2(952, 50)
	title.z_index = 10
	add_child(title)
	var tw_title = create_tween().set_parallel(true)
	tw_title.tween_property(title, "modulate:a", 1.0, 0.35)
	tw_title.tween_property(title, "position:y", 60.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Línea de reacción del personaje
	var reaction_lbl = Label.new()
	reaction_lbl.text = EVENT_CHARACTER_REACTIONS.get(GameManager.selected_character, "")
	reaction_lbl.add_theme_font_size_override("font_size", 15)
	if _font_narrative: reaction_lbl.add_theme_font_override("font", _font_narrative)
	const CHAR_REACTION_COLORS = {
		"prince":    Color(0.65, 0.3, 0.95),
		"estratega": Color(0.4, 0.75, 0.95),
		"guardian":  Color(0.4, 0.85, 0.55),
		"mahar":     Color(0.95, 0.65, 0.25),
	}
	var _rc = CHAR_REACTION_COLORS.get(GameManager.selected_character, Color(0.55, 0.5, 0.4))
	reaction_lbl.modulate = Color(_rc.r, _rc.g, _rc.b, 0.0)
	reaction_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reaction_lbl.position = Vector2(100, 108)
	reaction_lbl.size = Vector2(952, 26)
	reaction_lbl.z_index = 10
	add_child(reaction_lbl)
	create_tween().tween_property(reaction_lbl, "modulate:a", 1.0, 0.3).set_delay(0.25)

	var sep = ColorRect.new()
	sep.color = Color(0.4, 0.3, 0.1, 0.0)
	sep.size = Vector2(320, 1)
	sep.position = Vector2((vp.x - 320) / 2.0, 142)
	sep.z_index = 10
	add_child(sep)
	create_tween().tween_property(sep, "color:a", 0.45, 0.3).set_delay(0.3)

	var text_panel = Panel.new()
	text_panel.modulate.a = 0.0
	text_panel.position = Vector2(146, 150); text_panel.size = Vector2(860, 230)
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.05, 0.08, 0.85); ts.set_corner_radius_all(8)
	ts.border_width_left = 2; ts.border_width_top = 1; ts.border_color = Color(0.5, 0.4, 0.15, 0.6)
	text_panel.add_theme_stylebox_override("panel", ts)
	text_panel.z_index = 5
	add_child(text_panel)
	var tw_panel = create_tween().set_parallel(true)
	tw_panel.tween_property(text_panel, "modulate:a", 1.0, 0.3).set_delay(0.15)
	tw_panel.tween_property(text_panel, "position:x", 146.0, 0.3).from(116.0).set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Corrupción de texto por locura baja
	var raw_text: String = current_event["text"]
	var sanity = GameManager.sanity
	if sanity < 30:
		var words = raw_text.split(" ")
		var corruption_count = 5 if sanity < 15 else randi_range(2, 3)
		var indices = range(words.size())
		indices.shuffle()
		for ci in range(min(corruption_count, indices.size())):
			var wi = indices[ci]
			if words[wi].length() > 2:
				words[wi] = CORRUPTION_WORDS[randi() % CORRUPTION_WORDS.size()]
		raw_text = " ".join(words)

	var text_scroll = ScrollContainer.new()
	text_scroll.position = Vector2(16, 14)
	text_scroll.size = Vector2(828, 202)
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_panel.add_child(text_scroll)

	var text = Label.new()
	text.text = raw_text
	text.add_theme_font_size_override("font_size", 18)
	var chosen_font = _font_corrupt if GameManager.sanity < 30 else _font_ui
	if chosen_font: text.add_theme_font_override("font", chosen_font)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(800, 0)
	text_scroll.add_child(text)

	# Typewriter
	_typewriter_done = false
	_option_buttons.clear()
	var total_chars = raw_text.length()
	var tw_dur = clampf(total_chars * 0.018, 0.4, 0.8)
	text.visible_characters = 0
	var tw_type = create_tween()
	tw_type.tween_method(func(n: int): text.visible_characters = n, 0, total_chars, tw_dur).set_delay(0.2)
	tw_type.tween_callback(func():
		_typewriter_done = true
		for b in _option_buttons: b.disabled = b.get_meta("unaffordable", false)
	)
	# Skip typewriter on click (both panel and scroll container catch clicks)
	var _skip_typewriter = func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			text.visible_characters = -1
			_typewriter_done = true
			for b in _option_buttons: b.disabled = b.get_meta("unaffordable", false)
	text_panel.gui_input.connect(_skip_typewriter)
	text_scroll.gui_input.connect(_skip_typewriter)
	text_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	text_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	var options = current_event["options"]
	for i in range(options.size()):
		var opt = options[i]
		_create_option_button(i, opt)

	# --- BOTON VER MAZO ---
	var btn_view = Button.new()
	btn_view.text = "🎴 VER MAZO"
	btn_view.size = Vector2(180, 45)
	btn_view.position = Vector2(vp.x - 220, 20)
	btn_view.add_theme_font_size_override("font_size", 14)
	btn_view.pressed.connect(func(): GameManager.show_deck_overlay(self))
	add_child(btn_view)

func _create_background_sun(vp: Vector2) -> void:
	var sun = Panel.new()
	var sz = 400.0
	sun.size = Vector2(sz, sz)
	sun.position = Vector2(vp.x/2 - sz/2, -100)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0,0,0)
	s.set_corner_radius_all(sz/2)
	s.border_width_left = 4; s.border_color = Color(0.8, 0.5, 0.1, 0.2)
	sun.add_theme_stylebox_override("panel", s)
	sun.modulate.a = 0.4
	add_child(sun)

func _start_event_rain(vp: Vector2) -> void:
	for i in range(60):
		var drop = ColorRect.new()
		drop.size = Vector2(1, randi_range(10, 20))
		drop.color = Color(0.5, 0.5, 0.7, 0.2)
		drop.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		add_child(drop)
		var dur = randf_range(0.6, 1.0)
		var tw = create_tween().set_loops()
		tw.tween_property(drop, "position:y", vp.y + 20, dur).from(-20)

func _create_option_button(i: int, opt: Dictionary) -> void:
	var row = Node2D.new()
	row.name = "OptionRow" + str(i)
	row.position = Vector2(236, 400 + i * 65)
	row.z_index = 10
	add_child(row)

	var label_text = opt["label"]
	if opt.get("hp", 0) < 0 or opt.get("max_hp", 0) < 0: label_text = "🩸 " + label_text
	elif opt.get("heal", 0) > 0: label_text = "🩹 " + label_text
	if opt.get("sanity_loss", 0) > 0: label_text = "🧠 " + label_text
	elif opt.get("sanity_gain", 0) > 0: label_text = "🕯 " + label_text
	if opt.get("relic", false): label_text = "💍 " + label_text
	if opt.get("add_curse", false) or opt.get("double_curse", false): label_text = "💀 " + label_text
	if opt.get("remove_card_event", false):
		label_text = "✂ " + label_text

	var hp_cost = opt.get("hp", 0)
	var unaffordable = hp_cost < 0 and GameManager.player_hp + hp_cost <= 0

	var btn = Button.new()
	btn.text = label_text
	btn.size = Vector2(680, 60)
	btn.add_theme_font_size_override("font_size", 15)
	if _font_ui: btn.add_theme_font_override("font", _font_ui)
	btn.disabled = not _typewriter_done or unaffordable
	btn.pivot_offset = Vector2(340, 30)
	if unaffordable:
		btn.set_meta("unaffordable", true)
		btn.modulate = Color(0.5, 0.5, 0.5, 0.6)

	# Tooltip Dinamico
	var tt = ""
	var has_relic_info = false
	var r_data_final = {}

	if opt.get("hp", 0) < 0:
		tt += "Pierdes " + str(abs(opt["hp"])) + " HP.\n"
		if unaffordable: tt += "[ No tienes suficiente vida ]\n"
	if opt.get("max_hp", 0) < 0: tt += "Pierdes " + str(abs(opt["max_hp"])) + " de Vida Maxima.\n"
	if opt.get("sanity_loss", 0) > 0: tt += "Pierdes " + str(opt["sanity_loss"]) + " de Cordura.\n"

	if opt.get("relic", false) and relic_assignments.has(i):
		var r_id = relic_assignments[i]
		r_data_final = GameManager.RELIC_DATA[r_id]
		has_relic_info = true
	elif opt.get("specific_relic", "") != "":
		var r_id = opt["specific_relic"]
		r_data_final = GameManager.RELIC_DATA.get(r_id, {"name": "???", "desc": "???"})
		has_relic_info = true

	if opt.get("double_curse", false):
		tt += "[!] MALDICION: Recibes 2 cartas de 'Peso de la Verdad'.\n"
	if opt.get("add_curse", false):
		tt += "[!] MALDICION: Recibes 1 carta de 'Peso de la Verdad'.\n"

	btn.tooltip_text = tt

	# Borde izquierdo coloreado según tipo de consecuencia
	var border_color: Color
	if opt.get("miniboss", false):
		border_color = Color(0.5, 0.05, 0.05)
	elif opt.get("add_curse", false) or opt.get("double_curse", false):
		border_color = Color(0.4, 0.1, 0.5)
	elif opt.get("sanity_loss", 0) > 0:
		border_color = Color(0.5, 0.1, 0.7)
	elif opt.get("hp", 0) < 0 or opt.get("max_hp", 0) < 0:
		border_color = Color(0.7, 0.1, 0.1)
	elif opt.get("heal", 0) > 0:
		border_color = Color(0.2, 0.6, 0.2)
	elif opt.get("relic", false) or opt.get("specific_relic", "") != "":
		border_color = Color(0.75, 0.6, 0.1)
	else:
		border_color = Color(0.3, 0.3, 0.35)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.11, 0.92)
	style.set_border_width_all(1)
	style.border_width_left = 5
	style.border_color = border_color
	style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", style)

	var idx = i
	btn.pressed.connect(func(): _on_option_selected(idx))

	var is_curse = opt.get("add_curse", false) or opt.get("double_curse", false)
	var is_bonus = opt.get("bonus_card", false)

	btn.mouse_entered.connect(func():
		btn.create_tween().tween_property(btn, "scale", Vector2(1.02, 1.02), 0.1)
		if has_relic_info:
			_show_relic_preview(btn, r_data_final)
		if is_curse:
			var curse_data = {"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true}
			_show_card_preview(btn, curse_data, has_relic_info)
		elif is_bonus:
			var card_data = {"name": "Reina", "attack": 6, "defense": 2, "cost": 4}
			_show_card_preview(btn, card_data, has_relic_info)
	)

	btn.mouse_exited.connect(func():
		btn.create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		_hide_relic_preview()
		_hide_card_preview()
	)

	# Stagger fade-in
	btn.modulate.a = 0.0
	create_tween().tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(0.3 + 0.05 * i)

	_option_buttons.append(btn)
	row.add_child(btn)

var _card_preview: Control

func _show_card_preview(target: Button, data: Dictionary, is_offset: bool = false) -> void:
	if _card_preview: _card_preview.queue_free()
	
	var vp = get_viewport_rect().size
	var card_scene = load("res://scenes/combat/Card.tscn")
	_card_preview = card_scene.instantiate()
	add_child(_card_preview)
	_card_preview.setup(data)
	
	var card_w = 130 * 1.1
	var relic_w = 300 if is_offset else 0
	
	# Determinar si hay espacio a la derecha
	var space_right = vp.x - (target.global_position.x + target.size.x)
	var required_w = relic_w + card_w + 40
	
	var final_pos = Vector2.ZERO
	if space_right >= required_w:
		# Lógica normal: a la derecha
		final_pos = target.global_position + Vector2(target.size.x + 20 + relic_w, -50)
	else:
		# No hay espacio a la derecha: mover a la izquierda del botón
		final_pos = target.global_position + Vector2(-card_w - 20, -50)
		
	_card_preview.global_position = final_pos
	_card_preview.scale = Vector2(1.1, 1.1)
	_card_preview.z_index = 150

	# Preview-only: desactivar hover/tooltip para no solapar otros panels
	_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_preview.hover_scale_enabled = false
	if _card_preview.tooltip_panel:
		_card_preview.tooltip_panel.visible = false

	_card_preview.modulate.a = 0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_card_preview, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card_preview, "position:y", _card_preview.position.y + 20, 0.2).from(_card_preview.position.y)

func _hide_card_preview() -> void:
	if _card_preview:
		_card_preview.queue_free()
		_card_preview = null

var _relic_preview: Panel

func _show_relic_preview(target: Button, data: Dictionary) -> void:
	if _relic_preview: _relic_preview.queue_free()
	
	_relic_preview = Panel.new()
	_relic_preview.size = Vector2(280, 100)
	_relic_preview.z_index = 100
	
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.1, 0.98)
	s.border_width_left = 3; s.border_color = Color(0.9, 0.7, 0.2)
	s.set_corner_radius_all(6)
	_relic_preview.add_theme_stylebox_override("panel", s)
	
	var title = Label.new()
	title.text = "💍 " + data["name"].to_upper()
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(1, 0.9, 0.4)
	title.position = Vector2(12, 10)
	_relic_preview.add_child(title)
	
	var desc = Label.new()
	desc.text = data["desc"]
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	var est_lines = desc.text.length() / 30 + desc.text.count("\n") + 1
	var desc_h = max(60, est_lines * 16)
	desc.position = Vector2(12, 35); desc.size = Vector2(250, desc_h)
	_relic_preview.add_child(desc)
	
	_relic_preview.size = Vector2(280, 45 + desc_h)
	
	var vp2 = get_viewport_rect().size
	var rp_w = 280.0
	var space_right2 = vp2.x - (target.global_position.x + target.size.x)
	var preview_y = target.global_position.y - 20
	if space_right2 >= rp_w + 20:
		_relic_preview.global_position = Vector2(target.global_position.x + target.size.x + 15, preview_y)
	else:
		var left_x = max(10.0, target.global_position.x - rp_w - 15)
		_relic_preview.global_position = Vector2(left_x, preview_y)
	add_child(_relic_preview)
	
	_relic_preview.modulate.a = 0
	_relic_preview.scale = Vector2(0.9, 0.9)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_relic_preview, "modulate:a", 1.0, 0.15)
	tw.tween_property(_relic_preview, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_relic_preview() -> void:
	if _relic_preview:
		_relic_preview.queue_free()
		_relic_preview = null

func _show_lore_modal() -> void:
	var vp = get_viewport_rect().size
	# Usar CanvasLayer para asegurar prioridad sobre los otros elementos de Evento
	var layer = CanvasLayer.new()
	layer.layer = 150
	add_child(layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.96)
	overlay.size = vp
	layer.add_child(overlay)
	
	# Efecto de pergamino antiguo (estilizado con Panel)
	var scroll_panel = Panel.new()
	scroll_panel.size = Vector2(vp.x * 0.75, vp.y * 0.75)
	scroll_panel.position = (vp - scroll_panel.size) / 2
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.08, 0.05) # Sepia abisal
	s.set_border_width_all(3)
	s.border_color = Color(0.5, 0.4, 0.1)
	s.set_corner_radius_all(4)
	scroll_panel.add_theme_stylebox_override("panel", s)
	overlay.add_child(scroll_panel)
	
	var title = Label.new()
	title.text = "--- EL CAPÍTULO PROHIBIDO ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.9, 0.8, 0.3)
	title.position = Vector2(0, 40); title.size = Vector2(scroll_panel.size.x, 50)
	scroll_panel.add_child(title)
	
	var lore_text = Label.new()
	lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	lore_text.add_theme_font_size_override("font_size", 18)
	lore_text.modulate = Color(0.85, 0.85, 0.8)
	lore_text.position = Vector2(60, 110); lore_text.size = Vector2(scroll_panel.size.x - 120, scroll_panel.size.y - 220)
	scroll_panel.add_child(lore_text)
	
	var content = "En un reino que el mapa no nombra, un Rey buscó la eternidad en el reflejo de una pieza de marfil. No entendió que el tablero no era su dominio, sino su celda.\n\nAhora, el Rey Sin Corona aguarda en el tramo final del Tablero Dorado. Es el guardián de una puerta que no debe abrirse, el primer velo antes de la Perdida Carcosa.\n\n'Incluso los reyes lloran cuando el Amarillo viste su piel...'"
	
	var cont_btn = Button.new()
	cont_btn.text = "VOLVER AL MAPA"
	cont_btn.size = Vector2(240, 50)
	cont_btn.position = Vector2(scroll_panel.size.x/2 - 120, scroll_panel.size.y - 80)
	cont_btn.visible = false
	scroll_panel.add_child(cont_btn)
	cont_btn.pressed.connect(func(): GameManager.go_to_scene("res://scenes/ui/Map.tscn"))
	
	await _typewrite(lore_text, content)
	cont_btn.visible = true

func _typewrite(lbl: Label, text: String, base_delay: float = 0.015) -> void:
	lbl.text = ""
	for i in range(text.length()):
		lbl.text = text.substr(0, i + 1)
		if get_node_or_null("/root/AudioManager") and i % 6 == 0:
			AudioManager.play("menu_hover") # Sonido de escritura
		await get_tree().create_timer(base_delay).timeout

func _on_option_selected(idx: int) -> void:
	var opt = current_event["options"][idx]

	if opt.get("dice_game", false):
		_show_dice_game()
		return

	if opt.get("rift_relic_sacrifice", false):
		if GameManager.relics.is_empty():
			flash_small_event("No tienes nada que ofrecer al umbral.")
			return
		_show_relic_sacrifice_screen()
		return

	if opt.get("rift_wanderer_rest", false):
		GameManager.lore_progress += 20
		GameManager.rift_wanderer_offered = true
		GameManager.rift_notified = false
		# Añadir la carta más rara disponible del pool
		var rare_cards = CardData.ALL_CARDS.filter(func(c): return c.get("rarity", "") == "legendary" or c.get("rarity", "") == "rare")
		if not rare_cards.is_empty():
			rare_cards.shuffle()
			GameManager.add_card(rare_cards[0].duplicate())
		GameManager.go_to_scene("res://scenes/ui/Map.tscn")
		return

	if opt.get("hp", 0) != 0:
		GameManager.player_hp = clamp(GameManager.player_hp + opt["hp"], 1, GameManager.player_max_hp)

	if opt.get("coins", 0) != 0:
		GameManager.coins = max(0, GameManager.coins + opt["coins"])

	if opt.get("heal", 0) > 0:
		GameManager.heal(opt["heal"])

	if opt.get("max_hp", 0) != 0:
		GameManager.player_max_hp = max(10, GameManager.player_max_hp + opt["max_hp"])
		GameManager.player_hp = clamp(GameManager.player_hp, 1, GameManager.player_max_hp)

	if opt.get("miniboss", false):
		GameManager.is_miniboss_fight = true
		GameManager.is_boss_fight = false
		if opt.get("rift_on_win", false):
			GameManager.rift_combat_pending = true
		GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
		return

	if opt.get("goto_shop", false):
		GameManager.go_to_scene("res://scenes/ui/Shop.tscn")
		return

	if opt.get("bonus_card", false):
		var bonus = {"name": "Reina", "attack": 6, "defense": 2, "cost": 4}
		GameManager.add_card(bonus)

	if opt.get("remove_card_event", false):
		_show_card_removal_screen()
		return

	if opt.get("add_curse", false):
		var curse = {"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true}
		GameManager.add_card(curse)

	if opt.get("double_curse", false):
		var curse = {"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true}
		GameManager.add_card(curse)
		GameManager.add_card(curse)

	if opt.get("sanity_loss", 0) > 0:
		GameManager.sanity = max(0, GameManager.sanity - opt["sanity_loss"])

	if opt.get("sanity_gain", 0) > 0:
		GameManager.sanity = min(100, GameManager.sanity + opt["sanity_gain"])

	if opt.get("lore_hint_big", false):
		GameManager.lore_progress += 15
		GameManager.unlock_lore("capitulo_prohibido")
		_show_lore_modal()
		return

	if opt.get("relic", false) and relic_assignments.has(idx):
		GameManager.add_relic(relic_assignments[idx])
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("relic_get")

	if opt.get("specific_relic", "") != "":
		GameManager.add_relic(opt["specific_relic"])
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("relic_get")

	if opt.get("lore_hint", false):
		GameManager.lore_progress += 1

	if opt.get("add_specific_card", "") != "":
		var card_name = opt["add_specific_card"]
		var found = CardData.ALL_CARDS.filter(func(c): return c["name"] == card_name)
		if not found.is_empty():
			GameManager.add_card(found[0].duplicate())

	if opt.get("boost_attack_cards", false):
		for c in GameManager.player_deck:
			if c.get("attack", 0) > 0:
				c["attack"] += 1
		flash_small_event("Tus cartas de Ataque ganan +1 de daño.")

	if opt.get("sanity_conditional", false):
		_resolve_sanity_conditional(opt)
		return

	GameManager.go_to_scene("res://scenes/ui/Map.tscn")

# Dice game
func _show_dice_game() -> void:
	for i in range(current_event["options"].size()):
		var row = get_node_or_null("OptionRow" + str(i))
		if row:
			row.visible = false

	_dice_roll_count = 0

	_dice_panel = Panel.new()
	_dice_panel.position = Vector2(226, 100)
	_dice_panel.size = Vector2(700, 430)
	_dice_panel.z_index = 5
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.09, 0.98)
	ps.set_corner_radius_all(10)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.55, 0.45, 0.1)
	_dice_panel.add_theme_stylebox_override("panel", ps)
	add_child(_dice_panel)

	# Entrada animada del panel dado
	_dice_panel.modulate.a = 0.0
	_dice_panel.position.y -= 30.0
	var tw_panel = create_tween().set_parallel(true)
	tw_panel.tween_property(_dice_panel, "modulate:a", 1.0, 0.35)
	tw_panel.tween_property(_dice_panel, "position:y",
		_dice_panel.position.y + 30.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var title_lbl = Label.new()
	title_lbl.text = "El Dado del Destino"
	title_lbl.add_theme_font_size_override("font_size", 26)
	if _font_title: title_lbl.add_theme_font_override("font", _font_title)
	title_lbl.modulate = Color(0.95, 0.82, 0.3)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(0, 18)
	title_lbl.size = Vector2(700, 38)
	_dice_panel.add_child(title_lbl)

	_dice_face_lbl = Label.new()
	_dice_face_lbl.text = "⚄"
	_dice_face_lbl.add_theme_font_size_override("font_size", 100)
	_dice_face_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_face_lbl.position = Vector2(0, 60)
	_dice_face_lbl.size = Vector2(700, 120)
	_dice_panel.add_child(_dice_face_lbl)

	_dice_result_lbl = Label.new()
	_dice_result_lbl.add_theme_font_size_override("font_size", 17)
	if _font_narrative: _dice_result_lbl.add_theme_font_override("font", _font_narrative)
	_dice_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_result_lbl.position = Vector2(30, 195)
	_dice_result_lbl.size = Vector2(640, 30)
	_dice_panel.add_child(_dice_result_lbl)

	_dice_detail_lbl = Label.new()
	_dice_detail_lbl.add_theme_font_size_override("font_size", 14)
	if _font_narrative: _dice_detail_lbl.add_theme_font_override("font", _font_narrative)
	_dice_detail_lbl.modulate = Color(0.75, 0.75, 0.8)
	_dice_detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_detail_lbl.position = Vector2(30, 230)
	_dice_detail_lbl.size = Vector2(640, 50)
	_dice_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dice_panel.add_child(_dice_detail_lbl)

	_dice_status_lbl = Label.new()
	_dice_status_lbl.add_theme_font_size_override("font_size", 13)
	if _font_ui: _dice_status_lbl.add_theme_font_override("font", _font_ui)
	_dice_status_lbl.modulate = Color(0.6, 0.6, 0.65)
	_dice_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_status_lbl.position = Vector2(0, 288)
	_dice_status_lbl.size = Vector2(700, 26)
	_dice_panel.add_child(_dice_status_lbl)

	var sep = ColorRect.new()
	sep.color = Color(0.25, 0.22, 0.12, 0.6)
	sep.position = Vector2(40, 322)
	sep.size = Vector2(620, 1)
	_dice_panel.add_child(sep)

	var roll_btn = Button.new()
	roll_btn.name = "InitialRollBtn"
	roll_btn.text = "Tirar el dado"
	roll_btn.position = Vector2(200, 340)
	roll_btn.size = Vector2(300, 50)
	roll_btn.add_theme_font_size_override("font_size", 16)
	if _font_ui: roll_btn.add_theme_font_override("font", _font_ui)
	_style_btn(roll_btn, Color(0.2, 0.45, 0.2))
	roll_btn.pivot_offset = roll_btn.size / 2
	roll_btn.mouse_entered.connect(func(): create_tween().tween_property(roll_btn, "scale", Vector2(1.04, 1.04), 0.1))
	roll_btn.mouse_exited.connect(func():  create_tween().tween_property(roll_btn, "scale", Vector2.ONE, 0.1))
	roll_btn.pressed.connect(func(): _do_dice_roll(roll_btn))
	_dice_panel.add_child(roll_btn)

	_dice_reroll_btn = Button.new()
	_dice_reroll_btn.name = "RerollBtn"
	_dice_reroll_btn.text = "Lanzar de nuevo  (-%d HP)" % DICE_REROLL_COSTS[0]
	_dice_reroll_btn.position = Vector2(60, 340)
	_dice_reroll_btn.size = Vector2(320, 50)
	_dice_reroll_btn.add_theme_font_size_override("font_size", 14)
	if _font_ui: _dice_reroll_btn.add_theme_font_override("font", _font_ui)
	_style_btn(_dice_reroll_btn, Color(0.4, 0.22, 0.05))
	_dice_reroll_btn.visible = false
	_dice_reroll_btn.pivot_offset = _dice_reroll_btn.size / 2
	_dice_reroll_btn.mouse_entered.connect(func(): create_tween().tween_property(_dice_reroll_btn, "scale", Vector2(1.04, 1.04), 0.1))
	_dice_reroll_btn.mouse_exited.connect(func():  create_tween().tween_property(_dice_reroll_btn, "scale", Vector2.ONE, 0.1))
	_dice_reroll_btn.pressed.connect(func(): _do_dice_reroll())
	_dice_panel.add_child(_dice_reroll_btn)

	var cont_btn = Button.new()
	cont_btn.name = "ContinueBtn"
	cont_btn.text = "Continuar"
	cont_btn.position = Vector2(390, 340)
	cont_btn.size = Vector2(250, 50)
	cont_btn.add_theme_font_size_override("font_size", 14)
	if _font_ui: cont_btn.add_theme_font_override("font", _font_ui)
	_style_btn(cont_btn, Color(0.12, 0.12, 0.22))
	cont_btn.visible = false
	cont_btn.pivot_offset = cont_btn.size / 2
	cont_btn.mouse_entered.connect(func(): create_tween().tween_property(cont_btn, "scale", Vector2(1.04, 1.04), 0.1))
	cont_btn.mouse_exited.connect(func():  create_tween().tween_property(cont_btn, "scale", Vector2.ONE, 0.1))
	cont_btn.pressed.connect(func(): GameManager.go_to_scene("res://scenes/ui/Map.tscn"))
	_dice_panel.add_child(cont_btn)

	_update_dice_status()

func _do_dice_roll(initial_btn: Button) -> void:
	if _dice_rolling:
		return
	initial_btn.visible = false
	_start_roll_animation()

func _do_dice_reroll() -> void:
	if _dice_rolling or _dice_roll_count >= MAX_DICE_ROLLS:
		return
	var cost: int = DICE_REROLL_COSTS[min(_dice_roll_count - 1, DICE_REROLL_COSTS.size() - 1)]
	GameManager.player_hp = max(1, GameManager.player_hp - cost)
	_update_dice_status()
	_start_roll_animation()

func _start_roll_animation() -> void:
	_dice_rolling = true
	_dice_reroll_btn.visible = false
	var cont_btn = _dice_panel.get_node_or_null("ContinueBtn")
	if cont_btn:
		cont_btn.visible = false
	_dice_result_lbl.text = ""
	_dice_detail_lbl.text = ""

	var final_roll: int = randi_range(1, 6)
	_dice_face_lbl.pivot_offset = _dice_face_lbl.size / 2

	var steps_fast: int = 10
	var steps_slow: int = 5
	var total_steps: int = steps_fast + steps_slow
	var tween := create_tween()

	for step in range(total_steps):
		var delay: float = 0.055 if step < steps_fast else 0.13
		var face_idx: int = randi() % 6
		var is_last: bool = (step == total_steps - 1)
		if is_last:
			face_idx = final_roll - 1
		var captured_face := face_idx
		var captured_step := step
		tween.tween_callback(func():
			_dice_face_lbl.text = DICE_FACES[captured_face]
			if is_last:
				# Aterrizaje: escala bounce desde grande
				_dice_face_lbl.scale = Vector2(1.6, 1.6)
				create_tween().tween_property(_dice_face_lbl, "scale", Vector2.ONE, 0.45)\
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			else:
				# Tumble: squash/stretch alternado
				var sq := Vector2(1.25, 0.75) if captured_step % 2 == 0 else Vector2(0.75, 1.25)
				_dice_face_lbl.scale = sq
				create_tween().tween_property(_dice_face_lbl, "scale", Vector2.ONE, delay * 0.9)\
					.set_trans(Tween.TRANS_SINE)
		)
		tween.tween_interval(delay)

	tween.tween_callback(func(): _on_roll_settled(final_roll))

func _on_roll_settled(roll: int) -> void:
	_dice_rolling = false
	_dice_roll_count += 1

	var outcome = _dice_outcome(roll)
	_apply_dice_outcome(outcome)

	_dice_face_lbl.text = DICE_FACES[roll - 1]
	_dice_result_lbl.text = outcome["text"]
	_dice_result_lbl.modulate = outcome["color"]
	_dice_detail_lbl.text = outcome["detail"]
	_update_dice_status()

	# Bounce de escala en el resultado
	_dice_result_lbl.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(_dice_result_lbl, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if outcome["type"] == "curse":
		_shake_screen(5.0, 0.3)

	_spawn_dice_particles(outcome["type"])

	_dice_history.append({"face": DICE_FACES[roll - 1], "type": outcome["type"]})
	_update_dice_history()

	var border_color: Color
	match outcome["type"]:
		"curse":   border_color = Color(0.75, 0.15, 0.15)
		"neutral": border_color = Color(0.35, 0.35, 0.4)
		_:         border_color = Color(0.2, 0.7, 0.3)

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.09, 0.98)
	ps.set_corner_radius_all(10)
	ps.set_border_width_all(2)
	ps.border_color = border_color
	_dice_panel.add_theme_stylebox_override("panel", ps)

	_dice_result_lbl.modulate.a = 0.0
	create_tween().tween_property(_dice_result_lbl, "modulate:a", 1.0, 0.35)

	var cont_btn = _dice_panel.get_node_or_null("ContinueBtn")
	if cont_btn:
		cont_btn.visible = true

	var can_reroll: bool = _dice_roll_count < MAX_DICE_ROLLS
	_dice_reroll_btn.visible = can_reroll
	if can_reroll:
		var next_cost: int = DICE_REROLL_COSTS[min(_dice_roll_count - 1, DICE_REROLL_COSTS.size() - 1)]
		_dice_reroll_btn.text = "Lanzar de nuevo  (-%d HP)" % next_cost
		_dice_reroll_btn.disabled = GameManager.player_hp <= next_cost

func _dice_outcome(roll: int) -> Dictionary:
	match roll:
		1: return {
			"type": "curse",
			"text": "El telon cae sobre ti.",
			"detail": "Pierdes 10 HP.",
			"color": Color(0.9, 0.2, 0.2),
			"hp": -10
		}
		2: return {
			"type": "curse",
			"text": "Un rol se pierde para siempre.",
			"detail": "La carta mas debil de tu mazo desaparece.",
			"color": Color(0.85, 0.3, 0.15),
			"remove_weak_card": true
		}
		3: return {
			"type": "neutral",
			"text": "La funcion sigue sin ti.",
			"detail": "Pierdes 4 HP.",
			"color": Color(0.6, 0.6, 0.65),
			"hp": -4
		}
		4: return {
			"type": "bonus",
			"text": "El destino te favorece.",
			"detail": "Ganas 12 monedas.",
			"color": Color(0.35, 0.85, 0.45),
			"coins": 12
		}
		5: return {
			"type": "bonus",
			"text": "La obra te bendice.",
			"detail": "Recuperas 15 HP.",
			"color": Color(0.3, 0.8, 0.5),
			"heal": 15
		}
		6: return {
			"type": "bonus",
			"text": "El telon se abre para ti.",
			"detail": "Obtienes una reliquia aleatoria.",
			"color": Color(0.95, 0.82, 0.2),
			"relic": true
		}
	return {"type": "neutral", "text": "", "detail": "", "color": Color.WHITE}

func _apply_dice_outcome(outcome: Dictionary) -> void:
	if outcome.get("hp", 0) != 0:
		GameManager.player_hp = clamp(GameManager.player_hp + outcome["hp"], 1, GameManager.player_max_hp)

	if outcome.get("heal", 0) > 0:
		GameManager.heal(outcome["heal"])

	if outcome.get("coins", 0) > 0:
		GameManager.coins += outcome["coins"]

	if outcome.get("remove_weak_card", false) and GameManager.player_deck.size() > 1:
		var weakest_idx = 0
		var min_atk = GameManager.player_deck[0].get("attack", 0)
		for i in range(1, GameManager.player_deck.size()):
			var atk = GameManager.player_deck[i].get("attack", 0)
			if atk < min_atk:
				min_atk = atk
				weakest_idx = i
		var removed = GameManager.player_deck[weakest_idx]
		GameManager.player_deck.remove_at(weakest_idx)
		_dice_detail_lbl.text = "La carta '%s' ha sido eliminada." % removed["name"]

	if outcome.get("relic", false):
		var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
		if available.is_empty():
			_dice_detail_lbl.text = "Ya posees todas las reliquias. Recibes 15 monedas en su lugar."
			GameManager.coins += 15
		else:
			available.shuffle()
			GameManager.add_relic(available[0])
			var rname = GameManager.RELIC_DATA[available[0]]["name"]
			_dice_detail_lbl.text = "Obtienes: " + rname
			if get_node_or_null("/root/AudioManager"):
				AudioManager.play("relic_get")

func _update_dice_status() -> void:
	if _dice_status_lbl == null:
		return
	var base: String = "HP: %d/%d   |   Monedas: %d" % [
		GameManager.player_hp, GameManager.player_max_hp, GameManager.coins
	]
	var remaining: int = MAX_DICE_ROLLS - _dice_roll_count
	if _dice_roll_count == 0:
		base += "   |   Intentos: %d" % MAX_DICE_ROLLS
	else:
		base += "   |   Intentos restantes: %d" % remaining
	_dice_status_lbl.text = base
	var info = get_node_or_null("InfoLabel")
	if info:
		var hp_lbl = info.get_node_or_null("StatHP")
		if hp_lbl: hp_lbl.text = "❤ %d/%d" % [GameManager.player_hp, GameManager.player_max_hp]
		var coins_lbl = info.get_node_or_null("StatCoins")
		if coins_lbl: coins_lbl.text = "◆ %d" % GameManager.coins

func flash_small_event(msg: String) -> void:
	# Refresh individual stat labels
	var row = get_node_or_null("InfoLabel")
	if row:
		var hp_lbl = row.get_node_or_null("StatHP")
		if hp_lbl: hp_lbl.text = "❤ %d/%d" % [GameManager.player_hp, GameManager.player_max_hp]
		var coins_lbl = row.get_node_or_null("StatCoins")
		if coins_lbl: coins_lbl.text = "◆ %d" % GameManager.coins
		var sanity_lbl = row.get_node_or_null("StatSanity")
		if sanity_lbl: sanity_lbl.text = "⬤ %d/%d" % [GameManager.sanity, GameManager.max_sanity]
	# Show message as a temporary popup if non-empty
	if msg.is_empty(): return
	DialogueUI.toast(msg, Color(1.0, 0.85, 0.3))

func _resolve_sanity_conditional(_opt: Dictionary) -> void:
	var s = GameManager.sanity
	if s > 60:
		var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
		available.shuffle()
		if not available.is_empty():
			GameManager.add_relic(available[0])
			if get_node_or_null("/root/AudioManager"): AudioManager.play("relic_get")
	elif s >= 30:
		var curse = {"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true}
		GameManager.add_card(curse)
	else:
		# Beber a la fuerza: -25 cordura + Mirada que Devora
		GameManager.sanity = max(0, GameManager.sanity - 25)
		var found = CardData.ALL_CARDS.filter(func(c): return c["name"] == "Mirada que Devora")
		if not found.is_empty(): GameManager.add_card(found[0].duplicate())
	GameManager.go_to_scene("res://scenes/ui/Map.tscn")

func _style_btn(btn: Button, color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = color.lightened(0.3)
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate()
	h.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)

func _show_card_removal_screen() -> void:
	var vp = get_viewport_rect().size
	
	# Contenedor principal (oscurecimiento)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0) # Empieza invisible
	overlay.size = vp # Sizing manual
	overlay.z_index = 100
	add_child(overlay)
	
	# Tween para el fade-in del fondo
	var tw_bg = create_tween()
	tw_bg.tween_property(overlay, "color:a", 0.9, 0.4)
	
	# Panel Central Estilizado
	var panel = Panel.new()
	panel.size = Vector2(vp.x * 0.8, vp.y * 0.75)
	panel.position = (vp - panel.size) / 2
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	panel.pivot_offset = panel.size / 2
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.98)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.75, 0.2, 0.6) # Dorado tenue
	style.shadow_size = 30
	style.shadow_color = Color(0, 0, 0, 0.7)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	
	# Tween para el panel
	var tw_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_panel.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw_panel.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5)
	
	var title = Label.new()
	title.text = "ELIGE UNA PIEZA PARA OLVIDAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.9, 0.8, 0.4)
	title.position = Vector2(0, 30); title.size = Vector2(panel.size.x, 50)
	panel.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(50, 100)
	scroll.size = Vector2(panel.size.x - 100, panel.size.y - 200)
	panel.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 25)
	scroll.add_child(grid)
	
	var card_scene = load("res://scenes/combat/Card.tscn")
	for i in range(GameManager.player_deck.size()):
		var idx = i
		var card = card_scene.instantiate()
		grid.add_child(card)
		card.setup(GameManager.player_deck[i])
		card.scale = Vector2(0.85, 0.85)
		card.modulate.a = 0.0
		
		# Animación stagger para las cartas
		create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.2 + i * 0.05)
		
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameManager.player_deck.remove_at(idx)
				if get_node_or_null("/root/AudioManager"): AudioManager.play("card_discard")
				# Animación de salida
				var tw_out = create_tween()
				tw_out.tween_property(overlay, "modulate:a", 0.0, 0.3)
				await tw_out.finished
				GameManager.go_to_scene("res://scenes/ui/Map.tscn")
		)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "RETROCEDER"
	cancel_btn.size = Vector2(240, 50)
	cancel_btn.position = Vector2(panel.size.x/2 - 120, panel.size.y - 70)
	cancel_btn.pressed.connect(func(): 
		var tw_out = create_tween()
		tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
		await tw_out.finished
		GameManager.go_to_scene("res://scenes/ui/Map.tscn")
	)
	panel.add_child(cancel_btn)

func _show_relic_sacrifice_screen() -> void:
	var vp = get_viewport_rect().size

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = vp
	overlay.z_index = 100
	add_child(overlay)

	var tw_bg = create_tween()
	tw_bg.tween_property(overlay, "color:a", 0.92, 0.4)

	var panel = Panel.new()
	panel.size = Vector2(vp.x * 0.7, vp.y * 0.65)
	panel.position = (vp - panel.size) / 2
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	panel.pivot_offset = panel.size / 2

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.08, 0.98)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.5, 0.1, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var tw_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_panel.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw_panel.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5)

	var title = Label.new()
	title.text = "ELIGE LA RELIQUIA QUE OFRECES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(0.9, 0.75, 0.2)
	title.position = Vector2(0, 28)
	title.size = Vector2(panel.size.x, 46)
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "El viajero la tomará. A cambio, el camino al Umbral será tuyo."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.65, 0.6, 0.55)
	subtitle.position = Vector2(0, 72)
	subtitle.size = Vector2(panel.size.x, 28)
	panel.add_child(subtitle)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(40, 108)
	scroll.size = Vector2(panel.size.x - 80, panel.size.y - 200)
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	for relic_id in GameManager.relics:
		var r_data = GameManager.RELIC_DATA.get(relic_id, {})
		if r_data.is_empty():
			continue
		var rid = relic_id

		var btn = Button.new()
		btn.text = "💍 " + r_data["name"] + "  —  " + r_data["desc"]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.custom_minimum_size = Vector2(panel.size.x - 100, 54)
		btn.add_theme_font_size_override("font_size", 14)
		vbox.add_child(btn)

		btn.pressed.connect(func():
			GameManager.relics.erase(rid)
			var tw_out = create_tween()
			tw_out.tween_property(overlay, "modulate:a", 0.0, 0.3)
			await tw_out.finished
			GameManager.enter_void_path()
		)

	var cancel_btn = Button.new()
	cancel_btn.text = "RETROCEDER"
	cancel_btn.size = Vector2(220, 46)
	cancel_btn.position = Vector2(panel.size.x / 2 - 110, panel.size.y - 66)
	cancel_btn.pressed.connect(func():
		var tw_out = create_tween()
		tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
		await tw_out.finished
		overlay.queue_free()
	)
	panel.add_child(cancel_btn)

func _shake_screen(intensity: float = 6.0, duration: float = 0.35) -> void:
	var tw = create_tween()
	var steps = 10
	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tw.tween_property(self, "position", offset, duration / steps)
	tw.tween_property(self, "position", Vector2.ZERO, 0.08)

func _spawn_dice_particles(outcome_type: String) -> void:
	var gpu = GPUParticles2D.new()
	gpu.position = _dice_panel.position + Vector2(350, 180)
	gpu.z_index = 20
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.spread = 180.0
	mat.gravity = Vector3(0, 300, 0)
	mat.scale_min = 4.0
	mat.scale_max = 9.0
	var grad = Gradient.new()
	match outcome_type:
		"curse":
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 180.0
			grad.set_color(0, Color(0.9, 0.1, 0.1, 0.9))
			grad.set_color(1, Color(0.4, 0.0, 0.0, 0.0))
		"bonus":
			mat.initial_velocity_min = 100.0
			mat.initial_velocity_max = 280.0
			grad.set_color(0, Color(1.0, 0.9, 0.2, 1.0))
			grad.set_color(1, Color(0.6, 0.8, 0.3, 0.0))
		_:  # neutral
			mat.initial_velocity_min = 40.0
			mat.initial_velocity_max = 100.0
			grad.set_color(0, Color(0.5, 0.5, 0.6, 0.6))
			grad.set_color(1, Color(0.3, 0.3, 0.4, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	gpu.process_material = mat
	gpu.amount = 18 if outcome_type == "bonus" else 10
	gpu.lifetime = 0.8
	gpu.one_shot = true
	gpu.explosiveness = 0.85
	add_child(gpu)
	gpu.emitting = true
	get_tree().create_timer(1.4).timeout.connect(gpu.queue_free)

func _update_dice_history() -> void:
	# Eliminar etiquetas antiguas de historial
	for child in _dice_panel.get_children():
		if child.name.begins_with("hist_"):
			child.queue_free()
	# Mostrar últimos 3 (más antiguo a más reciente)
	var show = _dice_history.slice(max(0, _dice_history.size() - 3))
	for i in range(show.size()):
		var h = show[i]
		var lbl = Label.new()
		lbl.name = "hist_%d" % i
		lbl.text = h["face"]
		lbl.add_theme_font_size_override("font_size", 28)
		match h["type"]:
			"curse":   lbl.modulate = Color(0.9, 0.25, 0.25, 0.7)
			"bonus":   lbl.modulate = Color(0.95, 0.82, 0.2, 0.7)
			_:         lbl.modulate = Color(0.6, 0.6, 0.65, 0.7)
		lbl.position = Vector2(20 + i * 44, 290)
		_dice_panel.add_child(lbl)
