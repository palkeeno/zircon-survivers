extends Node

# Global signals
signal game_started
signal game_over
signal game_ended(is_clear: bool, reason: String)
signal game_paused(is_paused)
signal level_up_choice_requested

# Time / wave signals
signal run_time_changed(time_sec)
signal time_left_changed(time_left_sec)
signal minute_reached(minute)
signal miniboss_requested(minute)
signal boss_requested(boss_index)
signal miniboss_spawned
signal boss_spawned

# Score (coins)
signal score_changed(total_score)
var score: int = 0

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	LEVEL_UP
}

var current_state: GameState = GameState.MENU
var player_reference: Node2D = null

# Run timer (seconds since run started). Only advances in PLAYING.
var run_time_sec: float = 0.0
var _last_emitted_second: int = -1
var _last_emitted_minute: int = -1

# Run limit (seconds). When time reaches 0, run ends as CLEAR.
@export var max_run_time_sec: float = 300.0

# Last end info (used by UI)
var last_end_is_clear: bool = false
var last_end_reason: String = ""

# Scheduling: miniboss every minute, boss every 3 minutes.
var _next_miniboss_minute: int = 1
var _next_boss_index: int = 1


func trigger_level_up_choice():
	# Don't pause physics completely, but maybe stop Spawner?
	# Classic survivor pauses everything.
	if current_state != GameState.LEVEL_UP:
		var _prev_state = current_state
		current_state = GameState.LEVEL_UP
		get_tree().paused = true
		emit_signal("level_up_choice_requested")
func trigger_game_over():
	_trigger_game_end(false, "dead")

func trigger_game_clear(reason: String = "clear") -> void:
	_trigger_game_end(true, reason)

func _trigger_game_end(is_clear: bool, reason: String) -> void:
	if current_state == GameState.GAME_OVER:
		return
	last_end_is_clear = is_clear
	last_end_reason = str(reason)
	current_state = GameState.GAME_OVER
	emit_signal("game_ended", last_end_is_clear, last_end_reason)
	# Backwards-compatible: existing UI listens to game_over.
	emit_signal("game_over")

func reset_game():
	current_state = GameState.PLAYING
	# Reload scene handles most reset, but we might need to reset autoload state if any.
	player_reference = null
	score = 0
	last_end_is_clear = false
	last_end_reason = ""
	emit_signal("score_changed", score)
	_reset_run_timer()

func return_to_menu() -> void:
	# Used when leaving a run back to the start screen.
	current_state = GameState.MENU
	player_reference = null
	score = 0
	last_end_is_clear = false
	last_end_reason = ""
	emit_signal("score_changed", score)
	_reset_run_timer()
	get_tree().paused = false
	# Notify listeners that we're not paused anymore (helps HUD close menus cleanly).
	emit_signal("game_paused", false)

func add_score(amount: int) -> void:
	if amount <= 0:
		return
	score += int(amount)
	emit_signal("score_changed", score)

func _reset_run_timer():
	run_time_sec = 0.0
	_last_emitted_second = -1
	_last_emitted_minute = -1
	_next_miniboss_minute = 1
	_next_boss_index = 1

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep running even when paused
	_reset_run_timer()

func _process(delta: float) -> void:
	# Advance run timer only while actually playing.
	if current_state != GameState.PLAYING:
		return

	run_time_sec += delta

	var time_left_sec: float = maxf(0.0, float(max_run_time_sec) - run_time_sec)

	# Emit at most once per second to keep UI cheap.
	var sec_i := int(floor(run_time_sec))
	if sec_i != _last_emitted_second:
		_last_emitted_second = sec_i
		emit_signal("run_time_changed", run_time_sec)
		emit_signal("time_left_changed", time_left_sec)

		# Time limit reached => CLEAR
		if time_left_sec <= 0.0:
			trigger_game_clear("timeout")
			return

		var minute_i: int = int(floor(run_time_sec / 60.0))
		if minute_i != _last_emitted_minute:
			_last_emitted_minute = minute_i
			emit_signal("minute_reached", minute_i)

		# Mini-boss every minute (1,2,3,...)
		if minute_i >= _next_miniboss_minute:
			emit_signal("miniboss_requested", _next_miniboss_minute)
			_next_miniboss_minute += 1

			# Boss every 3 minutes (3,6,9,...) -> represented by boss_index 1,2,3...
			if (_next_miniboss_minute - 1) % 3 == 0:
				emit_signal("boss_requested", _next_boss_index)
				_next_boss_index += 1

func start_game():
	current_state = GameState.PLAYING
	_reset_run_timer()
	emit_signal("game_started")
	get_tree().paused = false

func pause_game():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		emit_signal("game_paused", true)

func resume_game():
	if current_state == GameState.PAUSED or current_state == GameState.LEVEL_UP:
		current_state = GameState.PLAYING
		get_tree().paused = false
		emit_signal("game_paused", false)


# Call these from whatever system actually spawns the miniboss/boss (e.g. Spawner).
func notify_miniboss_spawned() -> void:
	emit_signal("miniboss_spawned")

func notify_boss_spawned() -> void:
	emit_signal("boss_spawned")
