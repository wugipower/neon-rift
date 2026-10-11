extends Node
## P5 验证脚本：状态效果 / 技能施放 / 敌人AI(含Boss多阶段) / 装备 / 经验升级 / 多我多敌
## 运行：godot --headless --path <项目> res://tests/test_p5.tscn

var _fail := 0

func _ready() -> void:
	seed(20261011)
	print("========== P5 战斗系统扩展验证 ==========")
	_test_status_data()
	_test_dot_hot()
	_test_shield()
	_test_buff_freeze()
	_test_expiry()
	_test_shock_skip()
	_test_skill_mp()
	_test_skill_multitarget()
	_test_skill_effect_apply()
	_test_enemy_ai_basic()
	_test_enemy_ai_boss_phases()
	_test_equipment()
	_test_progression()
	_test_full_battle_multi()
	print("=========================================")
	if _fail == 0:
		print("结果：全部通过 [PASS]")
	else:
		print("结果：%d 项失败 [FAIL]" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


# ---------- 断言辅助 ----------
func _ok(label: String) -> void: print("  [OK] " + label)
func _bad(label: String) -> void:
	_fail += 1
	print("  [X] " + label)
func _true(label: String, cond: bool) -> void:
	if cond: _ok(label)
	else: _bad(label)
func _eqi(label: String, got: int, want: int) -> void:
	if got == want: _ok("%s = %d" % [label, got])
	else:
		_fail += 1
		print("  [X] %s 应为 %d，实为 %d" % [label, want, got])
func _eqf(label: String, got: float, want: float, eps := 0.01) -> void:
	if absf(got - want) <= eps: _ok("%s = %.3f" % [label, got])
	else:
		_fail += 1
		print("  [X] %s 应为 %.3f，实为 %.3f" % [label, want, got])


func _mk(stats: Dictionary) -> Unit:
	var u := Unit.new()
	u.uid = stats.get("id", "t")
	u.display_name = stats.get("name", "T")
	u.level = int(stats.get("level", 1))
	u.element = stats.get("element", "无")
	u.hp_max = int(stats.get("hp", 1000)); u.hp = u.hp_max
	u.mp_max = int(stats.get("mp", 100)); u.mp = u.mp_max
	u.atk = float(stats.get("atk", 0)); u.matk = float(stats.get("matk", 0))
	u.def = float(stats.get("def", 0)); u.spd = float(stats.get("spd", 10))
	u.crit = float(stats.get("crit", 0)); u.eva = float(stats.get("eva", 0))
	return u


# ---------- 1. 状态表加载 ----------
func _test_status_data() -> void:
	print("-- 1. 状态效果表加载 --")
	_eqi("状态效果数", DataManager.status_effects.size(), 7)
	var burn: Dictionary = DataManager.get_status("burn")
	_true("burn 存在", not burn.is_empty())
	_true("burn 为 dot_pct", String(burn.get("kind", "")) == "dot_pct")
	_eqf("burn 数值 0.08", float(burn.get("value", 0.0)), 0.08)


# ---------- 2. DoT / HoT ----------
func _test_dot_hot() -> void:
	print("-- 2. 灼烧掉血 / 回春回血 --")
	var u := _mk({"hp": 1000})
	u.apply_status("burn", 3)
	var t: Dictionary = u.on_turn_start()
	_eqi("灼烧掉血(8%=80)", int(t["dot"]), 80)
	_eqi("剩余HP", u.hp, 920)

	var h := _mk({"hp": 1000})
	h.hp = 500
	h.apply_status("regen", 3)
	var th: Dictionary = h.on_turn_start()
	_eqi("回春回血(6%=60)", int(th["hot"]), 60)
	_eqi("回血后HP", h.hp, 560)


# ---------- 3. 护盾吸收 ----------
func _test_shield() -> void:
	print("-- 3. 护盾先吸收伤害 --")
	var u := _mk({"hp": 1000})
	u.apply_status("shield", 3)
	_eqi("护盾量(25%=250)", u.shield, 250)
	var d1: Dictionary = u.take_damage(100)
	_eqi("吸收100", int(d1["absorbed"]), 100)
	_eqi("护盾剩余", u.shield, 150)
	_eqi("血量未损", u.hp, 1000)
	var d2: Dictionary = u.take_damage(200)
	_eqi("再吸收150", int(d2["absorbed"]), 150)
	_eqi("溢出扣血50", int(d2["hp_lost"]), 50)
	_eqi("血量950", u.hp, 950)


# ---------- 4. 增益 / 冰冻减速 ----------
func _test_buff_freeze() -> void:
	print("-- 4. atk_up 加攻 / freeze 减速 --")
	var u := _mk({"atk": 100, "matk": 50, "spd": 20})
	u.apply_status("atk_up", 3)
	_eqf("攻击+30%", u.eff_atk(), 130.0)
	_eqf("异能也+30%", u.eff_matk(), 65.0)
	u.apply_status("freeze", 3)
	_eqf("速度-50%", u.eff_spd(), 10.0)
	# 行动条应把冰冻单位排到后面
	var v := _mk({"spd": 20})
	var order: Array = TurnQueue.build_order([u, v], false)
	_true("未冰冻者先动", order[0] == v)


# ---------- 5. 到期移除 ----------
func _test_expiry() -> void:
	print("-- 5. 状态到期自动移除并撤销护盾 --")
	var u := _mk({"hp": 1000})
	u.apply_status("shield", 1)
	_eqi("护盾存在", u.shield, 250)
	var exp: Array = u.tick_durations()
	_eqi("到期状态数", exp.size(), 1)
	_eqi("护盾已清空", u.shield, 0)
	_eqi("状态列表清空", u.statuses.size(), 0)


# ---------- 6. 感电跳过 ----------
func _test_shock_skip() -> void:
	print("-- 6. 感电按概率跳过行动 --")
	var u := _mk({})
	# 注入一个 100% 跳过的感电，验证机制生效
	var s := StatusEffect.new()
	s.id = "shock"; s.effect_name = "感电"; s.kind = "skip_chance"; s.value = 1.0; s.turns_left = 2
	u.statuses.append(s)
	_true("必定跳过", u.roll_skip())
	var clean := _mk({})
	_true("无状态不跳过", not clean.roll_skip())


# ---------- 7. 技能蓝耗 ----------
func _test_skill_mp() -> void:
	print("-- 7. 技能消耗能量 / 蓝不足不可施放 --")
	var u := _mk({"mp": 25, "matk": 40})
	var skill := {"id": "s_test", "damage_type": "magic", "power": 1.0,
				  "element": "无", "target": "enemy_one", "mp_cost": 10}
	var foe := _mk({"hp": 1000, "def": 0, "element": "无"})
	_true("蓝足够可施放", SkillExecutor.can_cast(u, skill))
	SkillExecutor.cast(u, skill, [u], [foe])
	_eqi("扣蓝后剩15", u.mp, 15)
	var poor := _mk({"mp": 5})
	_true("蓝不足不可施放", not SkillExecutor.can_cast(poor, skill))


# ---------- 8. 多目标 ----------
func _test_skill_multitarget() -> void:
	print("-- 8. enemy_all 打全体 / ally_all 奶全体 --")
	var caster := _mk({"matk": 100, "mp": 99})
	var f1 := _mk({"hp": 1000, "def": 0}); var f2 := _mk({"hp": 1000, "def": 0})
	var aoe := {"damage_type": "magic", "power": 1.0, "element": "无",
				"target": "enemy_all", "mp_cost": 0}
	var res: Dictionary = SkillExecutor.cast(caster, aoe, [caster], [f1, f2])
	_eqi("命中2个目标", res["events"].size(), 2)
	_true("f1 掉血", f1.hp < 1000)
	_true("f2 掉血", f2.hp < 1000)

	var healer := _mk({"matk": 100, "mp": 99})
	var a1 := _mk({"hp": 1000}); a1.hp = 100
	var a2 := _mk({"hp": 1000}); a2.hp = 100
	var group_heal := {"damage_type": "heal", "power": 1.0, "target": "ally_all", "mp_cost": 0}
	SkillExecutor.cast(healer, group_heal, [healer, a1, a2], [])
	_true("a1 被治疗", a1.hp > 100)
	_true("a2 被治疗", a2.hp > 100)


# ---------- 9. 附带状态施加 ----------
func _test_skill_effect_apply() -> void:
	print("-- 9. 增益技能施加状态(100%概率) --")
	var u := _mk({"atk": 100, "mp": 99})
	var buff := {"damage_type": "buff", "target": "self", "effect": "atk_up",
				 "effect_chance": 1.0, "effect_turns": 3, "mp_cost": 4}
	SkillExecutor.cast(u, buff, [u], [])
	_true("获得 atk_up", u.statuses.size() == 1 and u.statuses[0].id == "atk_up")
	_eqf("攻击已提升", u.eff_atk(), 130.0)


# ---------- 10. 敌人AI基础 ----------
func _test_enemy_ai_basic() -> void:
	print("-- 10. 敌人AI按条件+权重选技能 --")
	var slime := Unit.from_enemy(DataManager.get_enemy("e_slime"))
	var sk: Dictionary = EnemyAI.choose_skill(slime, [slime])
	_true("黏体只会撕咬", String(sk.get("id", "")) == "e_bite")

	var warden := Unit.from_enemy(DataManager.get_enemy("e_warden"))
	# 满血：hp_below_50 的技能被过滤，只剩 e_ice_shard(always)
	var sk2: Dictionary = EnemyAI.choose_skill(warden, [warden])
	_true("守卫满血只用冰锥", String(sk2.get("id", "")) == "e_ice_shard")


# ---------- 11. Boss 多阶段 ----------
func _test_enemy_ai_boss_phases() -> void:
	print("-- 11. Boss 血量阈值解锁新技能(多阶段) --")
	var warden := Unit.from_enemy(DataManager.get_enemy("e_warden"))
	warden.hp = int(warden.hp_max * 0.4)   # <50%
	var seen := {}
	for i in 300:
		var s: Dictionary = EnemyAI.choose_skill(warden, [warden])
		seen[String(s.get("id", ""))] = true
	_true("残血解锁狂暴", seen.has("e_enrage"))
	_true("残血解锁霜之新星", seen.has("e_frost_nova"))

	var core := Unit.from_enemy(DataManager.get_enemy("e_rift_core"))
	core.hp = int(core.hp_max * 0.2)   # <30%
	var seen2 := {}
	for i in 400:
		var s2: Dictionary = EnemyAI.choose_skill(core, [core])
		seen2[String(s2.get("id", ""))] = true
	_true("核心残血解锁治疗", seen2.has("e_heal"))
	_true("核心仍有裂隙斩", seen2.has("b_rift_slash"))


# ---------- 12. 装备词条 ----------
func _test_equipment() -> void:
	print("-- 12. 装备词条汇总并生效 --")
	var b: Dictionary = EquipCalc.bonus_of(["w_focus_blade", "a_vest"])
	_eqf("atk+12", float(b.get("atk", 0)), 12.0)
	_eqf("crit+3", float(b.get("crit", 0)), 3.0)
	_eqf("def+10", float(b.get("def", 0)), 10.0)
	_eqf("hp+20", float(b.get("hp", 0)), 20.0)

	var lin := Unit.from_character(DataManager.get_character("lin"), 5)
	var atk0: float = lin.atk
	EquipCalc.equip(lin, ["w_focus_blade"])
	_eqf("穿武器后攻击+12", lin.atk - atk0, 12.0)


# ---------- 13. 经验升级 ----------
func _test_progression() -> void:
	print("-- 13. 经验累积与连升 --")
	var r: Dictionary = Progression.add_exp(5, 0, 700)   # Lv5→6 需 656
	_eqi("升到6级", int(r["level"]), 6)
	_eqi("溢出经验44", int(r["exp"]), 44)
	_true("标记升级", bool(r["leveled"]))
	var r2: Dictionary = Progression.add_exp(1, 0, 50 + 151)  # 连升两级
	_eqi("连升到3级", int(r2["level"]), 3)
	_eqi("升了2级", int(r2["gained_levels"]), 2)


# ---------- 14. 完整多人战斗 ----------
func _test_full_battle_multi() -> void:
	print("-- 14. 完整战斗：三人队 Lv5 vs 双敌(含AI技能) --")
	var p1 := Unit.from_character(DataManager.get_character("lin"), 5)
	var p2 := Unit.from_character(DataManager.get_character("cang"), 5)
	var p3 := Unit.from_character(DataManager.get_character("miao"), 5)
	var e1 := Unit.from_enemy(DataManager.get_enemy("e_slime"))
	var e2 := Unit.from_enemy(DataManager.get_enemy("e_bat"))
	var battle := BattleLogic.new([p1, p2, p3], [e1, e2])
	var guard := 0
	while not battle.over and guard < 800:
		var actor: Unit = battle.current_actor()
		# 玩家轮流用各自的第一个技能（蓝不足自动退回普攻）
		if actor != null and battle.is_player_actor(actor):
			var sid: String = String(DataManager.get_character(actor.uid).get("start_skills", "")).split("|")[0]
			var sk: Dictionary = DataManager.get_skill(sid)
			if not sk.is_empty():
				battle.set_player_action(sk)
		battle.step()
		guard += 1
	_true("战斗结束", battle.over)
	_true("玩家方获胜", battle.winner == "player")
	_true("敌全灭", not e1.is_alive() and not e2.is_alive())
	_true("有行动记录", battle.log.size() > 0)
	print("     用了 %d 回合，步数 %d" % [battle.round_num, battle.log.size()])
	_true("回合数合理(<=30)", battle.round_num <= 30)
