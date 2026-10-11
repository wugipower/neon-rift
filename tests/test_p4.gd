extends Node
## P4 验证脚本：伤害公式 / 行动条 / 战斗流程
## 运行：godot --headless --path <项目> res://tests/test_p4.tscn

var _fail := 0

func _ready() -> void:
	seed(20261011)  # 固定随机种子，结果可复现
	print("========== P4 战斗核心验证 ==========")
	_test_damage_physical()
	_test_damage_magic()
	_test_heal()
	_test_min_damage()
	_test_turn_queue()
	_test_battle_player_win()
	_test_battle_enemy_win()
	print("====================================")
	if _fail == 0:
		print("结果：全部通过 [PASS]")
	else:
		print("结果：%d 项失败 [FAIL]" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(label: String) -> void:
	print("  [OK] " + label)

func _bad(label: String) -> void:
	_fail += 1
	print("  [X] " + label)

func _true(label: String, cond: bool) -> void:
	if cond: _ok(label)
	else: _bad(label)

func _range(label: String, got: int, lo: int, hi: int) -> void:
	if got >= lo and got <= hi:
		print("  [OK] %s = %d (期望 %d~%d)" % [label, got, lo, hi])
	else:
		_fail += 1
		print("  [X] %s = %d (期望 %d~%d)" % [label, got, lo, hi])

func _eqf(label: String, got: float, want: float, eps := 0.01) -> void:
	if absf(got - want) <= eps: _ok("%s = %.3f" % [label, got])
	else:
		_fail += 1
		print("  [X] %s 应为 %.3f，实为 %.3f" % [label, want, got])


## 造一个自定义属性的单位
func _mk(stats: Dictionary) -> Unit:
	var u := Unit.new()
	u.display_name = stats.get("name", "T")
	u.level = int(stats.get("level", 1))
	u.element = stats.get("element", "无")
	u.hp_max = int(stats.get("hp", 1000)); u.hp = u.hp_max
	u.mp_max = int(stats.get("mp", 100)); u.mp = u.mp_max
	u.atk = float(stats.get("atk", 0)); u.matk = float(stats.get("matk", 0))
	u.def = float(stats.get("def", 0)); u.spd = float(stats.get("spd", 10))
	u.crit = float(stats.get("crit", 0)); u.eva = float(stats.get("eva", 0))
	return u


func _test_damage_physical() -> void:
	print("-- 1. 物理伤害公式（含减伤+元素克制） --")
	# 攻方 atk=50 Lv5 电；守方 def=50 水(eva0 crit0)
	# K=150, 减伤=50/200=0.25, base=50, *(0.75)=37.5, 电克水*1.5=56.25, 浮动0.95~1.05
	var atk := _mk({"name": "攻", "level": 5, "element": "电", "atk": 50, "crit": 0})
	var dfn := _mk({"name": "守", "element": "水", "def": 50, "eva": 0})
	var skill := {"damage_type": "physical", "power": 1.0, "element": "电"}
	var r := DamageCalc.compute(atk, dfn, skill)
	_true("命中(eva=0必中)", r["hit"])
	_true("非治疗", not r["is_heal"])
	_eqf("减伤率", r["mitigation"], 0.25)
	_eqf("元素系数(电>水)", r["element_mult"], 1.5)
	_range("伤害(56.25±5%)", int(r["damage"]), 53, 60)


func _test_damage_magic() -> void:
	print("-- 2. 魔法伤害用 MATK --")
	var atk := _mk({"level": 5, "matk": 60, "atk": 10, "crit": 0})
	var dfn := _mk({"def": 50, "element": "无"})
	var skill := {"damage_type": "magic", "power": 1.0, "element": "无"}
	var r := DamageCalc.compute(atk, dfn, skill)
	# base=60(matk), 减伤0.25 → 45, 元素1.0, 浮动
	_range("魔法伤害(45±5%)", int(r["damage"]), 42, 48)


func _test_heal() -> void:
	print("-- 3. 治疗量 = power*MATK --")
	var healer := _mk({"matk": 40})
	var ally := _mk({"hp": 100})
	ally.hp = 30
	var skill := {"damage_type": "heal", "power": 1.2}
	var r := DamageCalc.compute(healer, ally, skill)
	_true("标记为治疗", r["is_heal"])
	_eqf("治疗量(1.2*40=48)", float(r["damage"]), 48.0)


func _test_min_damage() -> void:
	print("-- 4. 最低伤害保底为 1 --")
	var weak := _mk({"level": 1, "atk": 1, "crit": 0})
	var tank := _mk({"def": 9999})
	var r := DamageCalc.compute(weak, tank, {"damage_type": "physical", "power": 1.0, "element": "无"})
	_true("高防下伤害>=1", int(r["damage"]) >= 1)


func _test_turn_queue() -> void:
	print("-- 5. 行动条按速度降序（无扰动） --")
	var slow := _mk({"name": "slow", "spd": 5})
	var mid := _mk({"name": "mid", "spd": 15})
	var fast := _mk({"name": "fast", "spd": 30})
	var order: Array = TurnQueue.build_order([slow, fast, mid], false)
	_true("最快先动", order[0] == fast)
	_true("最慢最后", order[2] == slow)
	_true("中间居中", order[1] == mid)


func _test_battle_player_win() -> void:
	print("-- 6. 完整战斗：凛 Lv5 vs 裂隙黏体 → 玩家胜 --")
	var hero := Unit.from_character(DataManager.get_character("lin"), 5)
	var foe := Unit.from_enemy(DataManager.get_enemy("e_slime"))
	var battle := BattleLogic.new([hero], [foe])
	var guard := 0
	while not battle.over and guard < 500:
		battle.step()
		guard += 1
	_true("战斗结束", battle.over)
	_true("玩家获胜", battle.winner == "player")
	_true("敌人HP归零", foe.hp == 0)
	_true("玩家存活", hero.is_alive())
	_true("有攻击记录", battle.log.size() > 0)
	print("     用了 %d 回合，玩家剩余HP %d/%d" % [battle.round_num, hero.hp, hero.hp_max])
	_true("回合数合理(<=20)", battle.round_num <= 20)


func _test_battle_enemy_win() -> void:
	print("-- 7. 完整战斗：澪 Lv1 vs 裂隙核心 → 敌方胜 --")
	var weak := Unit.from_character(DataManager.get_character("miao"), 1)
	var boss := Unit.from_enemy(DataManager.get_enemy("e_rift_core"))
	var battle := BattleLogic.new([weak], [boss])
	var guard := 0
	while not battle.over and guard < 500:
		battle.step()
		guard += 1
	_true("战斗结束", battle.over)
	_true("敌方获胜", battle.winner == "enemy")
	_true("玩家HP归零", weak.hp == 0)
