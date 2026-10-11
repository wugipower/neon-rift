extends Control
## 节点式区域地图：把 nodes.csv 渲染成可点击的节点图。
## 已完成=灰(禁用)，可进入=高亮，未解锁=暗(禁用)。
## story/ending 节点→播对话后完成；battle/boss 节点→设置遭遇并切到战斗场景。

const TYPE_COLOR := {
	"story": Color(0.35, 0.75, 0.95),
	"battle": Color(0.95, 0.6, 0.25),
	"boss": Color(0.95, 0.3, 0.3),
	"ending": Color(1.0, 0.85, 0.3),
}

var _gold_label: Label
var _party_label: Label
var _node_layer: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "区域地图 · 选择节点推进"
	title.position = Vector2(30, 14)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	add_child(title)

	_gold_label = Label.new()
	_gold_label.position = Vector2(30, 46)
	_gold_label.add_theme_font_size_override("font_size", 17)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	add_child(_gold_label)

	_party_label = Label.new()
	_party_label.position = Vector2(300, 46)
	_party_label.size = Vector2(700, 24)
	_party_label.add_theme_font_size_override("font_size", 15)
	_party_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	add_child(_party_label)

	var hub_btn := Button.new()
	hub_btn.text = "据点(事务所)"
	hub_btn.position = Vector2(1000, 14)
	hub_btn.size = Vector2(120, 44)
	hub_btn.add_theme_font_size_override("font_size", 15)
	hub_btn.pressed.connect(func(): SceneLoader.goto_hub())
	add_child(hub_btn)

	var menu_btn := Button.new()
	menu_btn.text = "主菜单"
	menu_btn.position = Vector2(1130, 14)
	menu_btn.size = Vector2(110, 44)
	menu_btn.add_theme_font_size_override("font_size", 15)
	menu_btn.pressed.connect(func(): SceneLoader.goto_menu())
	add_child(menu_btn)

	_node_layer = Control.new()
	add_child(_node_layer)

	_refresh()
	NeonTheme.apply_tree(self)
	AudioManager.play_bgm("bgm_menu")


func _refresh() -> void:
	_gold_label.text = "金钱：%d G" % GameState.gold
	var parts: Array = []
	for m in GameState.party_summary():
		parts.append("%s Lv%d" % [m["name"], m["level"]])
	_party_label.text = "队伍：" + "　".join(parts)

	for c in _node_layer.get_children():
		c.queue_free()

	for id in DataManager.node_order:
		_make_node_button(String(id))
	NeonTheme.apply_tree(self)


func _make_node_button(id: String) -> void:
	var node: Dictionary = DataManager.get_node_data(id)
	if node.is_empty():
		return
	var completed: bool = GameState.is_completed(id)
	var open: bool = GameState.is_node_open(id)
	var ntype: String = String(node.get("type", "story"))

	var b := Button.new()
	var label: String = String(node.get("name", id))
	if completed:
		label = "✓ " + label
	b.text = "第%s章\n%s" % [String(node.get("chapter", "?")), label]
	b.position = Vector2(float(node.get("x", 100)), float(node.get("y", 100)) + 40)
	b.size = Vector2(150, 54)
	b.add_theme_font_size_override("font_size", 13)
	b.disabled = not open
	b.clip_text = false

	var col: Color = TYPE_COLOR.get(ntype, Color(0.6, 0.6, 0.7))
	if completed:
		b.modulate = Color(0.45, 0.45, 0.5)
	elif open:
		b.modulate = col * Color(1.25, 1.25, 1.25)
	else:
		b.modulate = Color(0.3, 0.3, 0.35)
	if open:
		b.pressed.connect(_enter_node.bind(id))
	_node_layer.add_child(b)


func _enter_node(id: String) -> void:
	var node: Dictionary = DataManager.get_node_data(id)
	var ntype: String = String(node.get("type", "story"))

	if ntype == "battle" or ntype == "boss":
		GameState.set_pending_battle(id)
		SceneLoader.goto_battle()
		return

	# story / ending：播对话
	var did: String = String(node.get("dialogue", ""))
	var lines: Array = DataManager.get_dialogue(did)
	if lines.size() > 0:
		var db := DialogueBox.new(lines)
		add_child(db)
		await db.finished
	GameState.complete_node(id)

	if GameState.is_finished():
		_show_ending()
	else:
		_refresh()


func _show_ending() -> void:
	var panel := Panel.new()
	panel.position = Vector2(340, 240)
	panel.size = Vector2(600, 220)
	add_child(panel)
	var lbl := Label.new()
	lbl.text = "通 关 ！\n裂隙已被封印。\n\n金钱 %d G · 主线节点 %d 个" % [GameState.gold, GameState.completed.size()]
	lbl.position = Vector2(20, 20)
	lbl.size = Vector2(560, 120)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	panel.add_child(lbl)
	var back := Button.new()
	back.text = "返回主菜单"
	back.position = Vector2(200, 150)
	back.size = Vector2(200, 50)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): SceneLoader.goto_menu())
	panel.add_child(back)
	NeonTheme.apply_tree(self)
