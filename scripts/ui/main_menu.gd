extends Control
## 主菜单：新游戏 / 继续（读档）/ 退出。

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "霓虹裂隙  NeonRift"
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	add_child(title)

	var sub := Label.new()
	sub.text = "都市·二次元幻想 2D 回合制 RPG　（秋招游戏策划作品 · Demo）"
	sub.position = Vector2(0, 235)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.55, 0.6, 0.72))
	add_child(sub)

	_add_button("新游戏", Vector2(490, 340), _on_new)
	var cont := _add_button("继续游戏", Vector2(490, 420), _on_continue)
	cont.disabled = not GameState.has_save()
	if cont.disabled:
		cont.tooltip_text = "暂无存档"
	_add_button("退出", Vector2(490, 500), _on_quit)

	var foot := Label.new()
	foot.text = "Godot 4.7 · GDScript · 数据驱动（12 张 CSV）"
	foot.position = Vector2(0, 660)
	foot.size = Vector2(1280, 24)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
	add_child(foot)

	NeonTheme.apply_tree(self)
	NeonTheme.add_bg_image(self, "res://assets/art/bg_rooftop.png", 0.35)
	AudioManager.play_bgm("bgm_menu")


func _add_button(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _on_new() -> void:
	GameState.new_game()
	SceneLoader.goto_map()


func _on_continue() -> void:
	if GameState.load_game():
		SceneLoader.goto_map()


func _on_quit() -> void:
	get_tree().quit()
