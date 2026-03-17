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

	var card_handled = false
	var target_e = null
	if enemy_idx >= 0 and enemy_idx < main.enemies.size(): target_e = main.enemies[enemy_idx]
	var c_upper = card.card_name.to_upper()

	# ── LÓGICA DE CARTAS ESPECIALES ──
	if "APOCALIPSIS" in c_upper:
		card_handled = true
		for e_aoe in main.enemies:
			if e_aoe.hp > 0:
				e_aoe.hp -= 30
				main._spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), 30, Color(1, 0, 0))
				if e_aoe.hp <= 0: await main._kill_enemy(e_aoe)

	elif "SIGNO AMARILLO" in c_upper:
		card_handled = true
		GameManager.sanity = min(100, GameManager.sanity + 50)
		GameManager.mark_level += 1
		GameManager.player_max_energy += 1
		main.player_max_energy = GameManager.player_max_energy
		main.player_energy += 1

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

	elif "ECO" in c_upper:
		card_handled = true
		main.flash_small("¡ECO DEL VACÍO!")
		for e_aoe in main.enemies:
			if e_aoe.hp > 0:
				e_aoe.hp -= 4
				main._spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), 4, Color(0.7, 0.7, 1.0))
				main._animate_enemy_hit(e_aoe)
				if e_aoe.hp <= 0: await main._kill_enemy(e_aoe)
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

	# ── LÓGICA DE ATAQUE Y DEFENSA GENÉRICA ──
	if not card_handled:
		if target_e:
			if target_e.peaceful and card.attack > 0: target_e.peaceful = false; main.enemy_turn.set_enemy_aggressive(target_e)
			var dmg = card.attack
			if "AVATAR" in target_e.name.to_upper(): dmg = int(dmg * (1.0 + (100 - GameManager.sanity) * 0.015))
			if "JAQUE ETERNO" in c_upper: dmg = clamp(15 + int((main.player_max_hp - main.player_hp) * 0.4), 15, 40)
			if GameManager.velo_broken: dmg += 2
			if GameManager.selected_character == "guardian" and main.furia_points >= 3:
				dmg *= 2; main.furia_points = 0; main.flash_small("¡RESILIENCIA!"); main._trigger_screen_blink()

			var absorbed = min(target_e.shield, dmg)
			if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(target_e)
			if dmg > 0:
				target_e.hp -= dmg

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

		if card.defense > 0:
			main.player_shield += card.defense
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), card.defense, Color(0.4, 0.7, 1))

	# ── COSTES Y LIMPIEZA ──
	if "OFRENDA DE CARNE" in c_upper: main.player_hp -= 4
	elif "PESO DE LA VERDAD" in c_upper: main.player_hp -= 6
	if main.player_hp <= 0: main._check_player_death(); return

	var target_pos = Vector2.ZERO
	if target_e: target_pos = target_e.panel.global_position + Vector2(100, 100)
	await card.play_attack_animation(target_pos)

	if not card.exhaust:
		main.discard_pile.append({"name": card.card_name, "attack": card.attack, "defense": card.defense, "cost": card.cost})
	else:
		main.flash_small(card.card_name + " se agota.")

	main.first_card_this_turn = false
	card.queue_free()
	main.reorganize_hand()
	main.cards_played_this_turn += 1
	if GameManager.has_relic("reloj_negro") and main.cards_played_this_turn % 3 == 0:
		main.player_energy = min(main.player_energy + 1, main.player_max_energy); main._flash_relic("reloj_negro")

	main.update_ui(); main.update_intent_labels(); main.check_combat_end()


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
