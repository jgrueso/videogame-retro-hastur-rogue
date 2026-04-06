extends Node

# Este script maneja toda la representación visual del combate
# para que Combat.gd se centre únicamente en la lógica del juego.

const COMBAT_FLAVOR: Dictionary = {
	"default": [
		"El tablero exige sangre. Como siempre.",
		"Cada golpe es una oración al vacío.",
		"La partida continúa, quieras o no.",
	],
	"low_hp": [
		"Tu cuerpo recuerda cada herida. Tu mente empieza a olvidar por qué luchas.",
		"Quedan pocas piezas. El tablero ya sabe quién ganará.",
		"La carne es débil. Y el tablero lo sabe.",
		"¿Para qué seguir? El final ya fue escrito.",
	],
	"low_sanity": [
		"Las voces tienen razón. Siempre tuvieron razón.",
		"El ojo te observa. Lleva haciéndolo desde que naciste.",
		"Ya no distingues el combate de los sueños. ¿Importa la diferencia?",
		"Algo te susurra el nombre del siguiente movimiento. No era tu idea.",
	],
	"enemy_intro": {
		"default": "Una presencia del tablero se manifiesta.",
		"El Conquistador Fantasma": "El Conquistador reconoce el eco de su propio error.",
		"El Inquisidor": "El Inquisidor ya ha juzgado. Solo falta la sentencia.",
		"La Dama": "La Dama del Tablero mueve sus piezas sin mirarte.",
		"El Centinela": "El Centinela ha esperado este momento desde el principio.",
		"Avatar del Rey": "El tablero tiembla. La partida final ha comenzado.",
		"El Rey Amarillo": "Carcosa reclama lo que siempre fue suyo.",
		"El Testigo": "Ha visto cada una de tus muertes anteriores. Te recuerda bien.",
	}
}

var main: Node2D # Referencia al script principal de Combat

# Referencias a nodos de UI (serán inicializados en build_ui)
var player_panel: Panel
var player_sprite_label: Label
var lbl_player_hp: RichTextLabel
var lbl_sanity: Label
var hp_bar_player: ProgressBar
var sanity_bar_player: ProgressBar
var lbl_energy: Label
var lbl_furia: Label
var lbl_fervor: Label
var _fervor_last_san: int = -1
var _fervor_last_spent: bool = false
var _last_hp: int = -1
var _last_hand_size: int = -1
var hand_container: Control
var lbl_draw_pile: Label
var lbl_discard_pile: Label
var end_turn_btn: Button
var relics_container: HBoxContainer
var destilados_container: VBoxContainer
var vignette: ColorRect
var eye_node: Control
var blink_overlay: ColorRect
var targeting_arrow: Line2D
var targeting_arrow_head: Line2D

# --- Target highlight ---
var _target_highlight_style: Dictionary = {}   # panel -> StyleBoxFlat original
var _target_highlight_tween: Tween = null
var _currently_highlighted: Panel = null

# --- Energía visual (dots) ---
var energy_dots: Array = []

# --- Pulso de cordura crítica ---
var _sanity_pulse_tween: Tween = null
var _sanity_fill_style: StyleBoxFlat = null
var _vignette_pulse_tween: Tween = null

# --- Marca del Vacío (carta maldita) ---
var _cursed_card_index: int = -1
var _cursed_card_node = null
var _cursed_overlay_tween: Tween = null

# --- Estado de animación de barras de vida ---
var _bar_tweens: Dictionary = {}         # ProgressBar -> Tween activo
var _ghost_bar_tweens: Dictionary = {}   # ProgressBar -> Tween (drain)
var _ghost_bar_delays: Dictionary = {}   # ProgressBar -> Tween (delay timer)
var ghost_bar_player: ProgressBar = null
var shield_bar_player: ProgressBar
var _player_panel_style: StyleBoxFlat = null
var _low_hp_pulse_tween: Tween = null
var _char_color: Color = Color(0.45, 0.35, 0.65)

func setup(p_main: Node2D) -> void:
	main = p_main

func build_ui(vp: Vector2) -> void:
	_build_dynamic_background(vp)

	# ── Panel del jugador compacto con retrato ───────────────────────────────
	const PP_W   = 295
	const PP_H   = 112
	const PORT_W = 72   # Ancho del área de retrato
	const ST_X   = 80   # X de inicio de stats (PORT_W + margen)
	const BAR_W  = 208  # PP_W - ST_X - 7

	var char_id = GameManager.selected_character
	var char_info = CombatData.CHAR_DATA.get(char_id, {"symbol": "♟", "color": Color(0.8, 0.8, 0.8)})
	_char_color = char_info["color"]

	var _pp_style = StyleBoxFlat.new()
	_pp_style.bg_color = Color(_char_color.r * 0.15, _char_color.g * 0.12, _char_color.b * 0.25, 1.0)
	_pp_style.set_border_width_all(2)
	_pp_style.border_color = _char_color
	_pp_style.set_corner_radius_all(4)
	player_panel = Panel.new()
	player_panel.position = Vector2(20, 280)
	player_panel.size = Vector2(PP_W, PP_H)
	player_panel.add_theme_stylebox_override("panel", _pp_style)
	_player_panel_style = _pp_style
	main.add_child(player_panel)

	# Contenedor de retrato — sirve como sprite_label para bob e interacción
	player_sprite_label = Label.new()
	player_sprite_label.text = ""   # Sin símbolo — el retrato lo reemplaza
	player_sprite_label.position = Vector2(3, 4)
	player_sprite_label.size = Vector2(PORT_W, PP_H - 8)
	player_sprite_label.mouse_filter = Control.MOUSE_FILTER_STOP
	player_panel.add_child(player_sprite_label)

	# Retrato clipeado dentro del contenedor
	var port_clip = Control.new()
	port_clip.clip_contents = true
	port_clip.position = Vector2(0, 0)
	port_clip.size = Vector2(PORT_W, PP_H - 8)
	port_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_sprite_label.add_child(port_clip)

	var port_bg = ColorRect.new()
	port_bg.color = Color(0.04, 0.03, 0.06)
	port_bg.size = port_clip.size
	port_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_clip.add_child(port_bg)

	var portrait_path = "res://assets/characters/%s.png" % char_id
	if ResourceLoader.exists(portrait_path):
		var portrait_tex = TextureRect.new()
		portrait_tex.texture = load(portrait_path)
		portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait_tex.size = port_clip.size
		portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		port_clip.add_child(portrait_tex)

	# Borde del retrato con color del personaje
	var port_border = Panel.new()
	port_border.position = Vector2(0, 0)
	port_border.size = Vector2(PORT_W, PP_H - 8)
	port_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb_style = StyleBoxFlat.new()
	pb_style.bg_color = Color(0, 0, 0, 0)
	pb_style.set_border_width_all(2)
	pb_style.border_color = char_info["color"]
	pb_style.set_corner_radius_all(2)
	port_border.add_theme_stylebox_override("panel", pb_style)
	player_sprite_label.add_child(port_border)

	# Panel invisible sobre el retrato para detección de hover confiable
	var portrait_hover = Panel.new()
	portrait_hover.position = Vector2(3, 4)
	portrait_hover.size = Vector2(PORT_W, PP_H - 8)
	portrait_hover.mouse_filter = Control.MOUSE_FILTER_STOP
	var ph_style = StyleBoxFlat.new()
	ph_style.bg_color = Color(0, 0, 0, 0)
	ph_style.set_border_width_all(0)
	portrait_hover.add_theme_stylebox_override("panel", ph_style)
	portrait_hover.mouse_entered.connect(main._show_player_passive_tooltip)
	portrait_hover.mouse_exited.connect(main._hide_player_passive_tooltip)
	player_panel.add_child(portrait_hover)

	main._start_player_idle_bob()

	# ── Barras de HP / Escudo ──
	ghost_bar_player = _make_ghost_bar(main.player_max_hp, BAR_W, 6)
	ghost_bar_player.position = Vector2(ST_X, 26)
	player_panel.add_child(ghost_bar_player)

	hp_bar_player = _make_hp_bar(main.player_max_hp, BAR_W, 6)
	hp_bar_player.position = Vector2(ST_X, 26)
	player_panel.add_child(hp_bar_player)

	shield_bar_player = _make_shield_bar(main.player_max_hp, BAR_W, 5)
	shield_bar_player.position = Vector2(ST_X, 26)
	player_panel.add_child(shield_bar_player)

	# ── Barra de Cordura ──
	sanity_bar_player = _make_hp_bar(100, BAR_W, 5)
	sanity_bar_player.position = Vector2(ST_X, 55)
	player_panel.add_child(sanity_bar_player)
	var sb_style = StyleBoxFlat.new(); sb_style.bg_color = Color(0.04, 0.01, 0.1); sb_style.set_corner_radius_all(2)
	sb_style.set_content_margin_all(0)
	var sb_fill = StyleBoxFlat.new(); sb_fill.bg_color = Color(0.38, 0.1, 0.68)
	sb_fill.set_content_margin_all(0)
	sanity_bar_player.add_theme_stylebox_override("background", sb_style)
	sanity_bar_player.add_theme_stylebox_override("fill", sb_fill)
	_sanity_fill_style = sb_fill

	# ── Labels ──
	lbl_player_hp = RichTextLabel.new()
	lbl_player_hp.position = Vector2(ST_X, 8)
	lbl_player_hp.size = Vector2(BAR_W, 18)
	lbl_player_hp.bbcode_enabled = true
	lbl_player_hp.scroll_active = false
	lbl_player_hp.add_theme_font_size_override("font_size", 11)
	player_panel.add_child(lbl_player_hp)

	lbl_sanity = Label.new()
	lbl_sanity.position = Vector2(ST_X, 37)
	lbl_sanity.size = Vector2(BAR_W, 18)
	lbl_sanity.add_theme_font_size_override("font_size", 11)
	player_panel.add_child(lbl_sanity)

	var lbl_energy_title = Label.new()
	lbl_energy_title.text = "ENERGÍA"
	lbl_energy_title.position = Vector2(ST_X, 66)
	lbl_energy_title.add_theme_font_size_override("font_size", 9)
	lbl_energy_title.modulate = Color(0.7, 0.6, 0.3)
	player_panel.add_child(lbl_energy_title)

	lbl_energy = Label.new()
	lbl_energy.position = Vector2(ST_X + 56, 64)
	lbl_energy.add_theme_font_size_override("font_size", 9)
	player_panel.add_child(lbl_energy)

	if char_id == "guardian":
		player_panel.size.y = 126
		lbl_furia = Label.new()
		lbl_furia.position = Vector2(ST_X, 104)
		lbl_furia.size = Vector2(BAR_W, 18)
		lbl_furia.add_theme_font_size_override("font_size", 10)
		lbl_furia.modulate = Color(0.4, 0.9, 0.4)
		player_panel.add_child(lbl_furia)

	if char_id == "mahar":
		player_panel.size.y = 126
		lbl_fervor = Label.new()
		lbl_fervor.name = "LblFervor"
		lbl_fervor.position = Vector2(ST_X, 104)
		lbl_fervor.size = Vector2(BAR_W, 18)
		lbl_fervor.add_theme_font_size_override("font_size", 10)
		player_panel.add_child(lbl_fervor)

	hand_container = Control.new()
	hand_container.position = Vector2(20, 418); hand_container.size = Vector2(1112, 195)
	main.add_child(hand_container)

	lbl_draw_pile    = _make_pile_label(Vector2(950, 540), Color(0.7, 0.7, 0.9))
	lbl_discard_pile = _make_pile_label(Vector2(950, 575), Color(0.6, 0.5, 0.4))
	main.add_child(lbl_draw_pile); main.add_child(lbl_discard_pile)

	end_turn_btn = Button.new(); end_turn_btn.text = "TERMINAR TURNO"
	end_turn_btn.position = Vector2(900, 480); end_turn_btn.size = Vector2(230, 50)
	end_turn_btn.pressed.connect(main._on_end_turn_button_pressed); main.add_child(end_turn_btn)

	# Paneles enemigos
	for i in range(main.enemies.size()):
		var is_peaceful = main.enemies[i].peaceful
		var border_col = Color(0.2, 0.5, 0.2) if is_peaceful else Color(0.6, 0.2, 0.2)
		var bg_col     = Color(0.04, 0.1, 0.04) if is_peaceful else Color(0.1, 0.05, 0.05)
		var ep = _make_panel(Vector2(650 + i*220, 80), Vector2(200, 270), bg_col, border_col)
		ep.mouse_filter = Control.MOUSE_FILTER_PASS
		main.add_child(ep); main.enemies[i].panel = ep

		# Conectar señales para Tooltips de Intencion
		var idx = i
		ep.mouse_entered.connect(func(): main._show_enemy_intent_tooltip(idx))
		ep.mouse_exited.connect(func(): main._hide_enemy_intent_tooltip(idx))

		var en = Label.new(); en.text = main.enemies[i].name
		en.position = Vector2(0, 8); en.size = Vector2(200, 30)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en.add_theme_font_size_override("font_size", 11)
		en.modulate = Color(0.5, 1.0, 0.5) if is_peaceful else Color.WHITE
		ep.add_child(en); main.enemies[i].lbl_name = en

		var esl = load("res://scripts/EnemySprite.gd").new() # Debemos cargarlo
		esl.position = Vector2(0, 38)
		esl.size = Vector2(200, 130)
		esl.setup(main.enemies[i].name)
		ep.add_child(esl); main.enemies[i].sprite_label = esl

		var elh = Label.new(); elh.position = Vector2(10, 175); elh.size = Vector2(180, 20); ep.add_child(elh); main.enemies[i].lbl_hp = elh
		var ebl = Label.new(); ebl.position = Vector2(10, 195); ebl.size = Vector2(180, 20)
		ebl.modulate = Color(0.4, 0.7, 1.0); ep.add_child(ebl); main.enemies[i].lbl_shield = ebl

		# Barra fantasma del enemigo (debajo de la barra principal)
		var eg = _make_ghost_bar(main.enemies[i].max_hp, 160, 4)
		eg.position = Vector2(18, 198)
		ep.add_child(eg)
		main.enemies[i].ghost_bar = eg

		var eh = _make_hp_bar(main.enemies[i].max_hp, 160, 4)
		eh.position = Vector2(18, 198)
		ep.add_child(eh)
		main.enemies[i].hp_bar = eh

		var esh = _make_shield_bar(main.enemies[i].max_hp, 160, 4)
		esh.position = Vector2(18, 198)
		ep.add_child(esh)
		main.enemies[i].shield_bar = esh

		# lbl_status se añade DESPUÉS de las barras para quedar encima en z-order
		var est = Label.new()
		est.position = Vector2(10, 212)
		est.size = Vector2(180, 14)
		est.add_theme_font_size_override("font_size", 12)
		est.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ep.add_child(est)
		main.enemies[i].lbl_status = est
		var idx3 = i
		est.mouse_filter = Control.MOUSE_FILTER_PASS
		est.mouse_entered.connect(func(): main._show_enemy_intent_tooltip(idx3))
		est.mouse_exited.connect(func(): main._hide_enemy_intent_tooltip(idx3))

		var intent_badge = Panel.new()
		intent_badge.position = Vector2(10, 244)
		intent_badge.size = Vector2(180, 26)
		var ib_style = StyleBoxFlat.new()
		ib_style.bg_color = Color(0.3, 0.1, 0.1, 0.0)
		ib_style.set_corner_radius_all(4)
		intent_badge.add_theme_stylebox_override("panel", ib_style)
		ep.add_child(intent_badge)
		main.enemies[i].intent_badge = intent_badge
		main.enemies[i].intent_badge_style = ib_style

		var lin = Label.new(); lin.position = Vector2(10, 246); lin.size = Vector2(180, 22)
		lin.clip_text = true
		lin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lin.add_theme_font_size_override("font_size", 13)
		ep.add_child(lin); main.enemies[i].lbl_intent_icon = lin

	targeting_arrow = Line2D.new(); targeting_arrow.width = 4
	targeting_arrow.default_color = Color(1, 0.8, 0.2); targeting_arrow.visible = false; main.add_child(targeting_arrow)

	targeting_arrow_head = Line2D.new()
	targeting_arrow_head.width = 8
	targeting_arrow_head.default_color = Color(1.0, 0.9, 0.3)
	targeting_arrow_head.visible = false
	targeting_arrow_head.z_index = 5
	main.add_child(targeting_arrow_head)

	relics_container = HBoxContainer.new()
	relics_container.position = Vector2(10, 10)
	relics_container.add_theme_constant_override("separation", 6)
	main.add_child(relics_container)
	main._populate_relics()

	# Slots de Destilados (a la derecha del panel compacto del jugador)
	destilados_container = VBoxContainer.new()
	destilados_container.position = Vector2(322, 280)
	destilados_container.add_theme_constant_override("separation", 4)
	main.add_child(destilados_container)

	# Viñeta de Cordura
	vignette = ColorRect.new()
	vignette.size = vp
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0, 0, 0, 0) # Empieza invisible
	vignette.z_index = 40 # Encima de todo menos mensajes criticos
	main.add_child(vignette)

	blink_overlay = ColorRect.new()
	blink_overlay.size = vp
	blink_overlay.color = Color.BLACK
	blink_overlay.visible = false
	blink_overlay.z_index = 60 # El parpadeo tapa todo
	blink_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(blink_overlay)

	var dev_toggle = Button.new(); dev_toggle.text = "[DEV]"
	dev_toggle.position = Vector2(vp.x - 80, vp.y - 36); dev_toggle.size = Vector2(75, 30)
	dev_toggle.modulate = Color(0.5, 0.5, 0.5, 0.45)
	main.add_child(dev_toggle)

	# Botón Visor de Mazo
	var deck_btn = Button.new()
	deck_btn.text = " ▣ VER MAZO "
	deck_btn.position = Vector2(vp.x - 160, 10); deck_btn.size = Vector2(150, 40)
	deck_btn.add_theme_font_size_override("font_size", 14)
	main.add_child(deck_btn)
	deck_btn.pressed.connect(func(): GameManager.show_deck_overlay(main))

	var dev_panel = main._build_dev_panel(vp)
	dev_panel.visible = false
	main.add_child(dev_panel)
	dev_toggle.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)

func _build_dynamic_background(vp: Vector2) -> void:
	var is_w2 = GameManager.current_world == 1
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02) if not is_w2 else Color(0.04, 0.03, 0.01)
	bg.size = vp; bg.z_index = -10; main.add_child(bg)
	var sz = 450.0 if not is_w2 else 650.0
	var sun = Panel.new(); sun.size = Vector2(sz, sz); sun.position = Vector2(vp.x/2 - sz/2, -100)
	var sun_st = StyleBoxFlat.new(); sun_st.bg_color = Color(0,0,0)
	sun_st.set_corner_radius_all(sz/2); sun_st.border_width_left = 4
	sun_st.border_color = Color(0.9, 0.6, 0.1, 0.3)
	sun.add_theme_stylebox_override("panel", sun_st); sun.z_index = -9; main.add_child(sun)

	# El Ojo del Vacio (REDISEÑO GIGANTE)
	eye_node = Control.new()
	eye_node.position = sun.position + sun.size/2
	eye_node.z_index = -8; eye_node.modulate.a = 0.0
	main.add_child(eye_node)

	var eye_w = 320.0
	var eye_h = 160.0

	var eye_bg = Panel.new() # Esclerotica (Almendra simetrica)
	eye_bg.name = "EyeBg"
	eye_bg.size = Vector2(eye_w, eye_h); eye_bg.position = -eye_bg.size/2
	var es = StyleBoxFlat.new(); es.bg_color = Color(0.85, 0.8, 0.6)
	es.set_corner_radius_all(160) # Simplificado para evitar constantes no definidas
	es.border_width_left = 2; es.border_width_right = 2
	es.border_color = Color(0.2, 0.1, 0.0)
	eye_bg.add_theme_stylebox_override("panel", es); eye_node.add_child(eye_bg)

	var iris = Panel.new() # Iris Ambar
	iris.size = Vector2(140, 140); iris.position = -iris.size/2
	var is_style = StyleBoxFlat.new(); is_style.bg_color = Color(0.7, 0.4, 0.1); is_style.set_corner_radius_all(70)
	is_style.border_width_left = 10; is_style.border_color = Color(0.4, 0.2, 0.0)
	iris.add_theme_stylebox_override("panel", is_style); eye_node.add_child(iris); iris.name = "Iris"

	var pupil = Panel.new() # Pupila Rasgada (como gato/reptil)
	pupil.size = Vector2(45, 110); pupil.position = -pupil.size/2
	var ps = StyleBoxFlat.new(); ps.bg_color = Color(0,0,0); ps.set_corner_radius_all(22)
	pupil.add_theme_stylebox_override("panel", ps); iris.add_child(pupil); pupil.name = "Pupil"

	# VENAS (bloodshot) - se vuelven visibles con baja cordura
	for vi in range(5):
		var vein = ColorRect.new()
		vein.name = "Vein%d" % vi
		var angle = vi * (TAU / 5.0) + 0.3
		vein.size = Vector2(randf_range(28, 48), 2)
		vein.pivot_offset = Vector2(0, 1)
		vein.rotation = angle
		vein.position = Vector2(cos(angle) * 52, sin(angle) * 28) - Vector2(0, 1)
		vein.color = Color(0.75, 0.05, 0.05, 0.0)  # Invisible al inicio
		eye_node.add_child(vein)

	var lid_top = ColorRect.new() # Parpado superior mas grueso
	lid_top.size = Vector2(eye_w + 40, eye_h); lid_top.position = Vector2(-eye_w/2 - 20, -eye_h - 20); lid_top.color = Color.BLACK
	eye_node.add_child(lid_top); lid_top.name = "LidTop"

	var lid_bot = ColorRect.new() # Parpado inferior mas grueso
	lid_bot.size = Vector2(eye_w + 40, eye_h); lid_bot.position = Vector2(-eye_w/2 - 20, eye_h/2 + 10); lid_bot.color = Color.BLACK
	eye_node.add_child(lid_bot); lid_bot.name = "LidBot"

	main._start_eye_blink_loop()
	# Lluvia de fondo
	var is_avatar = not main.enemies.is_empty() and "AVATAR" in main.enemies[0].name.to_upper()

	var rain_color = Color(0.8, 0.1, 0.1, 0.35) if is_avatar else Color(0.5, 0.5, 0.75, 0.12)
	var gpu_rain = GPUParticles2D.new()
	gpu_rain.position = Vector2(vp.x * 0.5, -5.0)
	gpu_rain.z_index = -8
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(vp.x * 0.5, 1.0, 0.0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 0.0
	mat.initial_velocity_min = 600.0
	mat.initial_velocity_max = 950.0
	mat.gravity = Vector3.ZERO
	mat.color = rain_color
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	gpu_rain.process_material = mat
	gpu_rain.amount = 60
	gpu_rain.lifetime = vp.y / 750.0
	gpu_rain.one_shot = false
	gpu_rain.emitting = true
	main.add_child(gpu_rain)

func update_ui() -> void:
	var hp_text = "SALUD: %d / %d" % [max(0, main.player_hp), main.player_max_hp]
	if main.player_shield > 0:
		hp_text += " [color=#66ccff][font_size=9](+%d🛡)[/font_size][/color]" % main.player_shield

	lbl_player_hp.text = hp_text

	# Animación de la barra de vida del jugador
	hp_bar_player.max_value = main.player_max_hp
	var player_ratio = float(main.player_hp) / float(main.player_max_hp)
	var old_player_val = hp_bar_player.value
	var heal_player = main.player_hp > old_player_val
	_set_bar_color(hp_bar_player, player_ratio)
	var player_duration = 0.5 if heal_player else 0.3
	_animate_bar_to(hp_bar_player, main.player_hp, player_duration)
	_update_ghost_bar(ghost_bar_player, main.player_hp)
	shield_bar_player.max_value = main.player_max_hp
	shield_bar_player.value = main.player_shield
	if heal_player:
		_flash_heal(hp_bar_player, player_ratio)

	# Pulso crítico de HP
	if player_ratio < 0.25:
		_start_low_hp_pulse()
	else:
		_stop_low_hp_pulse()

	sanity_bar_player.max_value = GameManager.max_sanity
	_animate_bar_to(sanity_bar_player, GameManager.sanity, 0.3)

	var sanity_label = GameManager.get_sanity_label()
	lbl_sanity.text = "%s: %d / %d" % [sanity_label, GameManager.sanity, GameManager.max_sanity]
	var pulse_threshold: int
	if GameManager.selected_character == "prince":
		if GameManager.sanity < 35:
			lbl_sanity.modulate = Color(0.9, 0.5, 1.0)    # Violeta eléctrico — RESONANCIA
		elif GameManager.sanity < 60:
			lbl_sanity.modulate = Color(0.7, 0.4, 1.0)    # Violeta — Sombra
		else:
			lbl_sanity.modulate = Color(0.6, 0.5, 0.8)    # Muted
		pulse_threshold = 60
	else:
		if GameManager.sanity < 40:
			lbl_sanity.modulate = Color(0.8, 0.4, 1.0)
		else:
			lbl_sanity.modulate = Color(0.6, 0.5, 0.8)
		pulse_threshold = 30

	if GameManager.sanity < pulse_threshold:
		_start_sanity_pulse()
	else:
		_stop_sanity_pulse()

	_update_energy_dots(main.player_energy, main.player_max_energy)
	lbl_energy.text = ""
	if GameManager.mark_level > 0: lbl_energy.text = "(Signo Lv%d)" % GameManager.mark_level

	if lbl_furia:
		lbl_furia.text = "FURIA: %d/3" % main.furia_points
		lbl_furia.visible = true
		if main.furia_points >= 3:
			lbl_furia.modulate = Color(1.0, 0.4, 0.1)
		elif main.furia_points > 0:
			lbl_furia.modulate = Color(0.7, 0.9, 0.3)
		else:
			lbl_furia.modulate = Color(0.4, 0.5, 0.4, 0.7)

	if lbl_fervor:
		var san = GameManager.sanity
		var spent = main.mahar_guided_struck
		if san >= 60:
			lbl_fervor.text = "✦ FERVOR: Usado" if spent else "✦ FERVOR: Listo"
			lbl_fervor.modulate = Color(0.45, 0.38, 0.18, 0.65) if spent else Color(1.0, 0.75, 0.15)
		elif san < 40:
			lbl_fervor.text = "✦ FE ROTA: +2 ATK"
			lbl_fervor.modulate = Color(0.85, 0.35, 0.35)
		else:
			lbl_fervor.text = "✦ FERVOR: Inactivo"
			lbl_fervor.modulate = Color(0.35, 0.32, 0.28, 0.5)

		if san != _fervor_last_san or spent != _fervor_last_spent:
			_fervor_last_san = san
			_fervor_last_spent = spent
			main.update_card_states()

	var cur_hp = main.player_hp
	var cur_hs = main.hand_container.get_child_count() if main.hand_container else 0
	if cur_hp != _last_hp or cur_hs != _last_hand_size:
		_last_hp = cur_hp
		_last_hand_size = cur_hs
		main.update_card_states()

	lbl_draw_pile.text    = "MAZO: %d" % main.draw_pile.size()
	lbl_discard_pile.text = "DESC: %d" % main.discard_pile.size()

	for i in range(main.enemies.size()):
		var e = main.enemies[i]
		if not e.panel: continue

		if e.hp <= 0:
			e.panel.visible = false
			continue

		e.lbl_hp.text = "HP: %d / %d" % [e.hp, e.max_hp]
		e.hp_bar.max_value = e.max_hp
		var enemy_ratio = float(e.hp) / float(e.max_hp)
		var old_enemy_val = e.hp_bar.value
		var heal_enemy = e.hp > old_enemy_val
		_set_bar_color(e.hp_bar, enemy_ratio)
		var enemy_duration = 0.5 if heal_enemy else 0.3
		_animate_bar_to(e.hp_bar, e.hp, enemy_duration)
		if e.get("ghost_bar"):
			_update_ghost_bar(e.ghost_bar, e.hp)

		if e.get("shield_bar"):
			e.shield_bar.max_value = e.max_hp
			e.shield_bar.value = e.shield
		if e.shield > 0:
			e.lbl_shield.text = "ESCUDO: %d" % e.shield
			e.lbl_shield.visible = true
		else:
			e.lbl_shield.visible = false

		# Estados activos del enemigo
		var status_parts = []
		if e.get("bleed", 0) > 0:
			status_parts.append("🩸%d" % e["bleed"])
		if e.get("atk_reduction", 0) > 0:
			status_parts.append("⚡-%d" % e["atk_reduction"])
		if e.get("is_stunned", false):
			status_parts.append("💫")
		if e.get("lbl_status"):
			e.lbl_status.text = "  ".join(status_parts)
			e.lbl_status.visible = not status_parts.is_empty()

	# Represalia: reducir coste visualmente cuando el escudo está activo
	for card in hand_container.get_children():
		if card.card_data.get("cost_reduction_if_shield", 0) > 0:
			var mod = -card.card_data["cost_reduction_if_shield"] if main.player_shield > 0 else 0
			card.set_cost_modifier(mod)

# --- Funciones de animación de barras ---

func _animate_bar_to(bar: ProgressBar, target: float, duration: float = 0.35) -> void:
	if _bar_tweens.has(bar) and _bar_tweens[bar] != null:
		_bar_tweens[bar].kill()
	var tw = main.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar, "value", target, duration)
	_bar_tweens[bar] = tw

func _update_ghost_bar(ghost: ProgressBar, target: float) -> void:
	if target >= ghost.value:
		# Curación: sincronizar ghost inmediatamente
		if _ghost_bar_delays.has(ghost) and _ghost_bar_delays[ghost] != null:
			_ghost_bar_delays[ghost].kill()
		if _ghost_bar_tweens.has(ghost) and _ghost_bar_tweens[ghost] != null:
			_ghost_bar_tweens[ghost].kill()
		ghost.value = target
		return
	# Daño: esperar 0.45s luego drenar en 0.6s
	if _ghost_bar_delays.has(ghost) and _ghost_bar_delays[ghost] != null:
		_ghost_bar_delays[ghost].kill()
	var delay_tw = main.create_tween()
	delay_tw.tween_interval(0.45)
	delay_tw.tween_callback(func():
		if _ghost_bar_tweens.has(ghost) and _ghost_bar_tweens[ghost] != null:
			_ghost_bar_tweens[ghost].kill()
		var drain = main.create_tween()
		drain.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drain.tween_property(ghost, "value", target, 0.6)
		_ghost_bar_tweens[ghost] = drain
	)
	_ghost_bar_delays[ghost] = delay_tw

func _get_hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.72, 0.08, 0.08)   # Carmesí oscuro — sangre
	elif ratio > 0.3:
		return Color(0.78, 0.32, 0.04)   # Ámbar quemado
	else:
		return Color(0.92, 0.04, 0.04)   # Carmesí brillante crítico

func _set_bar_color(bar: ProgressBar, ratio: float) -> void:
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = _get_hp_color(ratio)
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", s_fg)

func _flash_heal(bar: ProgressBar, final_ratio: float) -> void:
	var flash = StyleBoxFlat.new()
	flash.bg_color = Color(0.9, 0.3, 0.3)   # Rosa-carmesí (curación)
	flash.set_corner_radius_all(2)
	flash.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", flash)
	var target_color = _get_hp_color(final_ratio)
	var tw = main.create_tween()
	tw.tween_method(func(c: Color): flash.bg_color = c,
		Color(0.9, 0.3, 0.3), target_color, 0.4)

func _start_low_hp_pulse() -> void:
	if _low_hp_pulse_tween != null and _low_hp_pulse_tween.is_running():
		return
	if _low_hp_pulse_tween != null:
		_low_hp_pulse_tween.kill()
	_low_hp_pulse_tween = main.create_tween().set_loops()
	_low_hp_pulse_tween.tween_method(
		func(c: Color): _player_panel_style.border_color = c,
		_char_color, Color(0.9, 0.1, 0.1), 0.5)
	_low_hp_pulse_tween.tween_method(
		func(c: Color): _player_panel_style.border_color = c,
		Color(0.9, 0.1, 0.1), _char_color, 0.5)

func _stop_low_hp_pulse() -> void:
	if _low_hp_pulse_tween != null:
		_low_hp_pulse_tween.kill()
		_low_hp_pulse_tween = null
	if _player_panel_style != null:
		_player_panel_style.border_color = _char_color

func update_intent_labels() -> void:
	var has_manual = GameManager.has_relic("manual_anatomista")
	for e in main.enemies:
		if e.hp <= 0 or not e.get("lbl_intent_icon"): continue

		# Corrupción del nombre enemigo a cordura extremadamente baja
		if GameManager.sanity < 15 and e.get("lbl_name"):
			var corrupt_names = ["ᛗᚾᛁ ᛖᚷ", "EL MISMO", "TÚ", "ᚦᛟᚱ ᚠᛒ", "..."]
			e.lbl_name.text = corrupt_names[randi() % corrupt_names.size()]
			e.lbl_name.modulate = Color(0.7, 0.1, 0.7)
		elif e.get("lbl_name") and e.lbl_name.modulate != Color.WHITE and e.lbl_name.modulate != Color(0.5, 1.0, 0.5):
			e.lbl_name.text = e.name
			e.lbl_name.modulate = Color.WHITE

		# Logica de Intenciones Corruptas por Locura (Respetar Manual del Anatomista)
		if GameManager.sanity < 20 and not has_manual:
			var creepy = ["ᚠᛒ ᛈᛇᚦ", "ᛟᛗ ᚾᛁᛖ", "...", "ᚷᛃ ᚹᚫᛤ", "INEVITABLE", "ᛞᚣᛝ ᚪᛠ"]
			e.lbl_intent_icon.text = creepy[randi() % creepy.size()]
			e.lbl_intent_icon.modulate = Color(0.8, 0.2, 0.2)
			if e.get("intent_badge_style"):
				e.intent_badge_style.bg_color = Color(0.4, 0.05, 0.4, 0.7)
			continue

		if e.peaceful:
			if e.name == "El Penitente":
				var thought = main._get_penitente_thought()
				var display_text = main._get_deciphered_thought(thought)
				if display_text.length() > 18:
					display_text = display_text.substr(0, 18) + "…"
				e.lbl_intent_icon.text = display_text + " (" + str(e.peaceful_turns) + ")"
				e.lbl_intent_icon.modulate = Color(0.9, 0.8, 0.2) # Amarillo
				if e.get("intent_badge_style"):
					e.intent_badge_style.bg_color = Color(0.3, 0.1, 0.1, 0.0)
				continue

		# Intencion normal
		var action = e.pattern[e.turn_index % e.pattern.size()]
		var icon = ""
		var col = Color.WHITE
		var badge_col = Color(0.3, 0.1, 0.1, 0.0)

		match action.type:
			"attack":
				var reduction = e.get("atk_reduction", 0)
				var final_dmg = max(0, action.value - reduction)
				icon = "⚔ " + str(final_dmg)
				if reduction > 0:
					col = Color(0.5, 1.0, 0.5) # Verde si está debilitado
					icon += " (-" + str(reduction) + ")"
				else:
					col = Color(1, 0.4, 0.4)
				badge_col = Color(0.5, 0.08, 0.08, 0.7)
			"shield":
				icon = "🛡 " + str(action.value)
				col = Color(0.4, 0.7, 1.0)
				badge_col = Color(0.05, 0.15, 0.5, 0.7)
			"insanity":
				icon = "👁 " + str(action.value)
				col = Color(0.7, 0.4, 1.0)
				badge_col = Color(0.25, 0.05, 0.4, 0.7)
			"ultimate_charge":
				icon = "⚠ CARGANDO..."
				col = Color(1.0, 0.9, 0.1)
				badge_col = Color(0.5, 0.3, 0.0, 0.8)
			"ultimate_attack":
				var reduction = e.get("atk_reduction", 0)
				var final_dmg = max(0, action.value - reduction)
				icon = "☠ JUICIO (" + str(final_dmg) + ")"
				if reduction > 0:
					col = Color(0.5, 1.0, 0.5)
				else:
					col = Color(1.0, 0.0, 0.0)
				badge_col = Color(0.5, 0.3, 0.0, 0.8)
			_:
				icon = "???"

		e.lbl_intent_icon.text = icon
		e.lbl_intent_icon.modulate = col
		if e.get("intent_badge_style"):
			e.intent_badge_style.bg_color = badge_col

		# Animacion de escala si es un ataque fuerte
		if action.type in ["ultimate_attack", "attack"] and action.value > 15:
			var tw_sc = main.create_tween().set_loops()
			tw_sc.tween_property(e.lbl_intent_icon, "scale", Vector2(1.1, 1.1), 0.5)
			tw_sc.tween_property(e.lbl_intent_icon, "scale", Vector2(1.0, 1.0), 0.5)


# --- Energía como puntos visuales ---
func _build_energy_dots(max_energy: int) -> void:
	for d in energy_dots:
		if is_instance_valid(d): d.queue_free()
	energy_dots.clear()
	for i in range(max_energy):
		var dot = Panel.new()
		dot.size = Vector2(14, 14)
		dot.position = Vector2(80 + i * 19, 88)
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = Color(0.9, 0.7, 0.1)
		dot_style.set_corner_radius_all(8)
		dot_style.set_border_width_all(1)
		dot_style.border_color = Color(0.6, 0.45, 0.05)
		dot.add_theme_stylebox_override("panel", dot_style)
		player_panel.add_child(dot)
		energy_dots.append(dot)

func _update_energy_dots(current: int, maximum: int) -> void:
	if energy_dots.size() != maximum:
		_build_energy_dots(maximum)
	for i in range(energy_dots.size()):
		var style = energy_dots[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i < current:
			style.bg_color = Color(0.9, 0.7, 0.1)
		else:
			style.bg_color = Color(0.25, 0.2, 0.05)

# --- Pulso de cordura crítica ---
func _start_sanity_pulse() -> void:
	if _sanity_pulse_tween != null and _sanity_pulse_tween.is_running(): return
	if _sanity_pulse_tween != null: _sanity_pulse_tween.kill()
	_sanity_pulse_tween = main.create_tween().set_loops()
	var col_a = Color(0.38, 0.1, 0.68)
	var col_b: Color
	if GameManager.selected_character == "prince":
		col_b = Color(0.75, 0.2, 1.0)  # Violeta eléctrico — poder emergente
	else:
		col_b = Color(0.65, 0.05, 0.45)  # Reddish — peligro
	_sanity_pulse_tween.tween_method(func(c: Color): _sanity_fill_style.bg_color = c, col_a, col_b, 0.7)
	_sanity_pulse_tween.tween_method(func(c: Color): _sanity_fill_style.bg_color = c, col_b, col_a, 0.7)

	# Príncipe: viñeta respirante en lugar de flashes agresivos
	if GameManager.selected_character == "prince" and vignette:
		if _vignette_pulse_tween != null and _vignette_pulse_tween.is_running(): return
		if _vignette_pulse_tween != null: _vignette_pulse_tween.kill()
		var alpha_max = 0.30 if GameManager.sanity < 35 else 0.18
		_vignette_pulse_tween = main.create_tween().set_loops()
		_vignette_pulse_tween.tween_property(vignette, "modulate:a", alpha_max, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_vignette_pulse_tween.tween_property(vignette, "modulate:a", 0.05, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_sanity_pulse() -> void:
	if _sanity_pulse_tween != null:
		_sanity_pulse_tween.kill(); _sanity_pulse_tween = null
	if _sanity_fill_style != null:
		_sanity_fill_style.bg_color = Color(0.38, 0.1, 0.68)
	if _vignette_pulse_tween != null:
		_vignette_pulse_tween.kill(); _vignette_pulse_tween = null
	if vignette:
		vignette.modulate.a = 1.0

# ── Marca del Vacío ────────────────────────────────────────────────────────────
func get_cursed_card_index() -> int:
	return _cursed_card_index

func get_cursed_card_node():
	return _cursed_card_node

func _assign_cursed_card() -> void:
	clear_cursed_card()
	if GameManager.sanity >= 35: return
	var cards = hand_container.get_children()
	if cards.is_empty(): return
	_cursed_card_index = randi() % cards.size()
	_cursed_card_node = cards[_cursed_card_index]
	_apply_cursed_visual(_cursed_card_node)
	if _cursed_card_node.has_method("set_marked"):
		_cursed_card_node.set_marked(true)

func clear_cursed_card() -> void:
	if _cursed_overlay_tween != null:
		_cursed_overlay_tween.kill()
		_cursed_overlay_tween = null
	if is_instance_valid(_cursed_card_node):
		var mark = _cursed_card_node.get_node_or_null("_void_mark")
		if mark:
			mark.queue_free()
		if _cursed_card_node.has_method("set_marked"):
			_cursed_card_node.set_marked(false)
	_cursed_card_index = -1
	_cursed_card_node = null

func _apply_cursed_visual(card_node: Control) -> void:
	var mark = Control.new()
	mark.name = "_void_mark"
	mark.position = Vector2.ZERO
	mark.size = card_node.size
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.z_index = 5
	card_node.add_child(mark)

	var overlay = ColorRect.new()
	overlay.size = card_node.size
	overlay.color = Color(0.5, 0.0, 0.9, 0.35)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(overlay)

	var lbl = Label.new()
	lbl.text = "✦ MARCADA"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.85, 0.0, 1.0)
	lbl.position = Vector2(5, 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(lbl)

	if _cursed_overlay_tween != null:
		_cursed_overlay_tween.kill()
	_cursed_overlay_tween = main.create_tween().set_loops()
	_cursed_overlay_tween.tween_property(overlay, "color:a", 0.6, 0.7)
	_cursed_overlay_tween.tween_property(overlay, "color:a", 0.15, 0.7)

# Funciones de utilidad para creación de nodos (copiadas de Combat.gd)
func _make_panel(pos: Vector2, size: Vector2, bg: Color, border: Color) -> Panel:
	var p = Panel.new()
	p.position = pos; p.size = size
	var s = StyleBoxFlat.new()
	s.bg_color = bg; s.set_border_width_all(2); s.border_color = border; s.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_hp_bar(m_hp: int, w: int, h: int = 16) -> ProgressBar:
	var b = ProgressBar.new()
	b.max_value = m_hp; b.value = m_hp; b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_constant_override("minimum_height", h)
	var s_bg = StyleBoxFlat.new()
	s_bg.bg_color = Color(0.08, 0.01, 0.01)
	s_bg.set_corner_radius_all(2)
	s_bg.set_content_margin_all(0)
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = Color(0.72, 0.08, 0.08)
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", s_bg); b.add_theme_stylebox_override("fill", s_fg)
	b.set_deferred("size", Vector2(w, h))
	return b

func _make_ghost_bar(m_hp: int, w: int, h: int = 16) -> ProgressBar:
	var b = ProgressBar.new()
	b.max_value = m_hp; b.value = m_hp; b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_constant_override("minimum_height", h)
	var s_bg = StyleBoxFlat.new(); s_bg.bg_color = Color(0, 0, 0, 0)
	s_bg.set_content_margin_all(0)
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = Color(0.45, 0.15, 0.04)   # naranja-marrón oscuro
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", s_bg); b.add_theme_stylebox_override("fill", s_fg)
	b.set_deferred("size", Vector2(w, h))
	return b

func _make_shield_bar(max_hp: int, w: int, h: int = 10) -> ProgressBar:
	var b = ProgressBar.new()
	b.max_value = max_hp; b.value = 0; b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_constant_override("minimum_height", h)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s_bg = StyleBoxFlat.new(); s_bg.bg_color = Color(0, 0, 0, 0)
	s_bg.set_content_margin_all(0)
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = Color(0.18, 0.48, 0.88, 0.75)
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", s_bg)
	b.add_theme_stylebox_override("fill", s_fg)
	b.set_deferred("size", Vector2(w, h))
	return b

func _make_pile_label(pos: Vector2, col: Color) -> Label:
	var l = Label.new(); l.position = pos; l.modulate = col
	l.add_theme_font_size_override("font_size", 14)
	return l

# --- Target Highlight ---
func highlight_enemy_panel(panel: Panel) -> void:
	if _currently_highlighted == panel:
		return
	if _currently_highlighted != null and _currently_highlighted != panel:
		clear_target_highlight()

	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return

	if not _target_highlight_style.has(panel):
		var saved = StyleBoxFlat.new()
		saved.bg_color = style.bg_color
		saved.border_color = style.border_color
		saved.set_border_width_all(style.get_border_width(SIDE_LEFT))
		saved.set_corner_radius_all(style.get_corner_radius(CORNER_TOP_LEFT))
		_target_highlight_style[panel] = saved

	style.border_color = Color(1.0, 0.85, 0.1)
	style.set_border_width_all(3)
	_currently_highlighted = panel

	if _target_highlight_tween != null:
		_target_highlight_tween.kill()
	_target_highlight_tween = main.create_tween().set_loops()
	_target_highlight_tween.tween_property(panel, "scale", Vector2(1.02, 1.02), 0.2)
	_target_highlight_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2)

func clear_target_highlight() -> void:
	if _currently_highlighted == null:
		return
	var panel = _currently_highlighted
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null and _target_highlight_style.has(panel):
		var saved = _target_highlight_style[panel] as StyleBoxFlat
		style.border_color = saved.border_color
		style.set_border_width_all(saved.get_border_width(SIDE_LEFT))
	if _target_highlight_tween != null:
		_target_highlight_tween.kill()
		_target_highlight_tween = null
	panel.scale = Vector2(1.0, 1.0)
	_currently_highlighted = null

func update_targeting_arrow(from: Vector2, to: Vector2) -> void:
	targeting_arrow.clear_points()
	targeting_arrow.add_point(from)
	targeting_arrow.add_point(to)
	targeting_arrow.visible = true

	# Arrowhead triangle
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var tip_size = 12.0
	var p1 = to
	var p2 = to - dir * tip_size + perp * (tip_size * 0.6)
	var p3 = to - dir * tip_size - perp * (tip_size * 0.6)
	targeting_arrow_head.clear_points()
	targeting_arrow_head.add_point(p1)
	targeting_arrow_head.add_point(p2)
	targeting_arrow_head.add_point(p3)
	targeting_arrow_head.add_point(p1)
	targeting_arrow_head.visible = true

# --- Damage Number Popups ---
func show_damage_popup(world_pos: Vector2, amount: int, is_heal: bool = false) -> void:
	var lbl = Label.new()
	lbl.text = ("+" if is_heal else "-") + str(amount)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.modulate = Color(0.4, 1.0, 0.5) if is_heal else Color(1.0, 0.25, 0.25)
	lbl.position = world_pos + Vector2(-20, -10)
	lbl.z_index = 100
	main.add_child(lbl)
	var tw = main.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 48, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.finished.connect(lbl.queue_free)

# --- Dread / Ambient Messages ---
func show_dread_message() -> void:
	var messages: Array = []
	var hp_ratio = float(main.player_hp) / float(main.player_max_hp)
	if hp_ratio < 0.30:
		messages = COMBAT_FLAVOR["low_hp"]
	elif GameManager.sanity < 20:
		messages = COMBAT_FLAVOR["low_sanity"]
	else:
		return
	if messages.is_empty():
		return
	DialogueUI.cinematic(messages[randi() % messages.size()])

func show_enemy_intro(enemy_name: String) -> void:
	var intro = COMBAT_FLAVOR["enemy_intro"].get(enemy_name,
		COMBAT_FLAVOR["enemy_intro"]["default"])
	DialogueUI.cinematic(intro)

# ─── Destilados ───────────────────────────────────────────────────────────────
func _show_destilado_tooltip(anchor: Control, dest_id: String) -> void:
	if anchor.get_node_or_null("DestiladoTooltip"):
		return
	var data = GameManager.DESTILADO_DATA.get(dest_id, {})
	var rarity = data.get("rarity", "comun").replace("_", " ").to_upper()
	var txt = "[%s]\n%s\n\n\"%s\"\n\n─ %s" % [
		data.get("name", dest_id),
		data.get("desc", ""),
		data.get("flavor", ""),
		rarity
	]
	var est_lines = txt.count("\n") + int(txt.length() / 32) + 2
	var panel_h = max(110, est_lines * 15 + 20)
	var panel_w = 240
	# Aparece a la izquierda del slot (los slots están en el lado derecho de la UI)
	var p = _make_panel(Vector2(-panel_w - 6, 0), Vector2(panel_w, panel_h),
		Color(0.04, 0.02, 0.08, 0.97), Color(0.55, 0.35, 0.75))
	p.name = "DestiladoTooltip"
	p.z_index = 200
	var lbl = Label.new()
	lbl.text = txt
	lbl.position = Vector2(10, 10)
	lbl.size = Vector2(panel_w - 20, panel_h - 20)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	anchor.add_child(p)

const _RARITY_COLORS = {
	"comun":       Color(0.65, 0.65, 0.65),
	"poco_comun":  Color(0.35, 0.55, 0.95),
	"raro":        Color(0.9,  0.75, 0.2),
	"maldito":     Color(0.7,  0.2,  0.85),
}

func populate_destilados(on_click: Callable) -> void:
	if not destilados_container:
		return
	for child in destilados_container.get_children():
		child.queue_free()

	var blocked = GameManager.destilados_blocked

	for slot_idx in range(GameManager.MAX_DESTILADOS):
		var has_item = slot_idx < GameManager.destilados.size()
		var dest_id: String = GameManager.destilados[slot_idx] if has_item else ""
		var data: Dictionary = GameManager.DESTILADO_DATA.get(dest_id, {}) if has_item else {}
		var rarity: String   = data.get("rarity", "comun")
		var border_col: Color = _RARITY_COLORS.get(rarity, Color(0.5, 0.5, 0.5))

		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(118, 42)
		slot.size = Vector2(118, 42)

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(3)
		if has_item and not blocked:
			style.bg_color    = Color(0.07, 0.05, 0.13)
			style.border_color = border_col
			style.set_border_width_all(2)
		else:
			# Slot vacío o bloqueado
			style.bg_color    = Color(0.05, 0.04, 0.08, 0.5)
			style.border_color = Color(0.25, 0.22, 0.3)
			style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", style)

		if has_item:
			# Nombre del destilado
			var lbl_name = Label.new()
			lbl_name.text = data.get("name", dest_id)
			lbl_name.position = Vector2(5, 4)
			lbl_name.size = Vector2(108, 20)
			lbl_name.add_theme_font_size_override("font_size", 9)
			lbl_name.modulate = Color(0.95, 0.92, 0.85) if not blocked else Color(0.4, 0.4, 0.4)
			lbl_name.clip_text = true
			slot.add_child(lbl_name)

			# Rareza + estado
			var lbl_sub = Label.new()
			lbl_sub.text = ("BLOQUEADO" if blocked else rarity.replace("_", " ").to_upper())
			lbl_sub.position = Vector2(5, 25)
			lbl_sub.size = Vector2(108, 14)
			lbl_sub.add_theme_font_size_override("font_size", 8)
			lbl_sub.modulate = Color(0.4, 0.4, 0.4) if blocked else border_col
			slot.add_child(lbl_sub)

			# Hover glow + tooltip
			slot.mouse_entered.connect(func():
				if not blocked:
					style.border_color = border_col.lightened(0.3)
				_show_destilado_tooltip(slot, dest_id))
			slot.mouse_exited.connect(func():
				style.border_color = border_col
				var t = slot.get_node_or_null("DestiladoTooltip")
				if t: t.queue_free())

			# Click → callback con el ID
			if not blocked:
				slot.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.pressed \
							and event.button_index == MOUSE_BUTTON_LEFT:
						on_click.call(dest_id))
		else:
			var lbl_empty = Label.new()
			lbl_empty.text = "[ destilado ]"
			lbl_empty.position = Vector2(5, 13)
			lbl_empty.size = Vector2(108, 16)
			lbl_empty.add_theme_font_size_override("font_size", 8)
			lbl_empty.modulate = Color(0.3, 0.28, 0.35)
			slot.add_child(lbl_empty)

		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		destilados_container.add_child(slot)
