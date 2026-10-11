extends Node
## P3 验证脚本（非常驻，仅用于自动化检查数据驱动框架）
## 运行：godot --headless --path <项目> res://tests/test_p3.tscn

var _fail := 0

func _ready() -> void:
	print("========== P3 数据驱动框架验证 ==========")
	_test_load()
	_test_derive()
	_test_enemy()
	_test_element()
	_test_levels()
	_test_ai_drops()
	print("========================================")
	if _fail == 0:
		print("结果：全部通过 [PASS]")
	else:
		print("结果：%d 项失败 [FAIL]" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


# 断言：整数相等
func _eqi(label: String, got: int, want: int) -> void:
	if got == want:
		print("  [OK] %s = %d" % [label, got])
	else:
		_fail += 1
		print("  [X] %s 应为 %d，实为 %d" % [label, want, got])

# 断言：浮点近似相等
func _eqf(label: String, got: float, want: float, eps := 0.01) -> void:
	if absf(got - want) <= eps:
		print("  [OK] %s = %.2f" % [label, got])
	else:
		_fail += 1
		print("  [X] %s 应为 %.2f，实为 %.2f" % [label, want, got])

# 断言：布尔为真
func _true(label: String, cond: bool) -> void:
	if cond:
		print("  [OK] %s" % label)
	else:
		_fail += 1
		print("  [X] %s" % label)


func _test_load() -> void:
	print("-- 1. CSV 加载计数 --")
	_eqi("角色数", DataManager.characters.size(), 3)
	_eqi("技能数", DataManager.skills.size(), 18)
	_eqi("敌人数", DataManager.enemies.size(), 9)
	_eqi("装备数", DataManager.equipment.size(), 8)
	_eqi("消耗品数", DataManager.items.size(), 5)
	_eqi("等级数", DataManager.levels.size(), 20)
	_eqi("AI组数", DataManager.enemy_ai.size(), 9)
	_eqi("元素对数", DataManager.elements.size(), 8)


func _test_derive() -> void:
	print("-- 2. 角色属性派生（凛） --")
	var lin: Dictionary = DataManager.get_character("lin")
	_true("能取到角色 lin", not lin.is_empty())

	var u1: Unit = Unit.from_character(lin, 1)
	print("  Lv1: HP=%d MP=%d ATK=%.1f MATK=%.1f DEF=%.1f SPD=%.1f CRT=%.2f EVA=%.2f" % [
		u1.hp_max, u1.mp_max, u1.atk, u1.matk, u1.def, u1.spd, u1.crit, u1.eva])
	_eqi("Lv1 HP", u1.hp_max, 225)
	_eqi("Lv1 MP", u1.mp_max, 92)
	_eqf("Lv1 ATK", u1.atk, 32.0)
	_eqf("Lv1 MATK", u1.matk, 28.0)
	_eqf("Lv1 DEF", u1.def, 15.5)
	_eqf("Lv1 SPD", u1.spd, 24.5)

	var u10: Unit = Unit.from_character(lin, 10)
	print("  Lv10: HP=%d MP=%d ATK=%.1f MATK=%.1f DEF=%.1f SPD=%.1f CRT=%.2f EVA=%.2f" % [
		u10.hp_max, u10.mp_max, u10.atk, u10.matk, u10.def, u10.spd, u10.crit, u10.eva])
	_eqi("Lv10 HP", u10.hp_max, 486)
	_eqi("Lv10 MP", u10.mp_max, 207)
	_eqf("Lv10 ATK", u10.atk, 71.6)
	_eqf("Lv10 MATK", u10.matk, 60.4)
	_eqf("Lv10 DEF", u10.def, 38.0)
	_eqf("Lv10 SPD", u10.spd, 48.8)
	_eqf("Lv10 CRT", u10.crit, 13.16)
	_true("升级后属性增长", u10.hp_max > u1.hp_max and u10.atk > u1.atk)
	_true("当前HP初始为满", u10.hp == u10.hp_max)


func _test_enemy() -> void:
	print("-- 3. 敌人加载 --")
	# P7a 起数值会持续调优：断言改为「以 CSV 为准」，验证 CSV→Unit 链路而非具体数字
	var row: Dictionary = DataManager.get_enemy("e_slime")
	var e: Unit = Unit.from_enemy(row)
	_eqi("裂隙黏体 HP", e.hp_max, int(row.get("hp", 0)))
	_eqf("裂隙黏体 ATK", e.atk, float(row.get("atk", 0)))
	_eqf("裂隙黏体 DEF", e.def, float(row.get("def", 0)))
	_true("敌人 is_enemy=true", e.is_enemy)
	_true("敌人元素=无", e.element == "无")
	var core_row: Dictionary = DataManager.get_enemy("e_rift_core")
	var boss: Unit = Unit.from_enemy(core_row)
	_eqi("最终Boss HP", boss.hp_max, int(core_row.get("hp", 0)))


func _test_element() -> void:
	print("-- 4. 元素克制 --")
	_eqf("电->水", DataManager.get_element_multiplier("电", "水"), 1.5)
	_eqf("水->电", DataManager.get_element_multiplier("水", "电"), 0.75)
	_eqf("电->火(无关)", DataManager.get_element_multiplier("电", "火"), 1.0)
	_eqf("同属性", DataManager.get_element_multiplier("火", "火"), 1.0)
	_eqf("无属性", DataManager.get_element_multiplier("无", "火"), 1.0)


func _test_levels() -> void:
	print("-- 5. 经验曲线 --")
	_eqi("Lv1->2", DataManager.get_exp_to_next(1), 50)
	_eqi("Lv5->6", DataManager.get_exp_to_next(5), 656)
	_eqi("Lv10->11", DataManager.get_exp_to_next(10), 1990)
	_eqi("Lv20(封顶)", DataManager.get_exp_to_next(20), 0)


func _test_ai_drops() -> void:
	print("-- 6. AI 与掉落 --")
	_eqi("e_warden AI条目", DataManager.get_enemy_ai("e_warden").size(), 3)
	_eqi("d_warden 掉落条目", DataManager.get_drops("d_warden").size(), 2)
	_eqi("不存在的敌人AI", DataManager.get_enemy_ai("不存在").size(), 0)
	# roll_drops：d_core 两条概率均为 1.0，必掉 2 件
	_eqi("d_core 必掉件数", DataManager.roll_drops("d_core").size(), 2)
