class_name BattleLogic
extends RefCounted
## 战斗流程核心（纯逻辑，不含 UI / 计时器，可无头运行与单元测试）。
## MVP：双方每回合对「首个存活敌方」普攻，按速度行动条轮流行动，直到一方全灭。

var players: Array = []
var enemies: Array = []
var order: Array = []
var idx: int = 0
var round_num: int = 0
var over: bool = false
var winner: String = ""     # "player" | "enemy" | ""
var log: Array = []


func _init(p_units: Array, e_units: Array) -> void:
	players = p_units
	enemies = e_units
	_start_round()


func _alive(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u.is_alive():
			out.append(u)
	return out


func _start_round() -> void:
	round_num += 1
	order = TurnQueue.build_order(_alive(players) + _alive(enemies))
	idx = 0


## 当前应行动的单位（跳过已死亡）；本轮行动完毕返回 null
func current_actor() -> Unit:
	while idx < order.size() and not order[idx].is_alive():
		idx += 1
	if idx >= order.size():
		return null
	return order[idx]


func is_player_actor(actor: Unit) -> bool:
	return players.has(actor)


func _foes_of(actor: Unit) -> Array:
	return _alive(enemies) if players.has(actor) else _alive(players)


func _first_foe(actor: Unit) -> Unit:
	var f: Array = _foes_of(actor)
	return f[0] if f.size() > 0 else null


func _check_over() -> void:
	if _alive(enemies).size() == 0:
		over = true
		winner = "player"
	elif _alive(players).size() == 0:
		over = true
		winner = "enemy"


## 推进一步。返回事件字典：
## {"type":"round_end"} 或 {"type":"attack","actor","target","result"} 或 {} (已结束)
func step() -> Dictionary:
	if over:
		return {}
	var actor: Unit = current_actor()
	if actor == null:
		# 本轮所有单位已行动完 → 检查胜负，未分则进入新一轮
		_check_over()
		if not over:
			_start_round()
			return {"type": "round_end", "round": round_num}
		return {}

	var target: Unit = _first_foe(actor)
	if target == null:
		_check_over()
		return {"type": "no_target"}

	var skill: Dictionary = DamageCalc.basic_attack(actor)
	var result: Dictionary = DamageCalc.compute(actor, target, skill)
	if result["hit"]:
		if result.get("is_heal", false):
			target.hp = mini(target.hp_max, target.hp + int(result["damage"]))
		else:
			target.hp = maxi(0, target.hp - int(result["damage"]))

	var ev := {"type": "attack", "actor": actor, "target": target, "result": result,
			   "round": round_num}
	log.append(ev)
	idx += 1
	_check_over()
	return ev
