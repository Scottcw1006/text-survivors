class_name Meta
extends RefCounted
## 局外成長（rogue-like）：鑽 和鑽石升級，存在 user://meta.cfg，關掉遊戲再開也還在。
## - 每玩滿一分鐘拿 1 個 鑽，一局最多 3 個；打倒最終王再多 2 個
## - 鑽石升級：一般升級提前升級（最高 3 級）、重抽次數（最高 2 級）、開局寶箱（最高 2 級）

const PATH := "user://meta.cfg"
const TOKEN_PER_MINUTE := 1
const TOKEN_MINUTE_CAP := 3
const TOKEN_WIN_BONUS := 2
const BASE_REROLLS := 3
const REROLL_PER_LEVEL := 3

## 鑽石升級的項目：id、名稱、最高等級、每一級要幾個 鑽
## 一般升級的 id 跟 main.gd 的 UPGRADES 一樣（power、haste…），前面加 "up_"
const ITEMS := [
	{"id": "up_power",  "icon": "力", "name": "攻擊力",   "max": 4, "cost": [1, 1, 1, 1]},
	{"id": "up_haste",  "icon": "疾", "name": "攻擊速度", "max": 4, "cost": [1, 1, 1, 1]},
	# 穿／廣：同一項，人開局升「穿」、刀開局升「廣」
	{"id": "up_pierce_reach", "icon": "穿", "name": "穿透／斬擊範圍", "max": 4, "cost": [1, 1, 1, 1]},
	{"id": "up_speed",  "icon": "速", "name": "移動速度", "max": 4, "cost": [1, 1, 1, 1]},
	{"id": "up_vital",  "icon": "體", "name": "體魄",     "max": 4, "cost": [1, 1, 1, 1]},
	{"id": "up_magnet", "icon": "磁", "name": "吸金",     "max": 4, "cost": [1, 1, 1, 1]},
	{"id": "up_focus",  "icon": "息", "name": "調息",     "max": 4, "cost": [1, 1, 1, 1]},
	{"id": "reroll",    "icon": "換", "name": "重抽次數 +3", "max": 3, "cost": [1, 1, 1]},
	{"id": "chest",     "icon": "寶", "name": "開局寶箱",   "max": 3, "cost": [5, 5, 5]},
]

static var tokens := 0
static var levels := {}
static var _loaded := false


static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	tokens = int(cfg.get_value("meta", "tokens", 0))
	levels = cfg.get_value("meta", "levels", {})
	# 舊存檔：穿、廣原本分開，合併成一項（取比較高的那個，另一個退回鑽）
	if levels.has("up_pierce") or levels.has("up_reach"):
		var a := int(levels.get("up_pierce", 0))
		var b := int(levels.get("up_reach", 0))
		levels["up_pierce_reach"] = maxi(maxi(a, b), int(levels.get("up_pierce_reach", 0)))
		tokens += mini(a, b)
		levels.erase("up_pierce")
		levels.erase("up_reach")
		save()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "tokens", tokens)
	cfg.set_value("meta", "levels", levels)
	cfg.save(PATH)


static func level(id: String) -> int:
	return int(levels.get(id, 0))


## 下一級要幾個 鑽；已經滿級回傳 -1
static func next_cost(item: Dictionary) -> int:
	var lv := level(item.id)
	if lv >= item.max:
		return -1
	return item.cost[lv]


## 買下一級，成功回傳 true
static func buy(item: Dictionary) -> bool:
	var cost := next_cost(item)
	if cost < 0 or tokens < cost:
		return false
	tokens -= cost
	levels[item.id] = level(item.id) + 1
	save()
	return true


## 全部重置：把花掉的 鑽 全部退回來
static func refund_all() -> int:
	var back := 0
	for it: Dictionary in ITEMS:
		for i in level(it.id):
			back += int(it.cost[i])
	tokens += back
	levels = {}
	save()
	return back


## 這一局拿到幾個 鑽：每滿一分鐘 1 個（最多 3 個），打倒最終王 +2
static func tokens_for_run(seconds: float, won: bool) -> int:
	var n := mini(int(seconds / 60.0) * TOKEN_PER_MINUTE, TOKEN_MINUTE_CAP)
	if won:
		n += TOKEN_WIN_BONUS
	return n


static func rerolls() -> int:
	return BASE_REROLLS + REROLL_PER_LEVEL * level("reroll")
