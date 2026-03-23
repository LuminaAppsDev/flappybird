extends Node
## API client for the PWA leaderboard service at ranks.flappybird2026.com.
## Registered as autoload; only active on Web platform.

signal registered(success: bool)
signal session_created(success: bool)
signal score_submitted(rank: int)
signal leaderboard_loaded(entries: Array)
signal username_changed(new_name: String)
signal avatar_loaded(target_uuid: String, texture: ImageTexture)

const BASE_URL := "https://ranks.flappybird2026.com/api/v1"
const GAME_SLUG := "flappy-bird"
const CREDENTIALS_PATH := "user://ranks.cfg"
const AVATAR_DIR := "user://avatars/"

var uuid: String = ""
var secret_token: String = ""
var username: String = ""
var session_id: String = ""
var is_registered: bool = false


func _ready() -> void:
	if OS.get_name() != "Web":
		return
	DirAccess.make_dir_recursive_absolute(AVATAR_DIR)
	if _load_credentials():
		is_registered = true
	else:
		register()


func register() -> void:
	uuid = _generate_uuid_v4()
	var body := JSON.stringify({"uuid": uuid})
	var http := _create_http()
	http.request_completed.connect(_on_register_completed.bind(http))
	(
		http
		. request(
			BASE_URL + "/register",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			body,
		)
	)


func create_session() -> void:
	if not is_registered:
		session_created.emit(false)
		return
	var body := JSON.stringify({"game_slug": GAME_SLUG})
	var http := _create_http()
	http.request_completed.connect(_on_session_completed.bind(http))
	(
		http
		. request(
			BASE_URL + "/sessions",
			_auth_headers(),
			HTTPClient.METHOD_POST,
			body,
		)
	)


func submit_score(score: int) -> void:
	if not is_registered or session_id.is_empty():
		score_submitted.emit(-1)
		return
	var body := JSON.stringify({"session_id": session_id, "score": score})
	var sid := session_id
	session_id = ""
	var http := _create_http()
	http.request_completed.connect(_on_score_completed.bind(http, sid))
	(
		http
		. request(
			BASE_URL + "/scores",
			_auth_headers(),
			HTTPClient.METHOD_POST,
			body,
		)
	)


func fetch_leaderboard(limit: int = 10) -> void:
	var url := BASE_URL + "/games/%s/leaderboard?limit=%d" % [GAME_SLUG, limit]
	var http := _create_http()
	http.request_completed.connect(_on_leaderboard_completed.bind(http))
	http.request(url, [], HTTPClient.METHOD_GET)


func change_username(new_name: String) -> void:
	if not is_registered:
		return
	var url := BASE_URL + "/users/%s" % uuid
	var body := JSON.stringify({"username": new_name})
	var http := _create_http()
	http.request_completed.connect(_on_username_completed.bind(http))
	(
		http
		. request(
			url,
			_auth_headers(),
			HTTPClient.METHOD_PATCH,
			body,
		)
	)


func fetch_avatar(target_uuid: String) -> void:
	var cache_path := AVATAR_DIR + target_uuid + ".png"
	if FileAccess.file_exists(cache_path):
		var tex := _load_avatar_from_disk(cache_path)
		if tex:
			avatar_loaded.emit(target_uuid, tex)
			return
	var url := BASE_URL + "/avatars/%s.png" % target_uuid
	var http := _create_http()
	http.request_completed.connect(_on_avatar_completed.bind(http, target_uuid))
	http.request(url, [], HTTPClient.METHOD_GET)


func fetch_user_profile() -> void:
	if not is_registered:
		return
	var url := BASE_URL + "/users/%s" % uuid
	var http := _create_http()
	http.request_completed.connect(_on_profile_completed.bind(http))
	http.request(url, [], HTTPClient.METHOD_GET)


# -- Callbacks ----------------------------------------------------------------


func _on_register_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 201:
		push_warning("RanksClient: registration failed (code %d)" % code)
		registered.emit(false)
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json is Dictionary:
		registered.emit(false)
		return
	secret_token = json.get("secret_token", "")
	username = json.get("username", "")
	_save_credentials()
	is_registered = true
	registered.emit(true)


func _on_session_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 201:
		push_warning("RanksClient: session creation failed (code %d)" % code)
		session_created.emit(false)
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json is Dictionary:
		session_created.emit(false)
		return
	session_id = json.get("session_id", "")
	session_created.emit(true)


func _on_score_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
	_sid: String,
) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 201:
		push_warning("RanksClient: score submission failed (code %d)" % code)
		score_submitted.emit(-1)
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json is Dictionary:
		score_submitted.emit(-1)
		return
	score_submitted.emit(json.get("rank", -1))


func _on_leaderboard_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("RanksClient: leaderboard fetch failed (code %d)" % code)
		leaderboard_loaded.emit([])
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json is Dictionary:
		leaderboard_loaded.emit([])
		return
	leaderboard_loaded.emit(json.get("entries", []))


func _on_username_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("RanksClient: username change failed (code %d)" % code)
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json is Dictionary:
		return
	var new_name: String = json.get("username", "")
	if not new_name.is_empty():
		username = new_name
		_save_credentials()
		username_changed.emit(new_name)


func _on_avatar_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
	target_uuid: String,
) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var cache_path := AVATAR_DIR + target_uuid + ".png"
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
	var img := Image.new()
	if img.load_png_from_buffer(body) != OK:
		return
	var tex := ImageTexture.create_from_image(img)
	avatar_loaded.emit(target_uuid, tex)


func _on_profile_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json is Dictionary:
		return
	var fetched_name: String = json.get("username", "")
	if not fetched_name.is_empty() and fetched_name != username:
		username = fetched_name
		_save_credentials()


# -- Helpers ------------------------------------------------------------------


func _create_http() -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	return http


func _auth_headers() -> PackedStringArray:
	return PackedStringArray(
		[
			"Content-Type: application/json",
			"X-User-UUID: %s" % uuid,
			"X-Auth-Token: %s" % secret_token,
		]
	)


func _load_credentials() -> bool:
	var config := ConfigFile.new()
	if config.load(CREDENTIALS_PATH) != OK:
		return false
	uuid = config.get_value("auth", "uuid", "")
	secret_token = config.get_value("auth", "secret_token", "")
	username = config.get_value("auth", "username", "")
	return not uuid.is_empty() and not secret_token.is_empty()


func _save_credentials() -> void:
	var config := ConfigFile.new()
	config.set_value("auth", "uuid", uuid)
	config.set_value("auth", "secret_token", secret_token)
	config.set_value("auth", "username", username)
	config.save(CREDENTIALS_PATH)


func _generate_uuid_v4() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = randi() % 256
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [
			hex.substr(0, 8),
			hex.substr(8, 4),
			hex.substr(12, 4),
			hex.substr(16, 4),
			hex.substr(20, 12),
		]
	)


func _load_avatar_from_disk(path: String) -> ImageTexture:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var data := file.get_buffer(file.get_length())
	file.close()
	var img := Image.new()
	if img.load_png_from_buffer(data) != OK:
		return null
	return ImageTexture.create_from_image(img)
