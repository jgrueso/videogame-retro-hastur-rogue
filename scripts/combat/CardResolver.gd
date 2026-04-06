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
	DialogueUI.add_log("TU", "Juegas " + card.card_name, Color(0.4, 0.8, 1.0))

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
		DialogueUI.toast("¡El Signo consume tu mente! Marca Nv." + str(GameManager.mark_level))

	elif "TRONO DE CARCOSA" in c_upper:
		card_handled = true
		if target_e:
			var dmg = card.attack
			var absorbed = min(target_e.shield, dmg)
			if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(target_e)
			if dmg > 0:
				target_e.hp -= dmg
				main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
				main._animate_enemy_hit(target_e)
				if target_e.hp <= 0: await main._kill_enemy(target_e)
		main.player_shield += card.defense
		main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), card.defense, Color(0.4, 0.7, 1))
		main.trono_carcosa_active = true
		DialogueUI.toast("¡El Trono reclama su dominio!")
		main.update_ui()

	elif "INCISION PRECISA" in c_upper:
		card_handled = true
		if target_e:
			var dmg = int(target_e.max_hp * 0.25)
			target_e.hp -= dmg
			DialogueUI.toast("Incisión: " + str(dmg))
			main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(0.5, 1, 0.5))
			main._animate_enemy_hit(target_e)
			if target_e.hp <= 0: await main._kill_enemy(target_e)
		else:
			DialogueUI.toast("Selecciona un objetivo")
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

			DialogueUI.toast("Selecciona un objetivo")
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
			DialogueUI.toast("Ceniza Preventiva: +" + str(shield_gain) + " Escudo")
		else:
			DialogueUI.toast("Mano vacía: No hay piezas que quemar.")
		main.update_ui()

	elif "ANALISIS" in c_upper:
		card_handled = true
		await main.draw_hand(2)

	elif "NOMBRE SIN PRONUNCIAR" in c_upper:
		card_handled = true
		var killed_any = false
		for e_kill in main.enemies.duplicate():
			if e_kill.hp > 0:
				e_kill.hp = 0
				await main._kill_enemy(e_kill)
				killed_any = true
		if killed_any:
			DialogueUI.toast("¡NOMBRE SIN PRONUNCIAR!", Color(0.9, 0.0, 0.2))
			main._trigger_screen_blink()
		main.update_ui()

	elif "FORMACION" in c_upper:
		card_handled = true
		main.player_shield += card.defense

	elif "ECO DEL VAC" in c_upper:
		card_handled = true
		DialogueUI.toast("¡" + card.card_name + "!")
		var dmg = card.attack
		for e_aoe in main.enemies:
			if e_aoe.hp > 0:
				e_aoe.hp -= dmg
				main._spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), dmg, Color(0.7, 0.7, 1.0))
				main._animate_enemy_hit(e_aoe)
				if e_aoe.hp <= 0: await main._kill_enemy(e_aoe)
		main.update_ui()

	elif "POSICION VENTAJOSA" in c_upper:
		card_handled = true
		var opt_atk = "⚔ " + str(card.attack) + " ATK"
		var opt_def = "🛡 " + str(card.defense) + " DEF"
		var choice = await _show_choice_dialog([opt_atk, opt_def])
		if choice == 0:
			# ATK: aplicar al primer enemigo vivo
			var atk_target = null
			for e_find in main.enemies:
				if e_find.hp > 0: atk_target = e_find; break
			if atk_target:
				var dmg = card.attack
				var absorbed = min(atk_target.shield, dmg)
				if absorbed > 0: atk_target.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(atk_target)
				if dmg > 0:
					atk_target.hp -= dmg
					main._spawn_damage_number(atk_target.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
					main._animate_enemy_hit(atk_target)
					if atk_target.hp <= 0: await main._kill_enemy(atk_target)
			else:
				DialogueUI.toast("No hay enemigos.")
		else:
			main.player_shield += card.defense
			main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), card.defense, Color(0.4, 0.7, 1))
		main.update_ui()

	elif "CONTRAOFENSIVA" in c_upper:
		card_handled = true
		if main.enemy_attacked_last_turn:
			if target_e:
				var dmg = card.attack
				var absorbed = min(target_e.shield, dmg)
				if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(target_e)
				if dmg > 0:
					target_e.hp -= dmg
					main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
					main._animate_enemy_hit(target_e)
					if target_e.hp <= 0: await main._kill_enemy(target_e)
			else:
				DialogueUI.toast("Selecciona un objetivo")
				main.player_energy += effective_cost
				card.set_disabled(false)
				return
		else:
			DialogueUI.toast("Contraofensiva: el enemigo no atacó el turno anterior.")
		main.update_ui()

	elif "SUSURRO DEBILITANTE" in c_upper:
		card_handled = true
		var is_last = main.hand.is_empty()
		var base_red = 6 + card.attack
		var reduction = base_red * 2 if is_last else base_red
		for e_deb in main.enemies:
			if e_deb.hp > 0:
				e_deb["atk_reduction"] = e_deb.get("atk_reduction", 0) + reduction
				CombatLog.log("DEBUFF", "-%d ATK (Susurro) → %s" % [reduction, e_deb.name], Color(0.4, 1.0, 0.4), CombatLog.Category.EFFECTS)
				# Feedback visual: Destello verde de debilidad
				var tw = create_tween()
				tw.tween_property(e_deb.panel, "modulate", Color(0.4, 1.2, 0.4), 0.1)
				tw.tween_property(e_deb.panel, "modulate", Color(1, 1, 1), 0.3)
		if is_last:
			DialogueUI.toast("¡SUSURRO FINAL! Todos debilitados: -" + str(reduction))
			main._trigger_screen_blink()
		else:
			DialogueUI.toast("Susurro: Todos -" + str(reduction) + " ATK")
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
		var shield_amount = int(main.player_max_hp * 0.20)
		main.player_shield += shield_amount
		main._spawn_damage_number(main.player_panel.global_position + Vector2(200, 30), shield_amount, Color(0.4, 0.7, 1))
		DialogueUI.toast("Fortaleza Interior: +" + str(shield_amount) + " Escudo")
		if main.furia_points < 3:
			main.furia_points += 1
			DialogueUI.toast("Fortaleza Interior: +1 Furia! (" + str(main.furia_points) + "/3)", Color(0.4, 0.9, 0.4))
		main.update_ui()

	elif "ESPEJO DE ACERO" in c_upper:
		card_handled = true
		main.espejo_acero_active = true
		DialogueUI.toast("Espejo de Acero: el proximo golpe sera reflejado.", Color(0.4, 0.7, 1))
		main.update_ui()

	elif card.card_data.get("dmg_equals_shield", false):
		card_handled = true
		if target_e:
			var total_dmg = main.player_shield
			if card.card_data.get("consumes_furia", false):
				main.furia_points = 0
			main.player_shield = 0
			var dmg = total_dmg
			if dmg > 0:
				var absorbed = min(target_e.shield, dmg)
				if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; main._animate_shield_block(target_e)
				if dmg > 0:
					target_e.hp = max(0, target_e.hp - dmg)
					main._spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(0.9, 0.6, 0.1))
					main._animate_enemy_hit(target_e)
					if target_e.hp <= 0: await main._kill_enemy(target_e)
			DialogueUI.toast("¡TORMENTA DE HIERRO! " + str(total_dmg) + " daño", Color(0.9, 0.6, 0.1))
			CombatLog.log("TORMENTA", "%d daño (= escudo)" % total_dmg, Color(0.9, 0.6, 0.1), CombatLog.Category.EFFECTS)
			main.update_ui()
		else:
			DialogueUI.toast("Selecciona un objetivo")
			main.player_energy += effective_cost
			card.set_disabled(false)
			return

	# ── LÓGICA DE ATAQUE Y DEFENSA GENÉRICA ──
	if not card_handled:
		var shield_amount = card.defense
		# Bonus de escudo condicional (ej: Trinchera: +bonus si ya hay escudo activo)
		var bonus_def = card.card_data.get("bonus_def_if_shield", 0)
		if bonus_def > 0 and main.player_shield > 0:
			shield_amount += bonus_def
		if target_e:
			if target_e.peaceful and card.attack > 0: target_e.peaceful = false; main.enemy_turn.set_enemy_aggressive(target_e)
			var dmg = card.attack
			
			# Modificador de FURIA del Guardián (x2 daño al atacar con 3 cargas)
			if GameManager.selected_character == "guardian" and main.furia_points >= 3 and dmg > 0:
				dmg *= 2
				main.furia_points = 0 # Se consume la furia al atacar
				DialogueUI.toast("¡GOLPE DE FURIA! Daño x2", Color(1.0, 0.5, 0.2))
				CombatLog.log("FURIA", "Ataque potenciado x2", Color(1.0, 0.5, 0.2), CombatLog.Category.EFFECTS)

			# Modificadores de Destilados
			if main.destilado_next_atk_mult > 1.0:
				dmg = int(dmg * main.destilado_next_atk_mult)
				main.destilado_next_atk_mult = 1.0
			if main.destilado_dmg_mult > 1.0:
				dmg = int(dmg * main.destilado_dmg_mult)
			if main.destilado_rey_amarillo:
				dmg *= 2
			if card.card_data.get("scaling_sanity", false):
				var san = GameManager.sanity
				if san < 35:
					dmg *= 2
					shield_amount *= 2
					DialogueUI.toast("¡RESONANCIA ABISAL!")
					main._trigger_screen_blink()
				elif san < 60:
					dmg = int(dmg * 1.5)
					shield_amount = int(shield_amount * 1.5)
					DialogueUI.toast("Eco del Abismo...")
			if "AVATAR" in target_e.name.to_upper(): dmg = int(dmg * (1.0 + (100 - GameManager.sanity) * 0.015))
			if "JAQUE ETERNO" in c_upper: dmg = clamp(15 + int((main.player_max_hp - main.player_hp) * 0.4), 15, 40)
			if GameManager.velo_broken: dmg += 2
			# Resonancia del Príncipe en W3: +1 ATK por stack
			if GameManager.selected_character == "prince" and GameManager.resonancia_stacks > 0:
				dmg += GameManager.resonancia_stacks
				CombatLog.log("RESONANCIA", "+%d ATK stacks" % GameManager.resonancia_stacks, Color(0.7, 0.2, 1.0), CombatLog.Category.EFFECTS)
			# Guardian RESILIENCIA: el rebound pasivo se activa en EnemyTurnProcessor, no aquí
			# Pasiva Mahar: FERVOR
			if GameManager.selected_character == "mahar" and dmg > 0:
				if GameManager.sanity >= 60 and not main.mahar_guided_struck:
					dmg += 4
					main.mahar_guided_struck = true
					DialogueUI.toast("FERVOR: +4 al golpe guiado", Color(0.9, 0.6, 0.2))
					CombatLog.log("FERVOR", "+4 al golpe guiado", Color(0.9, 0.6, 0.2), CombatLog.Category.EFFECTS)
				elif GameManager.sanity < 40:
					dmg += 2

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
			DialogueUI.toast("+" + str(cd["gain_energy"]) + " Energía")
		if cd.get("sanity_gain", 0) > 0:
			GameManager.sanity = min(GameManager.max_sanity, GameManager.sanity + cd["sanity_gain"])
			DialogueUI.toast("+" + str(cd["sanity_gain"]) + " Sanidad")
		if cd.get("draw", 0) > 0:
			await main.draw_hand(cd["draw"])
		if cd.get("enemy_atk_debuff", 0) > 0:
			var reduction = cd["enemy_atk_debuff"]
			for e_deb in main.enemies:
				if e_deb.hp > 0:
					e_deb["atk_reduction"] = e_deb.get("atk_reduction", 0) + reduction
			DialogueUI.toast("¡" + card.card_name + "! Todos -" + str(reduction) + " ATK")
			main.update_intent_labels()

	# ── COSTES Y LIMPIEZA ──
	var cd_costs = card.card_data
	if "OFRENDA DE CARNE" in c_upper:
		main.player_hp = max(0, main.player_hp - 4)
	elif "PESO DE LA VERDAD" in c_upper:
		main.player_hp = max(0, main.player_hp - 6)
	elif cd_costs.get("hp_cost", 0) > 0:
		main.player_hp = max(0, main.player_hp - cd_costs["hp_cost"])
		DialogueUI.toast("-" + str(cd_costs["hp_cost"]) + " HP")
		CombatLog.log("COSTE", "-%d HP (carta)" % cd_costs["hp_cost"], Color(0.9, 0.3, 0.3), CombatLog.Category.EFFECTS)
	if cd_costs.get("sanity_cost", 0) > 0:
		GameManager.sanity = max(0, GameManager.sanity - cd_costs["sanity_cost"])
		DialogueUI.toast("-" + str(cd_costs["sanity_cost"]) + " Sanidad")
		# QUIEBRE del Príncipe: cuando la cordura llega a 0
		if GameManager.selected_character == "prince" and GameManager.sanity <= 0 and not main.prince_quiebre_active:
			main.prince_quiebre_active = true
			DialogueUI.toast("¡QUIEBRE! La cordura se ha consumido. -5 HP por turno.", Color(0.8, 0.1, 0.9))
			CombatLog.log("QUIEBRE", "Cordura 0 — -5HP/turno", Color(0.8, 0.1, 0.9), CombatLog.Category.EFFECTS)
			main._trigger_screen_blink()

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
		DialogueUI.toast(msg, Color(0.6, 0.0, 0.9))
		main.ui.clear_cursed_card()
		if GameManager.selected_character == "prince" and GameManager.sanity <= 0 and not main.prince_quiebre_active:
			main.prince_quiebre_active = true
			DialogueUI.toast("¡QUIEBRE! La cordura se ha consumido. -5 HP por turno.", Color(0.8, 0.1, 0.9))
			main._trigger_screen_blink()

	if main.player_hp <= 0: main._check_player_death(); return

	var target_pos = Vector2.ZERO
	if target_e: target_pos = target_e.panel.global_position + Vector2(100, 100)
	await card.play_attack_animation(target_pos)

	if not card.exhaust:
		main.discard_pile.append(card.card_data.duplicate())
	else:
		DialogueUI.toast(card.card_name + " se agota.")
		CombatLog.log("AGOTADA", card.card_name, Color(0.6, 0.4, 0.8), CombatLog.Category.EFFECTS)

	main.first_card_this_turn = false
	card.queue_free()
	main.reorganize_hand()
	main.cards_played_this_turn += 1
	if GameManager.has_relic("reloj_negro") and main.cards_played_this_turn % 3 == 0:
		main.player_energy = min(main.player_energy + 1, main.player_max_energy); main._flash_relic("reloj_negro")

	# Pasiva Estratega: PRESIÓN TÁCTICA — cada carta jugada genera 1 Presión (+ extra del campo "presion")
	if GameManager.selected_character == "estratega":
		var card_presion = card.card_data.get("presion", 0)
		var old_presion = main.presion_points
		main.presion_points = min(5, main.presion_points + 1 + card_presion)
		var presion_gained = main.presion_points - old_presion
		if presion_gained > 0:
			for e_pr in main.enemies:
				if e_pr.hp > 0:
					e_pr["atk_reduction"] = e_pr.get("atk_reduction", 0) + presion_gained
			DialogueUI.toast("PRESION: " + str(main.presion_points) + "/5 (-" + str(main.presion_points) + " ATK enemigos)", Color(0.3, 0.6, 1.0))
			CombatLog.log("PRESIÓN", "Stack %d/5" % main.presion_points, Color(0.3, 0.6, 1.0), CombatLog.Category.EFFECTS)
			main.update_intent_labels()

	# Pasiva Guardian: RESILIENCIA — 1 Furia por cada 6 escudo generado en el turno
	if GameManager.selected_character == "guardian":
		var gained = max(0, main.player_shield - shield_before)
		if gained > 0:
			main.shield_gained_this_turn += gained
			while main.shield_gained_this_turn >= 6 and main.furia_points < 3:
				main.shield_gained_this_turn -= 6
				main.furia_points += 1
				DialogueUI.toast("¡RESILIENCIA! Furia acumulada: " + str(main.furia_points) + "/3")
				CombatLog.log("FURIA", "Stack %d/3" % main.furia_points, Color(0.4, 0.9, 0.4), CombatLog.Category.EFFECTS)

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
	var symbols = ["ᛈ", "ᛇ", "ᚦ", "ᛟ", "ᛗ", "ᚾ", "ᛁ", "ᛖ", "ᚷ", "ᛃ", "ᚹ", "ᚫ", "ᛤ", "ᛞ", "ᚣ", "ᛝ", "ᚪ", "ᛠ", "ᚩ", "ᛡ", "ᚢ", "ᛣ", "ᚠ", "ᛒ"]

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
