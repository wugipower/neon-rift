extends Control
## P5 战斗场景（占位方块版）：三人队 vs 多敌，完整技能/元素/状态/敌人AI/多阶段演示。
## 表现层——所有战斗规则都在 BattleLogic / SkillExecutor / EnemyAI / DamageCalc（已单测通过）。
## 玩家回合：点技能按钮 → 若为单体技能再点目标 → 结算。敌人回合由 EnemyAI 自动决策。

signal player_committed

const PLAYER_LEVEL := 6
const PARTY := ["lin", "cang", "miao"]
const FOES := ["e_slime", "e_bat", "e_turret"]

const ELEMENT_COLOR := {
	"电": Color(1.0, 0.85, 0.25),
	"水": Color(0.3, 0.6, 1.0),
	"火": Color(1.0, 0.45, 0.25),
	"冰": Color(0.45, 0.9, 1.0),
	"无": Color(0.7, 0.7, 0.75),
}

var logic: BattleLogic
var views := {}              # Unit -> 视图引用字典
var _status: Label
var _log_label: Label
var _skill_bar: Control
var _chosen_skill: Dictionary = {}
var _awaiting_target: bool = false


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
	title.text = "霓虹裂隙 · 战斗系统 (P5)"
	title.position = Vector2(40, 18)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	add_child(title)

	_log_label = Label.new()
	_log_label.position = Vector2(40, 60)
	_log_label.size = Vector2(560, 210)
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_log_label)

	_status = Label.new()
	_status.position = Vector2(40, 648)
	_status.size = Vector2(900, 40)
	_status.add_theme_font_size_override("font_size", 19)
	_status.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	add_child(_status)

	# 技能条容器（玩家回合动态填充）
	_skill_bar = Control.new()
	_skill_bar.position = Vector2(620, 560)
	_skill_bar.size = Vector2(620, 80)
	add_child(_skill_bar)

	var restart := Button.new()
	restart.text = "重新开始"
	restart.position = Vector2(1090, 650)
	restart.size = Vector2(150, 50)
	restart.add_theme_font_size_override("font_size", 18)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	add_child(restart)


## 创建一个战斗单位的占位视图（body 为可点击按钮，用于选目标）
func _make_view(unit: Unit, pos: Vector2, is_enemy: bool) -> Dictionary:
	var color: Color = ELEMENT_COLOR.get(unit.element, Color(0.7, 0.7, 0.75))
	var root := Control.new()
	root.position = pos
	root.size = Vector2(230, 150)
	add_child(root)

	var body := Button.new()
	body.text = ""
	body.flat = true
	body.position = Vector2(55, 0)
	body.size = Vector2(110, 90)
	body.modulate = color
	root.add_child(body)

	var tag := Label.new()
	tag.text = "敌" if is_enemy else "我"
	tag.position = Vector2(55, 2)
	tag.size = Vector2(110, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color(0, 0, 0, 0.5))
	root.add_child(tag)

	var name_label := Label.new()
	name_label.text = "%s Lv%d·%s" % [unit.display_name, unit.level, unit.element]
	name_label.position = Vector2(0, 92)
	name_label.size = Vector2(230, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	root.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = unit.hp_max
	hp_bar.value = unit.hp
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(15, 116)
	hp_bar.size = Vector2(200, 12)
	hp_bar.modulate = Color(0.4, 0.9, 0.45)
	root.add_child(hp_bar)

	var hp_text := Label.new()
	hp_text.text = "%d/%d" % [unit.hp, unit.hp_max]
	hp_text.position = Vector2(15, 114)
	hp_text.size = Vector2(200, 16)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 11)
	hp_text.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	root.add_child(hp_text)

	var mp_bar := ProgressBar.new()
	mp_bar.max_value = maxi(1, unit.mp_max)
	mp_bar.value = unit.mp
	mp_bar.show_percentage = false
	mp_bar.position = Vector2(15, 132)
	mp_bar.size = Vector2(200, 7)
	mp_bar.modulate = Color(0.4, 0.6, 1.0)
	root.add_child(mp_bar)

	var status_label := Label.new()
	status_label.text = ""
	status_label.position = Vector2(0, 140)
	status_label.size = Vector2(230, 18)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	root.add_child(status_label)

	body.pressed.connect(_on_unit_clicked.bind(unit))

	return {"root": root, "body": body, "name_label": name_label, "hp_bar": hp_bar,
			"hp_text": hp_text, "mp_bar": mp_bar, "status_label": status_label,
			"color": color, "is_enemy": is_enemy}


# ---------------- 战斗流程 ----------------

func _start_battle() -> void:
	views.clear()
	var party: Array = []
	var foes: Array = []
	for i in PARTY.size():
		var u := Unit.from_character(DataManager.get_character(PARTY[i]), PLAYER_LEVEL)
		party.append(u)
		views[u] = _make_view(u, Vector2(60 + i * 130, 420), false)
	for i in FOES.size():
		var e := Unit.from_enemy(DataManager.get_enemy(FOES[i]))
		foes.append(e)
		views[e] = _make_view(e, Vector2(660 + i * 190, 120), true)
	logic = BattleLogic.new(party, foes)
	_set_log("战斗开始！我方 Lv%d × %d  vs  敌方 × %d" % [PLAYER_LEVEL, party.size(), foes.size()])
	_run()


func _run() -> void:
	while not logic.over:
		var actor: Unit = logic.current_actor()
		if actor == null:
			var ev0: Dictionary = logic.step()
			_render(ev0)
			continue

		if logic.is_player_actor(actor):
			_prompt_skills(actor)
			await player_committed
			_clear_skills()
		else:
			_status.text = "敌方 %s 行动中…" % actor.display_name
			_highlight(actor, false)
			await get_tree().create_timer(0.7).timeout

		var ev: Dictionary = logic.step()
		_render(ev)
		_refresh_all()
		await get_tree().create_timer(0.45).timeout

	_clear_skills()
	if logic.winner == "player":
		_status.text = "战斗结束：你赢了！"
		_append_log(">> 玩家获胜，用了 %d 回合" % logic.round_num)
	else:
		_status.text = "战斗结束：你被击败了…"
		_append_log(">> 敌方获胜")


## 为当前玩家角色生成技能按钮
func _prompt_skills(actor: Unit) -> void:
	_clear_skills()
	_chosen_skill = {}
	_awaiting_target = false
	_status.text = "轮到 %s：选择技能" % actor.display_name
	_highlight(actor, true)

	# 普攻按钮
	_add_skill_button("普攻", DamageCalc.basic_attack(actor), actor, 0)
	# 角色技能
	var row: Dictionary = DataManager.get_character(actor.uid)
	var ids: PackedStringArray = String(row.get("start_skills", "")).split("|")
	var col := 1
	for sid in ids:
		if sid == "":
			continue
		var sk: Dictionary = DataManager.get_skill(sid)
		if sk.is_empty():
			continue
		_add_skill_button("%s(%d)" % [sk.get("name", sid), int(sk.get("mp_cost", 0))], sk, actor, col)
		col += 1


func _add_skill_button(label: String, skill: Dictionary, actor: Unit, col: int) -> void:
	var b := Button.new()
	b.text = label
	b.position = Vector2(col * 122, 0)
	b.size = Vector2(116, 44)
	b.add_theme_font_size_override("font_size", 14)
	var cost: int = int(skill.get("mp_cost", 0))
	if actor.mp < cost:
		b.disabled = true
		b.tooltip_text = "能量不足"
	else:
		b.tooltip_text = String(skill.get("desc", ""))
	b.pressed.connect(_on_skill_pressed.bind(skill, actor))
	_skill_bar.add_child(b)


func _on_skill_pressed(skill: Dictionary, actor: Unit) -> void:
	_chosen_skill = skill
	var tgt: String = skill.get("target", "enemy_one")
	if tgt == "enemy_one" or tgt == "ally_one":
		_awaiting_target = true
		_status.text = "%s：点击一个目标" % skill.get("name", "技能")
		_mark_targets(actor, tgt)
	else:
		_commit(actor, null)


func _on_unit_clicked(unit: Unit) -> void:
	if not _awaiting_target:
		return
	var actor: Unit = logic.current_actor()
	if actor == null or not logic.is_player_actor(actor):
		return
	var tgt: String = _chosen_skill.get("target", "enemy_one")
	if not _is_valid_target(actor, unit, tgt):
		return
	_commit(actor, unit)


func _is_valid_target(actor: Unit, unit: Unit, tgt: String) -> bool:
	if not unit.is_alive():
		return false
	if tgt == "enemy_one":
		return (not logic.players.has(unit))
	if tgt == "ally_one":
		return logic.players.has(unit)
	return false


func _commit(actor: Unit, target: Unit) -> void:
	_awaiting_target = false
	logic.set_player_action(_chosen_skill, target)
	_status.text = ""
	player_committed.emit()


# ---------------- 事件渲染 ----------------

func _render(ev: Dictionary) -> void:
	var t: String = ev.get("type", "")
	if t == "round_end":
		_append_log("—— 第 %d 回合 ——" % ev.get("round", logic.round_num))
		return
	if t == "skip":
		_append_log("%s 因感电麻痹，跳过了行动" % ev["actor"].display_name)
		return
	if t == "dot_death":
		_append_log("%s 因持续伤害倒下了" % ev["actor"].display_name)
		return
	if t != "action":
		return

	var actor: Unit = ev["actor"]
	_highlight(actor, false)
	# 回合开始的 DoT/HoT
	var tick: Dictionary = ev.get("tick", {})
	if int(tick.get("dot", 0)) > 0:
		_float_text(views[actor], "-%d" % int(tick["dot"]), Color(1.0, 0.5, 0.2))
		_append_log("%s 受到灼烧 %d 点" % [actor.display_name, int(tick["dot"])])
	if int(tick.get("hot", 0)) > 0:
		_float_text(views[actor], "+%d" % int(tick["hot"]), Color(0.4, 1.0, 0.5))
		_append_log("%s 回复了 %d 点生命" % [actor.display_name, int(tick["hot"])])

	var skill: Dictionary = ev["skill"]
	var sname: String = skill.get("name", "攻击")
	for e in ev["result"]["events"]:
		var target: Unit = e["target"]
		var tv: Dictionary = views[target]
		if e.has("result") and not e["result"].get("hit", true):
			_float_text(tv, "MISS", Color(0.7, 0.7, 0.7))
			_append_log("%s 的 %s 对 %s 未命中" % [actor.display_name, sname, target.display_name])
			continue
		if e.get("is_heal", false):
			_float_text(tv, "+%d" % int(e["damage"]), Color(0.4, 1.0, 0.5))
			_append_log("%s 用 %s 治疗 %s %d 点" % [actor.display_name, sname, target.display_name, int(e["damage"])])
		else:
			var res: Dictionary = e.get("result", {})
			var txt := "-%d" % int(e["damage"])
			var crit: bool = res.get("crit", false)
			if crit:
				txt += " 暴击!"
			_float_text(tv, txt, Color(1.0, 0.85, 0.2) if crit else Color(1.0, 0.4, 0.35))
			_flash(tv["body"])
			var extra := ""
			if res.has("element_mult") and absf(float(res["element_mult"]) - 1.0) > 0.01:
				extra = "（元素x%.2f）" % float(res["element_mult"])
			if int(e.get("absorbed", 0)) > 0:
				extra += "（护盾挡%d）" % int(e["absorbed"])
			_append_log("%s 用 %s 对 %s 造成 %d 点%s%s" % [
				actor.display_name, sname, target.display_name, int(e["damage"]),
				" [暴击]" if crit else "", extra])
		if bool(e.get("applied", false)):
			var eff: String = skill.get("effect", "")
			var sdef: Dictionary = DataManager.get_status(eff)
			_append_log("  ↳ %s 陷入【%s】" % [target.display_name, sdef.get("name", eff)])
		if bool(e.get("died", false)):
			_append_log("  ↳ %s 被击败！" % target.display_name)


func _refresh_all() -> void:
	for unit in views:
		var v: Dictionary = views[unit]
		v["hp_bar"].max_value = unit.hp_max
		v["hp_bar"].value = unit.hp
		v["hp_text"].text = "%d/%d" % [unit.hp, unit.hp_max]
		v["mp_bar"].max_value = maxi(1, unit.mp_max)
		v["mp_bar"].value = unit.mp
		var names: Array = unit.status_names()
		v["status_label"].text = " ".join(names) if names.size() > 0 else ""
		if not unit.is_alive():
			v["body"].modulate = Color(0.25, 0.25, 0.25)
			v["hp_text"].text = "倒下"
			v["body"].disabled = true
		else:
			v["body"].modulate = v["color"]


func _highlight(unit: Unit, on: bool) -> void:
	if not views.has(unit):
		return
	var v: Dictionary = views[unit]
	if not unit.is_alive():
		return
	v["body"].modulate = (v["color"] * Color(1.6, 1.6, 1.6)) if on else v["color"]


## 单体技能选目标时，高亮合法目标
func _mark_targets(actor: Unit, tgt: String) -> void:
	for unit in views:
		if not unit.is_alive():
			continue
		var valid: bool = _is_valid_target(actor, unit, tgt)
		var v: Dictionary = views[unit]
		v["body"].modulate = (v["color"] * Color(1.5, 1.5, 0.9)) if valid else (v["color"] * Color(0.6, 0.6, 0.6))


func _clear_skills() -> void:
	for c in _skill_bar.get_children():
		c.queue_free()
	# 复位高亮
	for unit in views:
		if unit.is_alive():
			views[unit]["body"].modulate = views[unit]["color"]


# ---------------- 小工具 ----------------

func _float_text(tv: Dictionary, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = tv["root"].position + Vector2(60, 10)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -55), 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)


func _flash(body: Button) -> void:
	var base: Color = Color(1, 1, 1)
	for unit in views:
		if views[unit]["body"] == body and unit.is_alive():
			base = views[unit]["color"]
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(3, 3, 3), 0.08)
	tw.tween_property(body, "modulate", base, 0.15)


func _set_log(text: String) -> void:
	_log_label.text = text


func _append_log(text: String) -> void:
	_log_label.text = (_log_label.text + "\n" + text) if _log_label.text != "" else text
	var lines := _log_label.text.split("\n")
	if lines.size() > 11:
		_log_label.text = "\n".join(lines.slice(lines.size() - 11))
