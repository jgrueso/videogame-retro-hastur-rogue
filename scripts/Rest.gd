extends Node2D

var btn_container: VBoxContainer

func _ready() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo abisal
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.size = vp
	add_child(bg)
	
	_start_ember_rain(vp)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.crossfade_loop("map_ambient_song", "resting_song", 1.5)
	
	build_ui()

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	var title = Label.new()
	title.text = "🕯 HOGUERA DE CENIZA 🕯"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.85, 0.75, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 60)
	add_child(title)

	var sub = Label.new()
	sub.text = "Un momento de tregua antes de que el tablero se cierre sobre ti."
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.6, 0.6, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 130); sub.size = Vector2(vp.x, 30)
	add_child(sub)

	var info = Label.new()
	info.text = "HP: %d/%d   |   Cordura: %d%%" % [GameManager.player_hp, GameManager.player_max_hp, GameManager.sanity]
	info.add_theme_font_size_override("font_size", 16)
	info.modulate = Color(0.8, 0.8, 0.8)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 165); info.size = Vector2(vp.x, 30)
	add_child(info)

	btn_container = VBoxContainer.new()
	btn_container.position = Vector2(vp.x * 0.3, 220)
	btn_container.size = Vector2(vp.x * 0.4, 300)
	btn_container.add_theme_constant_override("separation", 25)
	add_child(btn_container)

	# Opción 1: Descansar (Curar)
	var btn_heal = _make_rest_button("🔥 DESCANSAR (+20 HP)")
	btn_heal.pressed.connect(_on_heal_pressed)
	btn_container.add_child(btn_heal)

	# Opción 2: Forjar (Mejorar carta aleatoria)
	var btn_forge = _make_rest_button("⚒ FORJAR PIEZA (Mejora al azar)")
	btn_forge.pressed.connect(_on_forge_pressed)
	btn_container.add_child(btn_forge)

	# Opción 3: Sacrificio (Aumentar Cordura a cambio de HP Max)
	var btn_sac = _make_rest_button("🩸 SACRIFICIO (+25 Cordura | -10 HP MAX)")
	btn_sac.modulate = Color(0.8, 0.4, 0.4)
	btn_sac.disabled = GameManager.player_max_hp <= 30
	btn_sac.pressed.connect(_on_sacrifice_pressed)
	btn_container.add_child(btn_sac)

	# --- BOTON VER MAZO ---
	var btn_view = _make_rest_button("🎴 VER MAZO")
	btn_view.modulate = Color(0.6, 0.6, 0.9)
	btn_view.pressed.connect(func(): GameManager.show_deck_overlay(self))
	btn_container.add_child(btn_view)

func _make_rest_button(txt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 65)
	btn.add_theme_font_size_override("font_size", 18)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.08, 0.05); s.set_border_width_all(3); s.border_color = Color(0.4, 0.3, 0.1); s.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate(); h.bg_color = Color(0.15, 0.12, 0.08)
	btn.add_theme_stylebox_override("hover", h)
	return btn

func _on_heal_pressed() -> void:
	GameManager.heal(20)
	_finish_rest()

func _on_sacrifice_pressed() -> void:
	GameManager.player_max_hp -= 10
	GameManager.player_hp = min(GameManager.player_hp, GameManager.player_max_hp)
	GameManager.sanity = min(100, GameManager.sanity + 25)
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("agony_shriek")
	_finish_rest()

func _on_forge_pressed() -> void:
	# No se pueden forjar leyendas ni cartas ya mejoradas
	var upgradeables = []
	for i in range(GameManager.player_deck.size()):
		var c = GameManager.player_deck[i]
		var is_legendary = c.get("legendary", false)
		if not c.get("upgraded", false) and not is_legendary:
			upgradeables.append(i)
			
	if upgradeables.is_empty():
		_finish_rest()
		return
	
	upgradeables.shuffle()
	var deck_idx = upgradeables[0]
	var card = GameManager.player_deck[deck_idx]
	
	# --- NUEVA ANIMACIÓN DE FORJA ---
	btn_container.visible = false
	var vp = get_viewport_rect().size
	
	# Fondo oscuro bloqueante
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85); overlay.size = vp; overlay.z_index = 150
	add_child(overlay)
	
	var card_scene = load("res://scenes/combat/Card.tscn")
	var card_node = card_scene.instantiate()
	overlay.add_child(card_node)
	card_node.setup(card)
	card_node.position = vp / 2 - Vector2(65, 97)
	card_node.scale = Vector2(1.5, 1.5)
	
	# El Martillo
	var hammer = Label.new()
	hammer.text = "🔨"
	hammer.add_theme_font_size_override("font_size", 100)
	hammer.pivot_offset = Vector2(50, 50)
	hammer.position = Vector2(vp.x/2 - 50, vp.y/2 - 300)
	hammer.rotation = -0.6
	overlay.add_child(hammer)
	
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(hammer, "position:y", vp.y/2 - 120, 0.45)
	tw.parallel().tween_property(hammer, "rotation", 0.0, 0.45)
	
	# Impacto y chispas
	tw.tween_callback(func():
		if get_node_or_null("/root/AudioManager"): AudioManager.play("shield_block")
		_spawn_forge_sparks(vp/2, overlay)
		card_node.scale = Vector2(1.8, 1.8)
		create_tween().tween_property(card_node, "scale", Vector2(1.5, 1.5), 0.2)
		
		# Aplicar mejora al original en el deck (Duplicando para que sea mutable)
		var target = GameManager.player_deck[deck_idx].duplicate()
		target["upgraded"] = true
		if target.get("attack", 0) > 0: target["attack"] += 3
		if target.get("defense", 0) > 0: target["defense"] += 3
		if not "+" in str(target.get("name", "")): target["name"] = str(target.get("name", "")) + "+1"
		
		# Reemplazar en el mazo con la versión mutable mejorada
		GameManager.player_deck[deck_idx] = target
		
		card_node.setup(target) # Refrescar visual
	)
	
	tw.tween_property(hammer, "modulate:a", 0.0, 0.3).set_delay(0.2)
	
	# Boton Continuar
	var cont_btn = Button.new()
	cont_btn.text = "ACEPTAR Y CONTINUAR"
	cont_btn.size = Vector2(280, 60)
	cont_btn.position = Vector2(vp.x/2 - 140, vp.y - 120)
	cont_btn.modulate.a = 0
	overlay.add_child(cont_btn)
	cont_btn.pressed.connect(func(): GameManager.go_to_scene("res://scenes/ui/Map.tscn"))
	
	create_tween().tween_property(cont_btn, "modulate:a", 1.0, 0.5).set_delay(1.2)

func _spawn_forge_sparks(pos: Vector2, parent: Node) -> void:
	var gpu = GPUParticles2D.new()
	gpu.position = pos
	gpu.z_index = 160
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 250.0
	mat.gravity = Vector3(0, 600, 0)
	mat.scale_min = 3.0
	mat.scale_max = 7.0
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.3, 1.0))
	grad.set_color(1, Color(1.0, 0.4, 0.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	gpu.process_material = mat
	gpu.amount = 20
	gpu.lifetime = 0.7
	gpu.one_shot = true
	gpu.explosiveness = 0.9
	parent.add_child(gpu)
	gpu.emitting = true
	get_tree().create_timer(1.2).timeout.connect(gpu.queue_free)

func _finish_rest() -> void:
	GameManager.go_to_scene("res://scenes/ui/Map.tscn")

func _start_ember_rain(vp: Vector2) -> void:
	var gpu = GPUParticles2D.new()
	gpu.position = Vector2(vp.x * 0.5, vp.y + 5.0)
	gpu.z_index = -1
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(vp.x * 0.5, 1.0, 0.0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 200.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.45, 0.1, 0.5))
	grad.set_color(1, Color(0.8, 0.2, 0.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	gpu.process_material = mat
	gpu.amount = 30
	gpu.lifetime = vp.y / 140.0
	gpu.one_shot = false
	gpu.emitting = true
	add_child(gpu)
