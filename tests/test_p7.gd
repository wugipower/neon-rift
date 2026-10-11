extends Node
## P7 回归测试：战斗内道具指令（回血/回蓝/复活/占回合/库存扣减/战斗流程集成）。

var fails := 0


func _ready() -> void:
	print("========== P7 道具指令测试 ==========")
	_test_heal()
	_test_heal_cap()
	_test_mp()
	_test_revive()
	_test_consume()
	_test_flow()
	print("-----------------------------------")
	if fails > 0:
		print("结果：%d 项失败 [FAIL]" % fails)
		get_tree().quit(1)
	print("结果：全部通过 [PASS]")
	get_tree().quit(0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK] %s" % msg)
	else:
		fails += 1
		print("  [X] %s" % msg)


func _party() -> Array:
	return [Unit.from_character(DataManager.get_character("lin"), 6),
			Unit.from_character(DataManager.get_character("cang"), 6),
			Unit.from_character(DataManager.get_character("miao"), 6)]


## 推进到第一个玩家行动者
func _to_player(b: BattleLogic) -> Unit:
	var g := 0
	while b.current_actor() != null and not b.is_player_actor(b.current_actor()) and g < 20:
		b.step()
		g += 1
	return b.current_actor()


func _test_heal() -> void:
	var p: Array = _party()
	var hurt: Unit = p[0]
	hurt.hp = hurt.hp_max - 80
	var b := BattleLogic.new(p, [Unit.from_enemy(DataManager.get_enemy("e_slime"))])
	var actor: Unit = _to_player(b)
	b.set_player_item("i_potion_small", hurt)
	var ev: Dictionary = b.step()
	_check(ev.get("item_kind", "") == "heal_hp", "heal_hp 事件类型正确")
	_check(int(ev["result"]["events"][0]["damage"]) == 60, "小型修复剂回复 60 点")
	_check(hurt.hp == hurt.hp_max - 20, "治疗后 HP 正确")
	_check(b.current_actor() != actor, "使用道具占用本回合")


func _test_heal_cap() -> void:
	var p: Array = _party()
	var full: Unit = p[1]
	var hp0: int = full.hp
	var b := BattleLogic.new(p, [Unit.from_enemy(DataManager.get_enemy("e_slime"))])
	_to_player(b)
	b.set_player_item("i_potion_small", full)
	var ev: Dictionary = b.step()
	_check(int(ev["result"]["events"][0]["damage"]) == 0, "满血使用回复量为 0（不溢出）")
	_check(full.hp == hp0, "满血 HP 不变")


func _test_mp() -> void:
	var p: Array = _party()
	var u: Unit = p[2]
	u.mp = u.mp_max - 40
	var b := BattleLogic.new(p, [Unit.from_enemy(DataManager.get_enemy("e_slime"))])
	_to_player(b)
	b.set_player_item("i_ether_small", u)
	var ev: Dictionary = b.step()
	_check(ev.get("item_kind", "") == "heal_mp", "heal_mp 事件类型正确")
	_check(int(ev["result"]["events"][0]["damage"]) == 30, "小型能量剂回复 30 点能量")
	_check(u.mp == u.mp_max - 10, "能量回复正确")


func _test_revive() -> void:
	var p: Array = _party()
	var dead: Unit = p[1]
	dead.hp = 0
	_check(not dead.is_alive(), "前置：单位已战斗不能")
	var b := BattleLogic.new(p, [Unit.from_enemy(DataManager.get_enemy("e_slime"))])
	_to_player(b)
	b.set_player_item("i_revive", dead)
	var ev: Dictionary = b.step()
	_check(ev.get("item_kind", "") == "revive", "revive 事件类型正确")
	_check(dead.hp == int(round(float(dead.hp_max) * 0.5)), "复苏针以 50%% 生命复活（%d/%d）" % [dead.hp, dead.hp_max])
	_check(dead.is_alive(), "复活后重新可行动")


func _test_consume() -> void:
	GameState.items.clear()
	GameState.add_item("i_potion_small", 2)
	_check(GameState.consume_item("i_potion_small"), "第一次扣减成功")
	_check(GameState.item_count("i_potion_small") == 1, "库存剩 1")
	_check(GameState.consume_item("i_potion_small"), "第二次扣减成功")
	_check(not GameState.consume_item("i_potion_small"), "库存 0 时扣减失败")
	GameState.items.clear()


func _test_flow() -> void:
	# 集成：1v1 战斗中第一回合用道具（占回合），之后自动普攻直到结束
	var p: Array = [Unit.from_character(DataManager.get_character("lin"), 6)]
	var b := BattleLogic.new(p, [Unit.from_enemy(DataManager.get_enemy("e_slime"))])
	var first := true
	var saw_item := false
	var g := 0
	while not b.over and g < 60:
		var actor: Unit = b.current_actor()
		if actor != null and b.is_player_actor(actor) and first:
			first = false
			b.set_player_item("i_potion_small", actor)
			var ev: Dictionary = b.step()
			saw_item = ev.get("item_kind", "") == "heal_hp"
			continue
		b.step()
		g += 1
	_check(saw_item, "战斗流程中道具事件正常触发")
	_check(b.winner == "player", "用道具占一回合后仍能赢下战斗")
