extends Node2D

var shop_items: Array = [
	{"label": "Sangre Embalsamada (+15 HP max)", "cost": 25, "action": "max_hp", "desc": "Sabe a ceniza y a un pasado que no es tuyo."},
	{"label": "Elixir de la Agonia (Cura 20 HP)", "cost": 15, "action": "heal", "desc": "Dormira tu dolor, pero no tus pesadillas."},
	{"label": "Sello de la Dama (Reliquia)", "cost": 30, "action": "relic", "desc": "Un objeto que el Rey dio por perdido."},
]

var greeting: String = ""
const GREETINGS = [
	"\"¿Que traes en tus bolsillos, pequeña pieza? ¿Oro o arrepentimiento?\"",
	"\"Valla, valla... hueles a alguien que aun cree que tiene salida.\"",
	"\"El Rey no me deja hablar contigo, pero el Rey no esta mirando ahora.\"",
	"\"Tengo cosas que te harian llorar sangre. ¿Quieres verlas?\""
]

var shop_content: Control
var purchase_buttons: Array = []
var btn_sell_mem: Button
var btn_sell_future: Button
var offered_cards: Array = []
var card_shelf_container: HBoxContainer # Referencia para refrescar
var reroll_cost: int = 25
var reroll_btn: Button
var offered_destilados: Array = []  # [{id, label, cost, action, desc, sold}]
var destilados_grid: VBoxContainer  # Sección separada de destilados
var _dest_tooltip: Panel = null     # Tooltip flotante compartido

func _ready() -> void:
	greeting = GREETINGS[randi() % GREETINGS.size()]
	
	# Generar cartas al entrar filtrando por personaje y excluyendo legendarias
	_generate_offered_cards()
	_generate_offered_destilados()
	
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	build_ui()
	_update_info()

func _generate_offered_cards() -> void:
	offered_cards.clear()
	var char_id = GameManager.selected_character
	var pool = CardData.ALL_CARDS.filter(func(c):
		if c.get("legendary", false): return false
		var c_char = c.get("char", "")
		return c_char == "" or c_char == char_id
	)
	pool.shuffle()
	for i in range(min(3, pool.size())):
		var card = pool[i].duplicate()
		card["price"] = randi_range(6, 14)
		card["sold"] = false
		offered_cards.append(card)

func _generate_offered_destilados() -> void:
	offered_destilados.clear()
	if GameManager.destilados_blocked:
		return
	const RARITY_COSTS = {"comun": 15, "poco_comun": 20, "raro": 30, "maldito": 22}
	var pool = GameManager.DESTILADO_DATA.keys().duplicate()
	pool.shuffle()
	var count = 0
	for dest_id in pool:
		if count >= 2:
			break
		var data = GameManager.DESTILADO_DATA[dest_id]
		offered_destilados.append({
			"id": dest_id,
			"label": data["name"],
			"cost": RARITY_COSTS.get(data.get("rarity", "comun"), 20),
			"action": "destilado",
			"desc": data["desc"] + "\n\n\"" + data["flavor"] + "\"",
			"sold": false,
		})
		count += 1

func _build_destilados_section(vp: Vector2) -> void:
	if destilados_grid:
		destilados_grid.queue_free()
	destilados_grid = VBoxContainer.new()
	destilados_grid.position = Vector2(vp.x * 0.1, 570)
	destilados_grid.add_theme_constant_override("separation", 8)
	shop_content.add_child(destilados_grid)

	if GameManager.destilados_blocked:
		var blocked_lbl = Label.new()
		blocked_lbl.text = "[ Destilados sellados — El Último Vial ]"
		blocked_lbl.add_theme_font_size_override("font_size", 10)
		blocked_lbl.modulate = Color(0.4, 0.4, 0.4)
		destilados_grid.add_child(blocked_lbl)
		return

	var header = Label.new()
	header.text = "◈  DESTILADOS  ◈"
	header.add_theme_font_size_override("font_size", 11)
	header.modulate = Color(0.7, 0.5, 0.9)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	destilados_grid.add_child(header)

	if offered_destilados.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Sin existencias."
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.modulate = Color(0.4, 0.4, 0.4)
		destilados_grid.add_child(empty_lbl)
		return

	for item in offered_destilados:
		if item["sold"]:
			continue
		var btn = _create_destilado_button(item)
		destilados_grid.add_child(btn)

func _create_destilado_button(item: Dictionary) -> Button:
	const RARITY_COLORS = {"comun": Color(0.65,0.65,0.65), "poco_comun": Color(0.35,0.55,0.95),
		"raro": Color(0.9,0.75,0.2), "maldito": Color(0.7,0.2,0.85)}
	var data = GameManager.DESTILADO_DATA.get(item["id"], {})
	var rarity = data.get("rarity", "comun")
	var r_col = RARITY_COLORS.get(rarity, Color(0.5, 0.5, 0.5))

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(240, 54)

	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.07, 0.05, 0.12)
	n.set_border_width_all(1); n.border_color = r_col
	n.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", n)
	var h = n.duplicate(); h.bg_color = Color(0.12, 0.09, 0.2); h.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", h)
	var d = n.duplicate(); d.bg_color = Color(0.04,0.03,0.06); d.border_color = Color(0.2,0.2,0.2)
	btn.add_theme_stylebox_override("disabled", d)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var lbl_name = Label.new()
	lbl_name.text = item["label"].to_upper()
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 10)
	lbl_name.modulate = Color(0.95, 0.92, 0.85)
	vbox.add_child(lbl_name)

	var lbl_cost = Label.new()
	lbl_cost.text = "◈ %d Monedas  [%s]" % [item["cost"], rarity.replace("_", " ")]
	lbl_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cost.add_theme_font_size_override("font_size", 9)
	lbl_cost.modulate = r_col
	vbox.add_child(lbl_cost)

	var can_carry = GameManager.can_carry_destilado()
	var can_afford = GameManager.coins >= item["cost"]
	btn.disabled = not can_afford or not can_carry

	btn.mouse_entered.connect(func(): _show_dest_tooltip(item["id"], btn))
	btn.mouse_exited.connect(_hide_dest_tooltip)
	btn.pressed.connect(func(): _on_buy_destilado(item))
	return btn

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	shop_content = Control.new()
	shop_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shop_content)
	
	# --- MARCO DECORATIVO ---
	var border = ReferenceRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.editor_only = false; border.border_color = Color(0.2, 0.15, 0.05, 0.5); border.border_width = 10
	shop_content.add_child(border)

	# Header
	var title = Label.new()
	title.text = "☤ EL BUHONERO SIN ROSTRO ☤"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.85, 0.75, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40); title.size = Vector2(vp.x, 60)
	shop_content.add_child(title)

	# El Mercader (Area visual)
	var merchant_area = Panel.new()
	merchant_area.position = Vector2(vp.x * 0.1, 110); merchant_area.size = Vector2(vp.x * 0.8, 100)
	var ms = StyleBoxFlat.new(); ms.bg_color = Color(0.05, 0.04, 0.06); ms.set_corner_radius_all(10); ms.border_width_bottom = 2; ms.border_color = Color(0.3, 0.2, 0.4)
	merchant_area.add_theme_stylebox_override("panel", ms)
	shop_content.add_child(merchant_area)

	var greet_lbl = Label.new()
	greet_lbl.text = greeting
	greet_lbl.add_theme_font_size_override("font_size", 18)
	greet_lbl.modulate = Color(0.7, 0.6, 0.8)
	greet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greet_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	greet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	greet_lbl.size = merchant_area.size
	merchant_area.add_child(greet_lbl)

	# Stats Info
	var info = Label.new()
	info.name = "PlayerInfo"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 220); info.size = Vector2(vp.x, 30)
	info.modulate = Color(0.9, 0.9, 0.9)
	shop_content.add_child(info)

	# --- GRID DE ITEMS (Consumibles y Reliquias) ---
	var grid = GridContainer.new()
	grid.columns = 1
	grid.position = Vector2(vp.x * 0.1, 270)
	grid.size = Vector2(vp.x * 0.25, 300)
	grid.add_theme_constant_override("v_separation", 15)
	shop_content.add_child(grid)

	purchase_buttons.clear()
	for item in shop_items:
		var item_box = _create_shop_item_box(item)
		grid.add_child(item_box)
		purchase_buttons.append({"btn": item_box, "data": item})

	# --- SECCION CARTAS (Centro) ---
	var card_lbl = Label.new()
	card_lbl.text = "✦  PIEZAS EN VENTA  ✦"
	card_lbl.modulate = Color(0.4, 0.7, 0.9)
	card_lbl.position = Vector2(vp.x * 0.35, 270); card_lbl.size = Vector2(400, 30)
	card_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_content.add_child(card_lbl)
	
	card_shelf_container = HBoxContainer.new()
	card_shelf_container.position = Vector2(vp.x * 0.32, 310); card_shelf_container.size = Vector2(450, 200)
	card_shelf_container.add_theme_constant_override("separation", 15)
	shop_content.add_child(card_shelf_container)
	_build_card_shop(card_shelf_container)

	# --- BOTÓN REROLL CARTAS ---
	reroll_btn = Button.new()
	reroll_btn.text = "Otras cartas... (%d 🪙)" % reroll_cost
	reroll_btn.position = Vector2(vp.x * 0.35, vp.y - 98)
	reroll_btn.size = Vector2(400, 40)
	reroll_btn.add_theme_font_size_override("font_size", 14)
	var rb_style = StyleBoxFlat.new()
	rb_style.bg_color = Color(0.08, 0.06, 0.12)
	rb_style.set_corner_radius_all(5)
	rb_style.border_width_bottom = 2
	rb_style.border_color = Color(0.4, 0.3, 0.6)
	reroll_btn.add_theme_stylebox_override("normal", rb_style)
	shop_content.add_child(reroll_btn)
	reroll_btn.pressed.connect(_on_reroll_pressed)

	# --- SECCION SACRIFICIO (Derecha) ---
	var sac_container = VBoxContainer.new()
	sac_container.position = Vector2(vp.x * 0.75, 270); sac_container.size = Vector2(220, 300)
	sac_container.add_theme_constant_override("separation", 20)
	shop_content.add_child(sac_container)

	var sac_lbl = Label.new()
	sac_lbl.text = "💀  TRUEQUES  💀"
	sac_lbl.modulate = Color(0.8, 0.2, 0.2)
	sac_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sac_container.add_child(sac_lbl)

	btn_sell_mem = _create_sac_button("Vender un Recuerdo\n(+8 Monedas)", "Elimina una carta al azar de tu mazo.")
	btn_sell_mem.pressed.connect(_on_sell_memory)
	sac_container.add_child(btn_sell_mem)

	btn_sell_future = _create_sac_button("Vender tu Mañana\n(+12 Monedas)", "-10 Vida Máxima permanentemente.")
	btn_sell_future.pressed.connect(_on_sell_future)
	sac_container.add_child(btn_sell_future)

	# Boton Salir
	var btn_exit = Button.new()
	btn_exit.text = "DEJAR EL MERCADO"
	btn_exit.position = Vector2(vp.x/2 - 120, vp.y - 54); btn_exit.size = Vector2(240, 50)
	btn_exit.pressed.connect(func(): GameManager.go_to_scene("res://scenes/ui/Map.tscn"))
	_style_main_button(btn_exit, Color(0.15, 0.1, 0.05))
	shop_content.add_child(btn_exit)
	
	# Boton Ver Mazo
	var btn_view = Button.new()
	btn_view.text = "🎴 VER MAZO"
	btn_view.size = Vector2(180, 45)
	btn_view.position = Vector2(vp.x - 220, 40)
	btn_view.add_theme_font_size_override("font_size", 14)
	btn_view.pressed.connect(func(): GameManager.show_deck_overlay(self))
	shop_content.add_child(btn_view)

	_build_destilados_section(vp)

func _on_reroll_pressed() -> void:
	if GameManager.coins >= reroll_cost:
		GameManager.spend_coins(reroll_cost)
		reroll_cost += 25
		_generate_offered_cards()
		reroll_btn.text = "Otras cartas... (%d 🪙)" % reroll_cost
		reroll_btn.modulate = Color(1, 1, 1)
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
		_update_info()
	else:
		reroll_btn.modulate = Color(1, 0.3, 0.3)
		var tw = create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(func(): reroll_btn.modulate = Color(1, 1, 1))

func _build_card_shop(container: Control) -> void:
	for c in container.get_children(): c.queue_free()
	
	var card_scene = load("res://scenes/combat/Card.tscn")
	for i in range(offered_cards.size()):
		var card_data = offered_cards[i]
		if card_data["sold"]: continue
		
		var vbox = VBoxContainer.new()
		container.add_child(vbox)
		
		var card_node = card_scene.instantiate()
		vbox.add_child(card_node)
		card_node.setup(card_data)
		card_node.scale = Vector2(0.7, 0.7)
		card_node.custom_minimum_size = Vector2(130, 195)
		
		var buy_btn = Button.new()
		buy_btn.text = "COMPRAR: %d" % card_data["price"]
		buy_btn.disabled = GameManager.coins < card_data["price"]
		vbox.add_child(buy_btn)
		
		var idx = i
		buy_btn.pressed.connect(func():
			if GameManager.coins >= offered_cards[idx]["price"]:
				GameManager.spend_coins(offered_cards[idx]["price"])
				GameManager.add_card(offered_cards[idx])
				offered_cards[idx]["sold"] = true
				if get_node_or_null("/root/AudioManager"): AudioManager.play("button_click")
				_build_card_shop(container) # Refrescar esta seccion
				_update_info()
		)

func _create_shop_item_box(item: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(240, 80)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	var label = Label.new()
	label.text = item["label"].to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label)
	
	var cost_lbl = Label.new()
	cost_lbl.text = "◈ " + str(item["cost"]) + " Monedas"
	cost_lbl.modulate = Color(1, 0.8, 0.2)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)
	
	btn.tooltip_text = item["desc"]
	_style_item_button(btn)
	btn.pressed.connect(func(): _on_buy_pressed(item))
	return btn

func _create_sac_button(txt: String, tt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 80)
	btn.tooltip_text = tt
	_style_main_button(btn, Color(0.1, 0.02, 0.02))
	return btn

func _style_item_button(btn: Button) -> void:
	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.08, 0.08, 0.12); n.border_width_bottom = 3; n.border_color = Color(0.3, 0.3, 0.5); n.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", n)
	var h = n.duplicate(); h.bg_color = Color(0.15, 0.15, 0.25); h.border_color = Color(0.6, 0.6, 0.9)
	btn.add_theme_stylebox_override("hover", h)
	var d = n.duplicate()
	d.bg_color = Color(0.04, 0.04, 0.06)
	d.border_color = Color(0.15, 0.15, 0.2)
	btn.add_theme_stylebox_override("disabled", d)

func _style_main_button(btn: Button, color: Color) -> void:
	var n = StyleBoxFlat.new()
	n.bg_color = color; n.border_width_bottom = 2; n.border_color = color.lightened(0.2); n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", n)
	var h = n.duplicate(); h.bg_color = Color(0.15, 0.12, 0.05)
	btn.add_theme_stylebox_override("hover", h)

func _update_info() -> void:
	var info = shop_content.get_node_or_null("PlayerInfo")
	if info:
		info.text = "◈ MONEDAS: %d   ◈ VIDA: %d/%d   ◈ ENERGÍA: %d   📖 LORE: %d" % [GameManager.coins, GameManager.player_hp, GameManager.player_max_hp, GameManager.player_max_energy, GameManager.lore_progress]
	
	# Refrescar estantería de cartas para actualizar botones de compra según el oro nuevo
	if card_shelf_container:
		_build_card_shop(card_shelf_container)
	
	# Actualizar botones de compra
	for entry in purchase_buttons:
		var data = entry["data"]
		var btn = entry["btn"]
		var can_afford = GameManager.coins >= data["cost"]
		var is_full_hp = (data["action"] == "heal" and GameManager.player_hp >= GameManager.player_max_hp)
		
		btn.disabled = not can_afford or is_full_hp
		if is_full_hp:
			btn.tooltip_text = "Vida al maximo."
		else:
			btn.tooltip_text = data["desc"]
	
	# Actualizar sección destilados
	if destilados_grid and is_instance_valid(destilados_grid):
		_build_destilados_section(get_viewport_rect().size)

	# Actualizar botones de sacrificio
	if btn_sell_mem:
		btn_sell_mem.disabled = mem_sold or GameManager.player_deck.size() <= 3
		if mem_sold: btn_sell_mem.text = "VENDER RECUERDO\n(AGOTADO)"
	if btn_sell_future:
		btn_sell_future.disabled = future_sold or GameManager.player_max_hp <= 20
		if future_sold: btn_sell_future.text = "VENDER MAÑANA\n(AGOTADO)"

func _on_buy_pressed(item: Dictionary) -> void:
	if GameManager.coins >= item["cost"]:
		match item["action"]:
			"max_hp":
				GameManager.spend_coins(item["cost"])
				GameManager.player_max_hp += 15
				GameManager.player_hp += 15
			"heal":
				if GameManager.player_hp < GameManager.player_max_hp:
					GameManager.spend_coins(item["cost"])
					GameManager.heal(20)
				else:
					return
			"relic":
				var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
				if not available.is_empty():
					GameManager.spend_coins(item["cost"])
					available.shuffle()
					var r_id = available[0]
					GameManager.add_relic(r_id)
					_show_relic_modal(r_id)
					return
		
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
		_update_info()

func _show_dest_tooltip(dest_id: String, anchor: Control) -> void:
	if _dest_tooltip and is_instance_valid(_dest_tooltip):
		_dest_tooltip.queue_free()
	var data = GameManager.DESTILADO_DATA.get(dest_id, {})
	var rarity = data.get("rarity", "comun").replace("_", " ").to_upper()
	const RARITY_COLS = {"COMUN": Color(0.65,0.65,0.65), "POCO COMUN": Color(0.35,0.55,0.95),
		"RARO": Color(0.9,0.75,0.2), "MALDITO": Color(0.7,0.2,0.85)}
	var r_col = RARITY_COLS.get(rarity, Color(0.6, 0.5, 0.9))

	var txt = "[%s]\n%s\n\n\"%s\"" % [
		data.get("name", dest_id),
		data.get("desc", ""),
		data.get("flavor", "")
	]
	var est_lines = txt.count("\n") + int(txt.length() / 34) + 2
	var panel_h = max(100, est_lines * 15 + 24)
	var panel_w = 260

	_dest_tooltip = Panel.new()
	_dest_tooltip.z_index = 300
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.04, 0.03, 0.08, 0.97)
	ts.set_border_width_all(2); ts.border_color = r_col
	ts.set_corner_radius_all(4)
	_dest_tooltip.add_theme_stylebox_override("panel", ts)
	var lbl = Label.new()
	lbl.text = txt
	lbl.position = Vector2(10, 10)
	lbl.size = Vector2(panel_w - 20, panel_h - 20)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dest_tooltip.size = Vector2(panel_w, panel_h)
	_dest_tooltip.add_child(lbl)
	# Posicionar a la derecha del botón
	var global_pos = anchor.get_global_rect()
	_dest_tooltip.position = global_pos.position + Vector2(global_pos.size.x + 8, 0)
	# Ajuste si se sale de la pantalla
	var vp = get_viewport_rect().size
	if _dest_tooltip.position.x + panel_w > vp.x:
		_dest_tooltip.position.x = global_pos.position.x - panel_w - 8
	add_child(_dest_tooltip)
	_dest_tooltip.modulate.a = 0.0
	create_tween().tween_property(_dest_tooltip, "modulate:a", 1.0, 0.15)

func _hide_dest_tooltip() -> void:
	if _dest_tooltip and is_instance_valid(_dest_tooltip):
		_dest_tooltip.queue_free()
		_dest_tooltip = null

func _on_buy_destilado(item: Dictionary) -> void:
	if item["sold"] or not GameManager.can_carry_destilado():
		return
	if GameManager.spend_coins(item["cost"]):
		GameManager.add_destilado(item["id"])
		item["sold"] = true
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
		_build_destilados_section(get_viewport_rect().size)
		_update_info()

var mem_sold: bool = false
var future_sold: bool = false

func _on_sell_memory() -> void:
	if mem_sold: return
	if GameManager.player_deck.size() > 3:
		mem_sold = true
		var idx = randi() % GameManager.player_deck.size()
		var card_name = GameManager.player_deck[idx].get("name", "Pieza")
		GameManager.player_deck.remove_at(idx)
		GameManager.add_coins(8)
		
		var vp = get_viewport_rect().size
		var lbl = Label.new()
		lbl.text = "Recuerdo Olvidado: " + card_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, vp.y/2); lbl.size = Vector2(vp.x, 40)
		add_child(lbl)
		var tw = create_tween()
		tw.tween_property(lbl, "position:y", lbl.position.y - 100, 2.0)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 2.0)
		tw.tween_callback(lbl.queue_free)

		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
		_update_info()

func _on_sell_future() -> void:
	if future_sold: return
	if GameManager.player_max_hp > 20:
		future_sold = true
		GameManager.player_max_hp -= 10
		GameManager.player_hp = min(GameManager.player_hp, GameManager.player_max_hp)
		GameManager.add_coins(12)
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("agony_shriek")
		_update_info()


func _show_relic_modal(r_id: String) -> void:
	var vp = get_viewport_rect().size
	var r_data = GameManager.RELIC_DATA[r_id]
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = vp
	overlay.z_index = 100
	add_child(overlay)
	
	var modal = Panel.new()
	modal.size = Vector2(400, 300)
	modal.position = (vp - modal.size) / 2
	var ms = StyleBoxFlat.new(); ms.bg_color = Color(0.1, 0.08, 0.05); ms.set_border_width_all(2); ms.border_color = Color(0.8, 0.7, 0.2); ms.set_corner_radius_all(10)
	modal.add_theme_stylebox_override("panel", ms)
	overlay.add_child(modal)
	
	var title = Label.new()
	title.text = "¡NUEVA RELIQUIA!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20); title.size = Vector2(400, 40)
	title.modulate = Color(1, 0.9, 0.4)
	modal.add_child(title)
	
	var r_name = Label.new()
	r_name.text = r_data["name"].to_upper()
	r_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_name.position = Vector2(0, 70); r_name.size = Vector2(400, 30)
	modal.add_child(r_name)
	
	var r_desc = Label.new()
	r_desc.text = r_data["desc"]
	r_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	r_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var est_lines = r_desc.text.length() / 35 + r_desc.text.count("\n") + 1
	var desc_h = max(100, est_lines * 18)
	r_desc.position = Vector2(40, 110); r_desc.size = Vector2(320, desc_h)
	r_desc.modulate = Color(0.8, 0.8, 0.8)
	modal.add_child(r_desc)
	
	var btn = Button.new()
	btn.text = "ACEPTAR"
	btn.position = Vector2(125, 230); btn.size = Vector2(150, 40)
	modal.add_child(btn)
	
	btn.pressed.connect(func():
		overlay.queue_free()
		_update_info()
	)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("relic_get")
