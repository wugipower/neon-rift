extends Node
## P6 验证脚本：存档往返 / 新游戏 / 节点图推进 / 战斗奖励升级 / 对话 / 商店 / 装备 / 遭遇构建
## 运行：godot --headless --path <项目> res://tests/test_p6.tscn

var _fail := 0

func _ready() -> void:
	seed(20261011)
	print("========== P6 内容与关卡流程验证 ==========")
	_test_new_game()
	_test_build_units()
	_test_node_graph()
	_test_full_playthrough()
	_test_battle_reward()
	_test_dialogue()
	_test_shop()
	_test_equip()
	_test_save_load()
	await _test_dialogue_box()
	# 清理测试产生的存档，避免影响正式试玩的「继续」
	SaveGame.delete()
	print("===========================================")
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
func _eqs(label: String, got: String, want: String) -> void:
	if got == want: _ok("%s = %s" % [label, got])
	else:
		_fail += 1
		print("  [X] %s 应为 %s，实为 %s" % [label, want, got])


# ---------- 1. 新游戏 ----------
func _test_new_game() -> void:
	print("-- 1. 新游戏初始化 --")
	GameState.new_game()
	_true("已开始", GameState.started)
	_eqi("队伍3人", GameState.party.size(), 3)
	_eqi("初始金钱150", GameState.gold, 150)
	_eqs("起始节点 n_intro", GameState.current_node, "n_intro")
	_eqi("初始等级3", int(GameState.party[0]["level"]), 3)
	_eqi("初始药水2", GameState.item_count("i_potion_small"), 2)


# ---------- 2. 构建战斗单位 ----------
func _test_build_units() -> void:
	print("-- 2. 队伍/敌人单位构建 --")
	GameState.new_game()
	var party: Array = GameState.build_party_units()
	_eqi("3个玩家单位", party.size(), 3)
	var lin: Unit = party[0]
	_eqs("首个是凛", lin.display_name, "凛")
	_eqi("等级3", lin.level, 3)
	_true("满血", lin.hp == lin.hp_max)
	var foes: Array = GameState.build_enemy_units(["e_slime", "e_bat"])
	_eqi("2个敌人", foes.size(), 2)
	_true("敌人满血", foes[0].hp == foes[0].hp_max)


# ---------- 3. 节点图 ----------
func _test_node_graph() -> void:
	print("-- 3. 节点图：开放判定与推进 --")
	GameState.new_game()
	_true("n_intro 开放", GameState.is_node_open("n_intro"))
	_true("n_tut 未开放", not GameState.is_node_open("n_tut"))
	var nx: Array = GameState.next_of("n_intro")
	_true("n_intro 的后续是 n_tut", nx.size() == 1 and String(nx[0]) == "n_tut")
	GameState.complete_node("n_intro")
	_eqs("推进到 n_tut", GameState.current_node, "n_tut")
	_true("n_intro 已完成", GameState.is_completed("n_intro"))
	# 支线：完成 n_c1b 后 n_c1side 应开放
	GameState.current_node = "n_c1b"
	GameState.complete_node("n_c1b")
	_true("支线 n_c1side 开放", GameState.is_node_open("n_c1side"))
	_eqs("主线前沿推进到 n_c1c", GameState.current_node, "n_c1c")


# ---------- 4. 完整通关推进 ----------
func _test_full_playthrough() -> void:
	print("-- 4. 沿主线完成全部节点直到结局 --")
	GameState.new_game()
	var guard := 0
	while GameState.current_node != "" and guard < 50:
		GameState.complete_node(GameState.current_node)
		guard += 1
	_true("到达结局标记 finished", GameState.is_finished())
	_true("n_end 已完成", GameState.is_completed("n_end"))
	_eqs("前沿清空", GameState.current_node, "")
	print("     主线节点数 %d" % guard)


# ---------- 5. 战斗奖励与升级 ----------
func _test_battle_reward() -> void:
	print("-- 5. 战斗奖励：经验/金钱/升级 --")
	# P7a 起经验/金钱会持续调优：断言以 enemies.csv 为准，验证奖励链路而非具体数字
	GameState.new_game()
	var slime: Dictionary = DataManager.get_enemy("e_slime")
	var gold0: int = GameState.gold
	var r: Dictionary = GameState.apply_battle_reward(["e_slime"])
	_eqi("黏体经验与CSV一致", int(r["exp"]), int(slime.get("exp_reward", 0)))
	_eqi("黏体金钱与CSV一致", int(r["gold"]), int(slime.get("gold_reward", 0)))
	_eqi("金钱累加", GameState.gold, gold0 + int(slime.get("gold_reward", 0)))
	_eqi("未升级仍3级", int(GameState.party[0]["level"]), 3)
	_eqi("累积经验入账", int(GameState.party[0]["exp"]), int(slime.get("exp_reward", 0)))

	# 大额经验触发连升（最终Boss）
	GameState.new_game()
	var core: Dictionary = DataManager.get_enemy("e_rift_core")
	var r2: Dictionary = GameState.apply_battle_reward(["e_rift_core"])
	_eqi("核心经验与CSV一致", int(r2["exp"]), int(core.get("exp_reward", 0)))
	_true("Boss经验足以连升到5级以上", int(GameState.party[0]["level"]) > 5)
	_true("有升级记录", r2["levelups"].size() == 3)


# ---------- 6. 对话分组 ----------
func _test_dialogue() -> void:
	print("-- 6. 对话按 id 分组且有序 --")
	var d: Array = DataManager.get_dialogue("d_intro")
	_eqi("d_intro 4句", d.size(), 4)
	_eqs("首句说话人", String(d[0]["speaker"]), "旁白")
	_true("文本非空", String(d[0]["text"]).length() > 0)
	_eqi("d_ending 3句", DataManager.get_dialogue("d_ending").size(), 3)
	_eqi("未知对话为空", DataManager.get_dialogue("nope").size(), 0)


# ---------- 7. 商店 ----------
func _test_shop() -> void:
	print("-- 7. 商店购买：扣款/入库/余额不足拒绝 --")
	GameState.new_game()
	var stock: Array = DataManager.get_shop("hub")
	_true("据点商店有货架", stock.size() > 0)
	var gold0: int = GameState.gold   # 150
	_true("买药水成功", GameState.buy("item", "i_potion_small"))  # 30
	_eqi("扣款30", GameState.gold, gold0 - 30)
	_eqi("药水变3", GameState.item_count("i_potion_small"), 3)
	_true("买不起贵装备被拒", not GameState.buy("equip", "w_focus_blade"))  # 400 > 120
	_eqi("被拒不扣款", GameState.gold, gold0 - 30)
	GameState.gold = 1000
	_true("有钱后买装备成功", GameState.buy("equip", "w_battery_baton"))  # 120
	_true("装备入库", GameState.owned_equips.has("w_battery_baton"))


# ---------- 8. 装备生效 ----------
func _test_equip() -> void:
	print("-- 8. 装备穿到角色并提升属性 --")
	GameState.new_game()
	GameState.gold = 1000
	GameState.buy("equip", "w_battery_baton")   # atk+6
	var before: Array = GameState.build_party_units()
	var atk0: float = before[0].atk
	_true("穿装备成功", GameState.equip_to("lin", "w_battery_baton"))
	var after: Array = GameState.build_party_units()
	_eqi("凛攻击+6", int(round(after[0].atk - atk0)), 6)
	_true("装备记录在角色上", GameState.party[0]["equipment"].has("w_battery_baton"))


# ---------- 9. 存档往返 ----------
func _test_save_load() -> void:
	print("-- 9. 存档写入/读取往返一致 --")
	GameState.new_game()
	GameState.gold = 777
	GameState.party[0]["level"] = 8
	GameState.add_item("i_potion_large", 3)
	GameState.flags["frag1"] = true
	GameState.completed = ["n_intro", "n_tut"]
	GameState.current_node = "n_hub"
	_true("写入成功", GameState.save_game())
	_true("存档文件存在", GameState.has_save())

	# 重置后读回
	GameState.new_game()
	_true("读档成功", GameState.load_game())
	_eqi("金钱还原777", GameState.gold, 777)
	_eqi("凛等级还原8", int(GameState.party[0]["level"]), 8)
	_eqi("大型药水3", GameState.item_count("i_potion_large"), 3)
	_true("剧情标记还原", GameState.has_flag("frag1"))
	_eqs("当前节点还原", GameState.current_node, "n_hub")
	_eqi("已完成数还原", GameState.completed.size(), 2)


# ---------- 10. 对话框点击推进 ----------
## 回归用例：曾出现 set_anchors_preset 不拉伸代码创建的控件，
## 对话框根节点 0x0 → 全屏没有可点击区域 → "点击任意处继续"失效。
func _test_dialogue_box() -> void:
	print("-- 10. 对话框点击/按键推进 --")
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	await get_tree().process_frame

	var lines: Array = [
		{"speaker": "旁白", "text": "第一句"},
		{"speaker": "旁白", "text": "第二句"},
	]
	var db := DialogueBox.new(lines)
	host.add_child(db)
	await get_tree().process_frame
	_true("根节点铺满父级(有全屏点击区)", db.get_rect().size.x > 0 and db.get_rect().size == host.get_rect().size)

	var st := {"done": false}
	db.finished.connect(func(): st.done = true)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 100)
	db.gui_input.emit(click)
	_true("点击推进到第2句", db.is_inside_tree() and db._i == 1)
	db.gui_input.emit(click)
	_true("第二次点击发出 finished", bool(st.done))
	await get_tree().process_frame
	_true("对话框自毁离树", not is_instance_valid(db) or not db.is_inside_tree())

	# 键盘路径：空格/回车同样推进
	var db2 := DialogueBox.new(lines)
	host.add_child(db2)
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	db2._unhandled_input(key)
	_true("空格推进到第2句", db2.is_inside_tree() and db2._i == 1)
	db2._unhandled_input(key)
	await get_tree().process_frame
	_true("空格结束自毁", not is_instance_valid(db2) or not db2.is_inside_tree())
	host.queue_free()
