extends Node2D

var chest_panel: Panel
var chest_lid: Panel
var is_opened: bool = false
var reward_data: Dictionary = {}
var is_claiming: bool = false # Seguridad para no elegir varias

func _ready() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo abisal
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.size = vp
	add_child(bg)
	
	_start_treasure_rain(vp)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Glith_distorsion_noised_sound")
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		AudioManager.play_loop("map_ambient_song")
	
	build_ui()

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	var title = Label.new()
	title.text = "CÁMARA DEL TESORO"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.8, 0.6, 0.1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 60)
	add_child(title)

	var sub = Label.new()
	sub.text = "Algo brilla entre la ceniza. Una pieza que no debería estar aquí."
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.6, 0.6, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 130); sub.size = Vector2(vp.x, 30)
	add_child(sub)

	# --- EL COFRE ---
	var chest_container = Control.new()
	chest_container.position = Vector2(vp.x/2, vp.y/2 + 50)
	add_child(chest_container)
	
	chest_panel = Panel.new()
	chest_panel.size = Vector2(200, 120)
	chest_panel.position = -chest_panel.size / 2
	var s_body = StyleBoxFlat.new()
	s_body.bg_color = Color(0.15, 0.1, 0.05); s_body.set_border_width_all(3); s_body.border_color = Color(0.4, 0.3, 0.1); s_body.set_corner_radius_all(4)
	chest_panel.add_theme_stylebox_override("panel", s_body)
	chest_container.add_child(chest_panel)
	
	chest_lid = Panel.new()
	chest_lid.size = Vector2(210, 60)
	chest_lid.position = Vector2(-105, -90)
	chest_lid.pivot_offset = Vector2(105, 60)
	var s_lid = StyleBoxFlat.new()
	s_lid.bg_color = Color(0.2, 0.15, 0.08); s_lid.set_border_width_all(3); s_lid.border_color = Color(0.6, 0.5, 0.2); s_lid.set_corner_radius_all(8)
	chest_lid.add_theme_stylebox_override("panel", s_lid)
	chest_container.add_child(chest_lid)
	
	# Brillo indicativo
	var glow = ColorRect.new()
	glow.size = Vector2(240, 160); glow.position = Vector2(-120, -100); glow.z_index = -1
	glow.color = Color(0.8, 0.6, 0.2, 0.1)
	chest_container.add_child(glow)
	var tw_glow = create_tween().set_loops()
	tw_glow.tween_property(glow, "modulate:a", 0.4, 1.5)
	tw_glow.tween_property(glow, "modulate:a", 0.1, 1.5)
	
	# Boton invisible para clic
	var click_btn = Button.new()
	click_btn.flat = true
	click_btn.size = Vector2(300, 300)
	click_btn.position = Vector2(-150, -150)
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chest_container.add_child(click_btn)
	click_btn.pressed.connect(_on_chest_clicked)

	# --- BOTON VER MAZO ---
	var btn_view = Button.new()
	btn_view.text = "🎴 VER MAZO"
	btn_view.size = Vector2(180, 45)
	btn_view.position = Vector2(vp.x - 220, 25)
	btn_view.add_theme_font_size_override("font_size", 14)
	btn_view.pressed.connect(func(): GameManager.show_deck_overlay(self))
	add_child(btn_view)

func _on_chest_clicked() -> void:
	if is_opened: return
	is_opened = true
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("menu_glitch")
	
	# Animación de apertura
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(chest_lid, "rotation", -PI/1.5, 0.6)
	tw.tween_property(chest_lid, "position:y", -140, 0.6)
	
	await tw.finished
	_reveal_reward()

func _reveal_reward() -> void:
	var is_relic = false
	if GameManager.is_vault_room:
		if GameManager.current_world == 0:
			# Mundo 1: OFRECER TODAS LAS LEGENDARIAS (Elegir 1)
			var legendaries = CardData.ALL_CARDS.filter(func(c): return c.get("legendary", false))
			reward_data = {"choices": legendaries, "type": "legendary_draft"}
			is_relic = false
		else:
			# Mundo 2: Liberar al Príncipe
			if not GameManager.prince_unlocked:
				reward_data = {"type": "prince_unlock"}
			else:
				# Si ya está libre, dar reliquia de alto nivel
				var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
				available.shuffle()
				reward_data = {"id": available[0], "type": "relic", "special": "high_tier"}
	else:
		# Lógica de cofre normal
		is_relic = GameManager.sanity < 40 or randf() < 0.2
		
		if is_relic:
			var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
			if not available.is_empty():
				available.shuffle()
				reward_data = {"id": available[0], "type": "relic"}
			else:
				is_relic = false
		
		if not is_relic:
			# FILTRAR: Los cofres normales NO dan legendarias
			var normal_pool = CardData.ALL_CARDS.filter(func(c): return not c.get("legendary", false))
			normal_pool.shuffle()
			reward_data = {"data": normal_pool[0], "type": "card"}
	
	_show_reward_modal()

func _show_reward_modal() -> void:
	var vp = get_viewport_rect().size
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = vp # Sizing manual
	overlay.z_index = 100
	add_child(overlay)
	
	var tw = create_tween()
	tw.tween_property(overlay, "color:a", 0.85, 0.4)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("relic_get")

	var lbl = Label.new()
	lbl.text = "¡HAS ENCONTRADO!"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, vp.y/2 - 220); lbl.size = Vector2(vp.x, 40)
	overlay.add_child(lbl)

	# --- VISUALIZACIÓN DEL ITEM ---
	if reward_data["type"] == "legendary_draft":
		lbl.text = "ELIGE UNA PIEZA LEGENDARIA (LAS OTRAS SE PERDERÁN)"
		lbl.modulate = Color(1.0, 0.8, 0.2)
		
		var draft_grid = HBoxContainer.new()
		draft_grid.position = Vector2(vp.x * 0.1, vp.y/2 - 150)
		draft_grid.size = Vector2(vp.x * 0.8, 300)
		draft_grid.add_theme_constant_override("separation", 40)
		draft_grid.alignment = BoxContainer.ALIGNMENT_CENTER
		overlay.add_child(draft_grid)
		
		var card_scene = load("res://scenes/combat/Card.tscn")
		for c_data in reward_data["choices"]:
			var vbox = VBoxContainer.new()
			draft_grid.add_child(vbox)
			
			var card_node = card_scene.instantiate()
			vbox.add_child(card_node)
			card_node.setup(c_data)
			card_node.scale = Vector2(1.2, 1.2)
			card_node.custom_minimum_size = Vector2(130, 195)
			
			var claim_btn = Button.new()
			claim_btn.text = "RECLAMAR"
			vbox.add_child(claim_btn)
			
			var final_data = c_data
			claim_btn.pressed.connect(func():
				if is_claiming: return
				is_claiming = true
				GameManager.add_card(final_data)
				if GameManager.is_vault_room:
					GameManager.current_map_floor = min(GameManager.current_map_floor + 1, GameManager.map_graph.size() - 1)
					GameManager.current_map_col = -1
					GameManager.is_vault_room = false
				get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
			)
		return

	if reward_data["type"] == "card":
		var card_scene = load("res://scenes/combat/Card.tscn")
		var card = card_scene.instantiate()
		overlay.add_child(card)
		card.setup(reward_data["data"])
		card.scale = Vector2(1.4, 1.4)
		card.position = Vector2(vp.x/2 - 65, vp.y/2 - 100)
	elif reward_data["type"] == "prince_unlock":
		lbl.text = "¡HAS LIBERADO AL PRÍNCIPE DE CARCOSA!"
		var p_icon = Label.new(); p_icon.text = "🤴"; p_icon.add_theme_font_size_override("font_size", 120)
		p_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_icon.position = Vector2(vp.x/2 - 100, vp.y/2 - 100); overlay.add_child(p_icon)
		
		var p_desc = Label.new(); p_desc.text = "Un antiguo aliado del Rey, atrapado por siglos.\nAhora se une a tu tablero con sinergias de Locura."
		p_desc.add_theme_font_size_override("font_size", 18); p_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_desc.position = Vector2(0, vp.y/2 + 50); p_desc.size = Vector2(vp.x, 60); overlay.add_child(p_desc)
	else:
		var r_id = reward_data["id"]
		var r_data = GameManager.RELIC_DATA[r_id]
		var rpanel = Panel.new()
		rpanel.size = Vector2(300, 200)
		rpanel.position = (vp - rpanel.size) / 2
		var s = StyleBoxFlat.new(); s.bg_color = Color(0.1, 0.08, 0.05); s.set_border_width_all(2); s.border_color = Color(0.8, 0.6, 0.2); s.set_corner_radius_all(8)
		rpanel.add_theme_stylebox_override("panel", s)
		overlay.add_child(rpanel)
		var rn = Label.new(); rn.text = r_data["name"].to_upper(); rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rn.position = Vector2(0, 20); rn.size = Vector2(300, 30); rn.modulate = Color(1, 0.9, 0.4); rpanel.add_child(rn)
		var rd = Label.new(); rd.text = r_data["desc"]; rd.autowrap_mode = TextServer.AUTOWRAP_WORD; rd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rd.position = Vector2(20, 60); rd.size = Vector2(260, 100); rd.add_theme_font_size_override("font_size", 14); rpanel.add_child(rd)

	# --- BOTONES ---
	var btn_hbox = HBoxContainer.new()
	btn_hbox.size = Vector2(500, 60)
	btn_hbox.position = Vector2(vp.x/2 - 250, vp.y - 120)
	btn_hbox.add_theme_constant_override("separation", 40)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(btn_hbox)

	var btn_take = Button.new()
	btn_take.text = "ACEPTAR"
	btn_take.custom_minimum_size = Vector2(200, 50)
	btn_hbox.add_child(btn_take)
	btn_take.pressed.connect(func(): 
		if reward_data["type"] == "card":
			GameManager.add_card(reward_data["data"])
		elif reward_data["type"] == "prince_unlock":
			GameManager.prince_unlocked = true
			GameManager.unlock_lore("hastur_eco")
		else:
			GameManager.add_relic(reward_data["id"])
		
		# Avanzar piso si venimos de grieta para no repetir
		if GameManager.is_vault_room:
			GameManager.current_map_floor = min(GameManager.current_map_floor + 1, GameManager.map_graph.size() - 1)
			GameManager.current_map_col = -1 # Resetear columna para que el nuevo piso sea accesible
			GameManager.is_vault_room = false
		GameManager.came_from_room = true
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)

	var btn_leave = Button.new()
	btn_leave.text = "DEJAR ATRÁS"
	btn_leave.custom_minimum_size = Vector2(200, 50)
	btn_hbox.add_child(btn_leave)
	btn_leave.pressed.connect(func():
		if GameManager.is_vault_room:
			GameManager.current_map_floor = min(GameManager.current_map_floor + 1, GameManager.map_graph.size() - 1)
			GameManager.current_map_col = -1
			GameManager.is_vault_room = false
		GameManager.came_from_room = true
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)

func _start_treasure_rain(vp: Vector2) -> void:
	for i in range(40):
		var drop = ColorRect.new()
		drop.size = Vector2(1, randi_range(10, 20))
		drop.color = Color(0.8, 0.6, 0.2, 0.15)
		drop.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		add_child(drop)
		var dur = randf_range(1.5, 3.0)
		create_tween().set_loops().tween_property(drop, "position:y", vp.y + 20, dur).from(-20)
