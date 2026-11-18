class_name Enemy
extends Glyph
## 敵人：一個字，加上血量、速度、攻擊等屬性。
## 種類的數值定義在 main.gd 的 ENEMY_TYPES。

const FLASH_TIME := 0.08
const FLASH_COLOR := Color.WHITE

var kind := ""
var hp := 1.0
var max_hp := 1.0
var speed := 90.0
var radius := 14.0
var damage := 30           # 撞到主角扣多少血
var gold := 1              # 死掉掉幾個金
var ranged := false        # 弓：保持距離放箭
var ignores_walls := false # 王：直接穿牆走過來
var shoot_cd := 0.0
var flash := 0.0
var knock := Vector2.ZERO   # 擊退速度，會慢慢衰減
var knock_resist := 1.0    # 擊退倍率，王比較推不動
var is_boss := false       # 王、大弓：不會被瞬殺、死掉特效比較大
var shoot_range := 300.0   # 遠程敵人：多近開始放箭
var shoot_interval := 2.0  # 遠程敵人：幾秒放一次箭
var arrow_speed := 220.0   # 遠程敵人：矢飛多快
var volley := 1            # 遠程敵人：一次放幾支箭（扇形）
var shield := 0            # 魂、鬼：還能完全擋掉幾次攻擊（擋的時候身體是半透明的）
var wobble := false        # 魂、鬼：走路會左右飄
var wobble_freq := Vector2.ONE   # 兩個不同頻率的正弦疊起來，飄得不規則
var wobble_phase := Vector2.ZERO
var age := 0.0
var stun := 0.0             # 撞到主角（攻擊成功）後原地停頓的秒數

var base_color := Color.WHITE


func setup_type(type_name: String, t: Dictionary, hp_mult: float) -> Enemy:
	kind = type_name
	max_hp = t["hp"] * hp_mult
	hp = max_hp
	speed = t["speed"]
	radius = t["radius"]
	damage = t["damage"]
	gold = t["gold"]
	ranged = t.get("ranged", false)
	ignores_walls = t.get("ignores_walls", false)
	knock_resist = t.get("knock_resist", 1.0)
	is_boss = t.get("boss", false)
	shoot_range = t.get("shoot_range", 300.0)
	volley = t.get("volley", 1)
	base_color = t["color"]
	shield = t.get("shield", 0)
	wobble = t.get("wobble", false)
	wobble_freq = Vector2(randf_range(1.5, 3.0), randf_range(3.5, 6.0))
	wobble_phase = Vector2(randf() * TAU, randf() * TAU)
	_update_ghost()
	setup(type_name, t["size"], base_color)
	return self


## 受傷，回傳是否死亡
func take_damage(amount: float) -> bool:
	hp -= amount
	flash = FLASH_TIME
	color = FLASH_COLOR
	queue_redraw()
	return hp <= 0.0


## 擋下一次攻擊，回傳 true = 這次攻擊被擋掉了
func block_hit() -> bool:
	if shield <= 0:
		return false
	shield -= 1
	flash = FLASH_TIME
	color = FLASH_COLOR
	_update_ghost()
	queue_redraw()
	return true


## 還有無敵次數時半透明（像幽靈），用完才變實體
func _update_ghost() -> void:
	modulate.a = 0.6 if shield > 0 else 1.0


## 左右飄的量，-1 ~ 1
func sway() -> float:
	return (sin(age * wobble_freq.x + wobble_phase.x) + 0.5 * sin(age * wobble_freq.y + wobble_phase.y)) / 1.5


func tick(delta: float) -> void:
	age += delta
	if flash > 0.0:
		flash -= delta
		if flash <= 0.0:
			color = base_color
			queue_redraw()


func _draw() -> void:
	super()
	# 血比較厚的敵人，受傷後在腳下顯示血條
	if max_hp >= 30.0 and hp < max_hp:
		var w := radius * 2.0
		var y := radius + 4.0
		draw_rect(Rect2(-w / 2.0, y, w, 4), Color(0.3, 0.3, 0.3))
		draw_rect(Rect2(-w / 2.0, y, w * clampf(hp / max_hp, 0.0, 1.0), 4), base_color)
