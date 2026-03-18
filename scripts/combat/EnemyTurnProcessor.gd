extends Node

var main: Node

func setup(m) -> void:
	main = m

const ENEMY_COMBAT_BANTER = {
	"Siervo Rebelde":   ["...muere...", "no... escapes...", "el tablero... te reclama..."],
	"Peon Maldito":     ["maldito seas...", "nadie sale...", "somos todos lo mismo..."],
	"Alfil Caido":      ["hereje...", "tu fe es falsa...", "el Rey te vera caer..."],
	"Espectro":         ["sientes... el frio...", "ya... eres... uno de nosotros..."],
	"Torre Rota":       ["resistire... siglos...", "soy... lo que queda..."],
	"Caballero Roto":   ["falle... una vez... no... dos..."],
	"Inquisidor Ciego": ["la verdad... duele...", "no... puedes... saberlo..."],
	"EL CARCELERO":     ["NADIE ESCAPA DEL TABLERO.", "ERES UNA PIEZA. NADA MAS.", "EL REY... TE ESPERA."],
	"EL REY SIN CORONA":["campeon... mio...", "el tablero... te reclama...", "esto es... necesario..."],
	"EL REY AMARILLO":  ["JUEGA BIEN.", "SIEMPRE VUELVES.", "SOY EL TABLERO. SOY EL JUEGO."],
	"El Penitente": [
		"Escucha. Solo escucha un momento.",
		"No eres el heroe. Nunca lo fuiste.",
		"El tablero nos mueve a los dos.",
		"Ya estuviste aqui. No lo recuerdas, pero yo si.",
	],
}

func process_enemy_turn() -> void:
	main.is_player_turn = false; main.end_turn_btn.disabled = true
	main.first_card_this_turn = true
	main.update_card_states()
	await main.get_tree().create_timer(0.4).timeout

	for e in main.enemies:
		if e.hp <= 0: continue

		# Bleed (Mirada que Devora)
		if e.get("bleed", 0) > 0:
			var bleed_dmg = e["bleed"]
			e.hp -= bleed_dmg
			e["bleed"] = max(0, e["bleed"] - 1)
			main._spawn_damage_number(e.panel.global_position + Vector2(100, 60), bleed_dmg, Color(0.8, 0.1, 0.3))
			if e.get("sprite_label"): e.sprite_label.play_hit()
			main.log_message(e.name, "Sangra por %d de daño" % bleed_dmg, Color(0.8, 0.1, 0.3))
			main.update_ui()
			if e.hp <= 0:
				await main._kill_enemy(e)
				continue

		# Probabilidad de soltar un diálogo de lore (bark) al iniciar turno
		if "AVATAR" in e.name.to_upper() and randf() < 0.4:
			main.cinematics.show_avatar_bark()

		# RESUMEN: Escudo enemigo se resetea al inicio de su turno
		e.shield = 0
		main.update_ui()

		# El Penitente en modo pacífico: contar turnos
		if e.peaceful:
			e.peaceful_turns -= 1

			if e.penitente_mode == "silence":
				# Efecto Silencio: Glitch y oscuridad
				main._trigger_screen_blink()
				if is_instance_valid(main.eye_node):
					var tw_eye = create_tween()
					tw_eye.tween_property(main.eye_node, "modulate", Color(0.2, 0.2, 0.3, 0.9), 0.2)
					tw_eye.tween_property(main.eye_node, "modulate", Color(1, 1, 1, 1), 0.2)
				if main.get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
			else:
				# Efecto Misericordia: Luz y particulas
				var tw_glow = create_tween()
				tw_glow.tween_property(e.panel, "modulate", Color(1.5, 1.5, 2.0), 0.2)
				tw_glow.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.4)
				main._spawn_death_particles(e.panel.global_position + Vector2(100, 100)) # Reutilizo particulas con otro color si pudiera, pero esto ya es visual

			if e.peaceful_turns <= 0:
				await main._penitente_reward()
				return
			main.update_intent_labels()
			continue

		# MECÁNICA: Aturdimiento
		if e.get("is_stunned", false):
			e["is_stunned"] = false
			main.flash_small(e.name + ": ¡ATURDIDO!")
			show_enemy_banter(e.panel, "...", Color(0.5, 0.5, 0.5))
			await main.get_tree().create_timer(0.5).timeout
			continue

		# Enemigo agresivo: ejecutar acción
		var action = e.pattern[e.turn_index % e.pattern.size()]
		e.turn_index += 1

		if action.type == "attack":
			main.enemy_attacked_last_turn = true
			var banter = get_enemy_banter(e.name)
			if not banter.is_empty():
				show_enemy_banter(e.panel, banter, get_banter_color(e.name, banter))

			# Ejecutar animacion de ataque segun el enemigo
			await animate_enemy_attack_unique(e)

			var base_dmg = action.value
			var mark_bonus = 0
			if GameManager.mark_level > 0 and base_dmg > 0:
				mark_bonus = int(base_dmg * (0.25 * GameManager.mark_level))
				if mark_bonus < 1: mark_bonus = 1
				main.log_message("SIGNO AMARILLO", "La marca intensifica el dolor (+%d)" % mark_bonus, Color(1.0, 0.9, 0.2))

			var dmg = max(0, (base_dmg + mark_bonus) - e.get("atk_reduction", 0))
			var absorbed = min(main.player_shield, dmg)

			if absorbed > 0:
				main.player_shield -= absorbed; dmg -= absorbed
				if main.get_node_or_null("/root/AudioManager"): AudioManager.play("shield_block")
				main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), absorbed, Color(0.4, 0.7, 1.0))
				main.update_ui() # Actualizar escudo en tiempo real

			# Mostrar siempre el daño o el fallo si es un ataque
			if dmg > 0:
				main.player_hp -= dmg
				main.update_ui() # Actualizar HP en tiempo real
				main.log_message(e.name, "Te inflige %d de daño" % dmg, Color(1.0, 0.3, 0.3))
				main._animate_player_hit()
				main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), dmg, Color(1, 0.3, 0.3))
				if main.get_node_or_null("/root/AudioManager"): AudioManager.play("player_hit")

				# Sinergia Reliquia: Ojo Arrancado — contraataque 2 de daño
				if GameManager.has_relic("ojo_arrancado"):
					e.hp -= 2
					main._spawn_damage_number(e.panel.global_position + Vector2(100, 60), 2, Color(0.9, 0.55, 0.1))
					main._flash_relic("ojo_arrancado")
					if e.hp <= 0: await main._kill_enemy(e)

				# Pasiva Guardian: Furia (Acumulativa: 1 por cada 5 de daño total recibido)
				if GameManager.selected_character == "guardian":
					main.damage_received_pool += dmg
					while main.damage_received_pool >= 5:
						main.damage_received_pool -= 5
						main.furia_points = min(3, main.furia_points + 1)
						main.flash_small("¡RESILIENCIA! Furia acumulada: " + str(main.furia_points) + "/3")
					main.update_ui()

				# --- EFECTO CORONA DE ESPINAS ---
				if GameManager.has_relic("corona_espinas"):
					var thorns_dmg = int(dmg * 0.2) # 20% base
					if thorns_dmg > 0:
						if GameManager.sanity < 50:
							thorns_dmg = int(thorns_dmg * 1.5) # +50% en locura (antes era x2)
							main.flash_small("¡ESPINAS DE CARCOSA! (+50%)")
						else:
							main.flash_small("Espinas: Contraataque.")

						thorns_dmg = clamp(thorns_dmg, 1, 12) # Tope máximo de 12 por golpe
						main._flash_relic("corona_espinas")
						for e_thorns in main.enemies:
							if e_thorns.hp > 0:
								e_thorns.hp -= thorns_dmg
								main._spawn_damage_number(e_thorns.panel.global_position + Vector2(100, 60), thorns_dmg, Color(0.8, 0.1, 0.1))
								main._animate_enemy_hit(e_thorns)
						main.check_combat_end()

			else:
				# Es un FALLO (daño 0)
				main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), 0, Color(1, 0.3, 0.3))
		elif action.type == "shield":
			e.shield += action.value
		elif action.type == "insanity":
			GameManager.sanity = max(0, GameManager.sanity - action.value)
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), action.value, Color(0.7, 0.3, 1.0))
			main.flash_small(e.name + ": Ataca tu cordura! (-" + str(action.value) + ")")
			main.update_ui()
			if GameManager.selected_character == "prince":
				var shield_gain = int(action.value * 0.4)
				if shield_gain > 0:
					main.player_shield += shield_gain
					main.flash_small("Absorcion Abisal: +" + str(shield_gain) + " Escudo")

		# --- NUEVAS MECÁNICAS DE HASTUR ---
		elif action.type == "possession":
			var cards = main.hand_container.get_children()
			if not cards.is_empty():
				var target_card = cards[randi() % cards.size()]
				main.flash_small("¡HASTUR TOMA EL CONTROL!")
				main.flash_small("Usas " + target_card.card_name + " contra ti mismo.")

				# Aplicar daño al jugador basado en el ataque de la carta
				var self_dmg = target_card.attack

				main.player_hp -= self_dmg
				main.update_ui()
				main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), self_dmg, Color(1, 0.2, 0.2))
				main._animate_player_hit()

				# Animación de la carta volando hacia el jugador
				await target_card.play_attack_animation(main.player_panel.global_position + Vector2(200, 30))
				target_card.queue_free()
				main.reorganize_hand()

				main.flash_small("Tu turno ha sido arrebatado.")
				# Forzar fin de turno (pero como ya estamos en turno enemigo, esto solo salta las acciones restantes si las hubiera)
				break

		elif action.type == "ultimate_charge":
			main.flash_small("¡EL CIELO SE RASGA! Hastur prepara su juicio...")
			main._trigger_screen_blink()
			if main.get_node_or_null("/root/AudioManager"): AudioManager.play("agony_shriek")

		elif action.type == "ultimate_attack":
			main.flash_small("¡EL JUICIO DE CARCOSA!")
			main.player_hp -= action.value
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), action.value, Color(1, 0, 0))
			main._trigger_screen_blink()
			main._animate_player_hit()

		elif action.type == "anular_energia":
			main.flash_small("¡SILENCIO ETERNO! No podrás actuar el próximo turno.")
			main.player_energy = 0 # El jugador empezará con 0
			main._trigger_screen_blink()
			if main.get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")

		elif action.type == "curse_hand":
			var cards = main.hand_container.get_children()
			if not cards.is_empty():
				main.flash_small("¡CORRUPCIÓN! Tus piezas cambian de forma.")
				var target_card = cards[randi() % cards.size()]
				target_card.setup({"name": "Maldición de Ceniza", "attack": 0, "defense": 0, "cost": 1, "curse": true})
				target_card.modulate = Color(0.4, 0.1, 0.5)
				if main.get_node_or_null("/root/AudioManager"): AudioManager.play("curse_card")

		await main.get_tree().create_timer(0.35).timeout

	# ── FIN DEL TURNO ENEMIGO ──
	# Drenaje de cordura por turno si el Avatar o Hastur están presentes
	if not main.enemies.is_empty():
		var e0 = main.enemies[0]
		if "HASTUR" in e0.name.to_upper():
			GameManager.sanity = max(0, GameManager.sanity - 10) # Hastur drena más
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), 10, Color(0.7, 0.3, 1.0))
			main.flash_small("LA CANCIÓN DE CARCOSA TE PERSIGUE (-10)")
			main.update_ui()
		elif "AVATAR" in e0.name.to_upper():
			GameManager.sanity = max(0, GameManager.sanity - 5)
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), 5, Color(0.7, 0.3, 1.0))
			main.flash_small("LA PRESENCIA DEL AVATAR TE CORROMPE (-5)")

			# --- REFLEJO DE LA LOCURA ---
			if GameManager.sanity < 20:
				var cards_in_hand = main.hand_container.get_children()
				if not cards_in_hand.is_empty():
					var target_card = cards_in_hand[randi() % cards_in_hand.size()]
					main.flash_small("¡REFLEJO DE LA LOCURA! Una pieza ha sido corrompida.")
					target_card.setup({"name": "Maldición de Ceniza", "attack": 0, "defense": 0, "cost": 1, "curse": true})
					target_card.modulate = Color(0.4, 0.1, 0.5) # Color corrupto
					if main.get_node_or_null("/root/AudioManager"):
						AudioManager.play("Cry_whisper_woman_sound")

			main.update_ui()

	# Limpiar debuffs de TODOS los enemigos antes de que empiece el turno del jugador
	for e_final in main.enemies:
		e_final["atk_reduction"] = 0

	# Reset de energía (Basado en el nuevo máximo sincronizado)
	main.player_energy = main.player_max_energy

	# Sinergia Reliquia: Ficha de Marfil — drena 1 HP por turno
	if GameManager.has_relic("ficha_marfil"):
		main.player_hp -= 1
		main.flash_small("Ficha de Marfil: -1 HP", Color(0.9, 0.5, 0.2))
		main._flash_relic("ficha_marfil")

	main.player_shield = 0

	# Sinergia Reliquia: Velo de la Dama (Negar la muerte una vez por RUN)
	if main.player_hp <= 0 and GameManager.has_relic("velo_dama") and not GameManager.velo_broken:
		main.player_hp = int(main.player_max_hp * 0.25) # Recupera 25% HP
		GameManager.velo_broken = true
		main.flash_small("¡EL VELO SE RASGA! La muerte ha sido negada.")
		main.log_message("VELO", "Venganza de la Dama activa: +2 ATK permanente.", Color(1, 0.2, 0.2))
		main._flash_relic("velo_dama")
		if main.relics_container:
			for icon in main.relics_container.get_children():
				if icon.get("relic_id") == "velo_dama":
					icon.mark_broken()
					break
		main._trigger_screen_blink()
		if main.get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")

	if main.player_hp <= 0:
		main._check_player_death()
		return

	GameManager.player_hp = main.player_hp
	main.cards_played_this_turn = 0

	# Incrementar turno para el jugador
	main.turn_counter += 1

	main.update_ui(); main.update_intent_labels()
	await main.draw_hand()

	if main.trono_carcosa_active:
		var bonus = main.hand.size()
		if bonus > 0:
			main.player_shield += bonus
			main.flash_small("Trono de Carcosa: +" + str(bonus) + " Escudo")

	main.is_player_turn = true; main.end_turn_btn.disabled = false
	main.update_card_states()


func set_enemy_aggressive(e: Dictionary) -> void:
	if e.get("sprite_label") and e.sprite_label.has_method("set_aggressive"):
		e.sprite_label.set_aggressive(true)
	if e.name == "El Penitente" and main.get_node_or_null("/root/AudioManager"):
		# No detener el loop, sino distorsionarlo para que suene monstruoso
		AudioManager.update_loop_params("Cry_whisper_woman_sound", -2.0, 0.45) # Más fuerte y MUCHO más grave
		AudioManager.play_loop("Glith_distorsion_noised_sound") # Añadir estática abisal
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", -8.0, 0.7)

	# Cambiar panel a rojo
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.05, 0.05)
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.border_color = Color(0.6, 0.2, 0.2)
	e.panel.add_theme_stylebox_override("panel", s)
	if e.lbl_name: e.lbl_name.modulate = Color.WHITE
	# Flash rojo corregido (sin chain)
	var tw = create_tween()
	tw.tween_property(e.panel, "modulate", Color(1.5, 0.3, 0.3), 0.1)
	tw.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.3)


func trigger_boss_phase_2(e: Dictionary) -> void:
	e.in_phase_2 = true
	var heal = int(e.max_hp * 0.25)
	e.hp = min(e.hp + heal, e.max_hp)

	# Potenciar patron
	for action in e.pattern:
		action["value"] = int(action["value"] * 1.4) + 2

	if main.get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
	main.show_message(e.name + ": SEGUNDA FASE", Color(1.0, 0.2, 0.2))

	# Flash visual
	var flash = ColorRect.new()
	flash.size = main.get_viewport_rect().size; flash.color = Color(0.8, 0.1, 0.1, 0.3); flash.z_index = 45
	main.add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6)
	tw.tween_callback(flash.queue_free)

	await main.get_tree().create_timer(1.5).timeout
	main.panel_message.visible = false
	main.update_ui(); main.update_intent_labels()


func get_enemy_banter(enemy_name: String) -> String:
	var stage = LoreData.get_lore_stage()
	var has_translator = GameManager.has_relic("lengua_tablero")

	# Enemigos que hablan en idioma garbled (sin traductor en etapas tempranas)
	if enemy_name in LoreData.GARBLED and not has_translator and stage <= 1:
		if randf() < 0.55:
			return LoreData.GARBLED[enemy_name]

	var threshold = 0.7 if enemy_name == "El Penitente" else 0.35
	if randf() > threshold: return ""
	var pool = ENEMY_COMBAT_BANTER.get(enemy_name, [])
	if pool.is_empty(): return ""
	return pool[randi() % pool.size()]


func get_banter_color(enemy_name: String, text: String) -> Color:
	if LoreData.is_garbled(text):
		return Color(0.3, 0.9, 0.9)  # cian para texto garbled
	if enemy_name == "El Penitente":
		return Color(0.5, 1.0, 0.5)
	if enemy_name in ["EL CARCELERO", "EL REY AMARILLO", "EL REY SIN CORONA"]:
		return Color(0.95, 0.7, 0.1)
	return Color(0.9, 0.8, 0.5)


func show_enemy_banter(enemy_panel: Panel, text: String, col: Color = Color(0.9, 0.8, 0.5)) -> void:
	if text.is_empty(): return
	var lbl = Label.new()
	lbl.text = "\"%s\"" % text
	lbl.modulate = col; lbl.modulate.a = 0.0
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var est_lines = text.length() / 30 + text.count("\n") + 1
	var ban_h = max(65, est_lines * 16)
	lbl.size = Vector2(220, ban_h)
	lbl.position = enemy_panel.global_position + Vector2(-10, -ban_h - 10)
	lbl.z_index = 12; main.add_child(lbl)
	var t = create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.8)
	t.tween_property(lbl, "modulate:a", 0.0, 0.5)
	t.tween_callback(lbl.queue_free)


func animate_enemy_attack_unique(e: Dictionary) -> void:
	if not e.panel: return
	var orig = e.panel.position
	var t = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	match e.name:
		"EL CARCELERO":
			# Salto y caida pesada
			t.tween_property(e.panel, "position:y", orig.y - 40, 0.2)
			t.tween_property(e.panel, "position:y", orig.y + 20, 0.1)
			t.parallel().tween_property(e.panel, "scale", Vector2(1.2, 0.8), 0.1) # Impacto
			t.tween_property(e.panel, "position", orig, 0.2)
			t.parallel().tween_property(e.panel, "scale", Vector2(1, 1), 0.2)
			await t.finished
			# Temblor de pantalla sutil
			var st = create_tween().set_loops(4)
			st.tween_property(main, "position", Vector2(randf_range(-5,5), randf_range(-5,5)), 0.05)
			st.tween_property(main, "position", Vector2.ZERO, 0.05)

		"LA DAMA DE CENIZA":
			# Brillo incandescente
			t.tween_property(e.panel, "modulate", Color(2.5, 0.8, 0.2), 0.15)
			t.tween_property(e.panel, "position:x", orig.x - 30, 0.1)
			# Particulas de ceniza hacia el jugador
			main._spawn_death_particles(e.panel.global_position + Vector2(0, 100))
			t.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.3)
			t.parallel().tween_property(e.panel, "position", orig, 0.3)
			await t.finished

		"EL MARISCAL":
			# Carga rapida
			t.tween_property(e.panel, "position:x", orig.x - 150, 0.15).set_trans(Tween.TRANS_EXPO)
			t.tween_property(e.panel, "position:x", orig.x + 20, 0.05)
			t.tween_property(e.panel, "position", orig, 0.2)
			await t.finished

		"EL VERDADERO HASTUR":
			# Glitch total
			main.is_eye_breaking_4th_wall = true
			t.tween_property(e.panel, "scale", Vector2(1.5, 1.5), 0.1)
			t.parallel().tween_property(e.panel, "modulate", Color(0,0,0), 0.1)
			if main.get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
			await main.get_tree().create_timer(0.15).timeout
			e.panel.scale = Vector2(1,1); e.panel.modulate = Color.WHITE
			main.is_eye_breaking_4th_wall = false

		_:
			# Ataque generico
			var is_weak = e.get("atk_reduction", 0) > 0
			var dist = -40 if not is_weak else -15

			# Stretch de anticipación (se estira hacia la dirección del ataque)
			var tss = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tss.tween_property(e.panel, "scale", Vector2(0.85, 1.12), 0.08)

			t.tween_property(e.panel, "position:x", orig.x + dist, 0.15)
			# Al llegar al punto máximo: squash de impacto
			t.tween_callback(func():
				var ti = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				ti.tween_property(e.panel, "scale", Vector2(1.18, 0.82), 0.05)
				ti.tween_property(e.panel, "scale", Vector2(1.0, 1.0), 0.12)
			)
			t.tween_property(e.panel, "position", orig, 0.2)

			if is_weak:
				var st = create_tween().set_loops(3)
				st.tween_property(e.panel, "position:y", orig.y - 4, 0.05)
				st.tween_property(e.panel, "position:y", orig.y, 0.05)

			await t.finished
