extends Control
## P4 战斗场景（占位方块版）：1 名角色 vs 1 个敌人，普攻对轰，演示战斗核心循环。
## 表现层——真正的战斗规则都在 BattleLogic / DamageCalc / TurnQueue 里（已单测通过）。
## P5 会在此基础上加入技能/元素/状态/多单位/敌人AI。

signal player_acted

const PLAYER_CHAR := "lin"
const PLAYER_LEVEL := 5
const ENEMY_ID := "e_slime"

var logic: BattleLogic
var views := {}          # Unit -> 视图引用字典
var _status: Label
var _log_label: Label
var _attack_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_battle()


# ---------------- UI 构建 ----------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "战斗核心 MVP (P4) · 普攻对轰演示"
	title.position = Vector2(40, 24)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	add_child(title)

	_log_label = Label.new()
	_log_label.position = Vector2(40, 70)
	_log_label.size = Vector2(600, 200)
	_log_label.add_theme_font_size_override("font_size", 15)
	_log_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_log_label)

	_status = Label.new()
	_status.position = Vector2(40, 640)
	_status.size = Vector2(760, 40)
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	add_child(_status)

	_attack_btn = Button.new()
	_attack_btn.text = "攻击"
	_attack_btn.position = Vector2(860, 630)
	_attack_btn.size = Vector2(160, 54)
	_attack_btn.add_theme_font_size_override("font_size", 22)
	_attack_btn.disabled = true
	_attack_btn.pressed.connect(func(): player_acted.emit())
	add_child(_attack_btn)

	var restart := Button.new()
	restart.text = "重新开始"
	restart.position = Vector2(1050, 630)
	restart.size = Vector2(150, 54)
	restart.add_theme_font_size_override("font_size", 18)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	add_child(restart)


## 创建一个战斗单位的占位视图，返回引用字典
func _make_view(unit: Unit, pos: Vector2, color: Color) -> Dictionary:
	var root := Control.new()
	root.position = pos
	root.size = Vector2(240, 220)
	add_child(root)

	var body := ColorRect.new()
	body.color = color
	body.position = Vector2(60, 0)
	body.size = Vector2(120, 120)
	root.add_child(body)

	var name_label := Label.new()
	name_label.text = "%s  Lv%d" % [unit.display_name, unit.level]
	name_label.position = Vector2(0, 128)
	name_label.size = Vector2(240, 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	root.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = unit.hp_max
	hp_bar.value = unit.hp
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(20, 158)
	hp_bar.size = Vector2(200, 18)
	hp_bar.modulate = color
	root.add_child(hp_bar)

	var hp_text := Label.new()
	hp_text.text = "%d / %d" % [unit.hp, unit.hp_max]
	hp_text.position = Vector2(0, 180)
	hp_text.size = Vector2(240, 24)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 16)
	root.add_child(hp_text)

	var elem := Label.new()
	elem.text = "元素：%s" % unit.element
	elem.position = Vector2(0, 202)
	elem.size = Vector2(240, 20)
	elem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elem.add_theme_font_size_override("font_size", 13)
	elem.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	root.add_child(elem)

	return {"root": root, "body": body, "hp_bar": hp_bar, "hp_text": hp_text, "color": color}


# ---------------- 战斗流程 ----------------

func _start_battle() -> void:
	var hero := Unit.from_character(DataManager.get_character(PLAYER_CHAR), PLAYER_LEVEL)
	var foe := Unit.from_enemy(DataManager.get_enemy(ENEMY_ID))
	views.clear()
	views[hero] = _make_view(hero, Vector2(180, 340), Color(0.3, 0.6, 1.0))
	views[foe] = _make_view(foe, Vector2(840, 120), Color(1.0, 0.4, 0.35))
	logic = BattleLogic.new([hero], [foe])
	_set_log("战斗开始！%s(Lv%d) vs %s(Lv%d)" % [hero.display_name, hero.level, foe.display_name, foe.level])
	_run()


func _run() -> void:
	while not logic.over:
		var actor: Unit = logic.current_actor()
		if actor == null:
			logic.step()  # 结束本轮，开启新回合
			_append_log("—— 第 %d 回合 ——" % logic.round_num)
			continue

		if logic.is_player_actor(actor):
			_status.text = "轮到 %s，点击【攻击】" % actor.display_name
			_attack_btn.disabled = false
			await player_acted
			_attack_btn.disabled = true
		else:
			_status.text = "敌方 %s 行动中…" % actor.display_name
			await get_tree().create_timer(0.75).timeout

		var ev: Dictionary = logic.step()
		_render_attack(ev)
		await get_tree().create_timer(0.5).timeout

	_attack_btn.disabled = true
	if logic.winner == "player":
		_status.text = "战斗结束：你赢了！ 🎉"
		_append_log(">> 玩家获胜，用了 %d 回合" % logic.round_num)
	else:
		_status.text = "战斗结束：你被击败了…"
		_append_log(">> 敌方获胜")


func _render_attack(ev: Dictionary) -> void:
	if ev.get("type") != "attack":
		return
	var actor: Unit = ev["actor"]
	var target: Unit = ev["target"]
	var res: Dictionary = ev["result"]
	var tv: Dictionary = views[target]

	if not res["hit"]:
		_float_text(tv, "MISS", Color(0.7, 0.7, 0.7))
		_append_log("%s 攻击 %s —— 未命中" % [actor.display_name, target.display_name])
	elif res.get("is_heal", false):
		_float_text(tv, "+%d" % int(res["damage"]), Color(0.4, 1.0, 0.5))
	else:
		var txt := "-%d" % int(res["damage"])
		if res["crit"]:
			txt += " 暴击!"
		_float_text(tv, txt, Color(1.0, 0.85, 0.2) if res["crit"] else Color(1.0, 0.4, 0.35))
		_flash(tv["body"])
		_append_log("%s 对 %s 造成 %d 点伤害%s（减伤%.0f%% 元素x%.2f）" % [
			actor.display_name, target.display_name, int(res["damage"]),
			" [暴击]" if res["crit"] else "", res["mitigation"] * 100.0, res["element_mult"]])

	_refresh_hp(target)


func _refresh_hp(unit: Unit) -> void:
	var v: Dictionary = views[unit]
	v["hp_bar"].max_value = unit.hp_max
	v["hp_bar"].value = unit.hp
	v["hp_text"].text = "%d / %d" % [unit.hp, unit.hp_max]
	if not unit.is_alive():
		v["body"].modulate = Color(0.3, 0.3, 0.3)
		v["hp_text"].text = "倒下"


func _float_text(tv: Dictionary, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = tv["root"].position + Vector2(70, 20)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -60), 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)


func _flash(body: ColorRect) -> void:
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(3, 3, 3), 0.08)
	tw.tween_property(body, "modulate", Color(1, 1, 1), 0.15)


func _set_log(text: String) -> void:
	_log_label.text = text

func _append_log(text: String) -> void:
	_log_label.text = (_log_label.text + "\n" + text) if _log_label.text != "" else text
	# 只保留最近若干行，避免溢出
	var lines := _log_label.text.split("\n")
	if lines.size() > 9:
		_log_label.text = "\n".join(lines.slice(lines.size() - 9))
