extends Node
## P6 全流程自动模拟：从新游戏沿主线打完每场战斗，验证「可通关 + 难度曲线不断档」。
## 玩家用简单自动策略（有蓝放技能/残血治疗），敌人用 EnemyAI。不买装备=最低强度基线。

func _ready() -> void:
	seed(20261011)
	GameState.new_game()
	print("========== P6 全流程模拟 ==========")
	var guard := 0
	var lost := ""
	while not GameState.is_finished() and guard < 60:
		guard += 1
		var nid: String = GameState.current_node
		if nid == "":
			break
		var node: Dictionary = DataManager.get_node_data(nid)
		var ntype: String = String(node.get("type", "story"))
		if ntype == "battle" or ntype == "boss":
			var enemy_ids: Array = []
			for e in String(node.get("enemies", "")).split("|"):
				if e.strip_edges() != "":
					enemy_ids.append(e.strip_edges())
			var win: bool = _fight(enemy_ids)
			var plvl: Array = []
			for m in GameState.party:
				plvl.append("%s%d" % [String(m["id"])[0], int(m["level"])])
			print("  [%s] %-14s 敌:%-22s → %s  队伍Lv %s 金%d" % [
				ntype, String(node.get("name", nid)), "|".join(enemy_ids),
				"胜" if win else "负", "/".join(plvl), GameState.gold])
			if not win:
				lost = nid
				break
			GameState.apply_battle_reward(enemy_ids)
			GameState.complete_node(nid)
		else:
			print("  [story] %s" % String(node.get("name", nid)))
			GameState.complete_node(nid)
	print("-----------------------------------")
	if lost != "":
		print("结果：在节点 %s 战败，无法通关 [FAIL]" % lost)
		get_tree().quit(1)
	elif GameState.is_finished():
		var lv: Array = []
		for m in GameState.party:
			lv.append(int(m["level"]))
		print("结果：成功通关 [PASS]  最终队伍等级 %s  金钱 %d  用了 %d 个主线节点" % [str(lv), GameState.gold, guard])
		get_tree().quit(0)
	else:
		print("结果：未能到达结局 [FAIL]")
		get_tree().quit(1)


## 打一场战斗，返回是否玩家胜
func _fight(enemy_ids: Array) -> bool:
	var party: Array = GameState.build_party_units()
	var foes: Array = GameState.build_enemy_units(enemy_ids)
	var b := BattleLogic.new(party, foes)
	var g := 0
	while not b.over and g < 400:
		var actor: Unit = b.current_actor()
		if actor != null and b.is_player_actor(actor):
			var sk: Dictionary = _auto_skill(actor, party)
			b.set_player_action(sk)
		b.step()
		g += 1
	return b.winner == "player"


## 简单自动策略：队友残血且有治疗技能→治疗；否则放第一个能用的伤害技能；再否则普攻
func _auto_skill(actor: Unit, party: Array) -> Dictionary:
	var row: Dictionary = DataManager.get_character(actor.uid)
	var ids: PackedStringArray = String(row.get("start_skills", "")).split("|")
	var hurt: Unit = null
	for u in party:
		if u.is_alive() and float(u.hp) / float(u.hp_max) < 0.5:
			hurt = u
			break
	var first_atk: Dictionary = {}
	for sid in ids:
		if sid == "":
			continue
		var sk: Dictionary = DataManager.get_skill(String(sid))
		if sk.is_empty() or actor.mp < int(sk.get("mp_cost", 0)):
			continue
		var dt: String = String(sk.get("damage_type", ""))
		if dt == "heal" and hurt != null:
			return sk
		if (dt == "physical" or dt == "magic") and first_atk.is_empty():
			first_atk = sk
		if dt == "buff" and first_atk.is_empty():
			first_atk = sk
	if not first_atk.is_empty():
		return first_atk
	return DamageCalc.basic_attack(actor)
