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

# Kill count
signal enemies_killed_changed(total_killed)
var enemies_killed: int = 0

# Run summary container (kept here to avoid missing type errors)
class GameRunResult extends RefCounted:
	enum EndType {
		FAILED,    ## プレイヤー死亡
		TIME_UP,   ## 制限時間到達（サバイバル成功）
		ESCAPED,   ## 脱出成功（将来用）
	}

	var end_type: EndType
	var run_time_sec: float
	var final_level: int
	var enemies_killed: int
	var carry_over_resources: Dictionary
	var final_build: Array

	static func create(
		p_end_type: EndType,
		p_run_time_sec: float,
		p_final_level: int,
		p_enemies_killed: int,
		p_carry_over_resources: Dictionary,
		p_final_build: Array
	) -> GameRunResult:
		var r := GameRunResult.new()
		r.end_type = p_end_type
		r.run_time_sec = p_run_time_sec
		r.final_level = p_final_level
		r.enemies_killed = p_enemies_killed
		r.carry_over_resources = p_carry_over_resources
		r.final_build = p_final_build
		return r

	## end_type に対応する表示名を返す
	func get_end_type_name() -> String:
		match end_type:
			EndType.FAILED:
				return "GAME OVER"
			EndType.TIME_UP:
				return "TIME UP - SURVIVED!"
			EndType.ESCAPED:
				return "ESCAPED!"
			_:
				return "RUN RESULT"

	## end_type に対応するテーマカラーを返す
	func get_theme_color() -> Color:
		match end_type:
			EndType.FAILED:
				return Color(0.8, 0.2, 0.2, 0.85)  # 赤
			EndType.TIME_UP:
				return Color(0.2, 0.7, 0.3, 0.85)  # 緑
			EndType.ESCAPED:
				return Color(0.2, 0.4, 0.8, 0.85)  # 青
			_:
				return Color(0.3, 0.3, 0.3, 0.85)

	## 生存時間を "分:秒" 形式でフォーマット
	func format_survival_time() -> String:
		var minutes := int(run_time_sec / 60.0)
		var seconds := int(run_time_sec) % 60
		return "%d:%02d" % [minutes, seconds]

# Last run result (populated on game end)
var last_run_result: GameRunResult = null

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


## 敵撃破時に呼び出す
func add_enemy_kill(count: int = 1) -> void:
	if count <= 0:
		return
	enemies_killed += count
	emit_signal("enemies_killed_changed", enemies_killed)


## 現在のラン結果を生成
func build_run_result(end_type: GameRunResult.EndType) -> GameRunResult:
	var final_level := 1
	var final_build: Array = [[], []]
	
	if player_reference and is_instance_valid(player_reference):
		if "level" in player_reference:
			final_level = int(player_reference.level)
		# LoadoutManager から最終ビルドを取得
		var loadout_mgr = player_reference.get_node_or_null("LoadoutManager")
		if loadout_mgr and loadout_mgr.has_method("GetLoadoutSummary"):
			final_build = loadout_mgr.GetLoadoutSummary()
	
	# 持ち帰りリソース（現在はジルコインのみ）
	var carry_over := {
		"zircoin": score
	}
	
	return GameRunResult.create(
		end_type,
		run_time_sec,
		final_level,
		enemies_killed,
		carry_over,
		final_build
	)


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
	print("GameManager: trigger_game_clear() called with reason=", reason)
	print("  - run_time_sec=", run_time_sec, ", max_run_time_sec=", max_run_time_sec)
	_trigger_game_end(true, reason)

func _trigger_game_end(is_clear: bool, reason: String) -> void:
	if current_state == GameState.GAME_OVER:
		return
	last_end_is_clear = is_clear
	last_end_reason = str(reason)
	current_state = GameState.GAME_OVER
	
	# RunResult を生成
	var end_type: GameRunResult.EndType
	if is_clear:
		if reason == "escaped":
			end_type = GameRunResult.EndType.ESCAPED
		else:
			end_type = GameRunResult.EndType.TIME_UP
	else:
		end_type = GameRunResult.EndType.FAILED
	last_run_result = build_run_result(end_type)
	
	emit_signal("game_ended", last_end_is_clear, last_end_reason)
	# Backwards-compatible: existing UI listens to game_over.
	emit_signal("game_over")

func reset_game():
	print("GameManager: reset_game() called")
	print("  - Before: current_state=", current_state, ", run_time_sec=", run_time_sec)
	current_state = GameState.PLAYING
	# Reload scene handles most reset, but we might need to reset autoload state if any.
	player_reference = null
	score = 0
	enemies_killed = 0
	last_end_is_clear = false
	last_end_reason = ""
	last_run_result = null
	emit_signal("score_changed", score)
	emit_signal("enemies_killed_changed", enemies_killed)
	_reset_run_timer()
	print("  - After: run_time_sec=", run_time_sec, ", max_run_time_sec=", max_run_time_sec)

func return_to_menu() -> void:
	# Used when leaving a run back to the start screen.
	current_state = GameState.MENU
	player_reference = null
	score = 0
	enemies_killed = 0
	last_end_is_clear = false
	last_end_reason = ""
	last_run_result = null
	emit_signal("score_changed", score)
	emit_signal("enemies_killed_changed", enemies_killed)
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
	print("GameManager: start_game() called")
	print("  - Before: current_state=", current_state, ", run_time_sec=", run_time_sec, ", max_run_time_sec=", max_run_time_sec)
	current_state = GameState.PLAYING
	_reset_run_timer()
	print("  - After reset: run_time_sec=", run_time_sec, ", _last_emitted_second=", _last_emitted_second)
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
