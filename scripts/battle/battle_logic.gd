class_name BattleLogic
extends RefCounted
## 战斗流程核心（纯逻辑，不含 UI / 计时器，可无头运行与单元测试）。
## P5：支持技能施放、状态效果(DoT/HoT/护盾/感电跳过/冰冻减速)、
##     敌人 AI（含 Boss 多阶段条件）、多我多敌、行动条按有效速度排序。
##
## 每次 step() 推进「一个单位的一次行动」，返回事件字典：
##   {"type":"round_end","round"}         本轮行动完毕，进入下一轮
##   {"type":"tick","actor","tick"}       仅结算了回合开始的状态(未致死也未跳过)后继续
##   {"type":"dot_death","actor","tick"}  该单位因持续伤害死亡
##   {"type":"skip","actor"}              因感电跳过行动
##   {"type":"action","actor","skill","result","tick"} 正常施放技能
##   {}                                   战斗已结束

var players: Array = []
var enemies: Array = []
var order: Array = []
var idx: int = 0
var round_num: int = 0
var over: bool = false
var winner: String = ""     # "player" | "enemy" | ""
var log: Array = []

# 玩家指令（由 UI 在 step 前设置；未设置则默认普攻，便于无头模拟）
var pending_skill: Dictionary = {}
var pending_target: Unit = null


func _init(p_units: Array, e_units: Array) -> void:
	players = p_units
	enemies = e_units
	_start_round()


## UI/测试在玩家回合调用，指定本次要放的技能与目标
func set_player_action(skill: Dictionary, target: Unit = null) -> void:
	pending_skill = skill
	pending_target = target


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


func allies_of(actor: Unit) -> Array:
	return _alive(players) if players.has(actor) else _alive(enemies)


func foes_of(actor: Unit) -> Array:
	return _alive(enemies) if players.has(actor) else _alive(players)


func _check_over() -> void:
	if _alive(enemies).size() == 0:
		over = true
		winner = "player"
	elif _alive(players).size() == 0:
		over = true
		winner = "enemy"


func step() -> Dictionary:
	if over:
		return {}

	var actor: Unit = current_actor()
	if actor == null:
		_check_over()
		if not over:
			_start_round()
			return {"type": "round_end", "round": round_num}
		return {}

	# 1) 回合开始：结算 DoT/HoT，递减状态回合
	var tick: Dictionary = actor.on_turn_start()
	var expired: Array = actor.tick_durations()

	if not actor.is_alive():
		var dev := {"type": "dot_death", "actor": actor, "tick": tick,
					"expired": expired, "round": round_num}
		log.append(dev)
		idx += 1
		_check_over()
		return dev

	# 2) 感电：概率跳过行动
	if actor.roll_skip():
		var sev := {"type": "skip", "actor": actor, "tick": tick, "round": round_num}
		log.append(sev)
		idx += 1
		return sev

	# 3) 选择技能
	var skill: Dictionary
	var explicit_target: Unit = null
	if is_player_actor(actor):
		if pending_skill.size() > 0:
			skill = pending_skill
			explicit_target = pending_target
		else:
			skill = DamageCalc.basic_attack(actor)
		pending_skill = {}
		pending_target = null
	else:
		skill = EnemyAI.choose_skill(actor, _alive(enemies))

	# 蓝不足则退回普攻
	if not SkillExecutor.can_cast(actor, skill):
		skill = DamageCalc.basic_attack(actor)

	# 4) 结算
	var res: Dictionary = SkillExecutor.cast(
		actor, skill, allies_of(actor), foes_of(actor), explicit_target)
	var ev := {"type": "action", "actor": actor, "skill": skill, "result": res,
			   "tick": tick, "expired": expired, "round": round_num}
	log.append(ev)
	idx += 1
	_check_over()
	return ev
