extends Node2D

var _font_title:     FontFile
var _font_narrative: FontFile
var _font_ui:        FontFile
var _font_corrupt:   FontFile

func _ready() -> void:
	_font_title     = load("res://assets/fonts/CinzelDecorative-Bold.otf")
	_font_narrative = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	_font_ui        = load("res://assets/fonts/rajdhani.medium.ttf")
	_font_corrupt   = load("res://assets/fonts/RubikGlitch-Regular.ttf")

	var vp = get_viewport_rect().size

	# Fondo imagen rey oscuro
	var bg_tex = TextureRect.new()
	bg_tex.texture = load("res://assets/bg_mainmenu.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.size = vp
	bg_tex.position = Vector2.ZERO
	bg_tex.z_index = -10
	add_child(bg_tex)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = vp
	dim.z_index = -9
	add_child(dim)

	_start_rain(vp)
	_start_embers(vp)
	_start_golden_sparks(vp)
	_start_fog(vp)

	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_all()
		AudioManager.play_loop("intro_title_song")

	# Título
	var title = Label.new()
	title.text = "BLACK HOLE SONG"
	title.add_theme_font_size_override("font_size", 72)
	if _font_title: title.add_theme_font_override("font", _font_title)
	title.modulate = Color(0.85, 0.75, 0.1, 0.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, vp.y * 0.2 - 40.0)
	title.size = Vector2(vp.x, 100)
	title.z_index = 10
	add_child(title)

	var shadow = title.duplicate()
	shadow.modulate = Color(0.4, 0.1, 0.1, 0.0)
	shadow.position += Vector2(4, 4)
	add_child(shadow)

	# Animación de entrada del título
	var tw_in = create_tween().set_parallel(true)
	tw_in.tween_property(title, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tw_in.tween_property(title, "position:y", vp.y * 0.2, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.2)
	tw_in.tween_property(shadow, "modulate:a", 0.3, 0.6).set_delay(0.2)
	tw_in.tween_property(shadow, "position:y", vp.y * 0.2 + 4.0, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.2)

	_animate_hastur_glitch(title, shadow, vp)

	var sub = Label.new()
	sub.text = "Escucha el silencio que devora los mundos."
	sub.add_theme_font_size_override("font_size", 18)
	if _font_narrative: sub.add_theme_font_override("font", _font_narrative)
	sub.modulate = Color(0.6, 0.6, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, vp.y * 0.35)
	sub.size = Vector2(vp.x, 30)
	sub.z_index = 10
	add_child(sub)

	# Typewriter subtítulo
	sub.visible_characters = 0
	create_tween().tween_method(
		func(n: int): sub.visible_characters = n,
		0, sub.text.length(), 1.5
	).set_delay(0.9)

	var btn_container = VBoxContainer.new()
	btn_container.position = Vector2(vp.x * 0.35, vp.y * 0.6)
	btn_container.size = Vector2(vp.x * 0.3, 200)
	btn_container.add_theme_constant_override("separation", 20)
	btn_container.z_index = 15
	add_child(btn_container)

	var btn_start = _make_menu_button("NUEVA PARTIDA")
	var btn_continue = _make_menu_button("CONTINUAR EL LLAMADO")
	var btn_exit = _make_menu_button("NEGARSE AL JUEGO")

	# Solo mostrar Continuar si hay archivo
	if not FileAccess.file_exists(GameManager.RUN_SAVE_PATH):
		btn_continue.visible = false
	else:
		btn_continue.modulate = Color(0.4, 0.8, 1.0, 0.0)

	btn_container.add_child(btn_continue)
	btn_container.add_child(btn_start)
	btn_container.add_child(btn_exit)

	# Entrada en cascada de los botones
	for i in range(btn_container.get_child_count()):
		var b = btn_container.get_child(i)
		if b.visible:
			b.modulate.a = 0.0
			create_tween().tween_property(b, "modulate:a", 1.0, 0.3).set_delay(1.1 + i * 0.12)

	# Botón borrar: esquina inferior izquierda, casi invisible
	var btn_delete = Button.new()
	btn_delete.text = "borrar progreso"
	btn_delete.size = Vector2(160, 30)
	btn_delete.position = Vector2(20, vp.y - 48)
	btn_delete.add_theme_font_size_override("font_size", 12)
	if _font_ui: btn_delete.add_theme_font_override("font", _font_ui)
	btn_delete.z_index = 15
	var s_del = StyleBoxFlat.new()
	s_del.bg_color = Color(0, 0, 0, 0)
	s_del.set_border_width_all(0)
	var s_del_h = StyleBoxFlat.new()
	s_del_h.bg_color = Color(0.1, 0.02, 0.02, 0.6)
	s_del_h.border_width_bottom = 1
	s_del_h.border_color = Color(0.5, 0.1, 0.1)
	s_del_h.set_corner_radius_all(3)
	btn_delete.add_theme_stylebox_override("normal", s_del)
	btn_delete.add_theme_stylebox_override("hover", s_del_h)
	btn_delete.modulate = Color(0.5, 0.2, 0.2, 0.45)
	add_child(btn_delete)

	btn_start.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
			AudioManager.stop_loop("intro_title_song")
		GameManager.delete_run_save()
		GameManager.go_to_scene("res://scenes/ui/CharacterSelect.tscn")
	)

	btn_continue.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
			AudioManager.stop_loop("intro_title_song")
		if GameManager.load_run():
			GameManager.go_to_scene("res://scenes/ui/Map.tscn")
	)

	btn_delete.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"): AudioManager.play("button_click")
		_show_delete_menu(vp, btn_container)
	)

	btn_exit.pressed.connect(func(): get_tree().quit())

func _start_golden_sparks(vp: Vector2) -> void:
	var gp = GPUParticles2D.new()
	gp.position = Vector2(vp.x / 2, vp.y * 0.28)
	gp.amount = 28
	gp.lifetime = 3.5
	gp.z_index = 12

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(vp.x * 0.35, 40, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 45.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.5

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.85, 0.1, 0.0))
	gradient.add_point(0.25, Color(1.0, 0.85, 0.1, 0.9))
	gradient.add_point(0.8, Color(0.95, 0.6, 0.05, 0.5))
	gradient.add_point(1.0, Color(0.8, 0.4, 0.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	gp.process_material = mat
	gp.emitting = true
	add_child(gp)

func _start_fog(vp: Vector2) -> void:
	# Paleta de colores: violeta élfico y verde muerte
	var palettes: Array[Color] = [
		Color(0.28, 0.05, 0.40, 0.22),
		Color(0.06, 0.28, 0.10, 0.18),
		Color(0.22, 0.04, 0.32, 0.20),
		Color(0.08, 0.22, 0.08, 0.16),
		Color(0.32, 0.08, 0.45, 0.19),
		Color(0.05, 0.18, 0.07, 0.15),
	]
	for i in range(8):
		var col: Color = palettes[i % palettes.size()]

		# GradientTexture2D radial: centro tintado → bordes completamente transparentes
		var grad := Gradient.new()
		grad.set_color(0, Color(col.r, col.g, col.b, col.a))
		grad.set_color(1, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.0))

		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 128

		var fog := TextureRect.new()
		fog.texture = gt
		fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fog.stretch_mode = TextureRect.STRETCH_SCALE
		fog.size = Vector2(randf_range(260.0, 480.0), randf_range(70.0, 140.0))
		fog.position = Vector2(
			randf_range(-80.0, vp.x - fog.size.x * 0.4),
			randf_range(vp.y * 0.66, vp.y * 0.93)
		)
		fog.z_index = 8
		add_child(fog)

		var start_x := fog.position.x
		var drift := randf_range(55.0, 120.0) * (1.0 if randf() > 0.5 else -1.0)
		var dur := randf_range(10.0, 20.0)
		var tw := create_tween().set_loops()
		tw.tween_property(fog, "position:x", start_x + drift, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fog, "position:x", start_x, dur).set_trans(Tween.TRANS_SINE)

func _start_embers(vp: Vector2):
	for i in range(18):
		var e = ColorRect.new()
		e.size = Vector2(2, 2)
		e.color = Color(0.9, 0.55 + randf() * 0.3, 0.1, randf_range(0.4, 0.8))
		e.position = Vector2(randf_range(vp.x * 0.3, vp.x * 0.7), randf_range(vp.y * 0.25, vp.y * 0.55))
		e.z_index = 6
		add_child(e)
		var dur = randf_range(4.0, 8.0)
		var tw = create_tween().set_loops()
		tw.tween_property(e, "position",
			e.position + Vector2(randf_range(-40, 40), -randf_range(150, 350)), dur)
		tw.tween_property(e, "modulate:a", 0.0, 0.8)
		tw.tween_callback(func():
			e.position = Vector2(randf_range(vp.x * 0.3, vp.x * 0.7), randf_range(vp.y * 0.3, vp.y * 0.6))
			e.modulate.a = randf_range(0.4, 0.8)
		)

func _start_rain(vp: Vector2) -> void:
	# Tres capas de lluvia diagonal para dar profundidad
	_spawn_rain_layer(vp, 38, Color(0.55, 0.65, 0.80, 0.10), 0.65, 0.90, 3, Vector2(170, vp.y + 200))
	_spawn_rain_layer(vp, 48, Color(0.65, 0.72, 0.88, 0.16), 0.42, 0.60, 4, Vector2(190, vp.y + 200))
	_spawn_rain_layer(vp, 22, Color(0.78, 0.82, 0.95, 0.22), 0.28, 0.40, 5, Vector2(210, vp.y + 200))

func _spawn_rain_layer(vp: Vector2, count: int, col: Color, dur_min: float, dur_max: float, zi: int, travel: Vector2) -> void:
	for i in range(count):
		var drop := ColorRect.new()
		drop.size = Vector2(1, randi_range(18, 48))
		drop.color = col
		drop.rotation = deg_to_rad(12)
		drop.position = Vector2(randf_range(-200, vp.x), randf_range(-vp.y, 0))
		drop.z_index = zi
		add_child(drop)
		create_tween().set_loops().tween_property(
			drop, "position", drop.position + travel,
			randf_range(dur_min, dur_max)
		).from(drop.position)

func _make_menu_button(txt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 55)
	btn.add_theme_font_size_override("font_size", 22)
	if _font_ui: btn.add_theme_font_override("font", _font_ui)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.03, 0.9)
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_corner_radius_all(4)
	var hover = style.duplicate()
	hover.bg_color = Color(0.15, 0.12, 0.05)
	hover.border_color = Color(0.85, 0.75, 0.1)
	var pressed = style.duplicate()
	pressed.bg_color = Color(0.08, 0.07, 0.02, 0.95)
	pressed.border_color = Color(0.95, 0.85, 0.15)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pivot_offset = Vector2(150, 27)
	btn.mouse_entered.connect(func():
		create_tween().tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1)
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_hover")
	)
	btn.mouse_exited.connect(func():
		create_tween().tween_property(btn, "scale", Vector2.ONE, 0.1)
	)
	return btn

func _animate_hastur_glitch(t: Label, s: Label, vp: Vector2):
	var tw = create_tween(); tw.tween_interval(randf_range(5.0, 12.0))
	tw.tween_callback(func():
		var roll = randf()
		if roll < 0.2:
			t.text = "BLACK HOLE"
			t.modulate = Color(0, 0, 0)
			s.modulate = Color(1, 0.8, 0.2, 1.0)
			if _font_corrupt: t.add_theme_font_override("font", _font_corrupt)
		elif roll < 0.4:
			t.text = "H A S T U R"
			t.modulate = Color(0.8, 0.1, 0.1)
			if _font_corrupt: t.add_theme_font_override("font", _font_corrupt)
		t.position += Vector2(randf_range(-20, 20), randf_range(-10, 10))
		await get_tree().create_timer(0.2).timeout
		t.text = "BLACK HOLE SONG"
		t.modulate = Color(0.85, 0.75, 0.1)
		s.modulate = Color(0.4, 0.1, 0.1, 0.3)
		t.position = Vector2(0, vp.y * 0.2)
		if _font_title: t.add_theme_font_override("font", _font_title)
	)

func _play_ambient_hum():
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("ambient_hum")
		get_tree().create_timer(2.0).timeout.connect(_play_ambient_hum)

func _show_delete_menu(vp: Vector2, btn_container: Node) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = vp
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.82, 0.25)

	var panel = Panel.new()
	panel.size = Vector2(460, 300)
	panel.position = (vp - panel.size) / 2
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.02, 0.02)
	s.set_border_width_all(2)
	s.border_color = Color(0.6, 0.15, 0.15)
	s.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", s)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "¿QUÉ DESEAS BORRAR?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	if _font_title: title.add_theme_font_override("font", _font_title)
	title.modulate = Color(0.9, 0.4, 0.4)
	title.position = Vector2(0, 30)
	title.size = Vector2(460, 36)
	panel.add_child(title)

	var desc = Label.new()
	desc.text = "Esta acción no se puede deshacer."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.modulate = Color(0.55, 0.45, 0.45)
	desc.position = Vector2(0, 72)
	desc.size = Vector2(460, 24)
	panel.add_child(desc)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(60, 112)
	vbox.size = Vector2(340, 170)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var btn_run = _make_delete_button("BORRAR PARTIDA ACTUAL", Color(0.9, 0.6, 0.3))
	var btn_all = _make_delete_button("BORRAR TODO EL PROGRESO", Color(0.9, 0.25, 0.25))
	var btn_cancel = _make_menu_button("CANCELAR")

	vbox.add_child(btn_run)
	vbox.add_child(btn_all)
	vbox.add_child(btn_cancel)

	btn_run.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
		GameManager.delete_run_save()
		overlay.queue_free()
		get_tree().reload_current_scene()
	)

	btn_all.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
		GameManager.reset_all_progress()
		overlay.queue_free()
		get_tree().reload_current_scene()
	)

	btn_cancel.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"): AudioManager.play("button_click")
		create_tween().tween_property(overlay, "modulate:a", 0.0, 0.2).finished.connect(overlay.queue_free)
	)

func _make_delete_button(txt: String, col: Color) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 17)
	if _font_ui: btn.add_theme_font_override("font", _font_ui)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.02, 0.02, 0.9)
	s.border_width_bottom = 2
	s.border_color = col.darkened(0.3)
	s.set_corner_radius_all(4)
	var h = s.duplicate()
	h.bg_color = Color(0.18, 0.05, 0.05)
	h.border_color = col
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.modulate = col
	btn.mouse_entered.connect(func(): if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_hover"))
	return btn
