class_name WebKeyboardHelper
extends Node
## Workaround for mobile virtual keyboard issues in Godot HTML5 exports.
##
## Godot renders everything to a <canvas>, which causes two problems on mobile
## web browsers:
##   1. iOS WebKit refuses to show the on-screen keyboard unless a real user
##      gesture (tap) occurs on a native HTML <input> element.  Workaround:
##      inject a hidden HTML <input> and focus it instead of the Godot LineEdit.
##   2. Android Chrome consumes the user gesture on the canvas, so a
##      programmatic input.focus() no longer counts as user-initiated and the
##      keyboard will not appear.  Additionally, Godot's own IME handling is
##      broken — typed characters are not forwarded to LineEdit.  Workaround:
##      fall back to window.prompt(), which always shows a native input dialog.
##
## References:
##   https://github.com/nicoepp/nicmern.de/blob/main/docs/blog/ios-keyboard-bug-godot-engine.md
##   https://github.com/nicoepp/nicmern.de/blob/main/docs/blog/ios-keyboard-bug-godot-engine-2.md

## Emitted when the user confirms input (presses Enter or the done button).
signal text_submitted(text: String)

## Emitted when the text content changes while typing.
signal text_changed(text: String)

## Whether the workaround is active. False on non-mobile-web platforms.
var is_active := false

## True when running on iOS/iPadOS WebKit (hidden <input> strategy).
var _is_ios := false

## True when running on Android (window.prompt fallback strategy).
var _is_android := false

var _js_callback_change: JavaScriptObject
var _js_callback_submit: JavaScriptObject


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	var user_agent: String = str(JavaScriptBridge.eval("navigator.userAgent"))
	_is_ios = (
		"iPhone" in user_agent
		or "iPad" in user_agent
		or (
			"Macintosh" in user_agent
			and str(JavaScriptBridge.eval("'ontouchend' in document")) == "true"
		)
	)
	_is_android = "Android" in user_agent
	if not _is_ios and not _is_android:
		return

	is_active = true
	# iOS needs a hidden HTML <input> + JS callbacks.
	# Android uses window.prompt() which needs no setup.
	if _is_ios:
		_create_callbacks()
		_inject_html_input()


func _create_callbacks() -> void:
	# Create persistent JS callbacks so they survive garbage collection.
	_js_callback_change = JavaScriptBridge.create_callback(_on_js_text_changed)
	_js_callback_submit = JavaScriptBridge.create_callback(_on_js_text_submitted)
	# Register callbacks on the window object for the HTML input to call.
	(
		JavaScriptBridge
		. eval(
			"""
		window._godotWebKbChange = null;
		window._godotWebKbSubmit = null;
	"""
		)
	)
	var win: JavaScriptObject = JavaScriptBridge.get_interface("window")
	win._godotWebKbChange = _js_callback_change
	win._godotWebKbSubmit = _js_callback_submit


func _inject_html_input() -> void:
	# Inject a hidden <input> element that iOS WebKit will recognize for
	# keyboard activation. Positioned off-screen by default, moved over the
	# canvas when focus is requested.
	(
		JavaScriptBridge
		. eval(
			"""
		(function() {
			if (document.getElementById('_godot_mobile_kb_input')) return;
			var input = document.createElement('input');
			input.id = '_godot_mobile_kb_input';
			input.type = 'text';
			input.autocapitalize = 'off';
			input.autocomplete = 'off';
			input.style.position = 'fixed';
			input.style.left = '-9999px';
			input.style.top = '0px';
			input.style.opacity = '0';
			input.style.fontSize = '16px';
			input.style.zIndex = '9999';
			input.style.width = '200px';
			input.style.height = '40px';
			input.style.pointerEvents = 'none';
			input.maxLength = 32;
			document.body.appendChild(input);

			input.addEventListener('input', function() {
				if (window._godotWebKbChange) {
					window._godotWebKbChange(input.value);
				}
			});

			input.addEventListener('keydown', function(e) {
				if (e.key === 'Enter') {
					e.preventDefault();
					if (window._godotWebKbSubmit) {
						window._godotWebKbSubmit(input.value);
					}
					input.blur();
				}
			});
		})();
	"""
		)
	)


## Open the mobile keyboard and sync text back to Godot.
## On iOS: focuses the hidden HTML <input>.
## On Android: opens a native window.prompt() dialog.
## [param initial_text] Pre-fills the input with existing text.
## [param max_length] Maximum character count (0 = unlimited).
func request_keyboard(initial_text: String, max_length: int = 0) -> void:
	if not is_active:
		return
	if _is_android:
		_request_prompt(initial_text)
		return
	_request_ios_keyboard(initial_text, max_length)


## Android fallback: use window.prompt() which always shows a native keyboard.
## The prompt is synchronous and returns the entered text directly.
func _request_prompt(initial_text: String) -> void:
	var escaped := initial_text.replace("\\", "\\\\").replace("'", "\\'")
	var result: Variant = (
		JavaScriptBridge
		. eval(
			(
				"""
		(function() {
			var r = window.prompt('Enter username', '%s');
			return r;
		})();
	"""
				% escaped
			)
		)
	)
	if result == null:
		return
	var value := str(result)
	if value == "null" or value.is_empty():
		return
	text_changed.emit(value)
	text_submitted.emit(value)


## iOS: focus the hidden HTML <input> so WebKit shows the keyboard.
func _request_ios_keyboard(initial_text: String, max_length: int) -> void:
	var escaped := initial_text.replace("\\", "\\\\").replace("'", "\\'")
	var ml_str := str(max_length) if max_length > 0 else "524288"
	(
		JavaScriptBridge
		. eval(
			(
				"""
		(function() {
			var input = document.getElementById('_godot_mobile_kb_input');
			if (!input) return;
			input.value = '%s';
			input.maxLength = %s;
			input.style.left = '0px';
			input.style.pointerEvents = 'auto';
			input.focus();
			input.setSelectionRange(input.value.length, input.value.length);
		})();
	"""
				% [escaped, ml_str]
			)
		)
	)


## Dismiss the keyboard and hide the HTML input (iOS only, no-op on Android).
func dismiss_keyboard() -> void:
	if not is_active or not _is_ios:
		return
	(
		JavaScriptBridge
		. eval(
			"""
		(function() {
			var input = document.getElementById('_godot_mobile_kb_input');
			if (!input) return;
			input.blur();
			input.style.left = '-9999px';
			input.style.pointerEvents = 'none';
		})();
	"""
		)
	)


func _on_js_text_changed(args: Array) -> void:
	var value: String = str(args[0]) if args.size() > 0 else ""
	text_changed.emit(value)


func _on_js_text_submitted(args: Array) -> void:
	var value: String = str(args[0]) if args.size() > 0 else ""
	text_submitted.emit(value)
