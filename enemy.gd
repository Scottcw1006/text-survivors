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
var volley := 1            # 遠程敵人：一次放幾支箭（扇形）

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
	setup(type_name, t["size"], base_color)
	return self


## 受傷，回傳是否死亡
func take_damage(amount: float) -> bool:
	hp -= amount
	flash = FLASH_TIME
	color = FLASH_COLOR
	queue_redraw()
	return hp <= 0.0


func tick(delta: float) -> void:
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
