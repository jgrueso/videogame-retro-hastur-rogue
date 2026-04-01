extends Node

var main: Node

func setup(m) -> void:
	main = m

func resolve(card, enemy_idx: int) -> void:
	var effective_cost = card.get_effective_cost()

	if main.player_energy < effective_cost:
		card.set_disabled(false); return

	main.player_energy -= effective_cost

	# 1. Quitar de la mano lógica
	for i in range(main.hand.size()):
		if main.hand[i].get("name", "").to_upper() == card.card_name:
			main.hand.remove_at(i); break

	if main.get_node_or_null("/root/AudioManager"): AudioManager.play("card_play")
	main.log_message("TU", "Juegas " + card.card_name, Color(0.4, 0.8, 1.0))

	var shield_before: int = main.player_shield
	var card_handled = false
	var target_e = null
	if enemy_idx >= 0 and enemy_idx < main.enemies.size(): target_e = main.enemies[enemy_idx]
	var c_upper = card.card_name.to_upper()

	# ── LÓGICA DE CARTAS ESPECIALES ──
	if "APOCALIPSIS" in c_upper:
		card_handled = true
		for e_aoe in main.enemies:
			if e_aoe.hp > 0:
				e_aoe.hp -= 35
				main._spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), 35, Color(1, 0, 0))
				if e_aoe.hp <= 0: await main._kill_enemy(e_aoe)

	elif "SIGNO AMARILLO" in c_upper:
		card_handled = true
		GameManager.sanity = max(0, GameManager.sanity - 40)
		GameManager.mark_level += 1
		main.player_energy = min(main.player_max_energy, main.player_energy + 2)
		main.flash_small("¡El Signo consume tu mente! Marca Nv." + str(GameManager.mark_level))

	elif "TRONO DE CARCOSA" in c_upper:
		card_handled = true
		if target_e:
			var dmg = 10
			var absorbed = min(target_e.shield, dmg)
			if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(target_e)
			if dmg > 0:
				target_e.hp -= dmg
				main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
				main._animate_enemy_hit(target_e)
				if target_e.hp <= 0: await main._kill_enemy(target_e)
		main.player_shield += 10
		main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), 10, Color(0.4, 0.7, 1))
		main.trono_carcosa_active = true
		main.flash_small("¡El Trono reclama su dominio!")
		main.update_ui()

	elif "INCISION PRECISA" in c_upper:
		card_handled = true
		if target_e:
			var dmg = int(target_e.max_hp * 0.25)
			target_e.hp -= dmg
			main.flash_small("Incisión: " + str(dmg))
			main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(0.5, 1, 0.5))
			main._animate_enemy_hit(target_e)
			if target_e.hp <= 0: await main._kill_enemy(target_e)
		else:
			main.flash_small("Selecciona un objetivo")
			# Devolver energia si falla el objetivo
			main.player_energy += effective_cost
			card.set_disabled(false)
			return

	elif "MIRADA QUE DEVORA" in c_upper:
		card_handled = true
		if target_e:
			target_e["bleed"] = target_e.get("bleed", 0) + 3
			main._animate_enemy_hit(target_e)
			# Feedback visual directo de estado en lugar de un numero
			var lbl = Label.new()
			lbl.text = "🩸 SANGRADO"
			lbl.modulate = Color(0.8, 0.1, 0.3)
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.position = target_e.panel.global_position + Vector2(100, 60)
			lbl.z_index = 20; main.add_child(lbl)
			var t = create_tween().set_parallel(true)
			t.tween_property(lbl, "position:y", lbl.position.y - 60, 0.8)
			t.tween_property(lbl, "modulate:a", 0.0, 0.8)
			t.chain().tween_callback(lbl.queue_free)
			main.update_intent_labels() # ACTUALIZACIÓN EN TIEMPO REAL
		else:

			main.flash_small("Selecciona un objetivo")
			main.player_energy += effective_cost
			card.set_disabled(false)
			return

	elif "CENIZA PREVENTIVA" in c_upper:
		card_handled = true
		var discarded_count = main.hand.size()
		if discarded_count > 0:
			for c_rem in main.hand_container.get_children():
				if c_rem != card: c_rem.queue_free()
			for h_rem in main.hand: main.discard_pile.append(h_rem)
			main.hand.clear()

			var shield_gain = discarded_count * 3
			main.player_shield += shield_gain
			# Feedback visual: Número azul flotante
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), shield_gain, Color(0.4, 0.7, 1.0))
			main.flash_small("Ceniza Preventiva: +" + str(shield_gain) + " Escudo")
		else:
			main.flash_small("Mano vacía: No hay piezas que quemar.")
		main.update_ui()

	elif "ANALISIS" in c_upper:
		card_handled = true
		await main.draw_hand(2)

	elif "FORMACION" in c_upper:
		card_handled = true
		main.player_shield += card.defense

	elif "ECO DEL VAC" in c_upper:
		card_handled = true
		main.flash_small("¡ECO DEL VACÍO!")
		for e_aoe in main.enemies:
			if e_aoe.hp > 0:
				e_aoe.hp -= 4
				main._spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), 4, Color(0.7, 0.7, 1.0))
				main._animate_enemy_hit(e_aoe)
				if e_aoe.hp <= 0: await main._kill_enemy(e_aoe)
		main.update_ui()

	elif "POSICION VENTAJOSA" in c_upper:
		card_handled = true
		var choice = await _show_choice_dialog(["⚔ 4 ATK", "🛡 4 DEF"])
		if choice == 0:
			# ATK: aplicar al primer enemigo vivo
			var atk_target = null
			for e_find in main.enemies:
				if e_find.hp > 0: atk_target = e_find; break
			if atk_target:
				var dmg = 4
				var absorbed = min(atk_target.shield, dmg)
				if absorbed > 0: atk_target.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(atk_target)
				if dmg > 0:
					atk_target.hp -= dmg
					main._spawn_damage_number(atk_target.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
					main._animate_enemy_hit(atk_target)
					if atk_target.hp <= 0: await main._kill_enemy(atk_target)
			else:
				main.flash_small("No hay enemigos.")
		else:
			main.player_shield += 4
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), 4, Color(0.4, 0.7, 1))
		main.update_ui()

	elif "CONTRAOFENSIVA" in c_upper:
		card_handled = true
		if main.enemy_attacked_last_turn:
			if target_e:
				var dmg = 8
				var absorbed = min(target_e.shield, dmg)
				if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(target_e)
				if dmg > 0:
					target_e.hp -= dmg
					main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
					main._animate_enemy_hit(target_e)
					if target_e.hp <= 0: await main._kill_enemy(target_e)
			else:
				main.flash_small("Selecciona un objetivo")
				main.player_energy += effective_cost
				card.set_disabled(false)
				return
		else:
			main.flash_small("Contraofensiva: el enemigo no atacó el turno anterior.")
		main.update_ui()

	elif "SUSURRO DEBILITANTE" in c_upper:
		card_handled = true
		var is_last = main.hand.is_empty()
		var base_red = 6 + card.attack
		var reduction = base_red * 2 if is_last else base_red
		for e_deb in main.enemies:
			if e_deb.hp > 0:
				e_deb["atk_reduction"] = e_deb.get("atk_reduction", 0) + reduction
				# Feedback visual: Destello verde de debilidad
				var tw = create_tween()
				tw.tween_property(e_deb.panel, "modulate", Color(0.4, 1.2, 0.4), 0.1)
				tw.tween_property(e_deb.panel, "modulate", Color(1, 1, 1), 0.3)
		if is_last:
			main.flash_small("¡SUSURRO FINAL! Todos debilitados: -" + str(reduction))
			main._trigger_screen_blink()
		else:
			main.flash_small("Susurro: Todos -" + str(reduction) + " ATK")
			var candidates = []
			for c_node in main.hand_container.get_children():
				if not c_node.is_queued_for_deletion() and c_node != card:
					candidates.append(c_node)
			if not candidates.is_empty():
				var to_discard = candidates[randi() % candidates.size()]
				for j in range(main.hand.size()):
					if main.hand[j]["name"].to_upper() == to_discard.card_name:
						main.discard_pile.append(main.hand[j]); main.hand.remove_at(j); break
				to_discard.queue_free()
		main.update_intent_labels()

	elif "FORTALEZA INTERIOR" in c_upper:
		card_handled = true
		var shield_amount = int(main.player_max_hp * 0.15)
		main.player_shield += shield_amount
		main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), shield_amount, Color(0.4, 0.7, 1))
		main.flash_small("Fortaleza Interior: +" + str(shield_amount) + " Escudo")
		main.update_ui()

	# ── LÓGICA DE ATAQUE Y DEFENSA GENÉRICA ──
	if not card_handled:
		var shield_amount = card.defense
		if target_e:
			if target_e.peaceful and card.attack > 0: target_e.peaceful = false; main.enemy_turn.set_enemy_aggressive(target_e)
			var dmg = card.attack
			if card.card_data.get("scaling_sanity", false):
				var san = GameManager.sanity
				if san < 35:
					dmg *= 2
					shield_amount *= 2
					main.flash_small("¡RESONANCIA ABISAL!")
					main._trigger_screen_blink()
				elif san < 60:
					dmg = int(dmg * 1.5)
					shield_amount = int(shield_amount * 1.5)
					main.flash_small("Eco del Abismo...")
			if "AVATAR" in target_e.name.to_upper(): dmg = int(dmg * (1.0 + (100 - GameManager.sanity) * 0.015))
			if "JAQUE ETERNO" in c_upper: dmg = clamp(15 + int((main.player_max_hp - main.player_hp) * 0.4), 15, 40)
			if GameManager.velo_broken: dmg += 2
			# Resonancia del Príncipe en W3: +1 ATK por stack
			if GameManager.selected_character == "prince" and GameManager.resonancia_stacks > 0:
				dmg += GameManager.resonancia_stacks
			if GameManager.selected_character == "guardian" and main.furia_points >= 3:
				dmg *= 2; main.furia_points = 0; main.flash_small("¡RESILIENCIA!"); main._trigger_screen_blink()

			var absorbed = min(target_e.shield, dmg)
			if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(target_e)
			if dmg > 0:
				target_e.hp = max(0, target_e.hp - dmg)

				# MECÁNICA: La música del Rey Sin Corona cambia al recibir el primer golpe
				if "REY SIN CORONA" in target_e.name.to_upper() and not main.rey_music_triggered:
					main.rey_music_triggered = true
					if main.get_node_or_null("/root/AudioManager"):
						# No detener el lamento, sino hacerlo más grave y añadir la música de batalla
						AudioManager.stop_loop("king_intro_sound")
						AudioManager.play_loop("intro_title_song")

				main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
				main._animate_enemy_hit(target_e)
				if target_e.hp <= 0: await main._kill_enemy(target_e)

		if shield_amount > 0:
			main.player_shield += shield_amount
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), shield_amount, Color(0.4, 0.7, 1))

	# ── EFECTOS GENÉRICOS (draw, sanity, energía) ──
	# Se aplican solo si la carta no fue manejada por un caso especial,
	# para no duplicar efectos de cartas como Analisis Profundo o Signo Amarillo.
	if not card_handled:
		var cd = card.card_data
		if cd.get("gain_energy", 0) > 0:
			main.player_energy = min(main.player_max_energy, main.player_energy + cd["gain_energy"])
			main.flash_small("+" + str(cd["gain_energy"]) + " Energía")
		if cd.get("sanity_gain", 0) > 0:
			GameManager.sanity = min(GameManager.max_sanity, GameManager.sanity + cd["sanity_gain"])
			main.flash_small("+" + str(cd["sanity_gain"]) + " Sanidad")
		if cd.get("draw", 0) > 0:
			await main.draw_hand(cd["draw"])
		if cd.get("enemy_atk_debuff", 0) > 0:
			var reduction = cd["enemy_atk_debuff"]
			for e_deb in main.enemies:
				if e_deb.hp > 0:
					e_deb["atk_reduction"] = e_deb.get("atk_reduction", 0) + reduction
			main.flash_small("¡Grito de Guerra! Todos -" + str(reduction) + " ATK")
			main.update_intent_labels()

	# ── COSTES Y LIMPIEZA ──
	var cd_costs = card.card_data
	if "OFRENDA DE CARNE" in c_upper:
		main.player_hp = max(0, main.player_hp - 4)
	elif "PESO DE LA VERDAD" in c_upper:
		main.player_hp = max(0, main.player_hp - 6)
	elif cd_costs.get("hp_cost", 0) > 0:
		main.player_hp = max(0, main.player_hp - cd_costs["hp_cost"])
		main.flash_small("-" + str(cd_costs["hp_cost"]) + " HP")
	if cd_costs.get("sanity_cost", 0) > 0:
		GameManager.sanity = max(0, GameManager.sanity - cd_costs["sanity_cost"])
		main.flash_small("-" + str(cd_costs["sanity_cost"]) + " Sanidad")

	# ── MARCA DEL VACÍO ──
	if main.ui.get_cursed_card_node() == card:
		var curse_cost: int
		if GameManager.sanity >= 25:
			curse_cost = 4
		elif GameManager.sanity >= 10:
			curse_cost = 5
		else:
			curse_cost = 6
		if GameManager.selected_character == "prince":
			curse_cost = max(1, curse_cost / 2)
		var overflow: int = max(0, curse_cost - GameManager.sanity)
		GameManager.sanity = max(0, GameManager.sanity - curse_cost)
		var msg := "La Marca se cobra su precio. -%d Cordura" % curse_cost
		if overflow > 0:
			main.player_hp = max(0, main.player_hp - overflow)
			msg += " / -%d HP" % overflow
		main.flash_small(msg, Color(0.6, 0.0, 0.9))
		main.ui.clear_cursed_card()

	if main.player_hp <= 0: main._check_player_death(); return

	var target_pos = Vector2.ZERO
	if target_e: target_pos = target_e.panel.global_position + Vector2(100, 100)
	await card.play_attack_animation(target_pos)

	if not card.exhaust:
		main.discard_pile.append(card.card_data.duplicate())
	else:
		main.flash_small(card.card_name + " se agota.")

	main.first_card_this_turn = false
	card.queue_free()
	main.reorganize_hand()
	main.cards_played_this_turn += 1
	if GameManager.has_relic("reloj_negro") and main.cards_played_this_turn % 3 == 0:
		main.player_energy = min(main.player_energy + 1, main.player_max_energy); main._flash_relic("reloj_negro")

	# Pasiva Guardian: RESILIENCIA — 1 Furia por cada 10 escudo generado en el turno
	if GameManager.selected_character == "guardian":
		var gained = max(0, main.player_shield - shield_before)
		if gained > 0:
			main.shield_gained_this_turn += gained
			while main.shield_gained_this_turn >= 10 and main.furia_points < 3:
				main.shield_gained_this_turn -= 10
				main.furia_points += 1
				main.flash_small("¡RESILIENCIA! Furia acumulada: " + str(main.furia_points) + "/3")

	main.update_ui(); main.update_intent_labels(); main.check_combat_end()


signal _choice_made(idx: int)

func _show_choice_dialog(options: Array) -> int:
	var vp = main.get_viewport_rect().size

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 300
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(overlay)

	var panel = Panel.new()
	panel.size = Vector2(360, 110)
	panel.position = (vp - panel.size) / 2
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.05, 0.08)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.5, 0.45, 0.15)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var lbl = Label.new()
	lbl.text = "¿Qué efecto aplicas?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 12); lbl.size = Vector2(360, 28)
	lbl.modulate = Color(0.85, 0.75, 0.2)
	panel.add_child(lbl)

	var hbox = HBoxContainer.new()
	hbox.position = Vector2(20, 50); hbox.size = Vector2(320, 50)
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	for i in range(options.size()):
		var btn = Button.new()
		btn.text = options[i]
		btn.custom_minimum_size = Vector2(140, 46)
		btn.add_theme_font_size_override("font_size", 16)
		hbox.add_child(btn)
		var idx = i
		btn.pressed.connect(func():
			overlay.queue_free()
			_choice_made.emit(idx)
		)

	var result = await _choice_made
	return result


func get_deciphered_thought(original: String) -> String:
	# La reliquia Lengua del Tablero descifra todo automáticamente
	if GameManager.has_relic("lengua_tablero"):
		return original

	var sanity = GameManager.sanity
	var legibility = (100.0 - sanity) / 100.0 # 0.0 a 1.0

	if sanity <= 0: return original # Claridad total

	var result = ""
	var symbols = ["@", "#", "$", "%", "&", "*", "§", "Δ", "Ω", "▓", "░", "▒", "†", "‡"]

	for i in range(original.length()):
		var c = original[i]
		if c == " " or c == "\n":
			result += c
			continue

		# Decidir si este caracter es legible
		if randf() < legibility:
			result += c
		else:
			result += symbols[randi() % symbols.size()]

	return result


func get_penitente_thought() -> String:
	var thoughts = [
		"AYUDAME A SALIR DEL CICLO",
		"EL JUGADOR NOS ESTA MIRANDO",
		"HEMOS MUERTO MIL VECES AQUI",
		"EL TABLERO ES UNA PRISION DE CARNE",
		"NO ERES EL PRIMERO EN LLEGAR",
		"EL REY TIENE SED DE MEMORIAS"
	]
	return thoughts[GameManager.total_runs % thoughts.size()]
