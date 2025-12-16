extends Node

# Global signals
signal game_started
signal game_over
signal game_paused(is_paused)
signal level_up_choice_requested

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	LEVEL_UP
}

func trigger_level_up_choice():
	# Don't pause physics completely, but maybe stop Spawner?
	# Classic survivor pauses everything.
	if current_state != GameState.LEVEL_UP:
		var _prev_state = current_state
		current_state = GameState.LEVEL_UP
		get_tree().paused = true
		emit_signal("level_up_choice_requested")
var current_state: GameState = GameState.MENU
var player_reference: Node2D = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep running even when paused

func start_game():
	current_state = GameState.PLAYING
	emit_signal("game_started")
	get_tree().paused = false

func pause_game():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		emit_signal("game_paused", true)

func resume_game():
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		emit_signal("game_paused", false)

func trigger_game_over():
	if current_state != GameState.GAME_OVER:
		current_state = GameState.GAME_OVER
		get_tree().paused = true
		emit_signal("game_over")
