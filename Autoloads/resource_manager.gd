extends Node

const CARD_DATA_CONST = preload("res://Data/Card_data.gd")

# Key: String (id), Value: CardData instance
var all_cards: Dictionary = {}

func _ready() -> void:
	load_all_card_resources()

# --- 核心：自动化资源加载 ---
func load_all_card_resources() -> void:
	all_cards.clear()
	var path = "res://Resources/Cards/"
	_scan_folder_for_cards(path)
	print("ResourceManager: 已加载 ", all_cards.size(), " 张卡牌资源。")

func _scan_folder_for_cards(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		printerr("错误: 找不到卡牌资源路径: ", path)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			_scan_folder_for_cards(path + file_name + "/")
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var card = load(path + file_name)
			if card is CardData:
				if card.id != "":
					all_cards[card.id] = card
				else:
					printerr("警告: 卡牌资源缺失 ID: ", file_name)
		file_name = dir.get_next()

# --- 外部查询接口 ---
func get_card_data(card_id: String) -> CardData:
	if all_cards.has(card_id):
		return all_cards[card_id]
	printerr("ResourceManager: 未找到卡牌 ID '", card_id, "'。请检查资源文件。")
	return null
