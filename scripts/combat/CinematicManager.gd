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

	# Revelar de arriba hacia abajo
	var reveal_tw = create_tween()
	reveal_tw.tween_property(clip_lbl, "size:y", vp.y * 0.4, 1.8)
	await reveal_tw.finished
	await main.get_tree().create_timer(2.0).timeout

	# --- EFECTO ROTOSCOPIA / GLITCH / FLASH ---
	quote_lbl.visible = false
	if main.get_node_or_null("/root/AudioManager"):
		AudioManager.play("Glith_distorsion_noised_sound") # Usar audio externo

	# Simulamos rotoscopia con destellos
	for i in range(12):
		curtain.color = [Color.WHITE, Color.BLACK, Color.YELLOW, Color.RED][randi() % 4]
		main._trigger_screen_blink()
		await main.get_tree().create_timer(0.05).timeout

	curtain.color = Color.BLACK

	# Desvanecer oscuridad con un último flash
	var tw = create_tween()
	tw.tween_property(layer, "offset:y", -vp.y, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(curtain, "modulate:a", 0.0, 1.5)

	if main.get_node_or_null("/root/AudioManager"):
		AudioManager.play("player_hit")

	await tw.finished
	layer.queue_free()


func show_avatar_bark() -> void:
	if main.enemies.is_empty() or not "AVATAR" in main.enemies[0].name.to_upper(): return
	var msg = CombatData.ENEMY_COMBAT_BANTER["Avatar de Hastur"][randi() % CombatData.ENEMY_COMBAT_BANTER["Avatar de Hastur"].size()]
	main.log_message("AVATAR", msg, Color(0.8, 0.4, 1.0))

	var bark_lbl = Label.new()
	bark_lbl.text = msg
	bark_lbl.add_theme_font_size_override("font_size", 14)
	bark_lbl.modulate = Color(0.8, 0.7, 0.9, 0.0)
	bark_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Posición sobre el avatar
	bark_lbl.position = main.enemies[0].panel.global_position + Vector2(0, -40)
	bark_lbl.size = Vector2(200, 40)
	main.add_child(bark_lbl)

	var tw = create_tween()
	tw.tween_property(bark_lbl, "modulate:a", 1.0, 0.5)
	tw.tween_property(bark_lbl, "position:y", bark_lbl.position.y - 30, 3.0)
	tw.parallel().tween_property(bark_lbl, "modulate:a", 0.0, 2.0).set_delay(1.5)
	tw.chain().tween_callback(bark_lbl.queue_free)


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

	# Lineas — sugieren sin revelar
	var lines = [
		["...", Color(0.5, 0.5, 0.5), 20, false],
		["Los fragmentos vibran.", Color(0.75, 0.68, 0.3), 22, false],
		["Algo al otro lado\nreconoce el signo.", Color(0.7, 0.6, 0.25), 22, false],
		["No es un lugar.\nEs una promesa rota.", Color(0.65, 0.55, 0.2), 20, false],
		["C̴̡A̵̢R̴C̷O̴S̸A̷", Color(0.82, 0.72, 0.05), 42, true],
		["Él recuerda tu nombre.", Color(0.45, 0.15, 0.65), 22, false],
	]

	for pair in lines:
		var full_text: String = pair[0]
		var col: Color = pair[1]
		var fsize: int = pair[2]
		var do_shake: bool = pair[3]

		var lbl = Label.new()
		lbl.text = ""
		lbl.modulate = col
		lbl.add_theme_font_size_override("font_size", fsize)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, vp.y * 0.38)
		lbl.size = Vector2(vp.x, 110)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 56
		main.add_child(lbl)

		var char_delay = 0.09 if do_shake else 0.05
		for i in range(full_text.length()):
			lbl.text = full_text.substr(0, i + 1)
			await main.get_tree().create_timer(char_delay).timeout

		if do_shake:
			# La ciudad sacude la realidad
			var base_pos = lbl.position
			for _s in range(35):
				lbl.position = base_pos + Vector2(randf_range(-7, 7), randf_range(-4, 4))
				overlay.color = Color(
					randf_range(0.0, 0.08),
					randf_range(0.0, 0.04),
					randf_range(0.0, 0.12),
					1.0
				)
				await main.get_tree().create_timer(0.04).timeout
			lbl.position = base_pos
			overlay.color = Color(0, 0, 0, 1.0)

		await main.get_tree().create_timer(1.8).timeout

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
		var lines = [
			["H̷A̵S̷T̷U̵R̷  H̷A̵  C̷A̵I̷D̵O̷", Color(0.65, 0.1, 0.95), 38, true],
			["Pero el tablero sigue moviendose.", Color(0.6, 0.5, 0.85), 24, false],
			["¿Que clase de pieza puede matar al jugador?\nUna que ya no cree en el juego.", Color(0.55, 0.45, 0.78), 22, false],
			["El silencio pesa mas que antes.\nEres libre. Quizas.", Color(0.45, 0.38, 0.65), 20, false],
		]
		for pair in lines:
			var full_text: String = pair[0]
			var col: Color = pair[1]
			var fsize: int = pair[2]
			var do_shake: bool = pair[3]
			var lbl = Label.new()
			lbl.text = ""; lbl.modulate = col
			lbl.add_theme_font_size_override("font_size", fsize)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.position = Vector2(0, vp.y * 0.37); lbl.size = Vector2(vp.x, 110)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; lbl.z_index = 52
			main.add_child(lbl)
			var char_delay = 0.07 if do_shake else 0.04
			for i in range(full_text.length()):
				lbl.text = full_text.substr(0, i + 1)
				await main.get_tree().create_timer(char_delay).timeout
			if do_shake:
				var base_pos = lbl.position
				for _s in range(28):
					lbl.position = base_pos + Vector2(randf_range(-5, 5), randf_range(-3, 3))
					await main.get_tree().create_timer(0.04).timeout
				lbl.position = base_pos
			await main.get_tree().create_timer(2.2).timeout
			var t3 = create_tween()
			t3.tween_property(lbl, "modulate:a", 0.0, 0.55)
			await t3.finished
			lbl.queue_free()

		var cont_btn = Button.new()
		cont_btn.text = "Continuar"
		cont_btn.add_theme_font_size_override("font_size", 16)
		cont_btn.modulate = Color(1, 1, 1, 0.0)
		cont_btn.position = Vector2(vp.x / 2.0 - 100, vp.y * 0.65)
		cont_btn.size = Vector2(200, 44); cont_btn.z_index = 52
		main.add_child(cont_btn)
		var t4h = create_tween()
		t4h.tween_property(cont_btn, "modulate:a", 1.0, 0.5)
		await t4h.finished
		await cont_btn.pressed
		cont_btn.queue_free()

	else:
		# === CINEMÁTICA DRAMÁTICA DEL REY AMARILLO — 5 FASES ===

		# Fase 1 — Última palabra del Rey (eco, en silencio)
		if main.get_node_or_null("/root/AudioManager"):
			AudioManager.stop_all()
		await main.get_tree().create_timer(0.6).timeout

		var echo1 = Label.new()
		echo1.text = "\"¿Crees que esto termina aqui?\""
		echo1.add_theme_font_size_override("font_size", 20)
		echo1.modulate = Color(0.55, 0.55, 0.55, 0.0)
		echo1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		echo1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		echo1.position = Vector2(0, vp.y * 0.4); echo1.size = Vector2(vp.x, 50)
		echo1.mouse_filter = Control.MOUSE_FILTER_IGNORE; echo1.z_index = 52
		main.add_child(echo1)
		var te1 = create_tween()
		te1.tween_property(echo1, "modulate:a", 0.65, 0.4)
		await te1.finished
		await main.get_tree().create_timer(1.5).timeout
		var te1o = create_tween()
		te1o.tween_property(echo1, "modulate:a", 0.0, 0.4)
		await te1o.finished
		echo1.queue_free()

		var echo2 = Label.new()
		echo2.text = "\"Siempre vuelves.\""
		echo2.add_theme_font_size_override("font_size", 20)
		echo2.modulate = Color(0.55, 0.55, 0.55, 0.0)
		echo2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		echo2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		echo2.position = Vector2(0, vp.y * 0.4); echo2.size = Vector2(vp.x, 50)
		echo2.mouse_filter = Control.MOUSE_FILTER_IGNORE; echo2.z_index = 52
		main.add_child(echo2)
		var te2 = create_tween()
		te2.tween_property(echo2, "modulate:a", 0.65, 0.4)
		await te2.finished
		await main.get_tree().create_timer(2.0).timeout
		var te2o = create_tween()
		te2o.tween_property(echo2, "modulate:a", 0.0, 0.5)
		await te2o.finished
		echo2.queue_free()

		# Fase 2 — El tablero reacciona
		# Línea 1 — título grande con shake dorado
		var lbl1 = Label.new()
		lbl1.text = ""
		lbl1.modulate = Color(0.98, 0.88, 0.05)
		lbl1.add_theme_font_size_override("font_size", 42)
		lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl1.position = Vector2(0, vp.y * 0.28); lbl1.size = Vector2(vp.x, 80)
		lbl1.mouse_filter = Control.MOUSE_FILTER_IGNORE; lbl1.z_index = 52
		main.add_child(lbl1)
		var title_text = "EL REY AMARILLO HA CAIDO"
		for i in range(title_text.length()):
			lbl1.text = title_text.substr(0, i + 1)
			await main.get_tree().create_timer(0.07).timeout
		var base_pos1 = lbl1.position
		for _s in range(28):
			lbl1.position = base_pos1 + Vector2(randf_range(-5, 5), randf_range(-3, 3))
			await main.get_tree().create_timer(0.04).timeout
		lbl1.position = base_pos1
		await main.get_tree().create_timer(1.0).timeout

		# Línea 2 — fade lento
		var lbl2 = Label.new()
		lbl2.text = "El Tablero Dorado ha perdido su guardian."
		lbl2.modulate = Color(0.82, 0.74, 0.42, 0.0)
		lbl2.add_theme_font_size_override("font_size", 18)
		lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl2.position = Vector2(0, vp.y * 0.42); lbl2.size = Vector2(vp.x, 40)
		lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE; lbl2.z_index = 52
		main.add_child(lbl2)
		var tl2 = create_tween()
		tl2.tween_property(lbl2, "modulate:a", 1.0, 1.2)
		await tl2.finished
		await main.get_tree().create_timer(1.0).timeout

		# Línea 3 — contador de runs
		var run_count = GameManager.total_runs
		var run_text: String
		if run_count >= 1:
			run_text = "Llevas " + str(run_count) + " intentos llegando aqui.\nEsta vez, no lo olvidaras."
		else:
			run_text = "Primera vez que llegas aqui.\nEl tablero lo registra."
		var lbl3 = Label.new()
		lbl3.text = run_text
		lbl3.modulate = Color(0.72, 0.65, 0.48, 0.0)
		lbl3.add_theme_font_size_override("font_size", 18)
		lbl3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl3.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl3.position = Vector2(60, vp.y * 0.52); lbl3.size = Vector2(vp.x - 120, 60)
		lbl3.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl3.mouse_filter = Control.MOUSE_FILTER_IGNORE; lbl3.z_index = 52
		main.add_child(lbl3)
		var tl3 = create_tween()
		tl3.tween_property(lbl3, "modulate:a", 1.0, 1.0)
		await tl3.finished
		await main.get_tree().create_timer(1.5).timeout

		var fade2 = create_tween().set_parallel(true)
		fade2.tween_property(lbl1, "modulate:a", 0.0, 0.5)
		fade2.tween_property(lbl2, "modulate:a", 0.0, 0.5)
		fade2.tween_property(lbl3, "modulate:a", 0.0, 0.5)
		await fade2.finished
		lbl1.queue_free(); lbl2.queue_free(); lbl3.queue_free()

		# Fase 3 — La grieta narrativa (condicional)
		var fragment_count = GameManager.secret_items.size()
		var mark = GameManager.mark_level

		if mark > 0:
			var seal1 = Label.new()
			seal1.text = "Usaste su propio sello contra el."
			seal1.modulate = Color(0.65, 0.75, 0.2, 0.0)
			seal1.add_theme_font_size_override("font_size", 18)
			seal1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			seal1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			seal1.position = Vector2(0, vp.y * 0.35); seal1.size = Vector2(vp.x, 40)
			seal1.mouse_filter = Control.MOUSE_FILTER_IGNORE; seal1.z_index = 52
			main.add_child(seal1)
			var ts1 = create_tween()
			ts1.tween_property(seal1, "modulate:a", 1.0, 0.7)
			await ts1.finished
			await main.get_tree().create_timer(1.5).timeout

			var seal2 = Label.new()
			seal2.text = "El Signo Amarillo tiene memoria."
			seal2.modulate = Color(0.55, 0.62, 0.18, 0.0)
			seal2.add_theme_font_size_override("font_size", 16)
			seal2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			seal2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			seal2.position = Vector2(0, vp.y * 0.44); seal2.size = Vector2(vp.x, 40)
			seal2.mouse_filter = Control.MOUSE_FILTER_IGNORE; seal2.z_index = 52
			main.add_child(seal2)
			var ts2 = create_tween()
			ts2.tween_property(seal2, "modulate:a", 1.0, 0.7)
			await ts2.finished
			await main.get_tree().create_timer(2.0).timeout

			var fout3 = create_tween().set_parallel(true)
			fout3.tween_property(seal1, "modulate:a", 0.0, 0.5)
			fout3.tween_property(seal2, "modulate:a", 0.0, 0.5)
			await fout3.finished
			seal1.queue_free(); seal2.queue_free()

		elif fragment_count >= 1:
			# Glitch sutil antes del texto
			if main.get_node_or_null("/root/AudioManager"):
				AudioManager.play("Glith_distorsion_noised_sound")
			for _b in range(2):
				overlay.color.a = 0.6
				await main.get_tree().create_timer(0.08).timeout
				overlay.color.a = 0.95
				await main.get_tree().create_timer(0.08).timeout

			var frag1 = Label.new()
			frag1.text = str(fragment_count) + "/3 fragmentos. El camino no esta cerrado."
			frag1.modulate = Color(0.55, 0.55, 0.5, 0.0)
			frag1.add_theme_font_size_override("font_size", 16)
			frag1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			frag1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			frag1.position = Vector2(0, vp.y * 0.38); frag1.size = Vector2(vp.x, 40)
			frag1.mouse_filter = Control.MOUSE_FILTER_IGNORE; frag1.z_index = 52
			main.add_child(frag1)
			var tf1 = create_tween()
			tf1.tween_property(frag1, "modulate:a", 1.0, 0.7)
			await tf1.finished
			await main.get_tree().create_timer(1.5).timeout

			var frag2 = Label.new()
			frag2.text = "Carcosa recuerda lo que le debes."
			frag2.modulate = Color(0.35, 0.1, 0.45, 0.0)
			frag2.add_theme_font_size_override("font_size", 16)
			frag2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			frag2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			frag2.position = Vector2(0, vp.y * 0.47); frag2.size = Vector2(vp.x, 40)
			frag2.mouse_filter = Control.MOUSE_FILTER_IGNORE; frag2.z_index = 52
			main.add_child(frag2)
			var tf2 = create_tween()
			tf2.tween_property(frag2, "modulate:a", 1.0, 0.7)
			await tf2.finished
			await main.get_tree().create_timer(2.0).timeout

			var fout4 = create_tween().set_parallel(true)
			fout4.tween_property(frag1, "modulate:a", 0.0, 0.5)
			fout4.tween_property(frag2, "modulate:a", 0.0, 0.5)
			await fout4.finished
			frag1.queue_free(); frag2.queue_free()

		else:
			var trap1 = Label.new()
			trap1.text = "¿Ganar era la trampa?\n¿O era el tablero entero?"
			trap1.modulate = Color(0.65, 0.62, 0.55, 0.0)
			trap1.add_theme_font_size_override("font_size", 20)
			trap1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			trap1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			trap1.position = Vector2(60, vp.y * 0.38); trap1.size = Vector2(vp.x - 120, 80)
			trap1.autowrap_mode = TextServer.AUTOWRAP_WORD
			trap1.mouse_filter = Control.MOUSE_FILTER_IGNORE; trap1.z_index = 52
			main.add_child(trap1)
			var tt1 = create_tween()
			tt1.tween_property(trap1, "modulate:a", 1.0, 0.7)
			await tt1.finished
			await main.get_tree().create_timer(2.5).timeout
			var tt1o = create_tween()
			tt1o.tween_property(trap1, "modulate:a", 0.0, 0.5)
			await tt1o.finished
			trap1.queue_free()

		# Fase 4 — El silencio final (permanece hasta botón)
		var silence_lbl = Label.new()
		silence_lbl.text = "El tablero sigue en silencio."
		silence_lbl.modulate = Color(0.75, 0.75, 0.78, 0.0)
		silence_lbl.add_theme_font_size_override("font_size", 18)
		silence_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		silence_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		silence_lbl.position = Vector2(0, vp.y * 0.45); silence_lbl.size = Vector2(vp.x, 50)
		silence_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; silence_lbl.z_index = 52
		main.add_child(silence_lbl)
		var tsil = create_tween()
		tsil.tween_property(silence_lbl, "modulate:a", 0.6, 1.5)
		await tsil.finished
		await main.get_tree().create_timer(2.0).timeout

		# Fase 5 — Botón "Cerrar el Tablero" con fade in más lento (0.8s)
		var cont_btn = Button.new()
		cont_btn.text = "Cerrar el Tablero"
		cont_btn.add_theme_font_size_override("font_size", 16)
		cont_btn.modulate = Color(1, 1, 1, 0.0)
		cont_btn.position = Vector2(vp.x / 2.0 - 100, vp.y * 0.65)
		cont_btn.size = Vector2(200, 44); cont_btn.z_index = 52
		main.add_child(cont_btn)
		var t4y = create_tween()
		t4y.tween_property(cont_btn, "modulate:a", 1.0, 0.8)
		await t4y.finished
		await cont_btn.pressed
		cont_btn.queue_free()
		silence_lbl.queue_free()

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

			Events.relic_was_chosen.emit(relic_id)

			dim.queue_free(); title.queue_free(); panels_root.queue_free()
			if next_scene == "__world2__":
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
	var layer = CanvasLayer.new(); layer.layer = 160; main.add_child(layer)
	var bg = ColorRect.new(); bg.color = Color(0.05, 0.04, 0.08, 0.0)
	bg.position = Vector2.ZERO; bg.size = vp
	layer.add_child(bg)

	# Fase 1: fade a oscuro
	var tw = create_tween()
	tw.tween_property(bg, "color:a", 0.92, 0.7)
	await tw.finished

	# Fase 2: peón inclina la cabeza (no cae — muestra deferencia, no derrota)
	var pawn_lbl = Label.new()
	pawn_lbl.text = "♟"
	pawn_lbl.add_theme_font_size_override("font_size", 64)
	pawn_lbl.modulate = Color(0.75, 0.7, 0.85, 0.0)
	pawn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pawn_lbl.position = Vector2(0, vp.y * 0.18); pawn_lbl.size = Vector2(vp.x, 80)
	layer.add_child(pawn_lbl)

	var tw_pawn = create_tween().set_parallel(true)
	tw_pawn.tween_property(pawn_lbl, "modulate:a", 1.0, 0.6)
	tw_pawn.tween_property(pawn_lbl, "rotation_degrees", 12.0, 1.0).set_ease(Tween.EASE_OUT)  # inclina, no cae
	await tw_pawn.finished

	# Fase 3: texto narrativo
	var lines_data = [
		["Tu paciencia es... inusual.", 0.07, false],
		["La mayoría llega aquí con espadas levantadas.", 0.07, false],
		["Tú llegaste con silencio.", 0.09, true],
	]
	if has_relic_hint:
		lines_data.append(["Escucha: el Rey siente tu miedo, no tus piezas.", 0.07, false])
		lines_data.append(["Atácalo cuando tu mente esté más rota...\nes cuando más sangra.", 0.08, true])
	else:
		lines_data.append(["Toma este eco de un juramento roto.", 0.08, false])

	for line_data in lines_data:
		var lbl = Label.new()
		lbl.text = ""; lbl.modulate = Color(0.82, 0.78, 0.92, 0.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20 if not line_data[2] else 24)
		lbl.position = Vector2(60, vp.y * 0.38); lbl.size = Vector2(vp.x - 120, 90)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		layer.add_child(lbl)
		var fad = create_tween(); fad.tween_property(lbl, "modulate:a", 1.0, 0.4)
		await fad.finished
		var full_text = line_data[0]
		for c in full_text.length():
			lbl.text = full_text.substr(0, c + 1)
			await main.get_tree().create_timer(line_data[1]).timeout
		await main.get_tree().create_timer(1.6).timeout
		var fout = create_tween(); fout.tween_property(lbl, "modulate:a", 0.0, 0.4)
		await fout.finished
		lbl.queue_free()

	# Fase 4: interstitial — carta revelada
	var card_title = Label.new()
	card_title.text = "— DON DEL PENITENTE —"
	card_title.modulate = Color(0.75, 0.65, 0.95, 0.0)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 22)
	card_title.position = Vector2(0, vp.y * 0.25); card_title.size = Vector2(vp.x, 40)
	layer.add_child(card_title)

	var card_scene = load("res://scenes/combat/Card.tscn")
	var card_node = card_scene.instantiate()
	layer.add_child(card_node)
	card_node.setup(p_card)
	card_node.position = Vector2(vp.x / 2.0 - 65, vp.y * 0.35)
	card_node.scale = Vector2(1.5, 1.5)
	card_node.modulate = Color(1, 1, 1, 0.0)
	GameManager.add_card(p_card)

	var sub = Label.new()
	sub.text = "\"Que la ceniza te proteja donde el acero no puede.\""
	sub.modulate = Color(0.6, 0.55, 0.7, 0.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.position = Vector2(60, vp.y * 0.72); sub.size = Vector2(vp.x - 120, 50)
	layer.add_child(sub)

	var cont_btn = Button.new()
	cont_btn.text = "Aceptar y continuar"
	cont_btn.position = Vector2(vp.x / 2.0 - 110, vp.y * 0.82)
	cont_btn.size = Vector2(220, 44)
	cont_btn.modulate = Color(1, 1, 1, 0.0)
	layer.add_child(cont_btn)

	var fin_tw = create_tween().set_parallel(true)
	fin_tw.tween_property(card_title, "modulate:a", 1.0, 0.8)
	fin_tw.tween_property(card_node, "modulate:a", 1.0, 0.8).set_delay(0.2)
	fin_tw.tween_property(sub, "modulate:a", 1.0, 0.8).set_delay(0.5)
	fin_tw.tween_property(cont_btn, "modulate:a", 1.0, 0.8).set_delay(0.8)
	await fin_tw.finished

	await cont_btn.pressed

	var fout2 = create_tween(); fout2.tween_property(bg, "color:a", 0.0, 0.6)
	await fout2.finished
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
	cont_btn.text = "Descender al Tablero Dorado"
	cont_btn.position = Vector2(vp.x / 2.0 - 140, vp.y * 0.78)
	cont_btn.size = Vector2(280, 44)
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

	# Efecto rotoscopia
	for i in range(4):
		if not is_instance_valid(bg): break
		bg.color = Color(0.1, 0.08, 0.0) if i % 2 == 0 else Color.BLACK
		lbl.visible = !lbl.visible
		await main.get_tree().create_timer(0.05).timeout

	lbl.visible = true
	bg.color = Color.BLACK

	# Desvanecer todo
	var out = create_tween()
	out.tween_property(root, "modulate:a", 0.0, 1.0)
	await main.get_tree().create_timer(1.2).timeout

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

	# Encontrar el panel del enemigo que está muriendo
	var e_panel = null
	for e in main.enemies:
		if e.name == enemy_name:
			e_panel = e.panel
			break
	if not e_panel: return

	var col = Color(0.95, 0.8, 0.3) if enemy_name.begins_with("EL ") else Color(0.8, 0.8, 0.8)
	var pos = e_panel.global_position + Vector2(0, -35) # Más cerca del panel

	show_floating_dialogue(text, col, pos, LoreData.is_garbled(text))


func show_floating_dialogue(text: String, col: Color, pos: Vector2, is_cipher: bool = false) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 120
	main.add_child(layer)

	var lbl = Label.new()
	lbl.text = "\"%s\"" % text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size = Vector2(300, 80)
	lbl.position = pos - Vector2(lbl.size.x/2 - 100, 0) # Ajustar centrado local
	lbl.modulate = col
	lbl.modulate.a = 0
	layer.add_child(lbl)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.4)
	tw.tween_property(lbl, "position:y", lbl.position.y - 15, 0.4)

	if is_cipher:
		for _f in range(8):
			lbl.modulate.a = randf_range(0.4, 1.0)
			await main.get_tree().create_timer(0.06).timeout
		lbl.modulate.a = 1.0

	var wait_time = clamp(text.length() * 0.05, 2.5, 5.0)
	await main.get_tree().create_timer(wait_time).timeout

	var tw2 = create_tween().set_parallel(true)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw2.tween_property(lbl, "position:y", lbl.position.y - 20, 0.8)
	await tw2.finished
	layer.queue_free()


func typewrite(lbl: Label, text: String, base_delay: float = 0.02) -> void:
	lbl.text = ""
	for i in range(text.length()):
		lbl.text = text.substr(0, i + 1)
		var c = text[i]
		var wait = base_delay
		if c in [".", "!", "?"]:  wait = base_delay * 4.0
		elif c in [",", ";"]:     wait = base_delay * 2.0
		elif c == "\n":           wait = base_delay * 3.0
		await main.get_tree().create_timer(wait).timeout
