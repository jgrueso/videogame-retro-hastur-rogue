extends Node

## CombatLog — Autoload central de log de combate.
## Fuente de verdad del historial; DialogueUI.add_log() delega aquí.

enum Category { COMBAT, EFFECTS, NARRATIVE, SYSTEM, DEBUG }
enum Verbosity { NORMAL, VERBOSE }

signal entry_added(entry: Dictionary)
signal turn_started(turn_num: int, is_player: bool)

var verbosity: Verbosity = Verbosity.NORMAL
var _history: Array = []
const MAX_HISTORY = 200


func log(subject: String, text: String, color: Color,
		category: Category = Category.COMBAT) -> void:
	if category == Category.DEBUG and verbosity == Verbosity.NORMAL:
		return
	var entry = {
		"subject": subject,
		"text": text,
		"color": color,
		"category": category,
		"timestamp": Time.get_ticks_msec()
	}
	_history.append(entry)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()
	entry_added.emit(entry)


func log_turn(turn_num: int, is_player: bool) -> void:
	var label = "── TURNO %d — %s ──" % [turn_num, "JUGADOR" if is_player else "ENEMIGOS"]
	var color = Color(0.4, 0.8, 1.0) if is_player else Color(1.0, 0.5, 0.3)
	print("---", label, color, Category.SYSTEM)
	turn_started.emit(turn_num, is_player)


func export_to_file() -> void:
	var file = FileAccess.open("user://combat_log.txt", FileAccess.WRITE)
	if not file:
		return
	for e in _history:
		file.store_line("[%d] %s: %s" % [e["timestamp"], e["subject"], e["text"]])
	file.close()


func clear() -> void:
	_history.clear()
