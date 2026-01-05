extends Node
## セーブデータ管理 - ローカルファイルにプレイヤーの永続データを保存

const SAVE_FILE_PATH := "user://save_data.json"

signal zircoin_changed(total: int)

# プレイヤーの永続リソース
var total_zircoin: int = 0

func _ready() -> void:
	load_data()


## データをファイルからロード
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("SaveDataManager: No save file found, starting fresh.")
		total_zircoin = 0
		emit_signal("zircoin_changed", total_zircoin)
		return
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveDataManager: Failed to open save file for reading.")
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveDataManager: Failed to parse save file JSON.")
		return
	
	var data: Dictionary = json.data if json.data is Dictionary else {}
	total_zircoin = int(data.get("total_zircoin", 0))
	
	print("SaveDataManager: Loaded save data. total_zircoin=", total_zircoin)
	emit_signal("zircoin_changed", total_zircoin)


## データをファイルに保存
func save_data() -> void:
	var data := {
		"total_zircoin": total_zircoin,
		"last_saved": Time.get_datetime_string_from_system()
	}
	
	var json_string := JSON.stringify(data, "\t")
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveDataManager: Failed to open save file for writing.")
		return
	
	file.store_string(json_string)
	file.close()
	print("SaveDataManager: Saved data. total_zircoin=", total_zircoin)


## ラン終了時にジルコインを追加（持ち帰り率適用済み）
func add_zircoin(amount: int) -> void:
	if amount <= 0:
		return
	total_zircoin += amount
	emit_signal("zircoin_changed", total_zircoin)
	save_data()


## 現在の所持ジルコイン数を取得
func get_total_zircoin() -> int:
	return total_zircoin


## ジルコインを消費（将来のショップ機能用）
func spend_zircoin(amount: int) -> bool:
	if amount <= 0:
		return true
	if total_zircoin < amount:
		return false
	total_zircoin -= amount
	emit_signal("zircoin_changed", total_zircoin)
	save_data()
	return true
