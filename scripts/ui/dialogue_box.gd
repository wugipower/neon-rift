class_name DialogueBox
extends Control
## 可复用对话框：逐句显示 [{speaker,text}]，点击/空格推进，结束发 finished 信号并自毁。
## 由地图/据点在需要播剧情时 new 出来 add_child。

signal finished

var _lines: Array = []
var _i: int = 0
var _speaker: Label
var _text: Label


func _init(lines: Array) -> void:
	_lines = lines


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(140, 470)
	panel.size = Vector2(1000, 190)
	add_child(panel)

	_speaker = Label.new()
	_speaker.position = Vector2(30, 18)
	_speaker.size = Vector2(940, 34)
	_speaker.add_theme_font_size_override("font_size", 24)
	_speaker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	panel.add_child(_speaker)

	_text = Label.new()
	_text.position = Vector2(30, 62)
	_text.size = Vector2(940, 90)
	_text.add_theme_font_size_override("font_size", 20)
	_text.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_text)

	var hint := Label.new()
	hint.text = "点击任意处继续 ▸"
	hint.position = Vector2(30, 158)
	hint.size = Vector2(940, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	panel.add_child(hint)

	# 面板与文字不拦截鼠标，保证"点击任意处"都能落到根节点推进
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in panel.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	gui_input.connect(_on_gui_input)
	NeonTheme.apply_tree(self)

	if _lines.is_empty():
		finished.emit()
		queue_free()
		return
	_render()


func _render() -> void:
	var line: Dictionary = _lines[_i]
	_speaker.text = String(line.get("speaker", ""))
	_text.text = String(line.get("text", ""))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	_i += 1
	if _i >= _lines.size():
		finished.emit()
		queue_free()
	else:
		_render()
