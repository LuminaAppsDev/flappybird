extends Node
## Main game controller. Manages game states and routes input.

enum State { TITLE, GET_READY, PLAYING, GAME_OVER }

const ANDROID_LEADERBOARD_ID := "CgkI2ZWTjPMBEAIQAQ"
const IOS_LEADERBOARD_ID := "65255295705"

var _state: State = State.TITLE
var _signed_in := false
var _platform := OS.get_name()

# Android (Google Play Games)
var _leaderboards_client: PlayGamesLeaderboardsClient
var _sign_in_client: PlayGamesSignInClient

# iOS (Game Center) — untyped to avoid parse errors on non-Apple platforms
var _game_center = null

# Web (PWA leaderboard)
var _leaderboard_popup: Control = null

@onready var _world: Node2D = $World
@onready var _gui: CanvasLayer = $GUI


func _enter_tree() -> void:
	if _platform == "Android":
		GodotPlayGameServices.initialize()


func _ready() -> void:
	if _platform == "Android":
		_setup_play_games()
	elif _platform == "iOS":
		_setup_game_center()
	elif _platform == "Web":
		_setup_web_leaderboard()
	_world.game_over.connect(_on_game_over)
	_world.score_changed.connect(_on_score_changed)
	_gui.play_pressed.connect(_on_play_pressed)
	_gui.retry_pressed.connect(_on_retry_pressed)
	_gui.score_button_pressed.connect(_on_score_button_pressed)
	_gui.rate_button_pressed.connect(_on_rate_button_pressed)
	_gui.new_best_score.connect(_on_new_best_score)
	_enter_title()


func _setup_play_games() -> void:
	_leaderboards_client = PlayGamesLeaderboardsClient.new()
	add_child(_leaderboards_client)
	_sign_in_client = PlayGamesSignInClient.new()
	add_child(_sign_in_client)
	_sign_in_client.user_authenticated.connect(_on_user_authenticated)
	_sign_in_client.is_authenticated()


func _setup_game_center() -> void:
	if not ClassDB.class_exists(&"GameCenterManager"):
		return
	_game_center = ClassDB.instantiate(&"GameCenterManager")
	_game_center.authentication_result.connect(_on_user_authenticated)
	_game_center.authenticate()


func _setup_web_leaderboard() -> void:
	_leaderboard_popup = preload("res://LeaderboardPopup.tscn").instantiate()
	_gui.add_child(_leaderboard_popup)
	if RanksClient.is_registered:
		_signed_in = true
	else:
		RanksClient.registered.connect(func(success: bool) -> void: _signed_in = success)


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GET_READY:
		if _is_tap(event):
			_enter_playing()
	elif _state == State.PLAYING:
		if _is_tap(event):
			_world.bird.flap()


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		return true
	return false


func _enter_title() -> void:
	_state = State.TITLE
	_world.reset()
	var title_y := 200.0 - _world.position.y
	_world.bird.position = Vector2(144.0, title_y)
	_world.bird._start_y = title_y
	_gui.show_title()


func _enter_get_ready() -> void:
	_state = State.GET_READY
	_world.reset()
	_gui.show_get_ready()


func _enter_playing() -> void:
	_state = State.PLAYING
	_gui.show_hud()
	_world.start_game()


func _on_user_authenticated(is_authenticated: bool) -> void:
	_signed_in = is_authenticated


func _on_game_over() -> void:
	_state = State.GAME_OVER
	_gui.show_game_over(_world.score)


func _on_new_best_score(score: int) -> void:
	if not _signed_in or score <= 0:
		return
	if _platform == "Android":
		_leaderboards_client.submit_score(ANDROID_LEADERBOARD_ID, score)
	elif _platform == "iOS":
		_submit_game_center_score(score)
	elif _platform == "Web":
		RanksClient.submit_score(score)


func _submit_game_center_score(score: int) -> void:
	var gk_lb = ClassDB.instantiate(&"GKLeaderboard")
	gk_lb.call(
		"load_leaderboards",
		PackedStringArray([IOS_LEADERBOARD_ID]),
		func(leaderboards: Array, error: Variant) -> void:
			if error or leaderboards.is_empty():
				return
			leaderboards[0].submit_score(
				score,
				0,
				_game_center.local_player,
				func(submit_error: Variant) -> void:
					if submit_error:
						push_warning("Score submit error: %s" % submit_error)
			)
	)


func _on_score_changed(new_score: int) -> void:
	_gui.update_score(new_score)


func _on_rate_button_pressed() -> void:
	OS.shell_open("https://github.com/LuminaAppsDev/flappybird")


func _on_play_pressed() -> void:
	if _platform == "Web" and _signed_in:
		RanksClient.create_session()
	_enter_get_ready()


func _on_retry_pressed() -> void:
	if _platform == "Web" and _signed_in:
		RanksClient.create_session()
	_enter_get_ready()


func _on_score_button_pressed() -> void:
	if _platform == "Web":
		_leaderboard_popup.open()
	elif _signed_in:
		_show_leaderboard()
	elif _platform == "Android":
		_sign_in_client.sign_in()


func _show_leaderboard() -> void:
	if _platform == "Android":
		_leaderboards_client.show_leaderboard(ANDROID_LEADERBOARD_ID)
	elif _platform == "iOS":
		var gk_vc = ClassDB.instantiate(&"GKGameCenterViewController")
		gk_vc.call("show_leaderboard_time_period", IOS_LEADERBOARD_ID, 0, 2)
	elif _platform == "Web":
		_leaderboard_popup.open()
