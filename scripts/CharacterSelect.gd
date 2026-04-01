extends Node2D

const CHARACTERS = [
	{
		"id": "conquistador",
		"name": "EL CONQUISTADOR",
		"style": "Senda del Acero — AGRESIVO",
		"hp": 55,
		"lore": "Un general de armadura bermellon, el ultimo de un imperio que el tiempo olvido. Llego a Valdris buscando la gloria eterna que sus poetas prometieron. Nadie le advirtio que los tableros de los dioses no tienen victorias, solo sacrificios mas utiles.\n\n'Si este es el tablero de los dioses, lo teñire de rojo hasta que mi nombre sea ley.'",
		"fate": "El tablero ya trazó tu fin. Solo resta elegir con cuánta sangre lo escribes.",
		"passive": "CONQUISTA: Al matar a un enemigo, tus Siervos ganan +1 ATK permanente y recuperas 3 de vida.",
		"color": Color(0.7, 0.2, 0.2),
		"symbol": "♜",
		"deck": [
			{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
			{"name": "Susurro Debilitante", "attack": 0, "defense": 0, "cost": 0},
			{"name": "Cabalgante del Vacio", "attack": 6, "defense": 0, "cost": 2},
			{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2},
			{"name": "Ofrenda de Carne", "attack": 8, "defense": 0, "cost": 2},
		]
	},
	{
		"id": "estratega",
		"name": "EL ESTRATEGA",
		"style": "Senda del Cristal — TACTICO",
		"hp": 47,
		"lore": "Un erudito que paso decadas estudiando las estrellas y los mapas imposibles. Cree que Valdris es un rompecabezas que, una vez resuelto, detendra la podredumbre de su mundo. Lo que no ha contemplado es que el tablero ya lo ha calculado a el.\n\n'No busco sangre, sino el patron que mueve las manos de la realidad.'",
		"fate": "El patrón se completará. La pregunta es si quedarás dentro o fuera del diseño.",
		"passive": "LOGICA: Tus cartas de Inquisidor Ciego cuestan -1 de energia. Robas 1 carta extra al inicio de cada combate.",
		"color": Color(0.2, 0.4, 0.7),
		"symbol": "♛",
		"deck": [
			{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
			{"name": "Susurro Debilitante", "attack": 0, "defense": 0, "cost": 0},
			{"name": "Inquisidor Ciego", "attack": 4, "defense": 0, "cost": 2},
			{"name": "Inquisidor Ciego", "attack": 4, "defense": 0, "cost": 2},
			{"name": "Dama del Tablero", "attack": 8, "defense": 3, "cost": 3},
		]
	},
	{
		"id": "guardian",
		"name": "EL GUARDIAN",
		"style": "Senda del Muro — DEFENSIVO",
		"hp": 55,
		"lore": "Un caballero que desperto entre las ruinas de su propio juramento. No recuerda a quien protegia, solo que no debe fallar de nuevo. Su escudo es lo unico que queda de su identidad. Lo que aun no sabe es que el juramento que lleva roto era hacia si mismo.\n\n'No permitire que una sola pieza mas caiga en este juego sin sentido.'",
		"fate": "Lo que proteges ya está roto. Solo queda decidir quién paga el precio.",
		"passive": "RESILIENCIA: Cada vez que generas 10 o más Escudo en un turno, ganas 1 Furia. A las 3 cargas, tu siguiente ataque hace daño doble.",
		"color": Color(0.3, 0.55, 0.3),
		"symbol": "♞",
		"deck": [
			{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
			{"name": "Eco del Vacío", "attack": 4, "defense": 0, "cost": 2},
			{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2},
			{"name": "Bastion", "attack": 0, "defense": 6, "cost": 1},
			{"name": "Idolo Inerte", "attack": 0, "defense": 12, "cost": 3},
		]
	}
]

var available_characters: Array = []
var selected_idx: int = 0
var title_lbl: Label
var lore_lbl: Label
var passive_lbl: Label
var vida_lbl: Label
var style_lbl: Label
var portrait_container: Control
var portrait_tween: Tween
var seed_lbl: Label
var fate_lbl: Label
var deck_preview_lbl: Label

var _font_title: FontFile
var _font_narrative: FontFile
var _font_ui: FontFile
var _font_corrupt: FontFile

func _ready() -> void:
	# Filtrar personajes disponibles
	available_characters = CHARACTERS.duplicate()
	if GameManager.prince_unlocked:
		available_characters.append({
			"id": "prince",
			"name": "EL PRÍNCIPE DE CARCOSA",
			"style": "Senda del Abismo — LOCURA",
			"hp": 48,
			"lore": "Un antiguo heredero de un reino que ya no existe. Su cuerpo es un receptaculo de la estatica abisal. Lo que el Principe no dice es que ya conoce el final. Y lo acepta.\n\n'No me liberaste para salvarme, sino para que termine lo que el Rey empezó.'",
			"fate": "Cada movimiento te lleva de vuelta. Siempre de vuelta al mismo umbral.",
			"passive": "RESONANCIA: Cartas de Escala x1.5 (Cordura < 60) | x2 (Cordura < 35). Inicio de combate: -8 Cordura. Demencia recibida → Escudo parcial.",
			"color": Color(0.5, 0.2, 0.8),
			"symbol": "♔",
			"deck": CardData.PRINCE_DECK.duplicate(true)
		})
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_all()
		AudioManager.play_loop("ES_Lost in Time - Aiyo")

	_font_title     = load("res://assets/fonts/CinzelDecorative-Bold.otf")
	_font_narrative = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	_font_ui        = load("res://assets/fonts/rajdhani.medium.ttf")
	_font_corrupt   = load("res://assets/fonts/RubikGlitch-Regular.ttf")

	var vp_size = get_viewport_rect().size

	var bg_tex = TextureRect.new()
	bg_tex.texture = load("res://assets/bg_mainmenu.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.position = Vector2.ZERO
	bg_tex.size = vp_size
	bg_tex.z_index = -10
	add_child(bg_tex)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.position = Vector2.ZERO
	dim.size = vp_size
	dim.z_index = -9
	add_child(dim)

	_build_ui()
	_update_display()

func _build_ui() -> void:
	var vp = get_viewport_rect().size
	const PANEL_X = 126; const PANEL_Y = 79
	const PANEL_W = 900; const PANEL_H = 490
	const COL_R_X = 290  # right column x inside panel

	# ── Header ────────────────────────────────────────────────────────────
	var header = Label.new()
	header.text = "ELIGE TU PIEZA"
	if _font_title:
		header.add_theme_font_override("font", _font_title)
	header.add_theme_font_size_override("font_size", 44)
	header.modulate = Color(0.88, 0.76, 0.12)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 22)
	header.size = Vector2(vp.x, 58)
	add_child(header)

	# ── Panel ─────────────────────────────────────────────────────────────
	var panel = Panel.new()
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.size = Vector2(PANEL_W, PANEL_H)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.05, 0.07, 0.94)
	ps.set_corner_radius_all(8)
	ps.set_border_width_all(3)
	ps.border_color = Color(0.55, 0.42, 0.12)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# ── Rune strips ───────────────────────────────────────────────────────
	var RUNE_TEXT = "ᚠ ᛒ ᚱ ᛈ ᛇ ᚦ ᛟ ᛗ ᚾ ᛁ ᛖ ᚷ ᛃ ᚹ ᚫ ᛤ ᛞ ᚣ ᛝ ᚪ ᛠ ᚩ ᛡ ᚢ ᛣ"
	for i in 2:
		var rl = Label.new()
		rl.text = RUNE_TEXT
		if _font_ui:
			rl.add_theme_font_override("font", _font_ui)
		rl.add_theme_font_size_override("font_size", 11)
		rl.modulate = Color(0.62, 0.50, 0.15, 0.65)
		rl.clip_contents = true
		rl.size = Vector2(PANEL_W - 10, 18)
		rl.position = Vector2(5, 4 if i == 0 else PANEL_H - 19)
		panel.add_child(rl)

	# ── Column divider ────────────────────────────────────────────────────
	var divider = ColorRect.new()
	divider.color = Color(0.55, 0.42, 0.12, 0.45)
	divider.position = Vector2(282, 14)
	divider.size = Vector2(1, PANEL_H - 28)
	panel.add_child(divider)

	# ── Portrait frame ────────────────────────────────────────────────────
	var port_frame = Panel.new()
	port_frame.position = Vector2(10, 28)
	port_frame.size = Vector2(260, 280)
	var pf_style = StyleBoxFlat.new()
	pf_style.bg_color = Color(0.04, 0.03, 0.05)
	pf_style.set_corner_radius_all(4)
	pf_style.set_border_width_all(2)
	pf_style.border_color = Color(0.55, 0.42, 0.12)
	port_frame.add_theme_stylebox_override("panel", pf_style)
	panel.add_child(port_frame)

	portrait_container = Control.new()
	portrait_container.clip_contents = true
	portrait_container.position = Vector2(2, 2)
	portrait_container.size = Vector2(256, 276)
	port_frame.add_child(portrait_container)

	# ── Vida pill ─────────────────────────────────────────────────────────
	var vida_pill = Panel.new()
	vida_pill.position = Vector2(10, 316)
	vida_pill.size = Vector2(260, 30)
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.08, 0.06, 0.10, 0.95)
	pill_style.set_corner_radius_all(15)
	pill_style.set_border_width_all(1)
	pill_style.border_color = Color(0.55, 0.42, 0.12)
	vida_pill.add_theme_stylebox_override("panel", pill_style)
	panel.add_child(vida_pill)

	vida_lbl = Label.new()
	vida_lbl.add_theme_font_size_override("font_size", 13)
	if _font_ui:
		vida_lbl.add_theme_font_override("font", _font_ui)
	vida_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vida_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vida_lbl.position = Vector2(0, 0)
	vida_lbl.size = Vector2(260, 30)
	vida_pill.add_child(vida_lbl)

	# ── Deck preview ──────────────────────────────────────────────────────
	deck_preview_lbl = Label.new()
	deck_preview_lbl.add_theme_font_size_override("font_size", 11)
	if _font_ui:
		deck_preview_lbl.add_theme_font_override("font", _font_ui)
	deck_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	deck_preview_lbl.modulate = Color(0.62, 0.58, 0.42)
	deck_preview_lbl.position = Vector2(12, 352)
	deck_preview_lbl.size = Vector2(256, 128)
	panel.add_child(deck_preview_lbl)

	# ── Right column ──────────────────────────────────────────────────────
	title_lbl = Label.new()
	if _font_title:
		title_lbl.add_theme_font_override("font", _font_title)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.position = Vector2(COL_R_X, 18)
	title_lbl.size = Vector2(596, 46)
	panel.add_child(title_lbl)

	style_lbl = Label.new()
	if _font_narrative:
		style_lbl.add_theme_font_override("font", _font_narrative)
	style_lbl.add_theme_font_size_override("font_size", 13)
	style_lbl.modulate = Color(0.58, 0.54, 0.46)
	style_lbl.position = Vector2(COL_R_X, 62)
	style_lbl.size = Vector2(596, 22)
	panel.add_child(style_lbl)

	var sep = ColorRect.new()
	sep.color = Color(0.55, 0.42, 0.12, 0.35)
	sep.position = Vector2(COL_R_X, 88)
	sep.size = Vector2(596, 1)
	panel.add_child(sep)

	lore_lbl = Label.new()
	if _font_ui:
		lore_lbl.add_theme_font_override("font", _font_ui)
	lore_lbl.add_theme_font_size_override("font_size", 14)
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lore_lbl.modulate = Color(0.80, 0.78, 0.74)
	lore_lbl.position = Vector2(COL_R_X, 94)
	lore_lbl.size = Vector2(596, 180)
	panel.add_child(lore_lbl)

	passive_lbl = Label.new()
	if _font_ui:
		passive_lbl.add_theme_font_override("font", _font_ui)
	passive_lbl.add_theme_font_size_override("font_size", 13)
	passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	passive_lbl.modulate = Color(0.30, 0.82, 0.78)
	passive_lbl.position = Vector2(COL_R_X, 280)
	passive_lbl.size = Vector2(596, 80)
	panel.add_child(passive_lbl)

	fate_lbl = Label.new()
	if _font_narrative:
		fate_lbl.add_theme_font_override("font", _font_narrative)
	fate_lbl.add_theme_font_size_override("font_size", 12)
	fate_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	fate_lbl.modulate = Color(0.68, 0.52, 0.22)
	fate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fate_lbl.position = Vector2(COL_R_X, 416)
	fate_lbl.size = Vector2(596, 58)
	panel.add_child(fate_lbl)

	# ── Nav buttons (circular) ────────────────────────────────────────────
	var btn_prev = Button.new()
	btn_prev.text = "<"
	btn_prev.position = Vector2(56, 294)
	btn_prev.size = Vector2(60, 60)
	if _font_title:
		btn_prev.add_theme_font_override("font", _font_title)
	btn_prev.add_theme_font_size_override("font_size", 22)
	_style_circle_button(btn_prev)
	btn_prev.pressed.connect(func(): _change_selection(-1))
	add_child(btn_prev)

	var btn_next = Button.new()
	btn_next.text = ">"
	btn_next.position = Vector2(1036, 294)
	btn_next.size = Vector2(60, 60)
	if _font_title:
		btn_next.add_theme_font_override("font", _font_title)
	btn_next.add_theme_font_size_override("font_size", 22)
	_style_circle_button(btn_next)
	btn_next.pressed.connect(func(): _change_selection(1))
	add_child(btn_next)

	# ── Accept button ─────────────────────────────────────────────────────
	var btn_select = Button.new()
	btn_select.text = "     ACEPTAR ESTE DESTINO"
	btn_select.position = Vector2(446, 578)
	btn_select.size = Vector2(260, 42)
	if _font_title:
		btn_select.add_theme_font_override("font", _font_title)
	btn_select.add_theme_font_size_override("font_size", 14)
	btn_select.pressed.connect(_on_select_pressed)
	add_child(btn_select)
	_style_main_button(btn_select)

	# ── Wax seal (over btn_select, MOUSE_FILTER_IGNORE) ───────────────────
	var seal = Panel.new()
	seal.position = Vector2(458, 580)
	seal.size = Vector2(34, 34)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seal_style = StyleBoxFlat.new()
	seal_style.bg_color = Color(0.28, 0.08, 0.05)
	seal_style.set_corner_radius_all(17)
	seal_style.set_border_width_all(1)
	seal_style.border_color = Color(0.55, 0.25, 0.10)
	seal.add_theme_stylebox_override("panel", seal_style)
	add_child(seal)

	var seal_lbl = Label.new()
	seal_lbl.text = "♔"
	seal_lbl.add_theme_font_size_override("font_size", 16)
	seal_lbl.modulate = Color(0.90, 0.60, 0.20)
	seal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_lbl.position = Vector2(0, 0)
	seal_lbl.size = Vector2(34, 34)
	seal_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(seal_lbl)

	# ── DEV button ────────────────────────────────────────────────────────
	var btn_dev_prince = Button.new()
	btn_dev_prince.text = "DEV"
	btn_dev_prince.position = Vector2(8, vp.y - 36)
	btn_dev_prince.add_theme_font_size_override("font_size", 9)
	var dev_style = StyleBoxFlat.new()
	dev_style.bg_color = Color(0, 0, 0, 0.0)
	btn_dev_prince.add_theme_stylebox_override("normal", dev_style)
	btn_dev_prince.add_theme_stylebox_override("hover", dev_style)
	btn_dev_prince.modulate = Color(0.4, 0.4, 0.4, 0.6)
	btn_dev_prince.pressed.connect(func():
		GameManager.prince_unlocked = !GameManager.prince_unlocked
		get_tree().reload_current_scene()
	)
	add_child(btn_dev_prince)

	# ── Seed label ────────────────────────────────────────────────────────
	seed_lbl = Label.new()
	seed_lbl.add_theme_font_size_override("font_size", 13)
	seed_lbl.modulate = Color(0.5, 0.5, 0.6, 0.0)
	seed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_lbl.position = Vector2(0, 630)
	seed_lbl.size = Vector2(vp.x, 24)
	add_child(seed_lbl)

func _update_display() -> void:
	var c_data = available_characters[selected_idx]
	title_lbl.text = c_data["name"]; title_lbl.modulate = c_data["color"]; style_lbl.text = c_data["style"]; lore_lbl.text = c_data["lore"]
	passive_lbl.text = "PASIVA: " + c_data["passive"]
	vida_lbl.text = c_data["symbol"] + "  VIDA: " + str(c_data["hp"])
	vida_lbl.modulate = c_data["color"]
	if fate_lbl:
		fate_lbl.text = c_data.get("fate", "")
	if deck_preview_lbl:
		var deck_names = ["MAZO INICIAL:"]
		var seen: Dictionary = {}
		for card in c_data["deck"]:
			var key = card["name"] + "(%d)" % card["cost"]
			seen[key] = seen.get(key, 0) + 1
		for key in seen:
			var count = seen[key]
			deck_names.append("• " + key + (" ×%d" % count if count > 1 else ""))
		deck_preview_lbl.text = "\n".join(deck_names)
	_draw_portrait(c_data["id"])

func _draw_portrait(char_id: String) -> void:
	if portrait_tween: portrait_tween.kill()
	for c in portrait_container.get_children(): c.queue_free()

	var path = "res://assets/characters/%s.png" % char_id
	var texture = load(path) as Texture2D
	if texture == null:
		return

	portrait_container.clip_contents = true

	var portrait = TextureRect.new()
	portrait.texture = texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = portrait_container.size
	portrait.size = portrait_container.size
	portrait_container.add_child(portrait)

	_animate_portrait_features(char_id, portrait)

func _animate_portrait_features(char_id: String, portrait: TextureRect) -> void:
	portrait_tween = create_tween().set_loops()
	match char_id:
		"conquistador":
			portrait_tween.tween_property(portrait, "modulate", Color(1.15, 0.9, 0.9), 1.8)
			portrait_tween.tween_property(portrait, "modulate", Color(1.0, 1.0, 1.0), 1.8)
		"estratega":
			portrait_tween.tween_property(portrait, "modulate", Color(0.9, 0.95, 1.2), 2.0)
			portrait_tween.tween_property(portrait, "modulate", Color(1.0, 1.0, 1.0), 2.0)
		"guardian":
			portrait_tween.tween_property(portrait, "modulate", Color(0.85, 1.1, 0.85), 2.2)
			portrait_tween.tween_property(portrait, "modulate", Color(1.0, 1.0, 1.0), 2.2)
		"prince":
			portrait_tween.tween_property(portrait, "modulate", Color(1.05, 0.85, 1.25), 2.5)
			portrait_tween.parallel().tween_property(portrait, "scale", Vector2(1.02, 1.02), 2.5)
			portrait_tween.tween_property(portrait, "modulate", Color(1.0, 1.0, 1.0), 2.5)
			portrait_tween.parallel().tween_property(portrait, "scale", Vector2(1.0, 1.0), 2.5)

func _change_selection(dir: int) -> void:
	selected_idx = posmod(selected_idx + dir, available_characters.size())
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("menu_hover")
	_update_display()
	# Fade in newly updated content
	var fade_nodes: Array = [lore_lbl, passive_lbl, style_lbl, portrait_container, title_lbl, vida_lbl]
	if fate_lbl: fade_nodes.append(fate_lbl)
	if deck_preview_lbl: fade_nodes.append(deck_preview_lbl)
	for node in fade_nodes:
		if node:
			node.modulate.a = 0.0
			create_tween().set_trans(Tween.TRANS_SINE).tween_property(node, "modulate:a", 1.0, 0.22)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_change_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_change_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_select_pressed()
		get_viewport().set_input_as_handled()

func _on_select_pressed() -> void:
	var c_data = available_characters[selected_idx]
	var char_id = c_data["id"]

	# Reiniciar estado global para nueva partida (genera run_seed)
	GameManager.reset_run()

	# Mostrar semilla de la run
	seed_lbl.text = "SEMILLA: %d" % GameManager.run_seed
	create_tween().tween_property(seed_lbl, "modulate:a", 1.0, 0.3)

	GameManager.selected_character = char_id
	GameManager.player_hp = c_data["hp"]
	GameManager.player_max_hp = c_data["hp"]
	
	# Copia profunda del mazo base (Siempré limpio al empezar)
	var new_deck = []
	for card in c_data["deck"]:
		new_deck.append(card.duplicate())
	
	GameManager.player_deck = new_deck
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("button_click")
	GameManager.go_to_scene("res://scenes/ui/Map.tscn")

func _style_main_button(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.10, 0.05)
	s.set_corner_radius_all(6)
	s.set_border_width_all(2)
	s.border_color = Color(0.75, 0.60, 0.12)
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.20, 0.18, 0.08)
	h.border_color = Color(1.0, 0.85, 0.20)
	btn.add_theme_stylebox_override("hover", h)

func _style_circle_button(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.08, 0.04)
	s.set_corner_radius_all(30)
	s.set_border_width_all(2)
	s.border_color = Color(0.75, 0.60, 0.12)
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.22, 0.18, 0.08)
	h.border_color = Color(1.0, 0.85, 0.20)
	btn.add_theme_stylebox_override("hover", h)
