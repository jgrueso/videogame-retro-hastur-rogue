extends Node2D

func _ready() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo abisal
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.position = Vector2.ZERO; bg.size = vp
	add_child(bg)
	
	_create_massive_black_sun(vp)
	_start_heavy_rain(vp)
	_start_lightning_system(vp)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_all()
		AudioManager.play_loop("intro_title_song")

	# Título
	var title = Label.new()
	title.text = "BLACK HOLE SONG"
	title.add_theme_font_size_override("font_size", 72)
	title.modulate = Color(0.85, 0.75, 0.1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, vp.y * 0.2)
	title.size = Vector2(vp.x, 100)
	title.z_index = 10
	add_child(title)
	
	var shadow = title.duplicate()
	shadow.modulate = Color(0.4, 0.1, 0.1, 0.3)
	shadow.position += Vector2(4, 4)
	add_child(shadow)
	
	_animate_hastur_glitch(title, shadow, vp)

	var sub = Label.new()
	sub.text = "Escucha el silencio que devora los mundos."
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.6, 0.6, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, vp.y * 0.35)
	sub.size = Vector2(vp.x, 30)
	sub.z_index = 10
	add_child(sub)

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
		btn_continue.modulate = Color(0.4, 0.8, 1.0)

	btn_container.add_child(btn_continue)
	btn_container.add_child(btn_start)
	btn_container.add_child(btn_exit)

	# Botón borrar: esquina inferior izquierda, casi invisible
	var btn_delete = Button.new()
	btn_delete.text = "borrar progreso"
	btn_delete.size = Vector2(160, 30)
	btn_delete.position = Vector2(20, vp.y - 48)
	btn_delete.add_theme_font_size_override("font_size", 12)
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
		get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")
	)

	btn_continue.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
			AudioManager.stop_loop("intro_title_song")
		if GameManager.load_run():
			get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)

	btn_delete.pressed.connect(func():
		if get_node_or_null("/root/AudioManager"): AudioManager.play("button_click")
		_show_delete_menu(vp, btn_container)
	)

	btn_exit.pressed.connect(func(): get_tree().quit())

func _create_massive_black_sun(vp: Vector2):
	var sun_pos = Vector2(vp.x/2, vp.y * 0.2 + 20)
	var sun_radius = 500.0
	
	var aura_node = Panel.new()
	aura_node.size = Vector2(sun_radius + 40, sun_radius + 40)
	aura_node.position = sun_pos - aura_node.size/2
	var style_aura = StyleBoxFlat.new()
	style_aura.bg_color = Color(0, 0, 0, 0)
	style_aura.set_corner_radius_all(aura_node.size.x / 2)
	style_aura.border_width_left = 12
	style_aura.border_color = Color(0.95, 0.7, 0.1, 0.6)
	style_aura.shadow_size = 60
	aura_node.add_theme_stylebox_override("panel", style_aura)
	aura_node.z_index = 1
	add_child(aura_node)
	create_tween().set_loops().tween_property(aura_node, "scale", Vector2(1.1, 1.1), 3.0).set_trans(Tween.TRANS_SINE)
	
	var sun_node = Panel.new()
	sun_node.size = Vector2(sun_radius, sun_radius)
	sun_node.position = sun_pos - sun_node.size/2
	var style_sun = StyleBoxFlat.new()
	style_sun.bg_color = Color(0, 0, 0)
	style_sun.set_corner_radius_all(sun_radius / 2)
	sun_node.add_theme_stylebox_override("panel", style_sun)
	sun_node.z_index = 2
	add_child(sun_node)

func _start_heavy_rain(vp: Vector2):
	for i in range(100):
		var drop = ColorRect.new()
		drop.size = Vector2(2, randi_range(15, 40)); drop.color = Color(0.7, 0.7, 0.9, 0.3)
		drop.position = Vector2(randf_range(-200, vp.x), randf_range(-vp.y, 0)); drop.z_index = 4
		add_child(drop)
		var dur = randf_range(0.4, 0.6)
		create_tween().set_loops().tween_property(drop, "position", drop.position + Vector2(200, vp.y + 200), dur).from(drop.position)

func _start_lightning_system(vp: Vector2):
	var timer = get_tree().create_timer(randf_range(4.0, 12.0))
	timer.timeout.connect(func():
		_trigger_lightning(vp)
		_start_lightning_system(vp)
	)

func _trigger_lightning(vp: Vector2):
	var bolt = Line2D.new()
	bolt.width = 3.0; bolt.default_color = Color(1, 1, 1, 0.8); bolt.z_index = 20
	add_child(bolt)
	var current_pos = Vector2(randf_range(100, vp.x - 100), 0)
	bolt.add_point(current_pos)
	for i in range(6):
		current_pos += Vector2(randf_range(-60, 60), randf_range(80, 120)); bolt.add_point(current_pos)
	var flash = ColorRect.new(); flash.size = vp; flash.color = Color(1, 1, 1, 0.4); flash.z_index = 21; flash.visible = false
	add_child(flash)
	var tw = create_tween(); tw.tween_interval(0.1); tw.tween_callback(func(): flash.visible = true)
	if get_node_or_null("/root/AudioManager"): AudioManager.play("thunder")
	tw.tween_property(flash, "color:a", 0.0, 0.1); tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.tween_callback(bolt.queue_free); tw.tween_callback(flash.queue_free)

func _make_menu_button(txt: String) -> Button:
	var btn = Button.new(); btn.text = txt; btn.custom_minimum_size = Vector2(0, 55); btn.add_theme_font_size_override("font_size", 22)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.02, 0.02, 0.03, 0.9); style.border_width_bottom = 3; style.border_color = Color(0.4, 0.4, 0.4); style.set_corner_radius_all(4)
	var hover = style.duplicate(); hover.bg_color = Color(0.15, 0.12, 0.05); hover.border_color = Color(0.85, 0.75, 0.1)
	btn.add_theme_stylebox_override("normal", style); btn.add_theme_stylebox_override("hover", hover)
	btn.mouse_entered.connect(func(): if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_hover"))
	return btn

func _animate_hastur_glitch(t: Label, s: Label, vp: Vector2):
	var tw = create_tween().set_loops(); tw.tween_interval(randf_range(5.0, 12.0))
	tw.tween_callback(func():
		var roll = randf()
		if roll < 0.2: t.text = "BLACK HOLE"; t.modulate = Color(0, 0, 0); s.modulate = Color(1, 0.8, 0.2, 1.0)
		elif roll < 0.4: t.text = "H A S T U R"; t.modulate = Color(0.8, 0.1, 0.1)
		t.position += Vector2(randf_range(-20, 20), randf_range(-10, 10))
		await get_tree().create_timer(0.2).timeout
		t.text = "BLACK HOLE SONG"; t.modulate = Color(0.85, 0.75, 0.1); s.modulate = Color(0.4, 0.1, 0.1, 0.3); t.position = Vector2(0, vp.y * 0.2)
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
