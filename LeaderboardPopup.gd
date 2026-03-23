extends Control
## Popup overlay showing the player's profile and top-10 leaderboard.

signal closed

const AVATAR_SIZE := 24
const PROFILE_AVATAR_SIZE := 32

var _avatar_rects: Dictionary = {}

@onready var _username_label: Label = $Panel/VBox/ProfileSection/UsernameLabel
@onready var _avatar_rect: TextureRect = $Panel/VBox/ProfileSection/AvatarRect
@onready var _edit_button: Button = $Panel/VBox/ProfileSection/EditButton
@onready var _entries_container: VBoxContainer = $Panel/VBox/ScrollContainer/EntriesContainer
@onready var _loading_label: Label = $Panel/VBox/ScrollContainer/LoadingLabel
@onready var _close_button: Button = $Panel/VBox/CloseButton
@onready var _edit_panel: Control = $Panel/EditUsernamePanel
@onready var _name_input: LineEdit = $Panel/EditUsernamePanel/VBox/LineEdit
@onready var _confirm_button: Button = $Panel/EditUsernamePanel/VBox/Buttons/ConfirmButton
@onready var _cancel_button: Button = $Panel/EditUsernamePanel/VBox/Buttons/CancelButton
@onready var _dimmer: ColorRect = $Dimmer


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)
	_edit_button.pressed.connect(_on_edit_pressed)
	_confirm_button.pressed.connect(_on_confirm_username)
	_cancel_button.pressed.connect(_on_cancel_edit)
	_dimmer.gui_input.connect(_on_dimmer_input)


func open() -> void:
	_edit_panel.visible = false
	_avatar_rects.clear()
	var has_profile := RanksClient.is_registered
	_edit_button.visible = has_profile
	if has_profile:
		_username_label.text = RanksClient.username
		_avatar_rect.texture = null
		RanksClient.fetch_avatar(RanksClient.uuid)
	else:
		_username_label.text = "Not registered"
		_avatar_rect.texture = null
	_clear_entries()
	_loading_label.visible = true
	visible = true

	if not RanksClient.leaderboard_loaded.is_connected(_on_leaderboard_loaded):
		RanksClient.leaderboard_loaded.connect(_on_leaderboard_loaded)
	if not RanksClient.avatar_loaded.is_connected(_on_avatar_loaded):
		RanksClient.avatar_loaded.connect(_on_avatar_loaded)
	if not RanksClient.username_changed.is_connected(_on_username_changed):
		RanksClient.username_changed.connect(_on_username_changed)

	RanksClient.fetch_leaderboard(100)


func close() -> void:
	visible = false
	closed.emit()


func _clear_entries() -> void:
	for child in _entries_container.get_children():
		child.queue_free()


func _on_leaderboard_loaded(entries: Array) -> void:
	_loading_label.visible = false
	_clear_entries()

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No scores yet"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_label_style(empty_label, 9)
		_entries_container.add_child(empty_label)
		return

	var display_count := mini(entries.size(), 10)
	for i in display_count:
		var entry: Variant = entries[i]
		if not entry is Dictionary:
			continue
		var row := _create_entry_row(entry)
		_entries_container.add_child(row)
		var entry_uuid: String = entry.get("uuid", "")
		if not entry_uuid.is_empty():
			RanksClient.fetch_avatar(entry_uuid)

	_append_personal_row(entries, display_count)


func _create_entry_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var rank_label := Label.new()
	var rank_val: int = int(entry.get("rank", 0))
	rank_label.text = str(rank_val) if rank_val > 0 else "-"
	rank_label.custom_minimum_size.x = 20
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_label_style(rank_label, 9)
	row.add_child(rank_label)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(avatar)

	var entry_uuid: String = entry.get("uuid", "")
	if not entry_uuid.is_empty():
		_avatar_rects[entry_uuid] = avatar

	var name_label := Label.new()
	name_label.text = entry.get("username", "???")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	_apply_label_style(name_label, 9)
	row.add_child(name_label)

	var score_label := Label.new()
	score_label.text = str(int(entry.get("score", 0)))
	score_label.custom_minimum_size.x = 40
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_label_style(score_label, 9)
	row.add_child(score_label)

	return row


func _on_avatar_loaded(target_uuid: String, texture: ImageTexture) -> void:
	if target_uuid == RanksClient.uuid:
		_avatar_rect.texture = texture
	if _avatar_rects.has(target_uuid):
		var rect: TextureRect = _avatar_rects[target_uuid]
		if is_instance_valid(rect):
			rect.texture = texture


func _on_edit_pressed() -> void:
	_name_input.text = RanksClient.username
	_edit_panel.visible = true
	_name_input.grab_focus()


func _on_confirm_username() -> void:
	var new_name := _name_input.text.strip_edges()
	if new_name.length() < 3 or new_name.length() > 32:
		return
	_edit_panel.visible = false
	RanksClient.change_username(new_name)


func _on_cancel_edit() -> void:
	_edit_panel.visible = false


func _on_username_changed(new_name: String) -> void:
	_username_label.text = new_name


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _append_personal_row(entries: Array, displayed: int) -> void:
	if not RanksClient.is_registered:
		return
	var personal_entry: Dictionary = {}
	for entry: Variant in entries:
		if entry is Dictionary and entry.get("uuid", "") == RanksClient.uuid:
			personal_entry = entry
			break
	if personal_entry.is_empty():
		return
	if int(personal_entry.get("rank", 0)) <= displayed:
		return

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_entries_container.add_child(sep)

	var row := _create_entry_row(personal_entry)
	_entries_container.add_child(row)
	RanksClient.fetch_avatar(RanksClient.uuid)


func _apply_label_style(label: Label, size: int) -> void:
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = Color.WHITE
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	label.label_settings = settings
