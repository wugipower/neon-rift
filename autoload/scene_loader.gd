extends Node
## SceneLoader（全局单例）：统一的场景切换入口。
## 目前直接切换；P7 可在此加入淡入淡出转场。

func goto(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("[SceneLoader] 切换场景失败: " + scene_path)


func goto_battle() -> void:
	goto("res://scenes/battle.tscn")


func goto_map() -> void:
	goto("res://scenes/map.tscn")


func goto_hub() -> void:
	goto("res://scenes/hub.tscn")


func goto_menu() -> void:
	goto("res://scenes/main_menu.tscn")
