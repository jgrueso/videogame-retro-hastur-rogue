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
	_play_ambient_hum()

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

	var btn_start = _make_menu_button("ACEPTAR EL LLAMADO")
	var btn_exit = _make_menu_button("NEGARSE AL JUEGO")

	btn_container.add_child(btn_start)
	btn_container.add_child(btn_exit)

	btn_start.pressed.connect(func(): 
		if get_node_or_null("/root/AudioManager"): AudioManager.play("button_click")
		get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")
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
