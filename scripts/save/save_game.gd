class_name SaveGame
extends RefCounted
## 存档读写（JSON 存到 Godot 用户目录 user://save.json）。
## 纯静态方法，可无头测试往返一致性。

const SAVE_PATH := "user://save.json"


static func exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## 写入存档字典；成功返回 true
static func write(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveGame] 无法写入: " + SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


## 读取存档字典；不存在或解析失败返回空字典
static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveGame] 存档解析失败")
		return {}
	return parsed


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(SAVE_PATH)
