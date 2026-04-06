extends Node

var main: Node

func setup(m) -> void:
	main = m

func show_avatar_intro() -> void:
	var vp = main.get_viewport_rect().size

	# Silencio absoluto inicial
	if main.get_node_or_null("/root/AudioManager"):
		AudioManager.stop_all()

	# Usar CanvasLayer para asegurar que está por encima de todo el HUD y efectos
	var layer = CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)

	# Telón de oscuridad total
	var curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.size = vp # Forzar tamaño manual
	layer.add_child(curtain)

	var chambers_quote = "Canto de mi alma, se me ha muerto la voz. Muere, sin ser cantada, como las lágrimas no derramadas se secan y mueren en la Perdida Carcosa..."

	# Panel clip para revelar de arriba hacia abajo
	var clip_lbl = Panel.new()
	clip_lbl.clip_contents = true
	clip_lbl.position = Vector2(vp.x * 0.2, vp.y * 0.3)
	clip_lbl.size = Vector2(vp.x * 0.6, 0)
	var empty_s = StyleBoxEmpty.new()
	clip_lbl.add_theme_stylebox_override("panel", empty_s)
	layer.add_child(clip_lbl)

	var quote_lbl = Label.new()
	quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	quote_lbl.text = chambers_quote
	quote_lbl.position = Vector2(0, 0)
	quote_lbl.size = Vector2(vp.x * 0.6, vp.y * 0.4)
	quote_lbl.add_theme_font_size_override("font_size", 22)
	quote_lbl.modulate = Color(0.9, 0.8, 0.3)
	clip_lbl.add_child(quote_lbl)

	# Pausa en la oscuridad — el jugador procesa el silencio antes de leer
	await main.get_tree().create_timer(0.45).timeout
	# Revelar de arriba hacia abajo — emerge lentamente desde el negro
	var reveal_tw = create_tween()
	reveal_tw.tween_property(clip_lbl, "size:y", vp.y * 0.4, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await reveal_tw.finished

	# --- ELECCIÓN BASADA EN LORE / FRAGMENTOS ---
	var options = []
	options.append({"label": "Luchar (Iniciar Combate)", "effect": {"sanity": -10}})
	
	var has_reality_fragment = not GameManager.secret_items.is_empty()
	var has_persistent_fragment = GameManager.fragment_count_w3 > 0

	if has_reality_fragment or has_persistent_fragment:
		var frag_type = "de Realidad" if has_reality_fragment else "de Carcosa"
		options.append({
			"label": "Entregar (Ofrecer 1 Fragmento %s y -15 HP)" % frag_type, 
			"effect": {
				"remove_secret_item": true if has_reality_fragment else false,
				"fragment_count_w3": -1 if not has_reality_fragment else 0,
				"hp": -15
			}
		})
	
	options.append({
		"label": "Huir (Sacrificar 1 Carta y -25 Cordura)", 
		"effect": {"remove_card": true, "sanity": -25}
	})

	var intro_choice = await DialogueUI.cinematic_choice(options)

	# Si elige cualquier opción que NO sea Luchar (índice 0)
	if intro_choice > 0:
		quote_lbl.visible = false
		var exit_tw = create_tween()
		exit_tw.tween_property(curtain, "color:a", 1.0, 0.5)
		
		var selected_label = options[intro_choice]["label"]
		if selected_label.begins_with("Entregar"):
			DialogueUI.toast("FRAGMENTO ENTREGADO AL VACÍO", Color.GOLD)
		else:
			DialogueUI.toast("MENTE FRACTURADA AL HUIR", Color.DARK_RED)
			
		await exit_tw.finished
		await main.get_tree().create_timer(0.5).timeout
		layer.queue_free()
		GameManager.go_to_scene("res://scenes/ui/Map.tscn")
		return

	# --- CONTINUAR AL COMBATE (Si eligió Luchar) ---
	# --- EFECTO ROTOSCOPIA / GLITCH / FLASH ---
	quote_lbl.visible = false
	if main.get_node_or_null("/root/AudioManager"):
		AudioManager.play("Glith_distorsion_noised_sound") # Usar audio externo

	# Rotoscopia — velocidad errática, paleta más agresiva
	var glitch_palette = [Color.WHITE, Color.BLACK, Color(0.9, 0.8, 0.05), Color(0.55, 0.0, 0.0), Color(0.35, 0.0, 0.55)]
	for i in range(18):
		curtain.color = glitch_palette[randi() % glitch_palette.size()]
		main._trigger_screen_blink()
		await main.get_tree().create_timer(randf_range(0.02, 0.08)).timeout

	curtain.color = Color.BLACK

	# Desvanecer oscuridad con un último flash
	var tw = create_tween()
	tw.tween_property(layer, "offset:y", -vp.y, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(curtain, "modulate:a", 0.0, 1.5)

	if main.get_node_or_null("/root/AudioManager"):
		AudioManager.play("player_hit")

	await tw.finished
	print("Intro finalizada, apareciendo enemigo...")
	layer.queue_free()


func show_avatar_bark() -> void:
	if main.enemies.is_empty() or not "AVATAR" in main.enemies[0].name.to_upper(): return
	var msg = CombatData.ENEMY_COMBAT_BANTER["Avatar de Hastur"][randi() % CombatData.ENEMY_COMBAT_BANTER["Avatar de Hastur"].size()]
	var pos = main.enemies[0].panel.global_position + Vector2(0, -40)
	DialogueUI.add_log("AVATAR", msg, Color(0.8, 0.4, 1.0))
	DialogueUI.bark(msg, pos, Color(0.8, 0.7, 0.9), true, 200.0, "avatar_hastur")


func show_carcosa_transition() -> void:
	var vp = main.get_viewport_rect().size

	# Overlay que toma la pantalla
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.z_index = 55
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(overlay)

	var t = create_tween()
	t.tween_property(overlay, "color:a", 1.0, 1.2)
	await t.finished

	# Lineas — posiciones Y variadas: las palabras derivan en el espacio como fragmentos flotantes
	# [texto, color, tamaño, shake, y_pos, hold_time]
	var lines = [
		["...", Color(0.5, 0.5, 0.5), 20, false, vp.y * 0.40, 1.0],
		["Los fragmentos vibran.", Color(0.75, 0.68, 0.3), 22, false, vp.y * 0.37, 1.8],
		["Algo al otro lado\nreconoce el signo.", Color(0.7, 0.6, 0.25), 22, false, vp.y * 0.43, 2.0],
		["No es un lugar.\nEs una promesa rota.", Color(0.65, 0.55, 0.2), 20, false, vp.y * 0.35, 2.0],
		["C̴̡A̵̢R̴C̷O̴S̸A̷", Color(0.82, 0.72, 0.05), 42, true, vp.y * 0.38, 2.8],
		["Él recuerda tu nombre.", Color(0.45, 0.15, 0.65), 22, false, vp.y * 0.46, 2.4],
	]

	for pair in lines:
		var full_text: String = pair[0]
		var col: Color = pair[1]
		var fsize: int = pair[2]
		var do_shake: bool = pair[3]
		var y_pos: float = pair[4]
		var hold_time: float = pair[5]

		var lbl = Label.new()
		lbl.text = ""
		lbl.modulate = Color(col.r, col.g, col.b, 0.0)
		lbl.add_theme_font_size_override("font_size", fsize)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, y_pos)
		lbl.size = Vector2(vp.x, 110)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 56
		main.add_child(lbl)

		# El texto emerge desde el silencio antes de escribirse
		var tw_fadein = create_tween()
		tw_fadein.tween_property(lbl, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
		await tw_fadein.finished

		var char_delay = 0.09 if do_shake else 0.05
		for i in range(full_text.length()):
			lbl.text = full_text.substr(0, i + 1)
			await main.get_tree().create_timer(char_delay).timeout

		if do_shake:
			# La realidad se fractura — sacudida más corta pero más intensa
			var base_pos = lbl.position
			for _s in range(25):
				lbl.position = base_pos + Vector2(randf_range(-9, 9), randf_range(-5, 5))
				overlay.color = Color(
					randf_range(0.0, 0.10),
					randf_range(0.0, 0.04),
					randf_range(0.0, 0.16),
					1.0
				)
				await main.get_tree().create_timer(0.033).timeout
			lbl.position = base_pos
			overlay.color = Color(0, 0, 0, 1.0)
			# Flash púrpura post-impacto — el nombre resuena
			var flash_c = create_tween()
			flash_c.tween_property(overlay, "color", Color(0.12, 0.0, 0.22, 1.0), 0.07)
			flash_c.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.45) \
				.set_trans(Tween.TRANS_EXPO)
			await flash_c.finished

		await main.get_tree().create_timer(hold_time).timeout

		var t3 = create_tween()
		t3.tween_property(lbl, "modulate:a", 0.0, 0.5)
		await t3.finished
		lbl.queue_free()

	# Destello purpura antes del combate
	var flash = ColorRect.new()
	flash.color = Color(0.35, 0.05, 0.55, 0.0)
	flash.position = Vector2.ZERO
	flash.size = vp
	flash.z_index = 57
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(flash)
	var tf = create_tween()
	tf.tween_property(flash, "color:a", 0.9, 0.3)
	await tf.finished
	# El overlay se queda negro para la transición de escena


func show_victory_cinematic(is_hastur: bool) -> void:
	var vp = main.get_viewport_rect().size

	# Fase 0 — Flash de impacto inicial
	var flash = ColorRect.new()
	flash.color = Color(0.9, 0.8, 0.05, 0.9) if not is_hastur else Color(0.5, 0.05, 0.9, 0.9)
	flash.position = Vector2.ZERO
	flash.size = vp
	flash.z_index = 55
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(flash)
	var tf = create_tween()
	tf.tween_property(flash, "color:a", 0.0, 0.55)
	await tf.finished
	flash.queue_free()

	# Overlay oscuro
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.z_index = 50
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(overlay)
	var t = create_tween()
	t.tween_property(overlay, "color:a", 0.95, 0.65)
	await t.finished

	if is_hastur:
		await DialogueUI.cinematic_line("H̷A̵S̷T̷U̵R̷  H̷A̵  C̷A̵I̷D̵O̷", Color(0.65, 0.1, 0.95))
		await DialogueUI.cinematic_line("El tablero sigue moviéndose.", Color(0.5, 0.4, 0.7))
		await DialogueUI.cinematic_line("Eras una pieza. Sigues siéndolo.", Color(0.5, 0.4, 0.7))
		var choice = await DialogueUI.cinematic_choice([
			{"label": "Reclamar la corona",  "effect": {"max_hp": -5, "lore_progress": 20}},
			{"label": "Dejarla caer",        "effect": {"sanity": 15}},
		])
		if choice == 0:
			await DialogueUI.cinematic_line("El peso es tuyo ahora.", Color(0.6, 0.5, 0.85))
		else:
			await DialogueUI.cinematic_line("El tablero no recuerda los gestos nobles.", Color(0.45, 0.38, 0.65))

		var cont_btn = Button.new()
		cont_btn.text = "✦  Continuar"
		cont_btn.add_theme_font_size_override("font_size", 16)
		cont_btn.modulate = Color(1, 1, 1, 0.0)
		cont_btn.position = Vector2(vp.x / 2.0 - 115, vp.y * 0.65)
		cont_btn.size = Vector2(230, 48); cont_btn.z_index = 52
		cont_btn.pivot_offset = Vector2(115, 24)
		_style_cinematic_btn(cont_btn, Color(0.45, 0.22, 0.72), Color(0.75, 0.45, 1.0))
		main.add_child(cont_btn)
		var t4h = create_tween()
		t4h.tween_property(cont_btn, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
		await t4h.finished
		await cont_btn.pressed
		cont_btn.queue_free()

	else:
		if main.get_node_or_null("/root/AudioManager"):
			AudioManager.stop_all()

		await DialogueUI.cinematic_line("«¿Crees que esto termina aquí?»", Color(0.55, 0.55, 0.55))
		await DialogueUI.cinematic_line("Siempre vuelves. El Rey lo sabe.", Color(0.6, 0.5, 0.85))
		var choice = await DialogueUI.cinematic_choice([
			{"label": "Gritarle al vacío",   "effect": {"sanity": -10, "lore_progress": 15}},
			{"label": "Guardar silencio",    "effect": {"hp": 8}},
		])
		if choice == 0:
			await DialogueUI.cinematic_line("Tu voz se pierde. Algo la recoge.", Color(0.6, 0.5, 0.85))
		else:
			await DialogueUI.cinematic_line("El silencio es lo único que no puede usar.", Color(0.45, 0.38, 0.65))

		var cont_btn = Button.new()
		cont_btn.text = "◈  Cerrar el Tablero"
		cont_btn.add_theme_font_size_override("font_size", 16)
		cont_btn.modulate = Color(1, 1, 1, 0.0)
		cont_btn.position = Vector2(vp.x / 2.0 - 120, vp.y * 0.65)
		cont_btn.size = Vector2(240, 48); cont_btn.z_index = 52
		cont_btn.pivot_offset = Vector2(120, 24)
		_style_cinematic_btn(cont_btn, Color(0.38, 0.30, 0.12), Color(0.82, 0.66, 0.20))
		main.add_child(cont_btn)
		var t4y = create_tween()
		t4y.tween_property(cont_btn, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
		await t4y.finished
		await cont_btn.pressed
		cont_btn.queue_free()

	# Fade out overlay (compartido)
	var t5 = create_tween()
	t5.tween_property(overlay, "color:a", 0.0, 0.5)
	await t5.finished
	overlay.queue_free()


func show_relic_reward(next_scene: String = "res://scenes/ui/Map.tscn") -> void:
	var vp = main.get_viewport_rect().size

	var available = []
	for rid in GameManager.RELIC_DATA.keys():
		if not GameManager.has_relic(rid):
			available.append(rid)
	available.shuffle()
	var choices = available.slice(0, min(3, available.size()))
	if choices.is_empty(): return

	# Fondo oscuro bloqueante
	var dim = ColorRect.new(); dim.color = Color(0, 0, 0, 0.88)
	dim.position = Vector2.ZERO; dim.size = vp
	dim.z_index = 25; dim.mouse_filter = Control.MOUSE_FILTER_STOP; main.add_child(dim)

	var title = Label.new(); title.text = "RELIQUIA DE RECOMPENSA"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.9, 0.75, 0.1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 44); title.z_index = 26
	main.add_child(title)

	var picked = false  # evita doble clic
	var panel_w = 260; var panel_h = 260; var gap = 24
	var total_w = choices.size() * panel_w + (choices.size() - 1) * gap
	var start_x = (vp.x - total_w) / 2.0
	var relic_icon_scene = load("res://scenes/ui/RelicIcon.tscn")
	var panels_root = Node2D.new(); panels_root.z_index = 26; main.add_child(panels_root)

	for i in range(choices.size()):
		var rid = choices[i]
		var rdata = GameManager.RELIC_DATA[rid]
		var px = start_x + i * (panel_w + gap)
		var rpanel = main.ui._make_panel(Vector2(px, 100), Vector2(panel_w, panel_h),
			Color(0.08, 0.07, 0.04), Color(0.7, 0.55, 0.1))
		panels_root.add_child(rpanel)

		# Icono de reliquia centrado en la parte superior
		if relic_icon_scene:
			var icon = relic_icon_scene.instantiate()
			icon.position = Vector2(panel_w / 2.0 - 22, 10)
			rpanel.add_child(icon)
			icon.setup(rid)

		var rname = Label.new(); rname.text = rdata["name"]
		rname.add_theme_font_size_override("font_size", 15)
		rname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rname.modulate = Color(0.95, 0.85, 0.3)
		rname.position = Vector2(8, 62); rname.size = Vector2(panel_w - 16, 36)
		rname.autowrap_mode = TextServer.AUTOWRAP_WORD; rpanel.add_child(rname)

		var rdesc = Label.new(); rdesc.text = rdata["desc"]
		rdesc.add_theme_font_size_override("font_size", 12)
		rdesc.modulate = Color(0.75, 0.75, 0.8)
		rdesc.autowrap_mode = TextServer.AUTOWRAP_WORD

		# Ajustar panel si la descripción es muy larga
		var est_lines = rdesc.text.length() / 30 + rdesc.text.count("\n") + 1
		var desc_h = max(100, est_lines * 16)
		rdesc.position = Vector2(8, 104); rdesc.size = Vector2(panel_w - 16, desc_h)
		rpanel.add_child(rdesc)

		var rbtn = Button.new(); rbtn.text = "Tomar"
		rbtn.position = Vector2(80, 216); rbtn.size = Vector2(100, 34)
		rbtn.tooltip_text = rdata["name"] + ": " + rdata["desc"]
		if "maldicion" in rdata["desc"].to_lower() or "pierdes" in rdata["desc"].to_lower() or "cuesta" in rdata["desc"].to_lower():
			rbtn.tooltip_text += "\n[!] ADVERTENCIA: Esta reliquia conlleva una maldición o coste."
		rpanel.add_child(rbtn)

		var relic_id = rid
		rbtn.pressed.connect(func():
			if picked: return
			picked = true

			GameManager.add_relic(relic_id)
			Events.relic_was_chosen.emit(relic_id)

			dim.queue_free(); title.queue_free(); panels_root.queue_free()
			if next_scene == "__mimic_segunda__":
				# Segunda reliquia del mímico, luego mapa
				show_relic_reward("res://scenes/ui/Map.tscn")
			elif next_scene == "__world2__":
				await show_world2_transition()
				GameManager.current_world = 1
				GameManager.map_graph = []
				GameManager.map_path = {}
				GameManager.current_map_floor = 0
				GameManager.current_map_col = -1
				GameManager.player_hp = GameManager.player_max_hp
				GameManager.sanity = 100
				GameManager.go_to_scene("res://scenes/ui/Map.tscn")
			else:
				GameManager.go_to_scene(next_scene)
		)


func show_single_reward_modal(title_text: String, item_data: Dictionary, next_scene: String) -> void:
	var vp = main.get_viewport_rect().size

	# Usar un CanvasLayer para asegurar que está por encima de TODA la UI de combate
	var layer = CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)

	# Fondo oscuro bloqueante
	var dim = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.95)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.size = vp # Sizing manual para CanvasLayer
	layer.add_child(dim)

	if main.get_node_or_null("/root/AudioManager"):
		AudioManager.play("relic_get")

	var title = Label.new(); title.text = title_text
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(0.9, 0.8, 0.2); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 60); dim.add_child(title)

	var is_card = item_data.has("cost")

	if is_card:
		var card_scene = load("res://scenes/combat/Card.tscn")
		var card_node = card_scene.instantiate()
		dim.add_child(card_node) # Primero al árbol
		card_node.setup(item_data) # Luego setup (ahora _ready ya tiene labels listos)
		card_node.position = Vector2(vp.x/2 - 65, vp.y/2 - 80)
		card_node.scale = Vector2(1.6, 1.6)
		# Forzar que la descripción sea visible en el modal
		card_node.mouse_filter = Control.MOUSE_FILTER_STOP
		GameManager.add_card(item_data)

	var cont_btn = Button.new(); cont_btn.text = "ACEPTAR Y CONTINUAR"
	cont_btn.size = Vector2(280, 60); cont_btn.position = Vector2(vp.x/2 - 140, vp.y - 120)
	dim.add_child(cont_btn)

	cont_btn.pressed.connect(func():
		GameManager.go_to_scene(next_scene)
	)


func show_penitente_cinematic(has_relic_hint: bool, p_card: Dictionary) -> void:
	var vp = main.get_viewport_rect().size

	var _font_title     = load("res://assets/fonts/CinzelDecorative-Bold.otf")
	var _font_narrative = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	var _font_ui        = load("res://assets/fonts/rajdhani.medium.ttf")

	# ── Árbol de diálogo del Penitente ───────────────────────────────────────
	var dialogue_lines: Array = [
		{
			"id": "start",
			"text": "Tu paciencia es... inusual.\nLa mayoría llega con espadas levantadas. Tú llegaste con silencio.",
			"choices": [
				{"label": "¿Qué eres tú?",                    "runic": "ᚠᛒ ᛈᛇᚦ ᛟᛗᚾ?",              "next": "identidad"},
				{"label": "Habla. No tengo ciclos que perder.", "runic": "ᛁᛖᚷ. ᚾᛟ ᛗᚫᛤ ᛞᚣᛝᚪ.",        "next": "oferta"},
			]
		},
		{
			"id": "identidad",
			"text": "Soy lo que el tablero descarta cuando ya no sirve. Un peón que cumplió su función demasiado bien.\nHe visto a muchos como tú. Ninguno llegó tan lejos sin romperse algo.",
			"choices": [
				{"label": "¿Qué tienes para mí?",            "runic": "ᚢᛣᛈ ᛇᚦᛟ ᛗᚾᛁᛖ?",             "next": ("pista" if has_relic_hint else "oferta")},
				{"label": "No me interesa tu historia.",      "runic": "ᚾᛟ ᛁᛖᚷᛃ ᚹᚫᛤ ᛞᚣᛝ.",           "next": "oferta"},
			]
		},
		{
			"id": "pista",
			"text": "Escucha, porque no lo repetiré:\nel Rey Amarillo siente el miedo, no las piezas.\nCuanto más rota esté tu mente... más sangra él.",
			"choices": [
				{"label": "Lo recordaré.",                    "runic": "ᛠᚩᛡ ᚢᛣᛈᛇ.",                  "next": "oferta"},
			]
		},
		{
			"id": "oferta",
			"text": "Tengo algo. Un juramento hecho de ceniza, forjado por manos que ya no están.\nProtege donde el acero no puede.\nNo te pregunto si lo mereces.",
			"choices": [
				{"label": "Tomar la Plegaria de Ceniza.",     "runic": "ᚷᛃᚹᚫ ᛤᛞᚣ ᛝᚪᛠ ᚩᛡᚢᛣ.",        "next": "accept"},
				{"label": "Dejarla ir con él.",               "runic": "ᛈᛇᚦᛟ ᛗᚾᛁᛖ ᚷᛃ.",              "next": "refuse"},
			]
		},
	]

	# ── Overlay y panel estilo NPC ────────────────────────────────────────────
	var layer = CanvasLayer.new(); layer.layer = 160; main.add_child(layer)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.85, 0.35)
	await main.get_tree().create_timer(0.35).timeout

	var panel_w = min(vp.x * 0.62, 560.0)
	var panel_h = min(vp.y * 0.75, 520.0)
	var panel = Panel.new()
	panel.size = Vector2(panel_w, panel_h)
	panel.position = (vp - panel.size) / 2
	panel.modulate.a = 0.0
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.05, 0.09)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.45, 0.38, 0.55)
	ps.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.35)
	await main.get_tree().create_timer(0.2).timeout

	# Retrato + nombre
	var portrait_lbl = Label.new()
	portrait_lbl.text = "♟"
	portrait_lbl.add_theme_font_size_override("font_size", 42)
	portrait_lbl.modulate = Color(0.75, 0.68, 0.9)
	portrait_lbl.position = Vector2(20, 14); portrait_lbl.size = Vector2(56, 56)
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(portrait_lbl)

	var name_lbl = Label.new()
	name_lbl.text = "El Penitente"
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = Color(0.78, 0.68, 0.9)
	name_lbl.position = Vector2(84, 24); name_lbl.size = Vector2(panel_w - 100, 36)
	panel.add_child(name_lbl)

	var sep = ColorRect.new()
	sep.color = Color(0.38, 0.3, 0.48, 0.55)
	sep.size = Vector2(panel_w - 40, 1); sep.position = Vector2(20, 76)
	panel.add_child(sep)

	# Texto de diálogo
	var text_lbl = Label.new()
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.size = Vector2(panel_w - 40, 130)
	text_lbl.position = Vector2(20, 90)
	text_lbl.add_theme_font_size_override("font_size", 15)
	text_lbl.modulate = Color(0.86, 0.82, 0.92)
	panel.add_child(text_lbl)

	# Contenedor de opciones
	var choices_vbox = VBoxContainer.new()
	choices_vbox.position = Vector2(20, 232)
	choices_vbox.size = Vector2(panel_w - 40, panel_h - 252)
	choices_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(choices_vbox)

	# ── Textos rúnicos para el Penitente (sin reliquia lengua_tablero) ────────
	var PENITENTE_RUNIC = {
		"start":     "ᚠᛒ ᛈᛇᚦ ᛟᛗᚾ... ᛁᛖᚷᛃ.\nᚹᚫ ᛤᛞᚣᛝ ᚪᛠᚩ ᛡᚢᛣᛈ. ᛇᚦᛟ ᛗᚾᛁᛖ ᚷᛃ.",
		"identidad": "ᛒᚠᛈ ᛇᚦ ᛟᛗᚾᛁ ᛖᚷᛃ ᚹᚫᛤ ᛞᚣᛝ.\nᚪᛠᚩ ᛡᚢ ᛣᛈᛇ ᚦᛟᛗ. ᚾᛁᛖᚷ ᛃᚹᚫ ᛤᛞᚣ ᛝᚪᛠ.",
		"pista":     "ᛠᚩᛡᚢ ᛣᛈ ᛇᚦᛟ ᛗᚾᛁᛖ:\nᚷᛃᚹᚫ ᛤᛞᚣ ᛝᚪᛠ ᚩᛡᚢᛣ ᛈᛇᚦᛟ.\nᚾᛁᛖᚷ... ᛃᚹᚫ ᛤᛞᚣᛝ.",
		"oferta":    "ᚠᛒᛈᛇ ᚦᛟ. ᛗᚾᛁᛖ ᚷᛃ ᚹᚫᛤ ᛞᚣ ᛝᚪ.\nᛠᚩᛡ ᚢᛣᛈ ᛇᚦᛟᛗ.\nᚾᛁᛖ ᚷᛃᚹ ᚫᛤ ᛞᚣᛝᚪ ᛠᚩᛡᚢ.",
	}

	# ── Navegación de líneas ──────────────────────────────────────────────────
	# Array para captura por referencia en lambdas (GDScript no modifica vars externas en closures)
	var chosen_action := [""]   # chosen_action[0]: "" | "accept" | "refuse"
	var _nav: Array = [Callable()]
	_nav[0] = func(line_id: String) -> void:
		var line: Dictionary = {}
		for l in dialogue_lines:
			if l.get("id") == line_id:
				line = l; break
		if line.is_empty(): return

		for ch in choices_vbox.get_children(): ch.queue_free()

		# Typewriter — 0.018s por carácter
		var full_text: String
		if not has_relic_hint and PENITENTE_RUNIC.has(line_id):
			full_text = PENITENTE_RUNIC[line_id]
		else:
			full_text = line["text"]
		text_lbl.text = ""
		var char_speed := 0.018
		var tw_type = create_tween()
		tw_type.tween_method(func(n: int): text_lbl.text = full_text.substr(0, n),
			0, full_text.length(), float(full_text.length()) * char_speed)

		var choices: Array = line.get("choices", []).duplicate()
		choices.shuffle()
		await main.get_tree().create_timer(float(full_text.length()) * char_speed + 0.1).timeout

		for choice in choices:
			var cbtn = Button.new()
			cbtn.text = choice["runic"] if (not has_relic_hint and choice.has("runic")) else choice["label"]
			cbtn.custom_minimum_size = Vector2(panel_w - 40, 38)
			cbtn.autowrap_mode = TextServer.AUTOWRAP_WORD
			choices_vbox.add_child(cbtn)
			var next_id: String = choice.get("next", "end")
			cbtn.pressed.connect(func():
				if next_id in ["accept", "refuse"]:
					chosen_action[0] = next_id   # ← referencia correcta
				else:
					_nav[0].call(next_id)
			)

	_nav[0].call("start")

	# Esperar a que el jugador elija accept/refuse
	while chosen_action[0] == "":
		await main.get_tree().process_frame

	for ch in choices_vbox.get_children(): ch.queue_free()

	# ── Resolución ────────────────────────────────────────────────────────────
	if chosen_action[0] == "accept":
		GameManager.add_card(p_card)

		# Fade-out del panel de diálogo
		var tw_panel_out = create_tween()
		tw_panel_out.tween_property(panel, "modulate:a", 0.0, 0.25)
		await tw_panel_out.finished

		if main.get_node_or_null("/root/AudioManager"):
			AudioManager.play("relic_get")

		# ── Modal estilo cofre (paleta morada) ──────────────────────────────
		var modal = Panel.new()
		modal.size = Vector2(460, 430)
		modal.position = (vp - modal.size) / 2.0
		modal.modulate.a = 0.0
		modal.scale = Vector2(0.88, 0.88)
		modal.pivot_offset = Vector2(230, 215)
		var ms = StyleBoxFlat.new()
		ms.bg_color = Color(0.06, 0.05, 0.09, 0.97)
		ms.set_border_width_all(2)
		ms.border_color = Color(0.45, 0.35, 0.65)
		ms.set_corner_radius_all(12)
		ms.content_margin_left = 24; ms.content_margin_right = 24
		ms.content_margin_top = 20; ms.content_margin_bottom = 20
		modal.add_theme_stylebox_override("panel", ms)
		overlay.add_child(modal)

		# Pop de entrada
		var tw_modal = create_tween().set_parallel(true)
		tw_modal.tween_property(modal, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD)
		tw_modal.tween_property(modal, "scale", Vector2(1.0, 1.0), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Shimmer morado pulsante
		var glow_rect = ColorRect.new()
		glow_rect.color = Color(0.55, 0.3, 0.9, 0.06)
		glow_rect.size = Vector2(460, 250)
		glow_rect.position = Vector2(0, 72)
		glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow_rect.z_index = 10
		modal.add_child(glow_rect)
		var tw_glow_loop = create_tween().set_loops()
		tw_glow_loop.tween_property(glow_rect, "color:a", 0.12, 0.85).set_trans(Tween.TRANS_SINE)
		tw_glow_loop.tween_property(glow_rect, "color:a", 0.02, 0.85).set_trans(Tween.TRANS_SINE)

		# Línea decorativa superior
		var top_line = ColorRect.new()
		top_line.size = Vector2(340, 2)
		top_line.position = Vector2(60, 0)
		top_line.color = Color(0.45, 0.35, 0.65, 0.6)
		modal.add_child(top_line)

		# Header
		var header = Label.new()
		header.text = "PLEGARIA DE CENIZA"
		header.add_theme_font_size_override("font_size", 20)
		if _font_title: header.add_theme_font_override("font", _font_title)
		header.modulate = Color(0.78, 0.68, 0.9)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.position = Vector2(0, 18)
		header.size = Vector2(460, 34)
		modal.add_child(header)

		# Sub (narrativo)
		var sub = Label.new()
		sub.text = "«Que la ceniza te proteja donde el acero no puede.»"
		sub.add_theme_font_size_override("font_size", 14)
		if _font_narrative: sub.add_theme_font_override("font", _font_narrative)
		sub.modulate = Color(0.58, 0.52, 0.68, 0.0)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD
		sub.position = Vector2(20, 58)
		sub.size = Vector2(420, 32)
		modal.add_child(sub)

		# Área de la carta
		var item_area = Control.new()
		item_area.position = Vector2(0, 96)
		item_area.size = Vector2(460, 250)
		item_area.modulate.a = 0.0
		modal.add_child(item_area)

		var card_scene = load("res://scenes/combat/Card.tscn")
		var card_node = card_scene.instantiate()
		item_area.add_child(card_node)
		card_node.setup(p_card)
		card_node.hover_scale_enabled = false
		card_node.glow_enabled = true
		card_node.pivot_offset = Vector2(65, 97)
		card_node.position = Vector2(460.0 / 2.0 - 65.0, 20.0)
		card_node.scale = Vector2(0.5, 0.5)
		if is_instance_valid(card_node.tooltip_panel):
			card_node.tooltip_panel.visible = false
		card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Pop de la carta: 0.5 → 1.0 con BACK
		var tw_card = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_card.tween_interval(0.3)
		tw_card.tween_property(card_node, "scale", Vector2(1.0, 1.0), 0.4)
		create_tween().tween_callback(card_node.flash_new_card).set_delay(0.65)

		# Botón
		var cont_btn = Button.new()
		cont_btn.text = "✦ PARTIR"
		cont_btn.custom_minimum_size = Vector2(220, 50)
		cont_btn.modulate.a = 0.0
		cont_btn.position = Vector2(460.0 / 2.0 - 110.0, 358)
		cont_btn.pivot_offset = Vector2(110, 25)
		if _font_ui: cont_btn.add_theme_font_override("font", _font_ui)
		cont_btn.add_theme_font_size_override("font_size", 15)
		var bs_n = StyleBoxFlat.new()
		bs_n.bg_color = Color(0.11, 0.08, 0.18)
		bs_n.set_border_width_all(2); bs_n.border_color = Color(0.52, 0.38, 0.72)
		bs_n.set_corner_radius_all(6)
		bs_n.content_margin_left = 12; bs_n.content_margin_right = 12
		bs_n.content_margin_top = 8; bs_n.content_margin_bottom = 8
		cont_btn.add_theme_stylebox_override("normal", bs_n)
		var bs_h = StyleBoxFlat.new()
		bs_h.bg_color = Color(0.20, 0.13, 0.30)
		bs_h.set_border_width_all(2); bs_h.border_color = Color(0.75, 0.58, 1.0)
		bs_h.set_corner_radius_all(6)
		bs_h.content_margin_left = 12; bs_h.content_margin_right = 12
		bs_h.content_margin_top = 8; bs_h.content_margin_bottom = 8
		cont_btn.add_theme_stylebox_override("hover", bs_h)
		cont_btn.mouse_entered.connect(func(): create_tween().tween_property(cont_btn, "scale", Vector2(1.03, 1.03), 0.1))
		cont_btn.mouse_exited.connect(func():  create_tween().tween_property(cont_btn, "scale", Vector2.ONE, 0.1))
		modal.add_child(cont_btn)

		# Entrada staggered
		var tw_enter = create_tween()
		tw_enter.tween_interval(0.15)
		tw_enter.tween_property(sub, "modulate:a", 1.0, 0.3)
		tw_enter.tween_property(item_area, "modulate:a", 1.0, 0.35)
		tw_enter.tween_interval(0.45)
		tw_enter.tween_property(cont_btn, "modulate:a", 1.0, 0.3)

		await cont_btn.pressed

	else:  # refuse
		GameManager.sanity = min(GameManager.max_sanity, GameManager.sanity + 5)
		text_lbl.text = "Entonces lo llevas sin él.\n\nEl tablero recuerda los gestos nobles, aunque tú no vivas para verlo.\n\n[+5 Cordura]"
		text_lbl.modulate = Color(0.65, 0.6, 0.75)

		var cont_btn = Button.new()
		cont_btn.text = "Partir."
		cont_btn.custom_minimum_size = Vector2(200, 40)
		choices_vbox.add_child(cont_btn)
		await cont_btn.pressed

	# Fade out y navegar al mapa
	var tw_out = create_tween()
	tw_out.tween_property(overlay, "modulate:a", 0.0, 0.4)
	await tw_out.finished
	layer.queue_free()

	GameManager.go_to_scene("res://scenes/ui/Map.tscn")


func show_world2_transition() -> void:
	var vp = main.get_viewport_rect().size
	var layer = CanvasLayer.new(); layer.layer = 160; main.add_child(layer)
	var bg = ColorRect.new(); bg.color = Color(0, 0, 0, 0)
	bg.position = Vector2.ZERO; bg.size = vp
	layer.add_child(bg)

	# Fase 1: fade a negro
	var tw = create_tween()
	tw.tween_property(bg, "color:a", 1.0, 0.8)
	await tw.finished

	# Fase 2: rey derribado (texto-arte)
	var king_art = Label.new()
	king_art.text = "♚"
	king_art.add_theme_font_size_override("font_size", 72)
	king_art.modulate = Color(0.9, 0.85, 0.7)
	king_art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	king_art.position = Vector2(0, vp.y * 0.3); king_art.size = Vector2(vp.x, 90)
	layer.add_child(king_art)

	var tw2 = create_tween().set_parallel(true)
	tw2.tween_property(king_art, "rotation_degrees", 90.0, 1.2).set_ease(Tween.EASE_IN)
	tw2.tween_property(king_art, "modulate:a", 0.0, 1.4).set_delay(0.6)
	await tw2.finished
	# Impacto: destello dorado en el momento de la caída
	var impact = ColorRect.new()
	impact.color = Color(0.85, 0.72, 0.05, 0.0)
	impact.size = vp; impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(impact)
	var tw_impact = create_tween()
	tw_impact.tween_property(impact, "color:a", 0.40, 0.05)
	tw_impact.tween_property(impact, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_EXPO)
	await tw_impact.finished
	impact.queue_free()
	await main.get_tree().create_timer(0.3).timeout

	# Fase 3: texto narrativo
	var lines_data = [
		["El Rey Sin Corona ha sido reclamado por el vacío.", 0.08, false],
		["Buscó un trono que nunca existió...", 0.09, false],
		["Olvidando que en este tablero,\nincluso los reyes son peones.", 0.07, true],
		["El Tablero Dorado os aguarda.", 0.08, false],
		["Donde la ceniza se vuelve ley.", 0.1, true],
	]
	for line_data in lines_data:
		var lbl = Label.new()
		lbl.text = ""; lbl.modulate = Color(0.9, 0.82, 0.5, 0.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22 if line_data[2] else 18)
		lbl.position = Vector2(60, vp.y * 0.45); lbl.size = Vector2(vp.x - 120, 80)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		layer.add_child(lbl)
		var fad = create_tween(); fad.tween_property(lbl, "modulate:a", 1.0, 0.4)
		await fad.finished
		var full_text = line_data[0]
		for c in full_text.length():
			lbl.text = full_text.substr(0, c + 1)
			await main.get_tree().create_timer(line_data[1]).timeout
		await main.get_tree().create_timer(1.8).timeout
		var fout = create_tween(); fout.tween_property(lbl, "modulate:a", 0.0, 0.5)
		await fout.finished
		lbl.queue_free()

	# Fase 4: interstitial — título del Mundo 2
	var world_lbl = Label.new()
	world_lbl.text = "— MUNDO II —\nEl Tablero Dorado"
	world_lbl.modulate = Color(0.85, 0.65, 0.1, 0.0)
	world_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_lbl.add_theme_font_size_override("font_size", 32)
	world_lbl.position = Vector2(0, vp.y * 0.35); world_lbl.size = Vector2(vp.x, 80)
	layer.add_child(world_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "Enemigos más duros. Reliquias más oscuras.\nLa cordura tiene un precio más alto aquí."
	sub_lbl.modulate = Color(0.7, 0.6, 0.5, 0.0)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.position = Vector2(60, vp.y * 0.52); sub_lbl.size = Vector2(vp.x - 120, 60)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	layer.add_child(sub_lbl)

	var stats_lbl = Label.new()
	var relics_count = GameManager.relics.size()
	stats_lbl.text = "Reliquias obtenidas: %d   |   Cordura restaurada al 100" % relics_count
	stats_lbl.modulate = Color(0.55, 0.55, 0.6, 0.0)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.position = Vector2(0, vp.y * 0.67); stats_lbl.size = Vector2(vp.x, 30)
	layer.add_child(stats_lbl)

	var cont_btn = Button.new()
	cont_btn.text = "♚  Descender al Tablero Dorado"
	cont_btn.position = Vector2(vp.x / 2.0 - 155, vp.y * 0.78)
	cont_btn.size = Vector2(310, 48)
	cont_btn.modulate.a = 0.0
	cont_btn.pivot_offset = Vector2(155, 24)
	_style_cinematic_btn(cont_btn, Color(0.60, 0.44, 0.08), Color(1.0, 0.80, 0.18))
	layer.add_child(cont_btn)

	var fin_tw = create_tween().set_parallel(true)
	fin_tw.tween_property(world_lbl, "modulate:a", 1.0, 1.0)
	fin_tw.tween_property(sub_lbl, "modulate:a", 1.0, 1.0).set_delay(0.4)
	fin_tw.tween_property(stats_lbl, "modulate:a", 1.0, 1.0).set_delay(0.7)
	fin_tw.tween_property(cont_btn, "modulate:a", 1.0, 1.0).set_delay(1.0)
	await fin_tw.finished

	await cont_btn.pressed

	var fout2 = create_tween(); fout2.tween_property(bg, "color", Color(0, 0, 0, 1), 0.6)
	await fout2.finished
	layer.queue_free()


func show_yellow_truth_cinematic(lines: Array) -> void:
	var vp = main.get_viewport_rect().size
	var layer = CanvasLayer.new()
	layer.layer = 150
	main.add_child(layer)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1.0)
	bg.size = vp
	root.add_child(bg)

	if main.get_node_or_null("/root/AudioManager"):
		AudioManager.play("ambient_hum")

	# Combinar todas las líneas en un solo bloque de texto
	var full_text = "\n\n".join(lines)

	# Contenedor con clip para revelar de arriba hacia abajo
	var text_x = vp.x * 0.1
	var text_y = vp.y * 0.15
	var text_w = vp.x * 0.8
	var text_h = vp.y * 0.7

	var clip = Panel.new()
	clip.clip_contents = true
	clip.position = Vector2(text_x, text_y)
	clip.size = Vector2(text_w, 0)  # Empieza sin altura visible
	var empty_style = StyleBoxEmpty.new()
	clip.add_theme_stylebox_override("panel", empty_style)
	root.add_child(clip)

	var lbl = Label.new()
	lbl.text = full_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.position = Vector2(0, 0)
	lbl.size = Vector2(text_w, text_h)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.modulate = Color(1.2, 1.0, 0.2)
	clip.add_child(lbl)

	# Revelar de arriba hacia abajo expandiendo el clip
	var reveal = create_tween()
	reveal.tween_property(clip, "size:y", text_h, 2.2)
	await reveal.finished

	await main.get_tree().create_timer(3.0).timeout

	# Rotoscopia — acelera, luego se frena: la visión colapsa de forma irregular
	for i in range(8):
		if not is_instance_valid(bg): break
		bg.color = Color(0.1, 0.08, 0.0) if i % 2 == 0 else Color.BLACK
		lbl.visible = !lbl.visible
		var wait = 0.04 if i < 4 else 0.06 + i * 0.012
		await main.get_tree().create_timer(wait).timeout

	if is_instance_valid(lbl): lbl.visible = true
	if is_instance_valid(bg): bg.color = Color.BLACK

	# Pausa en el negro — el horror necesita silencio para asentarse
	await main.get_tree().create_timer(0.9).timeout

	# Desvanecer todo suavemente
	var out = create_tween()
	out.tween_property(root, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	await out.finished

	layer.queue_free()


func show_avatar_defeat_lore() -> void:
	var count = GameManager.secret_items.size()
	var lines = []

	match count:
		1:
			lines = [
				"El Heraldo cae, pero su sombra permanece.",
				"Un solo fragmento de verdad es una carga pesada.",
				"Has visto el borde del tablero... y lo que hay debajo."
			]
		2:
			lines = [
				"Dos verdades chocan en tu mente.",
				"El Rey no está lejos, su risa resuena en tu mazo.",
				"¿Sientes la lluvia roja? Es el cielo llorando por tu ignorancia."
			]
		3:
			lines = [
				"EL VELO SE HA ROTO.",
				"Hastur no necesita buscarte. Tú ya eres suyo.",
				"Bienvenido a la Perdida Carcosa. Aquí el tiempo es solo una pieza más."
			]
		_:
			lines = ["El vacío devuelve tu mirada."]

	await show_yellow_truth_cinematic(lines)


func show_loot_screen() -> void:
	var vp = main.get_viewport_rect().size
	# Panel de despojos con estetica Carcosa
	var loot_panel = main.ui._make_panel(Vector2(vp.x/2 - 300, 120), Vector2(600, 380), Color(0.04, 0.04, 0.06, 0.96), Color(0.85, 0.75, 0.2))
	main.add_child(loot_panel)
	loot_panel.z_index = 100

	var title = Label.new()
	title.text = "RECOLECTAR RESTOS"
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(0.7, 0.65, 0.4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 25); title.size = Vector2(600, 40)
	loot_panel.add_child(title)

	var reward_vbox = VBoxContainer.new()
	reward_vbox.position = Vector2(60, 90); reward_vbox.size = Vector2(480, 220)
	reward_vbox.add_theme_constant_override("separation", 15)
	loot_panel.add_child(reward_vbox)

	# Recompensas
	var frag_count = randi_range(12, 22)
	add_loot_button(reward_vbox, "◈ Tomar " + str(frag_count) + " Fragmentos de Tablero", func():
		GameManager.add_coins(frag_count)
	)

	add_loot_button(reward_vbox, "✦ Recolectar Ecos de los Caidos (Carta)", func():
		var draft_scene = load("res://scenes/ui/CardDraft.tscn")
		var draft = draft_scene.instantiate()
		draft.z_index = 200
		main.add_child(draft)
		# No hace falta conectar a señal si solo queremos que se cierre,
		# pero podemos ocultar el panel de loot mientras tanto
		loot_panel.visible = false
		draft.connect("draft_completed", func():
			loot_panel.visible = true
		)
	)

	if randf() < 0.35:
		add_loot_button(reward_vbox, "☤ Beber Esencia de Olvido (+8 Cordura)", func():
			GameManager.sanity = min(100, GameManager.sanity + 8)
		)

	var cont_btn = Button.new()
	cont_btn.text = "CONTINUAR EL VIAJE"
	cont_btn.position = Vector2(200, 315); cont_btn.size = Vector2(200, 45)
	cont_btn.pressed.connect(func():
		if GameManager.is_in_void_path:
			if GameManager.void_path_step == 2:
				GameManager.unlock_lore("centinela_nombre")
			GameManager.void_path_step += 1
			# Siempre volver al mapa de la grieta para ver el progreso
			GameManager.go_to_scene("res://scenes/ui/VoidMap.tscn")
		else:
			# Progresión normal del mapa (NO sumar piso aquí, Map.gd ya lo hizo al elegir)
			GameManager.go_to_scene("res://scenes/ui/Map.tscn")
	)
	loot_panel.add_child(cont_btn)


# ── Botón cinematográfico estilizado ─────────────────────────────────────────
func _style_cinematic_btn(btn: Button, border_normal: Color, border_hover: Color) -> void:
	var bs_n = StyleBoxFlat.new()
	bs_n.bg_color = Color(border_normal.r * 0.28, border_normal.g * 0.28, border_normal.b * 0.28, 0.92)
	bs_n.set_border_width_all(2); bs_n.border_color = border_normal
	bs_n.set_corner_radius_all(6)
	bs_n.content_margin_left = 14; bs_n.content_margin_right = 14
	bs_n.content_margin_top = 10; bs_n.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", bs_n)
	var bs_h = StyleBoxFlat.new()
	bs_h.bg_color = Color(border_hover.r * 0.18, border_hover.g * 0.18, border_hover.b * 0.18, 0.92)
	bs_h.set_border_width_all(2); bs_h.border_color = border_hover
	bs_h.set_corner_radius_all(6)
	bs_h.content_margin_left = 14; bs_h.content_margin_right = 14
	bs_h.content_margin_top = 10; bs_h.content_margin_bottom = 10
	btn.add_theme_stylebox_override("hover", bs_h)
	btn.mouse_entered.connect(func(): create_tween().tween_property(btn, "scale", Vector2(1.04, 1.04), 0.10))
	btn.mouse_exited.connect(func():  create_tween().tween_property(btn, "scale", Vector2.ONE, 0.10))


func add_loot_button(container: Control, txt: String, action: Callable) -> void:
	var btn = Button.new()
	btn.text = txt; btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func():
		action.call()
		btn.disabled = true; btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
		# Llamada directa al Autoload
		AudioManager.play("button_click")
	)
	container.add_child(btn)


func show_death_dialogue(enemy_name: String) -> void:
	var text = LoreData.get_death_dialogue(enemy_name)
	if text.is_empty(): return
	var col = Color(0.95, 0.8, 0.3) if enemy_name.begins_with("EL ") else Color(0.75, 0.75, 0.8)
	DialogueUI.cinematic(text, col)
