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

# P7：章节 → 战斗背景图
const BG_BY_CHAPTER := {
	0: "bg_office",
	1: "bg_subway",
	2: "bg_rooftop",
	3: "bg_rift",
}

var logic: BattleLogic
var views := {}              # Unit -> 视图引用字典
var _status: Label
var _log_label: Label
var _skill_bar: Control
var _flash_layer: ColorRect  # P7：元素闪屏层
var _shaking: bool = false
var _chosen_skill: Dictionary = {}
var _chosen_item: String = ""   # P7：待使用的道具 id
var _awaiting_target: bool = false

# 战役模式（从地图进入）：结算奖励/推进节点；否则为独立试玩 demo
var _campaign: bool = false
var _node_id: String = ""
var _enemy_ids: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_battle()


# ---------------- UI 构建 ----------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_offsets_preset(Control.PRESET_FULL_RECT)
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

	# P7：元素闪屏层（最上层、不拦鼠标）
	_flash_layer = ColorRect.new()
	_flash_layer.color = Color(1, 1, 1, 0.16)
	_flash_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_layer.set_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.modulate.a = 0.0
	add_child(_flash_layer)

	NeonTheme.apply_tree(self)


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
	var base_mod: Color = color
	if not is_enemy:
		# P7：我方显示立绘（有图时不再用元素色块）
		var tex: Texture2D = NeonTheme.load_tex("res://assets/art/portrait_%s.png" % unit.uid)
		if tex != null:
			body.icon = tex
			body.expand_icon = true
			body.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			base_mod = Color(1, 1, 1)
			body.modulate = base_mod
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
			"color": base_mod, "is_enemy": is_enemy}


# ---------------- 战斗流程 ----------------

func _start_battle() -> void:
	views.clear()
	var party: Array = []
	var foes: Array = []
	_enemy_ids = []

	if GameState.started and GameState.pending_node != "":
		# 战役模式：从 GameState 读取遭遇
		_campaign = true
		_node_id = GameState.pending_node
		for e in GameState.pending_enemies:
			_enemy_ids.append(String(e))
		party = GameState.build_party_units()
		foes = GameState.build_enemy_units(_enemy_ids)
	else:
		# 独立试玩 demo（双击 run_battle.bat）
		_campaign = false
		if GameState.items.is_empty():
			# demo 也给一点消耗品，便于展示「道具」指令
			GameState.items = {"i_potion_small": 3, "i_ether_small": 2, "i_revive": 1}
		for i in PARTY.size():
			party.append(Unit.from_character(DataManager.get_character(PARTY[i]), PLAYER_LEVEL))
		for i in FOES.size():
			_enemy_ids.append(FOES[i])
			foes.append(Unit.from_enemy(DataManager.get_enemy(FOES[i])))

	for i in party.size():
		views[party[i]] = _make_view(party[i], Vector2(60 + i * 130, 420), false)
	for i in foes.size():
		views[foes[i]] = _make_view(foes[i], Vector2(600 + i * 200, 120), true)

	logic = BattleLogic.new(party, foes)
	var title: String = "遭遇战"
	var chapter: int = 2
	var ntype: String = ""
	if _campaign:
		var nd: Dictionary = DataManager.get_node_data(_node_id)
		title = String(nd.get("name", "遭遇战"))
		chapter = int(nd.get("chapter", 0))
		ntype = String(nd.get("type", ""))
	# P7：章节背景图 + 按遭遇类型切 BGM
	NeonTheme.add_bg_image(self, "res://assets/art/%s.png" % BG_BY_CHAPTER.get(chapter, "bg_rooftop"), 0.30)
	move_child(_flash_layer, -1)
	AudioManager.play_bgm("bgm_boss" if ntype == "boss" else "bgm_battle")
	_set_log("战斗开始！%s　我方 %d vs 敌方 %d" % [title, party.size(), foes.size()])
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
		_on_victory()
	else:
		_on_defeat()


func _on_victory() -> void:
	_status.text = "战斗结束：你赢了！"
	_append_log(">> 玩家获胜，用了 %d 回合" % logic.round_num)
	AudioManager.play_sfx("sfx_victory")
	if not _campaign:
		return
	var reward: Dictionary = GameState.apply_battle_reward(_enemy_ids)
	GameState.complete_node(_node_id)
	GameState.save_game()          # 战斗胜利后自动存档
	GameState.pending_node = ""

	var txt := "战斗胜利！\n获得经验 %d · 金钱 %d G" % [int(reward["exp"]), int(reward["gold"])]
	if reward["drops"].size() > 0:
		var dnames: Array = []
		for d in reward["drops"]:
			dnames.append(String(DataManager.get_item(String(d)).get("name", d)))
		txt += "\n掉落：" + "、".join(dnames)
	if reward["levelups"].size() > 0:
		var lus: Array = []
		for lu in reward["levelups"]:
			lus.append("%s → Lv%d" % [
				DataManager.get_character(String(lu["id"])).get("name", lu["id"]), int(lu["level"])])
		txt += "\n升级：" + "、".join(lus)
	txt += "\n（已自动存档）"
	_show_result_panel(txt, "继续 →地图", func(): SceneLoader.goto_map())


func _on_defeat() -> void:
	_status.text = "战斗结束：你被击败了…"
	_append_log(">> 敌方获胜")
	AudioManager.play_sfx("sfx_defeat")
	if not _campaign:
		return
	GameState.pending_node = ""
	_show_result_panel("队伍被击败……\n返回据点休整（不会删档）。", "回据点", func(): SceneLoader.goto_hub())


func _show_result_panel(text: String, btn_label: String, cb: Callable) -> void:
	var panel := Panel.new()
	panel.position = Vector2(340, 210)
	panel.size = Vector2(600, 280)
	add_child(panel)
	NeonTheme.style_panel(panel)
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(24, 24)
	lbl.size = Vector2(552, 170)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.6))
	panel.add_child(lbl)
	var b := Button.new()
	b.text = btn_label
	b.position = Vector2(200, 210)
	b.size = Vector2(200, 52)
	b.add_theme_font_size_override("font_size", 18)
	NeonTheme.style_button(b, true)
	b.pressed.connect(cb)
	panel.add_child(b)


## 为当前玩家角色生成技能按钮
func _prompt_skills(actor: Unit) -> void:
	_clear_skills()
	_chosen_skill = {}
	_chosen_item = ""
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
	# 道具指令（P7）
	_add_item_button(actor, col)


## P7：道具按钮——点开显示库存消耗品清单
func _add_item_button(actor: Unit, col: int) -> void:
	var b := Button.new()
	b.text = "道具"
	b.position = Vector2(col * 122, 0)
	b.size = Vector2(116, 44)
	b.add_theme_font_size_override("font_size", 14)
	NeonTheme.style_button(b)
	var owned: Array = _owned_items()
	if owned.is_empty():
		b.disabled = true
		b.tooltip_text = "没有消耗品"
	else:
		b.tooltip_text = "使用消耗品（占用本回合）"
	b.pressed.connect(_on_item_pressed.bind(actor))
	_skill_bar.add_child(b)


func _owned_items() -> Array:
	var out: Array = []
	for k in GameState.items:
		if int(GameState.items[k]) > 0:
			out.append(String(k))
	return out


## 技能条换成道具清单 + 返回按钮
func _on_item_pressed(actor: Unit) -> void:
	_clear_skills()
	_chosen_skill = {}
	_chosen_item = ""
	_awaiting_target = false
	_status.text = "%s：选择要使用的道具" % actor.display_name
	var col := 0
	for id in _owned_items():
		var idef: Dictionary = DataManager.get_item(id)
		var b := Button.new()
		b.text = "%s x%d" % [idef.get("name", id), GameState.item_count(id)]
		b.position = Vector2(col * 152, 0)
		b.size = Vector2(146, 44)
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = String(idef.get("desc", ""))
		NeonTheme.style_button(b)
		b.pressed.connect(_on_item_chosen.bind(id, actor))
		_skill_bar.add_child(b)
		col += 1
	var back := Button.new()
	back.text = "返回"
	back.position = Vector2(col * 152, 0)
	back.size = Vector2(90, 44)
	back.add_theme_font_size_override("font_size", 13)
	NeonTheme.style_button(back)
	back.pressed.connect(func(): _prompt_skills(actor))
	_skill_bar.add_child(back)


func _on_item_chosen(item_id: String, actor: Unit) -> void:
	_chosen_item = item_id
	_chosen_skill = {}
	_awaiting_target = true
	var idef: Dictionary = DataManager.get_item(item_id)
	var kind: String = String(idef.get("effect", ""))
	_status.text = "%s：点击一名队友使用 %s%s" % [
		actor.display_name, idef.get("name", item_id),
		"（战斗不能）" if kind == "revive" else ""]
	_mark_targets(actor, "item")


func _add_skill_button(label: String, skill: Dictionary, actor: Unit, col: int) -> void:
	var b := Button.new()
	b.text = label
	b.position = Vector2(col * 122, 0)
	b.size = Vector2(116, 44)
	b.add_theme_font_size_override("font_size", 14)
	NeonTheme.style_button(b)
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
	if _chosen_item != "":
		# 道具：校验目标 → 扣库存 → 提交
		if not _is_valid_target(actor, unit, "item"):
			return
		if not GameState.consume_item(_chosen_item):
			return
		_awaiting_target = false
		logic.set_player_item(_chosen_item, unit)
		_chosen_item = ""
		_status.text = ""
		player_committed.emit()
		return
	var tgt: String = _chosen_skill.get("target", "enemy_one")
	if not _is_valid_target(actor, unit, tgt):
		return
	_commit(actor, unit)


func _is_valid_target(actor: Unit, unit: Unit, tgt: String) -> bool:
	if tgt == "item":
		if not logic.players.has(unit):
			return false
		var kind: String = String(DataManager.get_item(_chosen_item).get("effect", ""))
		if kind == "revive":
			return not unit.is_alive()
		return unit.is_alive()
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
	# P7：元素技能闪屏
	var elem: String = skill.get("element", "无")
	if ELEMENT_COLOR.has(elem) and elem != "无":
		_screen_flash(ELEMENT_COLOR[elem])
	for e in ev["result"]["events"]:
		var target: Unit = e["target"]
		var tv: Dictionary = views[target]
		if e.has("result") and not e["result"].get("hit", true):
			_float_text(tv, "MISS", Color(0.7, 0.7, 0.7))
			_append_log("%s 的 %s 对 %s 未命中" % [actor.display_name, sname, target.display_name])
			continue
		if e.get("is_heal", false):
			_float_text(tv, "+%d" % int(e["damage"]), Color(0.4, 1.0, 0.5))
			AudioManager.play_sfx("sfx_heal")
			var ik: String = ev.get("item_kind", "")
			if ik == "revive":
				_append_log("%s 用 %s 复活 %s，回复 %d 点生命" % [actor.display_name, sname, target.display_name, int(e["damage"])])
			elif ik == "heal_mp":
				_append_log("%s 用 %s 为 %s 回复 %d 点能量" % [actor.display_name, sname, target.display_name, int(e["damage"])])
			else:
				_append_log("%s 用 %s 治疗 %s %d 点" % [actor.display_name, sname, target.display_name, int(e["damage"])])
		else:
			var res: Dictionary = e.get("result", {})
			var txt := "-%d" % int(e["damage"])
			var crit: bool = res.get("crit", false)
			if crit:
				txt += " 暴击!"
			_float_text(tv, txt, Color(1.0, 0.85, 0.2) if crit else Color(1.0, 0.4, 0.35))
			_flash(tv["body"])
			_lunge(views[actor], tv)
			AudioManager.play_sfx("sfx_crit" if crit else "sfx_hit")
			if crit or target.hp_max >= 500:
				_shake(9.0 if crit else 6.0)
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


## 单体技能/道具选目标时，高亮合法目标（复活道具高亮倒下的队友）
func _mark_targets(actor: Unit, tgt: String) -> void:
	for unit in views:
		if tgt != "item" and not unit.is_alive():
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


# ---------------- P7 战斗特效 ----------------

## 元素色全屏轻闪（0.16 透明度淡出）
func _screen_flash(color: Color) -> void:
	_flash_layer.color = Color(color.r, color.g, color.b, 0.16)
	_flash_layer.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash_layer, "modulate:a", 0.0, 0.35)


## 屏幕震动：暴击/打到 Boss 时给冲击感
func _shake(amp: float) -> void:
	if _shaking:
		return
	_shaking = true
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.05)
	tw.tween_property(self, "position", Vector2.ZERO, 0.06)
	tw.tween_callback(func(): _shaking = false)


## 攻击者朝目标前冲一小步再回位
func _lunge(from_v: Dictionary, to_v: Dictionary) -> void:
	var from_r: Control = from_v["root"]
	var dir: Vector2 = (to_v["root"].position - from_r.position).normalized()
	var base: Vector2 = from_r.position
	var tw := create_tween()
	tw.tween_property(from_r, "position", base + dir * 26.0, 0.12)
	tw.tween_property(from_r, "position", base, 0.18)


func _set_log(text: String) -> void:
	_log_label.text = text


func _append_log(text: String) -> void:
	_log_label.text = (_log_label.text + "\n" + text) if _log_label.text != "" else text
	var lines := _log_label.text.split("\n")
	if lines.size() > 11:
		_log_label.text = "\n".join(lines.slice(lines.size() - 11))
