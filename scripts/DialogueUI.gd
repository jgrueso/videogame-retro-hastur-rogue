extends Node

## Sistema de Diálogo Unificado — Autoload global
## Reemplaza: flash_small, show_message, log_message, show_floating_dialogue, show_avatar_bark

enum Mode { TOAST, BARK, LOG, CINEMATIC }

const TYPEWRITER_SPEED  : float = 0.013
const TOAST_MIN_DURATION: float = 2.0
const TOAST_CHARS_PER_S : float = 25.0
const MAX_TOASTS        : int   = 4

signal cinematic_finished
signal _choice_selected(index: int)

var _canvas: CanvasLayer
var _log_panel: Panel
var _log_scroll: ScrollContainer
var _log_vbox: VBoxContainer
var _ticker_panel: Panel
var _ticker_label: Label
var _log_toggle_btn: Button
var _debug_overlay: Panel
var _debug_label: Label
var _debug_turn: int = 0
var _cinematic_panel: PanelContainer
var _cinematic_label: RichTextLabel
var _skip_hint: Label

var _choice_container: VBoxContainer

var _cinematic_busy: bool = false
var _skip_requested: bool = false
var _cinematic_queue: Array = []
var _active_toasts: Array = []
var _active_bark_nodes: Dictionary = {}  # entity_id → PanelContainer

var _font_narrative: Font
var _font_ui: Font
var _font_corrupted: Font

func _ready() -> void:
	_load_fonts()
	_build_ui()
	Events.combat_ended.connect(clear_log)

func _load_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/IMFellEnglish-Italic.ttf"):
		_font_narrative = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	if ResourceLoader.exists("res://assets/fonts/rajdhani.medium.ttf"):
		_font_ui = load("res://assets/fonts/rajdhani.medium.ttf")
	if ResourceLoader.exists("res://assets/fonts/RubikGlitch-Regular.ttf"):
		_font_corrupted = load("res://assets/fonts/RubikGlitch-Regular.ttf")
func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 200
	add_child(_canvas)

	# Botón LOG discreto (Esquina inferior derecha)
	_log_toggle_btn = Button.new()
	_log_toggle_btn.text = "LOG"
	_log_toggle_btn.position = Vector2(1060, 600)
	_log_toggle_btn.size = Vector2(36, 16)
	_log_toggle_btn.add_theme_font_size_override("font_size", 9)
	_log_toggle_btn.modulate.a = 0.65
	_log_toggle_btn.pressed.connect(_toggle_history_panel)
	_canvas.add_child(_log_toggle_btn)

	# Panel histórico discreto
	_log_panel = Panel.new()
	_log_panel.position = Vector2(850, 420)
	_log_panel.size = Vector2(250, 175)
	_log_panel.visible = false
	_log_panel.modulate.a = 0.85
	var ls = StyleBoxFlat.new()
	ls.bg_color = Color(0, 0, 0, 0.7)
	ls.border_width_left = 1
	ls.border_color = Color(0.25, 0.2, 0.1)
	_log_panel.add_theme_stylebox_override("panel", ls)
	_canvas.add_child(_log_panel)

	_log_scroll = ScrollContainer.new()
	_log_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 4)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_panel.add_child(_log_scroll)

	_log_vbox = VBoxContainer.new()
	_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_vbox)

	# Conectar señal de CombatLog
	CombatLog.entry_added.connect(_on_log_entry_added)

	# Debug overlay (solo en builds de depuración)
	if OS.is_debug_build():
		_debug_overlay = Panel.new()
		_debug_overlay.position = Vector2(0, 0)
		_debug_overlay.size = Vector2(1920, 22)
		_debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ds = StyleBoxFlat.new()
		ds.bg_color = Color(0, 0, 0, 0.55)
		_debug_overlay.add_theme_stylebox_override("panel", ds)
		_canvas.add_child(_debug_overlay)

		_debug_label = Label.new()
		_debug_label.add_theme_font_size_override("font_size", 10)
		_debug_label.position = Vector2(5, 3)
		_debug_label.size = Vector2(1910, 16)
		_debug_label.modulate = Color(0.5, 1.0, 0.5)
		_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_debug_overlay.add_child(_debug_label)

		CombatLog.turn_started.connect(_on_debug_turn_started)

	# Cinematic Panel (center-top)
	_cinematic_panel = PanelContainer.new()
	_cinematic_panel.visible = false
	_cinematic_panel.position = Vector2(510, 160)
	_cinematic_panel.custom_minimum_size = Vector2(900, 0)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	s.set_border_width_all(1)
	s.border_color = Color(0.3, 0.25, 0.15, 0.6)
	s.set_corner_radius_all(4)
	_cinematic_panel.add_theme_stylebox_override("panel", s)
	_canvas.add_child(_cinematic_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_cinematic_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_cinematic_label = RichTextLabel.new()
	_cinematic_label.bbcode_enabled = false
	_cinematic_label.custom_minimum_size = Vector2(860, 60)
	_cinematic_label.fit_content = true
	_cinematic_label.scroll_active = false
	if _font_narrative:
		_cinematic_label.add_theme_font_override("normal_font", _font_narrative)
	_cinematic_label.add_theme_font_size_override("normal_font_size", 18)
	vbox.add_child(_cinematic_label)

	_skip_hint = Label.new()
	_skip_hint.text = "[ CLICK O ESPACIO ]"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.modulate.a = 0.0
	if _font_ui:
		_skip_hint.add_theme_font_override("font", _font_ui)
	_skip_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_skip_hint)

	_choice_container = VBoxContainer.new()
	_choice_container.add_theme_constant_override("separation", 8)
	_choice_container.visible = false
	vbox.add_child(_choice_container)

	_cinematic_panel.gui_input.connect(_on_cinematic_panel_input)

func _on_cinematic_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip_requested = true

func _unhandled_input(event: InputEvent) -> void:
	if not _cinematic_busy:
		return
	if event is InputEventMouseButton and event.pressed:
		_skip_requested = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_skip_requested = true
		get_viewport().set_input_as_handled()

# ── API Pública ────────────────────────────────────────────────────────────────

func toast(text: String, color: Color = Color(1.0, 0.85, 0.2)) -> void:
	add_log("SISTEMA", text, color)

	if _active_toasts.size() >= MAX_TOASTS:
		var oldest = _active_toasts[0]
		if is_instance_valid(oldest):
			create_tween().tween_property(oldest, "modulate:a", 0.0, 0.15)

	var f = Label.new()
	f.text = text
	f.add_theme_font_size_override("font_size", 17)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.modulate = Color(color.r, color.g, color.b, 0.0)
	f.add_theme_constant_override("outline_size", 4)
	f.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	var y_off = _active_toasts.size() * 28
	f.position = Vector2(300, 250 + y_off)
	f.size = Vector2(600, 30)
	_canvas.add_child(f)
	_active_toasts.append(f)

	var duration = max(TOAST_MIN_DURATION, text.length() / TOAST_CHARS_PER_S)

	var tw = create_tween()
	tw.tween_property(f, "modulate:a", 1.0, 0.3)
	tw.tween_interval(duration)
	tw.parallel().tween_property(f, "position:y", f.position.y - 60, 0.5)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func():
		_active_toasts.erase(f)
		f.queue_free()
	)

func bark(text: String, world_pos: Vector2, color: Color = Color(0.8, 0.7, 0.9), is_enemy: bool = false, max_width: float = 260.0, entity_id: String = "") -> void:
	# Anti-stacking: eliminar bark previo de la misma entidad
	if entity_id != "":
		if _active_bark_nodes.has(entity_id):
			var old = _active_bark_nodes[entity_id]
			if is_instance_valid(old):
				old.queue_free()
		_active_bark_nodes[entity_id] = null

	# Mini panel estilizado — versión compacta del CinematicPanel
	var container = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.07, 0.88)
	style.set_border_width_all(1)
	style.border_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.5)
	style.set_corner_radius_all(3)
	container.add_theme_stylebox_override("panel", style)
	container.custom_minimum_size.x = min(max_width, 260.0)
	container.modulate.a = 0.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	container.add_child(margin)

	var lbl = Label.new()
	lbl.text = '"%s"' % text
	lbl.modulate = color
	if _font_narrative:
		lbl.add_theme_font_override("font", _font_narrative)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size.x = min(max_width, 260.0) - 16.0
	margin.add_child(lbl)

	_canvas.add_child(container)

	if entity_id != "":
		_active_bark_nodes[entity_id] = container

	# Esperar un frame para obtener tamaño real
	await get_tree().process_frame

	var final_pos = Vector2(world_pos.x - container.size.x / 2.0, world_pos.y - container.size.y - 8.0)
	var viewport_h = get_viewport().get_visible_rect().size.y
	final_pos.y = clamp(final_pos.y, 10.0, viewport_h - container.size.y - 10.0)
	var slide_dir = 30.0 if is_enemy else -30.0
	container.position = final_pos + Vector2(slide_dir, 0)

	var tw_in = create_tween().set_parallel(true)
	tw_in.tween_property(container, "position", final_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(container, "modulate:a", 1.0, 0.35)

	if LoreData.is_garbled(text):
		for _f in range(8):
			container.modulate.a = randf_range(0.4, 1.0)
			await get_tree().create_timer(0.06).timeout
		container.modulate.a = 1.0

	var hold_time = max(3.5, text.length() / 18.0)
	await get_tree().create_timer(hold_time).timeout

	var tw_out = create_tween().set_parallel(true)
	tw_out.tween_property(container, "modulate:a", 0.0, 0.5)
	tw_out.tween_property(container, "position", final_pos + Vector2(slide_dir * 0.67, 0), 0.5)
	await tw_out.finished
	if entity_id != "" and _active_bark_nodes.get(entity_id) == container:
		_active_bark_nodes.erase(entity_id)
	if is_instance_valid(container):
		container.queue_free()

func add_log(subject: String, text: String, color: Color,
		category: int = CombatLog.Category.COMBAT) -> void:
	CombatLog.log(subject, text, color, category)


func _toggle_history_panel() -> void:
	_log_panel.visible = not _log_panel.visible


func _on_log_entry_added(entry: Dictionary) -> void:
	# Debug overlay
	if is_instance_valid(_debug_label):
		_debug_label.text = "T%d | %s: %s" % [_debug_turn, entry["subject"], entry["text"]]

	# Separador especial para entradas SYSTEM (marcadores de turno)
	if entry["category"] == CombatLog.Category.SYSTEM:
		_add_turn_separator(entry["text"], entry["color"])
		return

	# Añadir al panel histórico
	if not is_instance_valid(_log_vbox):
		return
	var lbl = Label.new()
	lbl.text = "[%s]: %s" % [entry["subject"].to_upper(), entry["text"]]
	lbl.add_theme_font_size_override("font_size", 11)
	if _font_ui:
		lbl.add_theme_font_override("font", _font_ui)
	lbl.modulate = Color(entry["color"].r, entry["color"].g, entry["color"].b, 0.0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size.x = 280
	_log_vbox.add_child(lbl)

	create_tween().tween_property(lbl, "modulate:a", 1.0, 0.3)

	if _log_vbox.get_child_count() > 30:
		_log_vbox.get_child(0).queue_free()

	await get_tree().process_frame
	if is_instance_valid(_log_scroll):
		_log_scroll.set_v_scroll(int(_log_vbox.size.y))

	Events.dialogue_line_shown.emit(Mode.LOG, entry["text"])


func _add_turn_separator(text: String, color: Color) -> void:
	if not is_instance_valid(_log_vbox):
		return
	var sep = Label.new()
	sep.text = text
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 10)
	sep.modulate = color
	_log_vbox.add_child(sep)

	if _log_vbox.get_child_count() > 30:
		_log_vbox.get_child(0).queue_free()

	await get_tree().process_frame
	if is_instance_valid(_log_scroll):
		_log_scroll.set_v_scroll(int(_log_vbox.size.y))


func _on_debug_turn_started(turn_num: int, is_player: bool) -> void:
	_debug_turn = turn_num
	if is_instance_valid(_debug_label):
		_debug_label.text = "── TURNO %d — %s ──" % [turn_num, "JUGADOR" if is_player else "ENEMIGOS"]

func cinematic(text: String, color: Color = Color(0.9, 0.82, 0.75)) -> void:
	_cinematic_queue.push_back({"text": text, "color": color})
	if not _cinematic_busy:
		_process_cinematic_queue()

func cinematic_line(text: String, color: Color = Color(0.9, 0.82, 0.75)) -> void:
	cinematic(text, color)
	await cinematic_finished

func clear_log() -> void:
	CombatLog.clear()
	if not is_instance_valid(_log_vbox):
		return
	for child in _log_vbox.get_children():
		child.queue_free()

func skip() -> void:
	_skip_requested = true

## Pausa la cinematic y muestra opciones. Retorna índice elegido.
## options: Array[Dictionary] — cada dict: {"label": String, "effect": Dictionary}
## Efectos soportados: sanity (int), lore_progress (int), hp (int), gold (int), max_hp (int)
func cinematic_choice(options: Array) -> int:
	# Construir panel de elección centrado en la pantalla
	var vp_size = get_viewport().get_visible_rect().size
	var choice_panel := Panel.new()
	choice_panel.custom_minimum_size = Vector2(520, 0)
	choice_panel.position = Vector2(vp_size.x / 2.0 - 260, vp_size.y * 0.7)
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color(0.04, 0.03, 0.07, 0.97)
	cp_style.set_border_width_all(2)
	cp_style.border_color = Color(0.55, 0.42, 0.12, 0.85)
	cp_style.set_corner_radius_all(6)
	choice_panel.add_theme_stylebox_override("panel", cp_style)
	_canvas.add_child(choice_panel)

	var cp_vbox := VBoxContainer.new()
	cp_vbox.add_theme_constant_override("separation", 12)
	cp_vbox.position = Vector2(20, 20)
	cp_vbox.custom_minimum_size = Vector2(480, 0)
	choice_panel.add_child(cp_vbox)

	for i in range(options.size()):
		var opt = options[i]
		var btn := Button.new()
		btn.text = opt.get("label", "???")
		btn.custom_minimum_size = Vector2(480, 44)
		btn.add_theme_font_size_override("font_size", 15)
		if _font_ui:
			btn.add_theme_font_override("font", _font_ui)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.10, 0.08, 0.14)
		btn_style.set_border_width_all(1)
		btn_style.border_color = Color(0.45, 0.32, 0.10)
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)
		var btn_hover := btn_style.duplicate() as StyleBoxFlat
		btn_hover.bg_color = Color(0.22, 0.16, 0.08)
		btn_hover.border_color = Color(0.85, 0.65, 0.20)
		btn.add_theme_stylebox_override("hover", btn_hover)
		var idx := i
		btn.pressed.connect(_choice_selected.emit.bind(idx))
		cp_vbox.add_child(btn)

	# Ajustar tamaño del panel al contenido tras un frame
	await get_tree().process_frame
	choice_panel.size = Vector2(520, cp_vbox.size.y + 40)

	# Usar señal en lugar de closure para evitar problemas de captura en coroutinas
	var chosen: int = await _choice_selected

	choice_panel.queue_free()
	_skip_requested = false  # evitar que la siguiente cinematic_line se salte
	_apply_cinematic_effect(options[chosen].get("effect", {}))
	return chosen

func _apply_cinematic_effect(effect: Dictionary) -> void:
	if effect.has("sanity"):
		GameManager.sanity = clamp(GameManager.sanity + effect["sanity"], 0, GameManager.max_sanity)
	if effect.has("fragment_count_w3"):
		GameManager.fragment_count_w3 = max(0, GameManager.fragment_count_w3 + effect["fragment_count_w3"])
	if effect.has("lore_progress"):
		GameManager.lore_progress += effect["lore_progress"]
	if effect.has("hp"):
		GameManager.player_hp = clamp(GameManager.player_hp + effect["hp"], 1, GameManager.player_max_hp)
	if effect.has("gold"):
		GameManager.coins = max(0, GameManager.coins + effect["gold"])
	if effect.has("max_hp"):
		GameManager.player_max_hp = max(1, GameManager.player_max_hp + effect["max_hp"])
	if effect.has("remove_card") and effect["remove_card"]:
		var removed = GameManager.remove_random_card()
		if removed != "": toast("CARTA PERDIDA: " + removed, Color.RED)
	if effect.has("remove_secret_item") and effect["remove_secret_item"]:
		var removed = GameManager.remove_random_secret_item()
		if removed != "": toast("FRAGMENTO ENTREGADO: " + removed.replace("_", " ").to_upper(), Color.GOLD)
	if effect.has("remove_relic") and effect["remove_relic"]:
		var removed = GameManager.remove_random_relic()
		if removed != "": toast("RELIQUIA PERDIDA: " + removed, Color.RED)

# ── Cinematic interno ─────────────────────────────────────────────────────────

func _process_cinematic_queue() -> void:
	while not _cinematic_queue.is_empty():
		var entry = _cinematic_queue.pop_front()
		await _show_cinematic(entry.text, entry.color)
	Events.dialogue_finished.emit(Mode.CINEMATIC)
	cinematic_finished.emit()

func _show_cinematic(text: String, color: Color) -> void:
	_cinematic_busy = true
	_skip_requested = false

	var sanity = GameManager.sanity if GameManager else 100
	if sanity < 30 and _font_corrupted:
		_cinematic_label.add_theme_font_override("normal_font", _font_corrupted)
	elif _font_narrative:
		_cinematic_label.add_theme_font_override("normal_font", _font_narrative)

	_cinematic_label.modulate = color
	_cinematic_label.text = ""
	_cinematic_panel.visible = true
	_cinematic_panel.modulate.a = 0.0
	_skip_hint.modulate.a = 0.0

	create_tween().tween_property(_cinematic_panel, "modulate:a", 1.0, 0.3)

	if sanity < 30:
		var orig_pos = _cinematic_panel.position
		var shake_tw = create_tween().set_loops(20)
		shake_tw.tween_property(_cinematic_panel, "position",
			orig_pos + Vector2(randf_range(-5, 5), randf_range(-3, 3)), 0.05)
		shake_tw.tween_property(_cinematic_panel, "position", orig_pos, 0.05)

	get_tree().create_timer(0.5).timeout.connect(func():
		if _cinematic_busy:
			create_tween().tween_property(_skip_hint, "modulate:a", 0.6, 0.3)
	, CONNECT_ONE_SHOT)

	await _typewrite(text)

	if _skip_requested:
		_cinematic_label.text = text

	_skip_hint.modulate.a = 0.0

	if not _skip_requested:
		await get_tree().create_timer(min(4.0, max(1.2, text.length() * 0.025))).timeout

	var tw_out = create_tween()
	tw_out.tween_property(_cinematic_panel, "modulate:a", 0.0, 0.4)
	await tw_out.finished
	_cinematic_panel.visible = false

	_cinematic_busy = false
	_skip_requested = false

	Events.dialogue_line_shown.emit(Mode.CINEMATIC, text)

func _typewrite(text: String) -> void:
	_cinematic_label.text = ""
	for i in range(text.length()):
		if _skip_requested:
			return
		_cinematic_label.text = text.substr(0, i + 1)
		var c = text[i]
		var wait = TYPEWRITER_SPEED
		if c in [".", "!", "?"]:
			wait = TYPEWRITER_SPEED * 3.5
		elif c in [",", ";"]:
			wait = TYPEWRITER_SPEED * 2.0
		elif c == "\n":
			wait = TYPEWRITER_SPEED * 2.5
		await get_tree().create_timer(wait).timeout
