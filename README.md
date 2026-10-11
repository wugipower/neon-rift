# 霓虹裂隙 NeonRift

> 都市幻想 · 2D 回合制 RPG · Godot 4.7 + GDScript 独立开发作品
> 从主菜单一路玩到通关的完整小型 RPG：3 人小队、15 个剧情/战斗节点、双 Boss、商店装备、存档读档、完整战斗系统。

## 下载即玩（Windows）

1. 打开 [Releases](https://github.com/wugipower/neon-rift/releases/latest)，下载 `NeonRift.zip`
2. **解压**到任意文件夹（不要直接在压缩包里双击运行）
3. 双击 `NeonRift.exe` 开始游戏（单文件，无需安装任何运行库以外的东西；Win10/11 64 位）

存档位置：`%APPDATA%\Godot\app_userdata\霓虹裂隙 NeonRift\save.json`（据点手动存档 + 战斗胜利自动存档）

## 玩法一览

- **队伍铁三角**：凛（电·输出）/ 苍（冰·坦克）/ 澪（水·辅助），12 种异能 + 普攻 + 战斗道具（回血/回蓝/复活）
- **元素克制环**：电→水→火→冰→电（1.5x / 0.75x），克制系数实时显示在战斗日志
- **状态系统**：灼烧/回春/护盾/感电(概率跳过行动)/冰冻(减速)/攻防增益，全部数据表驱动
- **敌人 AI 与 Boss 多阶段**：中Boss 血量 <50% 解锁群体冰爆与狂暴；最终Boss 三阶段技能组
- **成长与经营**：经验升级曲线、据点商店买卖、装备穿戴即时改变属性、节点式章节地图

## 从源码运行

1. 安装 [Godot 4.7.2（标准版，非 .NET）](https://godotengine.org/download/windows/)
2. 用 Godot 导入本仓库目录（`project.godot`），按 F5 运行
3. 工程根目录附带三个双击即可运行的批处理：
   - `run_tests.bat` —— 跑全部 7 套无头自动化测试 + 全流程自动通关模拟
   - `run_battle.bat` —— 独立战斗试玩（不依赖战役进度）
   - `run_stat_panel.bat` —— 图形化属性面板（拖等级滑块看属性成长）

## 设计亮点（策划视角）

- **全数据驱动**：12 张 CSV 承载角色/技能/敌人/AI/装备/道具/状态/掉落/元素/关卡/对话/商店，调平衡、加关卡只改表不改代码（WPS/Excel 直接编辑）
- **数值有迭代证据**：`docs/数值调优记录.md` 完整记录 3 版调参的前后对比（固定种子自动模拟：回合数/最低血线/终局等级），把 Boss 战从「2 回合白嫖」调到「9 回合苦战、血线 31%」的节奏高点
- **逻辑与表现分离**：战斗规则全部在无头层（`BattleLogic/DamageCalc/SkillExecutor/EnemyAI`），可单元测试；UI 只做渲染。7 套测试共 100+ 断言
- **可复现的程序化资源**：BGM/音效/语音/怪物头像全部由 `tools/` 下脚本生成（Python 合成 + Windows TTS），零版权风险、可一键重做

## 项目结构

```
data/        12 张数值 CSV（内容底座）
autoload/    DataManager / GameState / SceneLoader / AudioManager（全局单例）
scripts/     battle(纯逻辑+表现) / entities / ui / save
scenes/      main_menu / hub / map / battle / stat_panel
tests/       7 套无头测试 + 全流程自动通关模拟
docs/        开发方案 / 数值设计 / 数值调优记录 / 开发进度
tools/       音频合成 / 语音生成 / 怪物头像生成脚本
```

## 开发历程

见 [docs/开发进度.md](docs/开发进度.md)：P1 环境 → P2 数值表 → P3 数据框架 → P4 战斗核心 → P5 战斗扩展 → P6 关卡流程 → P7 表现打磨（含调优） → P8 打包发布，每阶段附验证方式与提交记录。

License: MIT
