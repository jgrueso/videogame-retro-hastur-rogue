extends Node2D

var chest_panel: Panel
var chest_lid: Panel
var chest_container: Control
var lock_lbl: Label
var _float_tween: Tween = null

var is_opened: bool = false
var reward_data: Dictionary = {}
var is_claiming: bool = false

func _ready() -> void:
	var vp = get_viewport_rect().size
	modulate.a = 0.0

	# Fondo abisal
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.size = vp
	add_child(bg)

	_start_treasure_rain(vp)
	_start_dust_motes(vp)

	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Glith_distorsion_noised_sound")
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		AudioManager.play_loop("map_ambient_song")

	build_ui()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

# ─── UI ───────────────────────────────────────────────────────────────────────

func build_ui() -> void:
	var vp = get_viewport_rect().size

	# Título
	var title = Label.new()
	title.text = "CÁMARA DEL TESORO"
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.85, 0.65, 0.1, 0.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.size = Vector2(vp.x, 56)
	add_child(title)

	var sub = Label.new()
	sub.text = "Algo brilla entre la ceniza. Una pieza que no debería estar aquí."
	sub.add_theme_font_size_override("font_size", 17)
	sub.modulate = Color(0.55, 0.55, 0.55, 0.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 115)
	sub.size = Vector2(vp.x, 30)
	add_child(sub)

	# Separador decorativo
	var sep = ColorRect.new()
	sep.color = Color(0.4, 0.3, 0.1, 0.0)
	sep.size = Vector2(280, 1)
	sep.position = Vector2(vp.x / 2.0 - 140, 155)
	add_child(sep)

	# Entrada staggered: título → sub → separador
	var tw_enter = create_tween()
	tw_enter.tween_interval(0.15)
	tw_enter.tween_property(title, "modulate:a", 1.0, 0.4)
	tw_enter.tween_interval(0.05)
	tw_enter.tween_property(sub, "modulate:a", 1.0, 0.35)
	tw_enter.tween_property(sep, "color:a", 0.55, 0.3)

	# ── EL COFRE ──
	chest_container = Control.new()
	chest_container.position = Vector2(vp.x / 2.0, vp.y / 2.0 + 20.0)
	chest_container.modulate.a = 0.0
	add_child(chest_container)

	# Glow ambiental (ancho, suave)
	var glow_bg = ColorRect.new()
	glow_bg.size = Vector2(360, 210)
	glow_bg.position = Vector2(-180, -125)
	glow_bg.z_index = -2
	glow_bg.color = Color(0.7, 0.5, 0.1, 0.07)
	chest_container.add_child(glow_bg)
	var tw_glow = create_tween().set_loops()
	tw_glow.tween_property(glow_bg, "modulate:a", 0.55, 2.0).set_trans(Tween.TRANS_SINE)
	tw_glow.tween_property(glow_bg, "modulate:a", 0.1, 2.0).set_trans(Tween.TRANS_SINE)

	# Sombra dinámica (se encoge/estira con el float)
	var shadow = ColorRect.new()
	shadow.size = Vector2(220, 16)
	shadow.position = Vector2(-110, 72)
	shadow.z_index = -1
	shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	shadow.pivot_offset = Vector2(110, 8)
	chest_container.add_child(shadow)
	var tw_shad = create_tween().set_loops()
	tw_shad.tween_property(shadow, "scale:x", 0.82, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_shad.tween_property(shadow, "scale:x", 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Cuerpo del cofre
	chest_panel = Panel.new()
	chest_panel.size = Vector2(220, 130)
	chest_panel.position = Vector2(-110, -65)
	var s_body = StyleBoxFlat.new()
	s_body.bg_color = Color(0.18, 0.12, 0.06)
	s_body.set_border_width_all(3)
	s_body.border_color = Color(0.5, 0.38, 0.14)
	s_body.set_corner_radius_all(5)
	chest_panel.add_theme_stylebox_override("panel", s_body)
	chest_container.add_child(chest_panel)

	# Franja horizontal (herraje)
	var band = ColorRect.new()
	band.size = Vector2(220, 12)
	band.position = Vector2(-110, -8)
	band.color = Color(0.42, 0.30, 0.09)
	band.z_index = 1
	chest_container.add_child(band)

	# Fondo de cerradura
	var lock_bg = ColorRect.new()
	lock_bg.size = Vector2(26, 26)
	lock_bg.position = Vector2(-13, -13)
	lock_bg.color = Color(0.28, 0.20, 0.07)
	lock_bg.z_index = 2
	chest_container.add_child(lock_bg)

	# Cerradura (cambia a 🔓 al abrir)
	lock_lbl = Label.new()
	lock_lbl.text = "🔒"
	lock_lbl.add_theme_font_size_override("font_size", 16)
	lock_lbl.position = Vector2(-15, -15)
	lock_lbl.z_index = 3
	chest_container.add_child(lock_lbl)

	# Tapa del cofre
	chest_lid = Panel.new()
	chest_lid.size = Vector2(230, 68)
	chest_lid.position = Vector2(-115, -108)
	chest_lid.pivot_offset = Vector2(115, 68)
	var s_lid = StyleBoxFlat.new()
	s_lid.bg_color = Color(0.22, 0.16, 0.08)
	s_lid.set_border_width_all(3)
	s_lid.border_color = Color(0.65, 0.52, 0.2)
	s_lid.corner_radius_top_left = 8
	s_lid.corner_radius_top_right = 8
	s_lid.corner_radius_bottom_left = 0
	s_lid.corner_radius_bottom_right = 0
	chest_lid.add_theme_stylebox_override("panel", s_lid)
	chest_container.add_child(chest_lid)

	# Partículas ambientales (chispas ascendentes)
	_spawn_chest_ambient(chest_container.position)

	# Float suave
	var base_y = chest_container.position.y
	_float_tween = chest_container.create_tween().set_loops()
	_float_tween.tween_property(chest_container, "position:y", base_y + 9.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(chest_container, "position:y", base_y - 9.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Área de clic invisible
	var click_btn = Button.new()
	click_btn.flat = true
	click_btn.size = Vector2(320, 290)
	click_btn.position = Vector2(-160, -165)
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chest_container.add_child(click_btn)
	click_btn.pressed.connect(_on_chest_clicked)
	click_btn.mouse_entered.connect(func(): _on_chest_hover(true))
	click_btn.mouse_exited.connect(func(): _on_chest_hover(false))

	# Hint "haz clic"
	var hint = Label.new()
	hint.text = "[ haz clic para abrir ]"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.5, 0.5, 0.5, 0.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, vp.y / 2.0 + 115)
	hint.size = Vector2(vp.x, 22)
	add_child(hint)
	var tw_hint = create_tween()
	tw_hint.tween_interval(0.8)
	tw_hint.tween_property(hint, "modulate:a", 0.55, 0.4)

	# Cofre entra con delay
	var tw_chest_in = create_tween()
	tw_chest_in.tween_interval(0.35)
	tw_chest_in.tween_property(chest_container, "modulate:a", 1.0, 0.4)

	# Botón Ver Mazo
	var btn_view = Button.new()
	btn_view.text = "🎴 VER MAZO"
	btn_view.size = Vector2(180, 45)
	btn_view.position = Vector2(vp.x - 220, 25)
	btn_view.add_theme_font_size_override("font_size", 14)
	btn_view.pressed.connect(func(): GameManager.show_deck_overlay(self))
	add_child(btn_view)

# ─── HOVER & OPEN ─────────────────────────────────────────────────────────────

func _on_chest_hover(hovered: bool) -> void:
	if is_opened:
		return
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(chest_container, "scale", Vector2(1.06, 1.06) if hovered else Vector2(1.0, 1.0), 0.18)

func _on_chest_clicked() -> void:
	if is_opened:
		return
	is_opened = true

	# Detener float para no pelear con la animación de apertura
	if _float_tween:
		_float_tween.kill()
	var tw_recenter = create_tween()
	tw_recenter.tween_property(chest_container, "position:y", get_viewport_rect().size.y / 2.0 + 20.0, 0.1)

	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("menu_glitch")

	await tw_recenter.finished

	# Fase 1: anticipación (squash)
	var tw_anticipate = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_anticipate.tween_property(chest_container, "scale", Vector2(1.12, 0.88), 0.1)
	await tw_anticipate.finished

	# Fase 2: tapa vuela hacia arriba con BACK
	var tw_open = create_tween().set_parallel(true)
	tw_open.tween_property(chest_lid, "rotation", -PI / 1.4, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_open.tween_property(chest_lid, "position:y", -185.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_open.tween_property(chest_container, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_open.finished

	# Flash de luz
	_spawn_open_flash()

	# Cambiar cerradura
	if lock_lbl:
		lock_lbl.text = "🔓"

	# Burst de partículas
	_spawn_chest_burst(chest_panel.get_parent().global_position)

	await get_tree().create_timer(0.15).timeout
	_reveal_reward()

func _spawn_open_flash() -> void:
	var vp = get_viewport_rect().size
	var flash = ColorRect.new()
	flash.size = vp
	flash.color = Color(1.0, 0.92, 0.5, 0.0)
	flash.z_index = 20
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.38, 0.08)
	tw.tween_property(flash, "color:a", 0.0, 0.38).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(flash.queue_free)

# ─── REWARD ───────────────────────────────────────────────────────────────────

func _reveal_reward() -> void:
	var is_relic = false
	if GameManager.is_vault_room:
		if GameManager.current_world == 0:
			var legendaries = CardData.ALL_CARDS.filter(func(c): return c.get("legendary", false))
			reward_data = {"choices": legendaries, "type": "legendary_draft"}
			is_relic = false
		else:
			if not GameManager.prince_unlocked:
				reward_data = {"type": "prince_unlock"}
			else:
				var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
				available.shuffle()
				reward_data = {"id": available[0], "type": "relic", "special": "high_tier"}
	else:
		is_relic = GameManager.sanity < 40 or randf() < 0.2
		if is_relic:
			var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
			if not available.is_empty():
				available.shuffle()
				reward_data = {"id": available[0], "type": "relic"}
			else:
				is_relic = false
		if not is_relic:
			var normal_pool = CardData.ALL_CARDS.filter(func(c): return not c.get("legendary", false))
			normal_pool.shuffle()
			reward_data = {"data": normal_pool[0], "type": "card"}

	_show_reward_modal()

func _show_reward_modal() -> void:
	var vp = get_viewport_rect().size

	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("relic_get")

	# Overlay oscuro
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = vp
	overlay.z_index = 100
	add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.88, 0.3)

	# ── DRAFT LEGENDARIO (caso especial: usa todo el overlay) ──
	if reward_data["type"] == "legendary_draft":
		var header = Label.new()
		header.text = "ELIGE UNA PIEZA LEGENDARIA"
		header.add_theme_font_size_override("font_size", 26)
		header.modulate = Color(1.0, 0.85, 0.2)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.position = Vector2(0, vp.y * 0.08)
		header.size = Vector2(vp.x, 38)
		overlay.add_child(header)

		var sub_header = Label.new()
		sub_header.text = "Las no elegidas se perderán para siempre."
		sub_header.add_theme_font_size_override("font_size", 14)
		sub_header.modulate = Color(0.6, 0.55, 0.55)
		sub_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_header.position = Vector2(0, vp.y * 0.08 + 44)
		sub_header.size = Vector2(vp.x, 24)
		overlay.add_child(sub_header)

		var draft_grid = HBoxContainer.new()
		draft_grid.position = Vector2(vp.x * 0.08, vp.y * 0.18)
		draft_grid.size = Vector2(vp.x * 0.84, 320)
		draft_grid.add_theme_constant_override("separation", 40)
		draft_grid.alignment = BoxContainer.ALIGNMENT_CENTER
		overlay.add_child(draft_grid)

		var card_scene = load("res://scenes/combat/Card.tscn")
		for ci in range(reward_data["choices"].size()):
			var c_data = reward_data["choices"][ci]
			var vbox = VBoxContainer.new()
			vbox.modulate.a = 0.0
			draft_grid.add_child(vbox)

			var card_node = card_scene.instantiate()
			vbox.add_child(card_node)
			card_node.setup(c_data)
			card_node.scale = Vector2(1.2, 1.2)
			card_node.custom_minimum_size = Vector2(130, 195)

			var claim_btn = Button.new()
			claim_btn.text = "RECLAMAR"
			_style_btn_primary(claim_btn)
			vbox.add_child(claim_btn)

			# Entrada staggered
			var tw_c = create_tween()
			tw_c.tween_interval(0.1 + 0.12 * ci)
			tw_c.tween_property(vbox, "modulate:a", 1.0, 0.3)

			var final_data = c_data
			claim_btn.pressed.connect(func():
				if is_claiming: return
				is_claiming = true
				GameManager.add_card(final_data)
				if GameManager.is_vault_room:
					GameManager.current_map_floor = min(GameManager.current_map_floor + 1, GameManager.map_graph.size() - 1)
					GameManager.current_map_col = -1
					GameManager.is_vault_room = false
				_exit_to_map(overlay)
			)
		return

	# ── MODAL CENTRAL ──
	var modal = Panel.new()
	modal.size = Vector2(520, 440)
	modal.position = Vector2(vp.x / 2.0 - 260.0, vp.y / 2.0 - 210.0)
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.88, 0.88)
	modal.pivot_offset = Vector2(260, 220)
	var ms = StyleBoxFlat.new()
	ms.bg_color = Color(0.06, 0.05, 0.09, 0.97)
	ms.set_border_width_all(2)
	ms.border_color = Color(0.62, 0.48, 0.14)
	ms.set_corner_radius_all(12)
	ms.content_margin_left = 24; ms.content_margin_right = 24
	ms.content_margin_top = 20; ms.content_margin_bottom = 20
	modal.add_theme_stylebox_override("panel", ms)
	overlay.add_child(modal)

	# Pop de entrada del modal
	var tw_modal = create_tween().set_parallel(true)
	tw_modal.tween_property(modal, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD)
	tw_modal.tween_property(modal, "scale", Vector2(1.0, 1.0), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Línea decorativa superior
	var top_line = ColorRect.new()
	top_line.size = Vector2(380, 2)
	top_line.position = Vector2(70, 0)
	top_line.color = Color(0.6, 0.46, 0.13, 0.6)
	modal.add_child(top_line)

	# Header
	var lbl = Label.new()
	lbl.text = "¡HAS ENCONTRADO!"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.modulate = Color(0.85, 0.72, 0.2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 22)
	lbl.size = Vector2(520, 36)
	modal.add_child(lbl)

	# ── ITEM AREA ──
	var item_area = Control.new()
	item_area.position = Vector2(0, 68)
	item_area.size = Vector2(520, 280)
	item_area.modulate.a = 0.0
	modal.add_child(item_area)

	if reward_data["type"] == "card":
		var card_scene = load("res://scenes/combat/Card.tscn")
		var card = card_scene.instantiate()
		item_area.add_child(card)
		card.setup(reward_data["data"])
		card.pivot_offset = Vector2(65, 95)
		card.scale = Vector2(0.4, 0.4)
		card.position = Vector2(520.0 / 2.0 - 65.0, 20.0)
		# Pop de la carta
		var tw_card = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_card.tween_interval(0.25)
		tw_card.tween_property(card, "scale", Vector2(1.5, 1.5), 0.45)

	elif reward_data["type"] == "prince_unlock":
		lbl.text = "¡HAS LIBERADO AL PRÍNCIPE DE CARCOSA!"
		lbl.modulate = Color(0.88, 0.7, 1.0)
		lbl.add_theme_font_size_override("font_size", 18)
		var p_icon = Label.new()
		p_icon.text = "🤴"
		p_icon.add_theme_font_size_override("font_size", 88)
		p_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_icon.position = Vector2(0, 15)
		p_icon.size = Vector2(520, 110)
		item_area.add_child(p_icon)
		var p_desc = Label.new()
		p_desc.text = "Un antiguo aliado del Rey, atrapado por siglos.\nAhora se une a tu tablero con sinergias de Locura."
		p_desc.add_theme_font_size_override("font_size", 16)
		p_desc.modulate = Color(0.75, 0.7, 0.82)
		p_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		p_desc.position = Vector2(40, 130)
		p_desc.size = Vector2(440, 80)
		item_area.add_child(p_desc)

	else:
		# Reliquia
		var r_id = reward_data["id"]
		var r_data = GameManager.RELIC_DATA[r_id]
		var r_icon = Label.new()
		r_icon.text = "◈"
		r_icon.add_theme_font_size_override("font_size", 72)
		r_icon.modulate = Color(1.0, 0.88, 0.35)
		r_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_icon.position = Vector2(0, 8)
		r_icon.size = Vector2(520, 96)
		item_area.add_child(r_icon)
		# Pulso del icono
		var tw_pulse = r_icon.create_tween().set_loops()
		tw_pulse.tween_property(r_icon, "scale", Vector2(1.08, 1.08), 1.1).set_trans(Tween.TRANS_SINE)
		tw_pulse.tween_property(r_icon, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_SINE)

		var rn = Label.new()
		rn.text = r_data["name"].to_upper()
		rn.add_theme_font_size_override("font_size", 22)
		rn.modulate = Color(1.0, 0.88, 0.38)
		rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rn.position = Vector2(0, 108)
		rn.size = Vector2(520, 32)
		item_area.add_child(rn)

		var rd = Label.new()
		rd.text = r_data["desc"]
		rd.autowrap_mode = TextServer.AUTOWRAP_WORD
		rd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rd.add_theme_font_size_override("font_size", 14)
		rd.modulate = Color(0.72, 0.7, 0.76)
		rd.position = Vector2(40, 148)
		rd.size = Vector2(440, 90)
		item_area.add_child(rd)

	# Item entra con delay
	var tw_item = create_tween()
	tw_item.tween_interval(0.25)
	tw_item.tween_property(item_area, "modulate:a", 1.0, 0.35)

	# ── BOTONES ──
	var btn_hbox = HBoxContainer.new()
	btn_hbox.size = Vector2(460, 56)
	btn_hbox.position = Vector2(30, 365)
	btn_hbox.add_theme_constant_override("separation", 20)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.modulate.a = 0.0
	modal.add_child(btn_hbox)

	var btn_take = Button.new()
	btn_take.text = "✦ ACEPTAR"
	btn_take.custom_minimum_size = Vector2(195, 52)
	_style_btn_primary(btn_take)
	btn_hbox.add_child(btn_take)

	var btn_leave = Button.new()
	btn_leave.text = "DEJAR ATRÁS"
	btn_leave.custom_minimum_size = Vector2(195, 52)
	_style_btn_secondary(btn_leave)
	btn_hbox.add_child(btn_leave)

	# Botones entran con delay
	var tw_btns = create_tween()
	tw_btns.tween_interval(0.5)
	tw_btns.tween_property(btn_hbox, "modulate:a", 1.0, 0.3)

	btn_take.pressed.connect(func():
		if reward_data["type"] == "card":
			GameManager.add_card(reward_data["data"])
		elif reward_data["type"] == "prince_unlock":
			GameManager.prince_unlocked = true
			GameManager.unlock_lore("hastur_eco")
		else:
			GameManager.add_relic(reward_data["id"])
		if GameManager.is_vault_room:
			GameManager.current_map_floor = min(GameManager.current_map_floor + 1, GameManager.map_graph.size() - 1)
			GameManager.current_map_col = -1
			GameManager.is_vault_room = false
		GameManager.came_from_room = true
		_exit_to_map(overlay)
	)

	btn_leave.pressed.connect(func():
		if GameManager.is_vault_room:
			GameManager.current_map_floor = min(GameManager.current_map_floor + 1, GameManager.map_graph.size() - 1)
			GameManager.current_map_col = -1
			GameManager.is_vault_room = false
		GameManager.came_from_room = true
		_exit_to_map(overlay)
	)

func _exit_to_map(overlay: ColorRect) -> void:
	var tw = create_tween()
	tw.tween_property(overlay, "color:a", 1.0, 0.22)
	tw.tween_callback(func(): GameManager.go_to_scene("res://scenes/ui/Map.tscn"))

# ─── ESTILOS ──────────────────────────────────────────────────────────────────

func _style_btn_primary(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 15)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.14, 0.04)
	s.set_border_width_all(2); s.border_color = Color(0.75, 0.58, 0.15)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 8; s.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", s)
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.28, 0.22, 0.06)
	sh.set_border_width_all(2); sh.border_color = Color(1.0, 0.82, 0.25)
	sh.set_corner_radius_all(6)
	sh.content_margin_left = 12; sh.content_margin_right = 12
	sh.content_margin_top = 8; sh.content_margin_bottom = 8
	btn.add_theme_stylebox_override("hover", sh)
	var sp = StyleBoxFlat.new()
	sp.bg_color = Color(0.12, 0.09, 0.02)
	sp.set_border_width_all(2); sp.border_color = Color(0.9, 0.7, 0.1)
	sp.set_corner_radius_all(6)
	sp.content_margin_left = 12; sp.content_margin_right = 12
	sp.content_margin_top = 8; sp.content_margin_bottom = 8
	btn.add_theme_stylebox_override("pressed", sp)

func _style_btn_secondary(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.52, 0.52, 0.58))
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.07, 0.09)
	s.set_border_width_all(1); s.border_color = Color(0.28, 0.28, 0.33)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 8; s.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", s)
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.13, 0.12, 0.15)
	sh.set_border_width_all(1); sh.border_color = Color(0.42, 0.42, 0.48)
	sh.set_corner_radius_all(6)
	sh.content_margin_left = 12; sh.content_margin_right = 12
	sh.content_margin_top = 8; sh.content_margin_bottom = 8
	btn.add_theme_stylebox_override("hover", sh)

# ─── PARTÍCULAS ───────────────────────────────────────────────────────────────

func _start_treasure_rain(vp: Vector2) -> void:
	var gpu = GPUParticles2D.new()
	gpu.position = Vector2(vp.x * 0.5, -5.0)
	gpu.z_index = -1
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(vp.x * 0.5, 1.0, 0.0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 10.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 25, 0)
	mat.scale_min = 1.0
	mat.scale_max = 3.5
	var g = Gradient.new()
	g.set_color(0, Color(0.9, 0.7, 0.2, 0.35))
	g.set_color(1, Color(0.6, 0.4, 0.1, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = g
	mat.color_ramp = gt
	gpu.process_material = mat
	gpu.amount = 40
	gpu.lifetime = vp.y / 90.0
	gpu.one_shot = false; gpu.emitting = true
	add_child(gpu)

func _start_dust_motes(vp: Vector2) -> void:
	# Segundo layer: polvo lento y grande — profundidad ambiental
	var gpu = GPUParticles2D.new()
	gpu.position = Vector2(vp.x * 0.5, -5.0)
	gpu.z_index = -2
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(vp.x * 0.5, 1.0, 0.0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 8, 0)
	mat.scale_min = 3.5
	mat.scale_max = 8.0
	var g = Gradient.new()
	g.set_color(0, Color(0.8, 0.65, 0.25, 0.1))
	g.set_color(1, Color(0.5, 0.35, 0.1, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = g
	mat.color_ramp = gt
	gpu.process_material = mat
	gpu.amount = 18
	gpu.lifetime = vp.y / 28.0
	gpu.one_shot = false; gpu.emitting = true
	add_child(gpu)

func _spawn_chest_ambient(pos: Vector2) -> void:
	# Chispas sutiles que ascienden del cofre antes de abrirlo
	var gpu = GPUParticles2D.new()
	gpu.position = pos
	gpu.z_index = 1
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 55.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 55.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 22.0
	mat.gravity = Vector3(0, -4, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.5
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 0.0))
	g.set_color(0.25, Color(1.0, 0.85, 0.3, 0.75))
	g.set_color(1.0, Color(0.8, 0.5, 0.1, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = g
	mat.color_ramp = gt
	gpu.process_material = mat
	gpu.amount = 12
	gpu.lifetime = 2.4
	gpu.one_shot = false; gpu.emitting = true
	add_child(gpu)

func _spawn_chest_burst(pos: Vector2) -> void:
	var gpu = GPUParticles2D.new()
	gpu.position = pos
	gpu.z_index = 50
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.spread = 180.0
	mat.initial_velocity_min = 120.0
	mat.initial_velocity_max = 360.0
	mat.gravity = Vector3(0, 400, 0)
	mat.scale_min = 3.0
	mat.scale_max = 9.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	g.set_color(1, Color(0.8, 0.5, 0.0, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = g
	mat.color_ramp = gt
	gpu.process_material = mat
	gpu.amount = 50
	gpu.lifetime = 1.0
	gpu.one_shot = true
	gpu.explosiveness = 0.95
	add_child(gpu)
	gpu.emitting = true
	get_tree().create_timer(1.8).timeout.connect(gpu.queue_free)
