extends Node2D
## 文字倖存者 MVP：選角、一局的流程、生成、攻擊、升級、碰撞與 HUD 都在這裡。

# ===== 遊戲參數（調平衡改這裡）=====
const GAME_DURATION := 180.0        # 撐過幾秒進入決戰
## 決戰：兩隻「王」加一隻「大」字頭的王，全部打倒才算贏（種類隨機）
const FINAL_KINGS := 2
const BIG_KINDS := ["弓", "鬼", "魂", "牛", "犇", "弩"]   # 「大」字王可能是哪幾種
const VOLLEY_SPREAD := 0.7          # 大弓一次放箭的扇形角度（弧度，約 40 度）
const PLAYER_MAX_HP := 100
const VITAL_REGEN := 0.1             # 「體」每一級每秒回多少血
const PLAYER_SPEED := 220.0
const PLAYER_RADIUS := 14.0
const BASE_DAMAGE := 10.0           # 斬擊、迴旋刃等的基礎傷害
const BULLET_DAMAGE := 8.0          # 人的子彈基礎傷害
# ---------- 牛、犇 ----------
const CHARGE_RANGE := 300.0           # 多近開始蓄力（約 8 格）
const CHARGE_WINDUP := 0.8            # 蓄力幾秒
const STOMP_TIMES := [0.3, 0.65]      # 蓄力中第幾成的時候踩下去（踩兩下）
const STOMP_LEN := 0.18               # 每一下抬腳佔蓄力時間的比例
const STOMP_HEIGHT := 10.0            # 抬多高
const CHARGE_SPEED := 620.0           # 衝刺速度
const CHARGE_OVERSHOOT := 40.0        # 衝到目標點後再多衝一點
const CHARGE_REST := 0.5              # 衝完喘幾秒
const CHARGE_COOLDOWN := 2.5          # 衝完之後多久才能再蓄力
const BLAST_RADIUS := 80.0            # 犇的爆炸半徑
const BLAST_DAMAGE := 15              # 犇的爆炸傷害
const ATTACK_PAUSE := 0.3            # 敵人撞到主角之後原地停頓幾秒
const INVINCIBLE_TIME := 1.5        # 被打後無敵幾秒（避免一碰就連續扣血秒死）

# 「人」：遠程射擊
const FIRE_INTERVAL := 0.5          # 幾秒射一發（每秒 2 次）
const BULLET_SPEED := 300.0
const BULLET_LIFETIME := 3.0
const BULLET_RADIUS := 8.0
const AIM_RANGE := 1400.0           # 自動瞄準範圍（約畫面寬的一半）
const MUZZLE_DIST := 34.0           # 槍口在主角前面多遠
const RECOIL := 6.0                 # 開槍時主角往後退幾像素（只是畫面效果）
const RECOIL_RECOVER := 80.0        # 後座力每秒回復多少像素

# 「刀」：近身斬擊
const SLASH_INTERVAL := 0.6         # 幾秒砍一次
const SLASH_RANGE := 108.0          # 約三個字的距離
const SLASH_ARC := PI * 5.0 / 6.0    # 扇形角度（150 度）

# Shift 技能
const SKILL_MAX_CHARGES := 2
const SKILL_COOLDOWN := 5.0         # 每一格充能要幾秒
const DASH_DISTANCE := 216.0        # 人：衝刺六格
const DASH_TIME := 0.12             # 很快，像瞬移
const JUMP_DISTANCE := 180.0        # 刀：跳五格
const JUMP_TIME := 0.35
const JUMP_LAND_RANGE := 108.0      # 落地時三格內的敵人瞬殺
const LAND_GRACE := 0.2             # 落地後再多無敵一下
const DASH_EXTRA_GRACE := 1.0       # 人衝刺結束後再多無敵 1 秒

# 「金」：敵人掉落
const GOLD_PICKUP_RANGE := 144.0    # 約四個字的距離，進入範圍就被吸過來
const GOLD_PULL_SPEED := 420.0
const GOLD_SIZE := 22

const ENEMY_GAP := 2.0              # 敵人彼此多保持的距離，避免疊成一個字
const HP_GROWTH_PER_MINUTE := 0.10  # 每過一分鐘，新生的敵人血量 +10%
const BOSS_INTERVAL := 60.0         # 每隔幾秒出一隻王
const BOSS_LAND_MULT := 5.0         # 刀落地對王的傷害倍率（王不會被瞬殺）
const WOBBLE_AMOUNT := 2.0           # 魂、鬼左右飄的幅度（相對於移動速度）
const RAT_GROUP := 4                # 鼠一次來幾隻
const BIRD_GROUP := 3               # 鳥一次來幾隻
const FINAL_SIZE_MULT := 1.3        # 最終王的字放大幾倍（會取最近的 11 的倍數，像素字才銳利）
const FINAL_HP_MULT := 2.0          # 最終王的血量倍率
const FINAL_SPEED_MULT := 1.5       # 最終王的移動速度倍率
const FINAL_FIRE_RATE_MULT := 1.5   # 最終王放箭的頻率倍率
const FINAL_ARROW_SPEED_MULT := 1.5 # 最終王矢的飛行速度倍率
const ARCHER_RANGE := 300.0         # 弓在這個距離內、看得到你就停下來放箭
const ARROW_INTERVAL := 2.0
const ARROW_SPEED := 220.0
const ARROW_DAMAGE := 10
const ARROW_LIFETIME := 3.0

## 敵人種類。hp 是基礎血量（會隨時間成長），gold 是死掉掉幾個金
## 鼠的血量要小於子彈基礎傷害 10（三分鐘時 7.5 × 1.3 = 9.75），才會一直被一發打死
const ENEMY_TYPES := {
	"敵": {"hp": 15.0, "speed": 90.0, "radius": 14.0, "size": 33, "damage": 25, "gold": 1,
		"color": Color(1.0, 0.45, 0.45)},
	"鼠": {"hp": 7.5, "speed": 150.0, "radius": 10.0, "size": 22, "damage": 10, "gold": 1,
		"color": Color(0.3, 0.6, 0.35)},
	"甲": {"hp": 60.0, "speed": 55.0, "radius": 15.0, "size": 33, "damage": 25, "gold": 3,
		"color": Color(0.8, 0.3, 0.3)},
	"弓": {"hp": 22.5, "speed": 80.0, "radius": 14.0, "size": 33, "damage": 10, "gold": 2,
		"color": Color(0.65, 0.35, 0.9), "ranged": true},
	# 鳥：鼠的進階，速度 1.5 倍、血多一點
	"鳥": {"hp": 10.0, "speed": 225.0, "radius": 10.0, "size": 22, "damage": 10, "gold": 1,
		"color": Color(0.5, 0.9, 0.45)},
	# 弩：弓的進階，開始放箭的距離是弓的 1.5 倍、血多一點
	"弩": {"hp": 30.0, "speed": 80.0, "radius": 14.0, "size": 33, "damage": 10, "gold": 3,
		"color": Color(0.5, 0.25, 0.85), "ranged": true, "shoot_range": 450.0},
	# 冑：甲的進階，兩倍血、完全不吃擊退
	"冑": {"hp": 120.0, "speed": 55.0, "radius": 15.0, "size": 33, "damage": 25, "gold": 5,
		"color": Color(0.65, 0.2, 0.2), "knock_resist": 0.0},
	# 魂：穿牆、左右飄著過來，第一次被打到完全無效（半透明 = 還有無敵）
	"魂": {"hp": 15.0, "speed": 90.0, "radius": 14.0, "size": 33, "damage": 15, "gold": 2,
		"color": Color(0.55, 0.65, 1.0), "ignores_walls": true, "wobble": true, "shield": 1},
	# 鬼：魂的進階，速度 1.5 倍、無敵三次
	"鬼": {"hp": 22.5, "speed": 135.0, "radius": 14.0, "size": 33, "damage": 20, "gold": 3,
		"color": Color(0.4, 0.5, 1.0), "ignores_walls": true, "wobble": true, "shield": 3},
	# 牛：靠近後蓄力，直線衝向蓄力那一刻玩家的位置，衝刺中不吃擊退
	"牛": {"hp": 45.0, "speed": 70.0, "radius": 16.0, "size": 33, "damage": 25, "gold": 3,
		"color": Color(0.75, 0.5, 0.3), "charger": true},
	# 犇：牛的進階，更大更硬，蓄力時和衝到定點時各炸一圈
	"犇": {"hp": 90.0, "speed": 65.0, "radius": 22.0, "size": 44, "damage": 35, "gold": 6,
		"color": Color(0.85, 0.35, 0.2), "charger": true, "blaster": true},
}
# ---------- 王（任何一種敵人的大字版，會穿牆） ----------
const BOSS_HP_BASE := 600.0           # 王的血量 = 600 × √(小兵血量 ÷ 15)：敵 600、甲 1200、冑 1697、鼠 424
const BOSS_SPEED_MULT := 0.78         # 王的速度 = 那種小兵 × 0.78（敵 90 → 70）
const BOSS_SIZE := 66
const BOSS_RADIUS := 28.0
const BOSS_DAMAGE := 40
const BOSS_GOLD := 25
const BOSS_KNOCK_RESIST := 0.15
const BOSS_SHIELD_EVERY := 7.0        # 王魂、王鬼：每幾秒重置無敵
const BOSS_TWEAK := {"鳥": 0.85}      # 個別種類的王再乘的倍率（血量、速度都乘）：王鳥太快太硬
const BIG_HP_MULT := 1.5              # 「大」字王比一般的王多 50% 血
const BIG_SIZE := 55
const BIG_RADIUS := 34.0
const BIG_SHIELD_EVERY := 3.0         # 大魂、大鬼：每幾秒重置無敵
const AURA_RADIUS := 108.0            # 大魂的無敵領域半徑（3 格）
const AURA_TIME := 1.0                # 領域裡的敵人無敵幾秒
const BURST_GAP := 0.12               # 大弩連射的間隔
const COLOR_AURA := Color(0.6, 0.75, 1.0)
const SPAWN_INTERVAL_START := 0.4   # 開局幾秒生一隻
const SPAWN_INTERVAL_END := 0.15    # 三分鐘時幾秒生一隻
const SPAWN_MARGIN := 60.0          # 在畫面邊緣外多遠生成

# 打擊感
const KNOCK_BULLET := 80.0          # 子彈打中把敵人往後推多快
const KNOCK_MAX := 300.0            # 擊退速度上限：很多子彈同時打中也不會疊到飛太遠
const KNOCK_SLASH := 260.0          # 斬擊把敵人往外推多快
const KNOCK_DECAY := 900.0          # 擊退速度每秒衰減多少
const SHAKE_DECAY := 40.0           # 畫面震動每秒衰減多少像素
const SHARDS := ["丶", "ノ", "一", "丿"]  # 敵人死掉碎成的筆畫

# 全畫面調色：整體亮度與彩度（1 = 原本）。畫面太刺眼就往下調
const SCREEN_BRIGHTNESS := 0.85
const SCREEN_SATURATION := 0.8

const GLYPH_SIZE := 33              # 像素字型 11px 的 3 倍，保持銳利
const BULLET_SIZE := 22
const GRID_CELL := 48.0             # 碰撞用的空間格子，要 >= 最大碰撞距離

const COLOR_PLAYER := Color.WHITE
const COLOR_ARROW := Color(0.65, 0.35, 0.9)
const COLOR_ENEMY_BOSS := Color(1.0, 0.2, 0.2)
const COLOR_CHEST := Color(0.45, 0.85, 1.0)
const COLOR_BULLET := Color(1.0, 0.9, 0.4)
const COLOR_GOLD := Color(1.0, 0.75, 0.2)

# 天罰：滑鼠左鍵點擊，該位置三格內的小兵秒殺（王只吃重傷害）
const SMITE_RADIUS := 108.0         # 只用來畫中間那圈「罰」
const COLOR_SMITE := Color(0.75, 0.9, 1.0)

# 寶箱：每 30 秒在附近隨機出現，王死掉也會掉；打開後二選一強化「彈」或「刀」
const POINTER_SIZE := 66              # 寶箱、王在畫面外時，邊緣提示字的大小
const POINTER_MARGIN := 60.0          # 提示字離畫面邊緣多遠（字變大了，要往內縮才不會被切掉）
# ---------- 人＋砲 ----------
const CANNON_INTERVAL := FIRE_INTERVAL * 4.0   # 射速是一般射擊的四分之一
const CANNON_SPEED := 420.0
const CANNON_RANGE := 900.0           # 沒打到東西飛多遠就自己爆
const CANNON_DAMAGE := 24.0
const CANNON_RADIUS := 54.0           # Lv1 爆炸半徑（1.5 格），Lv2 ×2、Lv4 再 ×2
const CANNON_SPREAD := 0.22           # Lv3 以上兩發之間的角度（弧度）
const CANNON_BIG_DIST := 360.0        # Lv5 巨砲飛 10 格後爆炸
const CANNON_BIG_RADIUS := 360.0      # 巨砲半徑 10 格
const CANNON_BIG_MULT := 3.0          # 巨砲傷害倍率
const CANNON_PIERCE_BONUS := 0.25     # 每一級「穿」讓砲的傷害 +25%
const COLOR_CANNON := Color(1.0, 0.55, 0.2)
# ---------- 刀＋影 ----------
const SHADE_COLOR := Color(0.65, 0.65, 1.0, 0.5)    # 分身本體（半透明）
const SHADE_FX_COLOR := Color(0.7, 0.7, 1.0, 0.7)   # 分身的斬擊特效
const SHADE_GAP := 56.0               # 分身跟主角的距離
const SHADE_SPEED := 520.0            # Lv3 以上分身自己衝過去的速度
const SHADE_LEASH := 540.0            # 分身最遠離開主角多遠（也是 Lv3 以上找敵人的範圍，約 15 格）
const SHADE_WEAK := 0.5               # Lv1～3 分身傷害倍率
const EXPLOSION_LINGER := 0.5         # 爆炸的字留在畫面上多久（只打一次）
# ---------- 蘇生（寶箱卡片，可以重複拿） ----------
const REVIVE_HP := 25                 # 蘇生後的血量
const REVIVE_INVINCIBLE := 3.0        # 蘇生後無敵幾秒
const HEAL_INTERVAL := 25.0          # 每幾秒出現一顆補血愛心
const HEAL_AMOUNT := 20               # 一顆補多少血
const HEAL_MAX_ON_MAP := 3            # 地圖上最多同時幾顆（沒撿就不再多生）
const HEAL_MIN_DIST := 200.0
const HEAL_MAX_DIST := 550.0
const HEAL_PICK_RANGE := 34.0
const CHEST_INTERVAL := 30.0
const CHEST_MIN_DIST := 400.0
const CHEST_MAX_DIST := 1000.0
const CHEST_OPEN_RANGE := 30.0

# 強化線（寶箱給的）：兩條線各自 Lv 1~5，同一條往深走或兩條混著走
const LINE_MAX := 5
const SPREAD_DEG := [0.0, 15.0, 25.0, 35.0, 45.0]   # 人＋彈：各級散射總角度
const ORBIT_RADIUS := 70.0          # 人＋刀：迴旋刃內圈半徑
const ORBIT_RING_GAP := 50.0        # Lv2 外圈比內圈遠多少
const ORBIT_PER_RING := 4           # 每一圈幾把刃
const FLY_BARRAGE := 8              # Lv5：爆炸後一整圈射出幾把刃
const ORBIT_SPEED := 3.6            # 人＋刀：每秒轉幾弧度
const ORBIT_DAMAGE_MULT := 1.2      # 迴旋刃（含爆旋、刃幕）的傷害倍率
const ORBIT_HIT_CD := 0.4           # 同一把刃多久能再打同一隻敵人
const SPIN_EVERY := 1.0             # Lv3 疾旋：每轉 1 秒……
const SPIN_TIME := 1.0              # ……就快速旋轉 1 秒
const SPIN_MULT := 3.0              # 快速旋轉是平常的幾倍速
const SPIN_HIT_CD := 0.15           # 快速旋轉時同一隻敵人多久能再被打
const BURST_GROW := 72.0            # Lv4 爆旋：刃往外擴大兩格
const BURST_TIME := 0.3             # 擴大再收回的時間（擴到最大時爆炸）
const BURST_MULT := 2.0             # 爆炸傷害倍率
const FLY_SPEED_MULT := 2.0         # Lv5 飛刃：速度是子彈的幾倍
const FLY_RANGE_MULT := 2.0         # Lv5 飛刃：飛行距離是子彈的幾倍
const ORBIT_SIZE := 22              # 人＋刀：「刃」字大小
const COMBO_DELAY := 0.12           # 刀＋刀：連擊之間的間隔
const COMBO_GROW := 36.0            # 刀＋刀 Lv2：連斬第二刀比第一刀大一格
const SCISSOR_OVERLAP := PI / 6.0   # 刀＋刀 Lv4：雙刀中間重疊 30 度
const AFTERIMAGE_ARC := PI * 1.5    # 刀＋刀 Lv5 殘影斬：270 度
const AFTERIMAGE_TIME := 0.5        # 殘影斬殘留幾秒
const ZONE_TICK := 0.5              # 殘留的斬擊每幾秒打一次
const WAVE_INTERVAL := 1.0          # 刀＋彈：多久發一次（會乘上攻擊速度）
const WAVE_SPEED := 480.0
const WAVE_RANGE := 288.0           # Lv1~3：飛 8 格
const WAVE_PIERCE := 2              # 斬擊波穿透幾個（打到第 3 個就消失）
const WAVE_BIG_SCALE := 2.0         # 大斬擊波是一般的幾倍
const WAVE_RANGE_LONG := 540.0      # Lv4：飛 15 格
const WAVE_SPEED_FAST := 800.0      # Lv4：快速斬擊波
const WAVE_BURST_GAP := 0.07        # Lv4：四連發之間的間隔
const RIFT_TARGETS := 4             # Lv5 空間斬擊：鎖定畫面內最近的幾個敵人
const RIFT_RADIUS := 40.0           # 空間斬擊的半徑
const RIFT_TIME := 0.5              # 空間斬擊停留幾秒
const RIFT_REACH_BONUS := 0.15        # 「廣」每級讓空間斬擊的直徑 +15%
const COLOR_RIFT := Color(0.8, 0.6, 1.0)

## 卡片上的名稱與說明：[角色][線] -> 名稱、各級說明（index = 升到第幾級）
## 說明：卡片一行大約 8 個中文字，用 \n 自己斷行（最多 5 行），才不會斷在詞中間
const POWER_INFO := {
	"人": {
		"彈": {"name": "彈道", "desc": ["", "自動往最近的\n敵人射子彈", "散射 3 發子彈", "散射 5 發，\n角度更廣", "散射 7 發", "散射 9 發，\n扇形 45°"]},
		"刀": {"name": "迴旋刃", "desc": ["",
			"4 把「刃」\n繞身旋轉，\n碰到就砍，\n也能擋下飛來的矢",
			"雙圈：\n內外兩圈，\n各 4 把",
			"疾旋：\n一般速度 1 秒、\n加速 1 秒，輪流",
			"爆旋：\n加速完兩圈\n往外擴大，\n以外圈爆炸一大圈",
			"刃幕：\n爆炸後往四周\n射出一整圈刃，\n撞牆反彈，\n穿透吃「穿」升級"]},
		"砲": {"name": "火砲", "desc": ["",
			"砲擊：\n每 2 秒射一發，\n命中就爆炸；\n「穿」升級\n改成加砲的傷害",
			"爆炸範圍加倍",
			"一次射兩發",
			"爆炸範圍\n再加倍",
			"巨砲：\n兩發中間多一發\n巨砲，飛 10 格\n後大爆炸，\n半徑 10 格"]},
	},
	"刀": {
		"刀": {"name": "刀法", "desc": ["", "扇形揮砍，\n一次砍多個\n敵人",
			"連斬：\n反方向再斬一次，\n第二刀大一格",
			"三連斬：\n連斬後換手再斬，\n一刀比一刀大；\n斬擊可以砍掉\n飛來的矢",
			"雙刀連斬：\n兩刀像剪刀合起，\n再反過來打開，\n範圍同三連斬\n後兩刀（共四刀）",
			"殘影斬：\n270° 大斬擊，\n殘留 0.5 秒，\n結束時再打一次，\n殘留時也會砍矢"]},
		"影": {"name": "影分身", "desc": ["",
			"影分身：\n身後出現一個\n半透明的「刀」，\n跟著一起揮刀\n（傷害 50%）",
			"兩個分身，\n左右各一",
			"分身會自己\n衝向附近的\n敵人去砍",
			"分身傷害\n提高到 100%",
			"繼承本體：\n分身使用本體的\n攻擊力與招式\n（刀法、斬擊波、\n落地震）"]},
		"彈": {"name": "斬擊波", "desc": ["",
			"斬擊波：\n自動射出斬擊波，\n飛 8 格，\n可穿透 2 個敵人\n（「廣」每級 +1）",
			"大斬擊波：\n兩倍大",
			"四方斬擊：\n同時往四個方向\n射出大斬擊波",
			"四連斬擊：\n快速連射 4 道\n大斬擊波，\n飛 15 格，鎖定\n最近 4 個敵人",
			"空間斬擊：\n直接在畫面內\n最近 4 個敵人\n身上出現斬擊"]},
	},
}

# 升級：吃「金」累積經驗，升級時三選一
const XP_FIRST_LEVEL := 6           # 升到 2 級要幾個金
const XP_STEP := 4                  # 之後每級多要幾個
const UPGRADE_MAX_LEVEL := 7          # 一般升級（力、疾…）每種最多幾級
## who：all = 兩個角色都有，否則只給那個角色
const UPGRADES := [
	{"id": "power",  "icon": "力", "name": "攻擊力",   "desc": "傷害 +20%", "who": "all"},
	{"id": "haste",  "icon": "疾", "name": "攻擊速度", "desc": "攻擊速度 +15%", "who": "all"},
	{"id": "pierce", "icon": "穿", "name": "穿透",     "desc": "子彈多穿過\n1 個敵人；\n砲傷害 +25%", "who": "人"},
	{"id": "reach",  "icon": "廣", "name": "斬擊範圍", "desc": "斬擊距離 +20%；\n斬擊波多穿過\n1 個敵人；\n空間斬擊 +15%", "who": "刀"},
	{"id": "speed",  "icon": "速", "name": "移動速度", "desc": "移動速度 +12%", "who": "all"},
	{"id": "vital",  "icon": "體", "name": "體魄",     "desc": "每秒回 0.1 血", "who": "all"},
	{"id": "magnet", "icon": "磁", "name": "吸金",     "desc": "吸金範圍 +35%", "who": "all"},
	{"id": "focus",  "icon": "息", "name": "調息",     "desc": "技能冷卻 -15%", "who": "all"},
]

const CHARACTERS := [
	# 說明：卡片一行大約 8 個中文字，自己用 \n 斷行，才不會斷在奇怪的地方
	{"glyph": "人", "name": "遠程型", "desc": "武器：彈道、\n迴旋刃、火砲\nShift：衝刺六格\n衝刺中與結束後\n1 秒無敵"},
	{"glyph": "刀", "name": "近戰型", "desc": "武器：刀法、\n斬擊波、影分身\nShift：跳五格\n落地震殺周圍敵人"},
]

enum State { SELECT, PLAYING, LEVEL_UP, DEAD, WON, POWER_UP, PAUSED, META }


class Bullet:
	var node: Glyph
	var vel: Vector2
	var life: float
	var pierce: int                 # 還能再穿過幾個敵人
	var damage: float
	var hits: Array = []            # 已經打過的敵人，穿透時不重複打


## 人＋砲：飛行中的砲彈
class Shell:
	var node: Glyph
	var vel: Vector2
	var traveled := 0.0
	var max_dist := 0.0
	var radius := 0.0           # 爆炸半徑
	var damage := 0.0
	var big := false            # Lv5 中間那發巨砲：不撞敵人、不撞牆，飛到定點才爆炸


## 刀＋影：影分身
class Shade:
	var node: Glyph
	var cd := 0.0               # 揮刀冷卻
	var wave_cd := 0.0          # Lv5：自己的斬擊波冷卻
	var slot := 0               # 第幾個分身（決定站位）


class Chest:
	var node: Glyph


## 刀＋彈：飛行中的斬擊波
class Wave:
	var scale := 1.0            # 傷害倍率（影分身射的）
	var node: WaveFx
	var dir: Vector2
	var big := false
	var reach := 0.0
	var speed := 0.0
	var traveled := 0.0
	var hits := {}              # 已經打過的敵人
	var pierce := WAVE_PIERCE   # 還能再穿過幾個


## 殘留在地上的斬擊（殘影斬、空間斬擊）：每 0.5 秒對範圍內的敵人造成一次傷害
class Zone:
	var scale := 1.0            # 傷害倍率（影分身的殘影）
	var origin: Vector2
	var facing: float
	var arc: float
	var reach: float
	var life: float
	var tick: float
	var check_walls: bool
	var cuts_arrows: bool       # 殘影斬：殘留期間飛進來的矢也會被砍掉


## 跟著滑鼠的天罰範圍圈；冷卻中變暗
class SmiteRing:
	extends Node2D
	var radius := 108.0
	var armed := true

	func _draw() -> void:
		var c := Color(0.75, 0.9, 1.0, 0.5 if armed else 0.15)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, c, 2.0)


## 會淡出的文字特效（斬擊、殘影、落地衝擊）
class Fx:
	var nodes: Array[Glyph] = []
	var life: float
	var duration: float


static var last_character := 0      # 重開時記得上次選的角色
static var difficulty := 1          # 難度：0 簡單、1 普通、2 困難（重開會記得）
static var touch_mode := -1          # 操作模式：-1 還沒決定（開局自動偵測）、0 電腦、1 手機

var state := State.SELECT
var character := 0
var elapsed := 0.0
var kills := 0
var kills_by_kind := {}              # 每種敵人各打倒幾隻（結算畫面用）
var gold := 0
var hp := PLAYER_MAX_HP
var level := 1
var xp := 0                        # 這一級已經吃到的金
var pending_levels := 0            # 一次吃很多金時，可能連升好幾級
var pending_power := 0             # 還沒選的寶箱強化
var power_choices: Array = []      # 寶箱卡片上的選項（"彈" / "刀"）
var power_cursor := 0
var bullet_lv := 1                 # 強化線「彈」
var blade_lv := 1                  # 強化線「刀」
var cannon_lv := 0                 # 強化線「砲」（只有人有，從 Lv0 開始）
var shadow_lv := 0                 # 強化線「影」（只有刀有，從 Lv0 開始）
var revives := 0                   # 還有幾次蘇生（寶箱「蘇」卡）
var shades: Array[Shade] = []      # 影分身
## 刀的攻擊從哪裡出、傷害倍率多少：平常是主角本人，影分身出手時暫時換成分身的位置
var atk_from := Vector2.ZERO
var atk_scale := 1.0
var atk_color := Color.WHITE
var cannon_cd := 0.0
var shells: Array[Shell] = []
var combo: Array = []              # 刀＋刀：排好的後續連擊
var zones: Array[Zone] = []
var wave_cd := 0.0
var wave_queue: Array = []         # 刀＋彈 Lv4：排好的四連發
var orbit_angle := 0.0
var orbit_blades: Array[Glyph] = []
var orbit_hits := {}               # 敵人 id -> 上次被迴旋刃打到的時間
var orbit_clock := 0.0             # 疾旋的計時（0~5 秒正常，5~6 秒快速）
var burst_t := -1.0                # 爆旋進行中的時間，< 0 代表沒有在爆旋
var burst_done := false            # 這次爆旋是否已經爆炸過
var flying_blades: Array[Bullet] = []   # Lv5 飛刃
var waves: Array[Wave] = []
var upgrade_choices: Array = []    # 升級畫面上的三個選項
var upgrade_cursor := 0
var upgrade_levels := {}           # id -> 已經升了幾級

# 會被升級改變的數值
var attack_mult := 1.0
var damage_mult := 1.0
var bullet_pierce := 0
var slash_range := SLASH_RANGE
var player_speed := PLAYER_SPEED
var max_hp := PLAYER_MAX_HP
var regen_per_sec := 0.0             # 每秒自動回血（「體」）
var regen_acc := 0.0                 # 回血累積到 1 才真的加 1 點
var pickup_range := GOLD_PICKUP_RANGE
var skill_cooldown := SKILL_COOLDOWN
var invincible := 0.0
var attack_cd := 0.0
var spawn_cd := 0.0
var facing_dir := Vector2.RIGHT    # 最後一次移動的方向，技能往這裡放
var skill_charges := SKILL_MAX_CHARGES
var skill_recharge := 0.0
var skill_time := 0.0              # > 0 代表正在衝刺 / 跳躍中（無敵）
var skill_duration := 0.0
var skill_from := Vector2.ZERO
var skill_to := Vector2.ZERO
var land_grace := 0.0
var next_boss_time := BOSS_INTERVAL
var next_chest_time := CHEST_INTERVAL
var next_heal_time := HEAL_INTERVAL
var hearts: Array[HeartPickup] = []
var heart_pointer: HeartPickup      # 最近的愛心在畫面外時，畫面邊緣的提示
var final_phase := false           # 三分鐘後的決戰：還是會掉金，但不再出寶箱
var final_bosses: Array[Enemy] = []
var final_roster: Array[String] = []  # 決戰一開始有哪些王（照順序），血條用；死掉的從 final_bosses 拿掉
var smite_used := false            # 天罰一局只能用一次

var font: FontFile
var cam: Camera2D
var particles: TextParticles
var hurt_overlay: ColorRect         # 受傷時整個畫面閃紅
var shake := 0.0                    # 目前畫面震動強度（像素）
var hitstop := 0.0                  # 大招命中時畫面停頓一下
var terrain: Terrain
var player: Glyph
var enemies: Array[Enemy] = []
var bullets: Array[Bullet] = []
var arrows: Array[Bullet] = []      # 弓射出來的箭
var effects: Array[Fx] = []
var golds: Array[Glyph] = []
var chests: Array[Chest] = []
var chest_pointer: Glyph            # 寶箱在畫面外時，畫面邊緣的提示
var boss_pointers: Array[Glyph] = []  # 王在畫面外時，畫面邊緣的提示（一隻王一個）
var player_bar: Node2D              # 主角頭上的血條
var smite_ring: SmiteRing           # 滑鼠位置的天罰範圍圈
var grid := {}  # Vector2i -> Array[Enemy]

var hud_hp: Label
var hud_skill: Label
var hud_key_skill: Label            # 「技」下面的操作鍵說明
var hud_key_smite: Label            # 「天」下面的操作鍵說明
var hud_power: Label
var hud_time: Label
var hud_boss: Label                 # 決戰時上方的最終王血條
var hud_version: Label              # 選角畫面右下角的版本號
var hud_final_hint: Label           # 決戰開始時畫面中上方的「打倒全部最終王！」
var final_hint_time := 0.0          # 提示還要顯示幾秒
var final_intro := 0.0              # 最終決戰開場停頓還剩幾秒
var _intro_shown := 0               # 「最終決戰」已經出現幾個字
var celebrate := 0.0                # 過關煙火還剩幾秒
var firework_cd := 0.0
var big_banner: Label               # 畫面正中間的大字（最終決戰、過關）
var hud_kills: Label
var menu: Control                  # 選角 / 升級 / 結束畫面共用
var menu_label: Label
var level_cards: UpgradeCards       # 升級卡片畫面
var touch: TouchControls            # 手機觸控（虛擬搖桿、技/天按鍵）
var audio: GameAudio                # 音樂與音效
var pause_menu: PauseMenu           # 暫停畫面（音量設定）
var meta_menu: MetaMenu             # 鑽石升級畫面
var start_pick := false             # 開局選武器中（跟寶箱共用卡片畫面）
var rerolls_left := 0               # 這一局升級時還能重抽幾次
var tokens_earned := -1             # 這一局拿到幾個 鑽（結算時算一次）
var _ignore_click_frame := -1       # 點暫停畫面的「繼續」那一格，不要觸發天罰
var is_touch := false               # 有觸控螢幕就開手機操作
var rotate_hint: ColorRect          # 手機直拿時的「請轉橫」提示
var final_frame: Control            # 決戰時整個畫面外圍的一圈紅色「戰」


func _ready() -> void:
	font = _load_pixel_font()
	Glyph.font = font

	Meta.load_save()
	audio = GameAudio.new()
	add_child(audio)
	audio.play_music("main")
	audio._stream("res://audio/music_final.wav")   # 先載入決戰音樂，三分鐘時才不會卡

	terrain = Terrain.new()
	terrain.font = font
	terrain.font_size = GLYPH_SIZE
	add_child(terrain)

	character = last_character
	player = Glyph.new().setup(CHARACTERS[character].glyph, GLYPH_SIZE, COLOR_PLAYER)
	player.z_index = 10
	add_child(player)
	cam = Camera2D.new()
	player.add_child(cam)
	player_bar = Node2D.new()
	player_bar.draw.connect(_draw_player_bar)
	player.add_child(player_bar)

	particles = TextParticles.new()
	particles.z_index = 8
	add_child(particles)

	smite_ring = SmiteRing.new()
	smite_ring.radius = SMITE_RADIUS
	smite_ring.z_index = 15
	smite_ring.visible = false
	add_child(smite_ring)

	chest_pointer = Glyph.new().setup("寶", POINTER_SIZE, COLOR_CHEST)
	chest_pointer.modulate.a = 0.7
	chest_pointer.z_index = 20
	chest_pointer.visible = false
	add_child(chest_pointer)

	heart_pointer = HeartPickup.new()
	heart_pointer.pulse = false
	heart_pointer.scale = Vector2(0.7, 0.7)
	heart_pointer.modulate.a = 0.7
	heart_pointer.z_index = 20
	heart_pointer.visible = false
	add_child(heart_pointer)

	_setup_input()
	_build_hud()
	_build_screen_filter()
	terrain.follow(player.position)
	terrain.update_flow(player.position)
	_update_hud()
	_show_select()


func _process(delta: float) -> void:
	_update_feedback(delta)
	if Input.is_action_just_pressed("mute"):
		toggle_mute()
	match state:
		State.SELECT:
			_process_select()
			return
		State.LEVEL_UP:
			_process_level_up()
			return
		State.POWER_UP:
			_process_power_up()
			return
		State.DEAD, State.WON:
			if Input.is_action_just_pressed("confirm"):
				get_tree().reload_current_scene()
			return
		State.PAUSED:
			_process_pause()
			return
		State.META:
			_process_meta()
			return

	if Input.is_action_just_pressed("pause"):
		_set_paused(true)
		return

	# 最終決戰開場：全部停住 2 秒，畫面中間「最終決戰」
	if final_intro > 0.0:
		final_intro -= delta
		# 一個字一個字跳出來：最 → 最終 → 最終決 → 最終決戰，每個字出來時震一下
		var shown := clampi(int((FINAL_INTRO_TIME - final_intro) / INTRO_CHAR_GAP) + 1, 1, INTRO_TEXT.length())
		if shown != _intro_shown:
			_intro_shown = shown
			# 還沒出來的字用全形空白佔位，字的位置才不會跟著移動
			var chars := []
			for i in INTRO_TEXT.length():
				chars.append(INTRO_TEXT[i] if i < shown else "　")
			big_banner.text = " ".join(chars)   # 字中間用半形空白
			_shake(8.0)
			audio.play("land")
		if final_intro <= 0.0:
			big_banner.visible = false
		return
	# 打倒最終王：放 3 秒煙火再進結算
	if celebrate > 0.0:
		_update_celebration(delta)
		return

	if hitstop > 0.0:
		hitstop -= delta
		return

	elapsed += delta
	if regen_per_sec > 0.0 and hp < max_hp:
		regen_acc += regen_per_sec * delta
		if regen_acc >= 1.0:
			hp = mini(hp + int(regen_acc), max_hp)
			regen_acc -= floorf(regen_acc)
	final_hint_time = maxf(0.0, final_hint_time - delta)
	if not final_phase and elapsed >= GAME_DURATION:
		_start_final_phase()
	if final_phase and final_bosses.is_empty():
		_start_celebration()
		return

	if player.offset != Vector2.ZERO:
		player.offset = player.offset.move_toward(Vector2.ZERO, RECOIL_RECOVER * delta)
		player.queue_redraw()
	var old_cell := terrain.cell_of(player.position)
	if not _update_skill(delta):
		_move_player(delta)
	if terrain.cell_of(player.position) != old_cell:
		terrain.update_flow(player.position)
	_spawn_enemies(delta)
	_build_grid()
	_move_enemies(delta)
	_build_grid()
	_attack(delta)
	_move_bullets(delta)
	_move_waves(delta)
	_update_orbit(delta)
	_move_flying_blades(delta)
	_move_arrows(delta)
	_update_effects(delta)
	_update_gold(delta)
	_update_chests()
	_update_smite(delta)
	_check_player_hit(delta)

	terrain.follow(player.position)
	_update_hud()
	if state == State.PLAYING and pending_levels > 0:
		_open_level_up()
	elif state == State.PLAYING and pending_power > 0:
		_open_power_up()


func _load_pixel_font() -> FontFile:
	var f: FontFile = load("res://fonts/Cubic_11.ttf")
	# 關掉反鋸齒與次像素，像素字才會銳利
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	# 萬一有字不在字型裡，退回系統字型
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["PingFang TC", "Microsoft JhengHei", "Noto Sans CJK TC"])
	f.fallbacks = [fallback]
	return f


## 方向鍵和 WASD 都能移動
func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"skill": [KEY_SHIFT],
		"confirm": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],  # 選單確定：Space 左手就按得到，Enter 也可以
		"toggle_mode": [KEY_TAB],    # 選角畫面切換手機／電腦操作
		"reroll": [KEY_R],           # 升級時重抽
		"meta": [KEY_U],             # 選角畫面打開鑽石升級
		"meta_reset": [KEY_BACKSPACE],  # 鑽石升級：全部重置
		"pause": [KEY_ESCAPE],       # 遊戲中暫停／繼續
		"mute": [KEY_M],             # 靜音／取消靜音（任何時候都可以）
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("smite"):
		InputMap.add_action("smite")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("smite", click)


# ---------- 選角 ----------

func _process_select() -> void:
	if Input.is_action_just_pressed("meta"):
		open_meta()
		return
	if Input.is_action_just_pressed("toggle_mode"):
		toggle_touch_mode()
	if Input.is_action_just_pressed("move_up"):
		set_difficulty(difficulty - 1)
	elif Input.is_action_just_pressed("move_down"):
		set_difficulty(difficulty + 1)
	var step := 0
	if Input.is_action_just_pressed("move_left"):
		step = -1
	elif Input.is_action_just_pressed("move_right"):
		step = 1
	if step != 0:
		audio.play("ui_move")
		character = posmod(character + step, CHARACTERS.size())
		player.set_text(CHARACTERS[character].glyph)
		_show_select()
	if Input.is_action_just_pressed("confirm"):
		audio.play("ui_ok")
		last_character = character
		# 一開始沒有任何武器，進遊戲先選一個
		bullet_lv = 0
		blade_lv = 0
		level_cards.visible = false
		hud_version.visible = false
		state = State.PLAYING
		_apply_meta_start()
		_open_start_weapon()


## 開局選武器：這個角色的每一條武器線（都從 Lv0 → Lv1）選一個
func _open_start_weapon() -> void:
	start_pick = true
	power_choices = _lines()
	power_cursor = 0
	state = State.POWER_UP
	_show_power_up()


## 開局套用鑽石升級：一般升級先升好、重抽次數、開局寶箱
func _apply_meta_start() -> void:
	var who: String = CHARACTERS[character].glyph
	for u: Dictionary in UPGRADES:
		if u.who != "all" and u.who != who:
			continue
		var key: String = "up_" + u.id
		if u.id == "pierce" or u.id == "reach":
			key = "up_pierce_reach"   # 穿、廣共用同一項鑽石升級
		for i in Meta.level(key):
			_apply_upgrade(u.id)
	rerolls_left = Meta.rerolls()
	pending_power += Meta.level("chest")
	_update_hud()


# ---------- 鑽石升級 ----------

func open_meta() -> void:
	audio.play("ui_ok")
	meta_menu.reset_armed = false
	state = State.META
	level_cards.visible = false
	meta_menu.open(CHARACTERS[character].glyph, is_touch)


func close_meta() -> void:
	audio.play("ui_move")
	meta_menu.visible = false
	state = State.SELECT
	_show_select()


func _process_meta() -> void:
	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("meta"):
		close_meta()
		return
	var n := meta_menu.items().size()
	if Input.is_action_just_pressed("move_up"):
		meta_menu.cursor = posmod(meta_menu.cursor - 1, n)
		meta_menu.flash = ""
		meta_menu.reset_armed = false
		audio.play("ui_move")
	elif Input.is_action_just_pressed("move_down"):
		meta_menu.cursor = posmod(meta_menu.cursor + 1, n)
		meta_menu.flash = ""
		meta_menu.reset_armed = false
		audio.play("ui_move")
	elif Input.is_action_just_pressed("confirm"):
		_meta_buy()
	elif Input.is_action_just_pressed("meta_reset"):
		_meta_reset()
	meta_menu.queue_redraw()


## 全部重置：第一次按只是提醒，再按一次才真的退回全部 鑽
func _meta_reset() -> void:
	if not meta_menu.reset_armed:
		meta_menu.reset_armed = true
		meta_menu.flash = "再按一次確定重置，退回全部的鑽"
		audio.play("block")
	else:
		var back := Meta.refund_all()
		meta_menu.reset_armed = false
		meta_menu.flash = "已重置，退回 %d 個鑽" % back
		audio.play("chest")
	meta_menu.queue_redraw()


func _meta_buy() -> void:
	meta_menu.reset_armed = false
	var it: Dictionary = meta_menu.items()[meta_menu.cursor]
	var cost := Meta.next_cost(it)
	if cost < 0:
		meta_menu.flash = "已經滿級了"
	elif Meta.buy(it):
		audio.play("level")
		meta_menu.flash = "%s 升到 Lv%d" % [it.name, Meta.level(it.id)]
	else:
		audio.play("block")
		meta_menu.flash = "鑽不夠（需要 %d 個）" % cost
	meta_menu.queue_redraw()


## 手機／滑鼠點鑽石升級畫面：點一行選它，再點一次升級；點「返回」離開
func meta_tap(pos: Vector2) -> void:
	if meta_menu.back_at(pos):
		close_meta()
		return
	if meta_menu.reset_at(pos):
		_meta_reset()
		return
	var i := meta_menu.row_at(pos)
	if i < 0:
		return
	if i == meta_menu.cursor:
		_meta_buy()
	else:
		meta_menu.cursor = i
		meta_menu.flash = ""
		audio.play("ui_move")
		meta_menu.queue_redraw()


func _show_select() -> void:
	if hud_version != null:
		var ver: String = preload("res://version.gd").TEXT
		hud_version.text = ver if is_touch else "M 靜音　" + ver
	var cards := []
	for c: Dictionary in CHARACTERS:
		var desc: String = c.desc.replace("Shift", "技") if is_touch else c.desc
		cards.append({"icon": c.glyph, "name": c.name, "sub": "", "desc": desc})
	var names := DIFFICULTIES.map(func(d: Dictionary) -> String: return d.name)
	var descs := DIFFICULTIES.map(func(d: Dictionary) -> String: return d.desc)
	if is_touch:
		level_cards.show_cards("選擇角色", cards, character, "點卡片選擇，再點一次開始",
				"操作模式：手機　（點這裡切換成電腦）", TUTORIAL_TIPS_TOUCH, "鑽石升級　鑽 %d" % Meta.tokens)
		level_cards.set_options("難度", names, difficulty, "點選", descs)
	else:
		level_cards.show_cards("選擇角色", cards, character, "A D / ←→ 選角色　W S / ↑↓ 選難度　Space / Enter 開始　U 鑽石升級",
				"操作模式：電腦　（按 Tab 或點這裡切換成手機）", TUTORIAL_TIPS, "鑽石升級　鑽 %d" % Meta.tokens)
		level_cards.set_options("難度", names, difficulty, "W S / ↑↓", descs)


## 難度：hp = 怪物血量倍率、count = 怪物數量倍率、speed = 移動速度倍率、banned = 不會出現的怪
const DIFFICULTIES := [
	{"name": "簡單", "hp": 0.5, "count": 0.5, "speed": 0.7, "banned": ["鳥", "冑", "弩", "魂", "鬼", "犇"],
		"desc": "怪物血量、數量減半，速度 70%，不會出現進階怪物"},
	{"name": "普通", "hp": 1.0, "count": 1.0, "speed": 1.0, "banned": [],
		"desc": "標準難度"},
	{"name": "困難", "hp": 1.5, "count": 1.2, "speed": 1.2, "banned": [],
		"desc": "怪物血量 +50%，數量、速度 +20%"},
]


func set_difficulty(i: int) -> void:
	var d := clampi(i, 0, DIFFICULTIES.size() - 1)
	if d != difficulty:
		audio.play("ui_move")
	difficulty = d
	_show_select()


## 選角畫面下面的操作教學（手機版）
const TUTORIAL_TIPS_TOUCH := [
	{"name": "移動", "key": "拖曳螢幕", "desc": "手指按住往哪拖\n就往哪走，\n攻擊全自動"},
	{"name": "技能", "key": "右下「技」", "desc": "人衝刺、刀跳躍，\n都會無敵。\n存兩次，5 秒回一次"},
	{"name": "天罰", "key": "右下「天」", "desc": "一局只能用一次，\n清空全地圖的小兵"},
	{"name": "選卡片", "key": "點卡片", "desc": "點一下選擇，\n再點一次選好的\n卡片確定"},
]

## 選角畫面下面的操作教學
const TUTORIAL_TIPS := [
	{"name": "移動", "key": "WASD / ↑↓←→", "desc": "攻擊全自動，\n只要專心走位、\n撿「金」升級"},
	{"name": "技能", "key": "Shift", "desc": "人衝刺、刀跳躍，\n都會無敵。\n存兩次，5 秒回一次"},
	{"name": "天罰", "key": "滑鼠左鍵", "desc": "一局只能用一次，\n清空全地圖的小兵"},
	{"name": "選卡片", "key": "A D / ←→", "desc": "升級、開寶箱時\n左右選，\n按 Space / Enter 確定"},
]


func _check_orientation() -> void:
	var win := DisplayServer.window_get_size()
	rotate_hint.visible = is_touch and win.y > win.x


## 暫停／繼續：整個遊戲停住（連飛散的字、斬擊特效也停），畫面蓋一層「暫停」
func _set_paused(on: bool) -> void:
	state = State.PAUSED if on else State.PLAYING
	audio.play("pause")
	for child in get_children():
		if child is TextParticles or child is SlashFx:
			child.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		pause_menu.open(is_touch)
	else:
		pause_menu.visible = false
	if touch != null:
		touch.refresh()


## 暫停畫面：W S 選、A D 調音量、Space / Enter 在「繼續」上確定、Esc 直接繼續
func _process_pause() -> void:
	if Input.is_action_just_pressed("pause"):
		_set_paused(false)
		return
	var row := pause_menu.cursor
	if Input.is_action_just_pressed("move_up"):
		pause_menu.cursor = posmod(row - 1, PauseMenu.ROW_COUNT)
		audio.play("ui_move")
	elif Input.is_action_just_pressed("move_down"):
		pause_menu.cursor = posmod(row + 1, PauseMenu.ROW_COUNT)
		audio.play("ui_move")
	elif row < 2 and Input.is_action_just_pressed("move_left"):
		_change_volume("music" if row == 0 else "sfx", -1)
	elif row < 2 and Input.is_action_just_pressed("move_right"):
		_change_volume("music" if row == 0 else "sfx", 1)
	elif row == 2 and Input.is_action_just_pressed("confirm"):
		_set_paused(false)
		return
	elif row == 3 and Input.is_action_just_pressed("confirm"):
		_back_to_select()
		return
	pause_menu.queue_redraw()


func _change_volume(which: String, delta: int) -> void:
	GameAudio.change_level(which, delta)
	audio.play("gold" if which == "sfx" else "ui_move")   # 調音效時播一聲，聽得出大小
	pause_menu.queue_redraw()


## 放棄這一局，回到選角畫面（角色、難度、音量都會記得）
func _back_to_select() -> void:
	audio.play("ui_ok")
	get_tree().reload_current_scene()


## 手機點暫停畫面
func pause_tap(pos: Vector2) -> void:
	var key := pause_menu.button_at(pos)
	match key:
		"music-": pause_menu.cursor = 0; _change_volume("music", -1)
		"music+": pause_menu.cursor = 0; _change_volume("music", 1)
		"sfx-": pause_menu.cursor = 1; _change_volume("sfx", -1)
		"sfx+": pause_menu.cursor = 1; _change_volume("sfx", 1)
		"menu":
			_back_to_select()
		"resume":
			_set_paused(false)
			_ignore_click_frame = Engine.get_process_frames()   # 這一下點擊不要當成天罰


## 靜音切換（M 鍵、手機的「音」按鍵）
func toggle_mute() -> void:
	GameAudio.toggle_mute()
	if touch != null:
		touch.refresh()


## 卡片畫面下面的操作提示
func _pick_hint() -> String:
	return "點卡片選擇，再點一次確定" if is_touch else "A D / ←→ 選擇　Space / Enter 確定"


## 手機模式：畫面基準解析度減半，所有東西（字、卡片、地圖）看起來放大一倍
## （看得到的範圍也跟著變小一半）
func _apply_screen_scale() -> void:
	var base := Vector2i(1280, 720) if is_touch else Vector2i(2560, 1440)
	get_window().content_scale_size = base
	# 手機畫面比較窄，時間／決戰那行放到第二排，才不會跟左邊的血條疊在一起
	if hud_time != null:
		hud_time.position.y = 70 if is_touch else 16
	if hud_boss != null:
		# 手機畫面比較窄：血條用小一號的字，放在決戰那行下面
		hud_boss.position.y = 116 if is_touch else 62
		hud_boss.add_theme_font_size_override("font_size", 22 if is_touch else 33)
	if hud_final_hint != null:
		# 手機畫面上方太擠：提示改小一點、放到主角下面
		hud_final_hint.anchor_top = 0.62 if is_touch else 0.0
		hud_final_hint.anchor_bottom = 0.82 if is_touch else 0.5
		hud_final_hint.offset_top = 0
		hud_final_hint.offset_bottom = 0
		hud_final_hint.add_theme_font_size_override("font_size", 44 if is_touch else 66)
	if terrain != null:
		terrain.queue_redraw()


## 選角畫面切換手機／電腦操作，重開後也會記得
func toggle_touch_mode() -> void:
	is_touch = not is_touch
	touch_mode = 1 if is_touch else 0
	_apply_screen_scale()
	hud_key_skill.visible = not is_touch
	hud_key_smite.visible = not is_touch
	if rotate_hint != null:
		_check_orientation()
	_show_select()


func is_playing() -> bool:
	return state == State.PLAYING


## 手機點了第 i 張卡片（還沒確定，只是選它）
func touch_select(i: int) -> void:
	audio.play("ui_move")
	match state:
		State.SELECT:
			character = i
			player.set_text(CHARACTERS[character].glyph)
			_show_select()
		State.LEVEL_UP:
			upgrade_cursor = i
			_show_level_up()
		State.POWER_UP:
			power_cursor = i
			_show_power_up()


# ---------- 玩家 ----------

## 移動方向：鍵盤，或手機的虛擬搖桿
func _input_dir() -> Vector2:
	if touch != null and touch.move != Vector2.ZERO:
		return touch.move
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _move_player(delta: float) -> void:
	var dir := _input_dir()
	if dir != Vector2.ZERO:
		facing_dir = dir.normalized()
	player.position = terrain.slide(player.position, dir * player_speed * delta, PLAYER_RADIUS)


func _check_player_hit(delta: float) -> void:
	if land_grace > 0.0:
		land_grace -= delta
		# 衝刺後的無敵也閃爍，讓玩家知道還在無敵
		if invincible <= 0.0:
			player.modulate.a = 0.5 if int(land_grace * 10.0) % 2 == 0 else 1.0
			if land_grace <= 0.0:
				player.modulate.a = 1.0
	if invincible > 0.0:
		invincible -= delta
		# 無敵期間閃爍
		player.modulate.a = 0.3 if int(invincible * 10.0) % 2 == 0 else 1.0
		if invincible <= 0.0:
			player.modulate.a = 1.0
	if not _player_vulnerable():
		return
	for e: Enemy in _nearby(player.position):
		if e.position.distance_to(player.position) < PLAYER_RADIUS + e.radius:
			e.stun = ATTACK_PAUSE   # 攻擊成功的敵人原地停一下，玩家才甩得掉（例如很快的鳥）
			_hurt_player(e.damage)
			return


## 技能中、落地後、剛被打過都不會受傷
func _player_vulnerable() -> bool:
	return skill_time <= 0.0 and land_grace <= 0.0 and invincible <= 0.0


func _hurt_player(amount: int) -> void:
	if not _player_vulnerable():
		return
	audio.play("hurt")
	hp -= amount
	invincible = INVINCIBLE_TIME
	_shake(10.0)
	_hitstop(0.06)
	hurt_overlay.color = Color(1, 0, 0, 0.3)
	if hp <= 0:
		hp = 0
		if revives > 0:
			_revive()
		else:
			_end(State.DEAD)


## 蘇生：用掉一次，回到 25 血、3 秒無敵，大大的「蘇」字，把身邊的敵人推開
func _revive() -> void:
	revives -= 1
	hp = mini(REVIVE_HP, max_hp)
	invincible = REVIVE_INVINCIBLE
	audio.play("level")
	hurt_overlay.color = Color(1, 1, 1, 0.35)
	var p := particles.add("蘇", player.position + Vector2(0, -40), Vector2(0, -30), 1.2, 132, Color(1.0, 0.9, 0.5))
	p.grow = 0.5
	for e: Enemy in _nearby_radius(player.position, 160.0):
		var to := e.position - player.position
		e.knock += to.normalized() * 600.0 * e.knock_resist
	_shake(12.0)
	_update_hud()


# ---------- Shift 技能 ----------

## 處理充能、施放與進行中的技能。技能進行中回傳 true（這幀不吃移動輸入）
func _update_skill(delta: float) -> bool:
	if skill_charges < SKILL_MAX_CHARGES:
		skill_recharge -= delta
		if skill_recharge <= 0.0:
			skill_charges += 1
			skill_recharge = skill_cooldown if skill_charges < SKILL_MAX_CHARGES else 0.0

	if skill_time > 0.0:
		_step_skill(delta)
		return true

	if Input.is_action_just_pressed("skill") and skill_charges > 0:
		if skill_charges == SKILL_MAX_CHARGES:
			skill_recharge = skill_cooldown
		skill_charges -= 1
		_start_skill()
		return true
	return false


func _start_skill() -> void:
	var dir := _input_dir()
	if dir != Vector2.ZERO:
		facing_dir = dir.normalized()
	skill_from = player.position
	if _is_blade():
		# 刀用跳的，可以跳過牆；落點在牆裡就往回找空地
		skill_duration = JUMP_TIME
		skill_to = skill_from + facing_dir * JUMP_DISTANCE
		while skill_to.distance_to(skill_from) > 1.0 and terrain.overlaps_wall(skill_to, PLAYER_RADIUS):
			skill_to = skill_to.move_toward(skill_from, 6.0)
	else:
		# 人是貼地衝刺，會被牆擋下
		skill_duration = DASH_TIME
		skill_to = skill_from + facing_dir * DASH_DISTANCE
	skill_time = skill_duration
	invincible = 0.0
	player.modulate.a = 1.0
	audio.play("jump" if _is_blade() else "dash")


func _step_skill(delta: float) -> void:
	var prev := player.position
	skill_time = maxf(skill_time - delta, 0.0)
	var t := 1.0 - skill_time / skill_duration

	if _is_blade():
		player.position = skill_from.lerp(skill_to, t)
		player.scale = Vector2.ONE * (1.0 + 0.6 * sin(t * PI))  # 跳起來變大，看起來離地
		if skill_time <= 0.0:
			player.scale = Vector2.ONE
			_land()
	else:
		# 分小步移動，避免一幀走太遠穿牆
		var target := skill_from.lerp(skill_to, t)
		var motion := target - prev
		var steps := int(ceil(motion.length() / 8.0))
		for i in steps:
			player.position = terrain.slide(player.position, motion / steps, PLAYER_RADIUS)
		# 殘影
		var fx := Fx.new()
		fx.nodes.append(_fx_glyph("人", prev, GLYPH_SIZE))
		_add_fx(fx, 0.2)
		if skill_time <= 0.0:
			land_grace = LAND_GRACE + DASH_EXTRA_GRACE


## 刀落地：三格內的敵人瞬殺（王只吃重傷害）
func _land() -> void:
	audio.play("land")
	land_grace = LAND_GRACE
	_land_at(player.position)
	# 影 Lv5：分身也跟著落地震
	if shadow_lv >= 5:
		for sh in shades:
			_push_atk(sh.node.position, 1.0, SHADE_FX_COLOR)
			_land_at(sh.node.position)
			_pop_atk()
	_shake(8.0)
	_hitstop(0.05)


func _land_at(origin: Vector2) -> void:
	for e: Enemy in enemies.duplicate():
		if e.position.distance_to(origin) > JUMP_LAND_RANGE + e.radius:
			continue
		if e.is_boss:
			_damage_enemy(e, _damage() * BOSS_LAND_MULT)
		elif not _block_hit(e):   # 魂、鬼的無敵也擋得住落地
			_kill_enemy(e)
	var fx := Fx.new()
	var count := 12   # 範圍變大，「震」也多幾個才不會太稀
	for i in count:
		var a := TAU * i / count
		fx.nodes.append(_fx_glyph("震", origin + Vector2.from_angle(a) * JUMP_LAND_RANGE * 0.8))
	_add_fx(fx, 0.25)


func _is_blade() -> bool:
	return CHARACTERS[character].glyph == "刀"


# ---------- 決戰 ----------

## 三分鐘到：出現最終王（兩隻王、一隻「大」字王），打倒全部才算贏；之後還是會掉金，但不再出寶箱
func _start_final_phase() -> void:
	final_phase = true
	audio.play("final")
	audio.play_music("final")
	var bigs := BIG_KINDS.filter(func(k: String) -> bool: return not DIFFICULTIES[difficulty].banned.has(k))
	var total := FINAL_KINGS + 1
	for i in total:
		var pos := _find_spawn_point()
		if pos == Vector2.INF:
			pos = player.position + Vector2.from_angle(TAU * i / total) * get_viewport_rect().size.x * 0.55
		var big := i == total - 1
		var boss := _spawn_boss(bigs.pick_random() if big else _pick_boss_type(), pos, big)
		boss.font_size = int(roundf(boss.font_size * FINAL_SIZE_MULT / 11.0)) * 11
		boss.radius *= FINAL_SIZE_MULT
		boss.max_hp *= FINAL_HP_MULT
		boss.hp = boss.max_hp
		boss.speed *= FINAL_SPEED_MULT
		boss.knock_resist = 0.0   # 完全不吃擊退
		boss.shoot_interval /= FINAL_FIRE_RATE_MULT
		boss.arrow_speed *= FINAL_ARROW_SPEED_MULT
		boss.shoot_cd = minf(boss.shoot_cd, boss.shoot_interval)
		boss.queue_redraw()
		final_bosses.append(boss)
		final_roster.append(boss.label)
	# 停 2 秒，畫面中間大大的「最終決戰」（也順便蓋掉生成最終王的卡頓）
	final_intro = FINAL_INTRO_TIME
	_intro_shown = 0
	_show_big_banner("", COLOR_ENEMY_BOSS)
	_shake(12.0)
	final_hint_time = FINAL_HINT_TIME


# ---------- 敵人 ----------

func _spawn_enemies(delta: float) -> void:
	# 每分鐘來一隻王
	if not final_phase and elapsed >= next_boss_time and next_boss_time < GAME_DURATION:
		next_boss_time += BOSS_INTERVAL
		var bp := _find_spawn_point()
		if bp != Vector2.INF:
			_spawn_boss(_pick_boss_type(), bp, false)
			audio.play("boss")

	spawn_cd -= delta
	if spawn_cd > 0.0:
		return
	spawn_cd = lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_END, minf(elapsed / GAME_DURATION, 1.0))
	spawn_cd /= DIFFICULTIES[difficulty].count   # 數量多 = 生得快
	var pos := _find_spawn_point()
	if pos == Vector2.INF:
		return
	var kind := _pick_enemy_type()
	if kind == "鼠" or kind == "鳥":
		for i in (RAT_GROUP if kind == "鼠" else BIRD_GROUP):
			var p := pos + Vector2(randf_range(-12, 12), randf_range(-12, 12))
			if terrain.overlaps_wall(p, ENEMY_TYPES[kind]["radius"]):
				p = pos
			_spawn_enemy(kind, p)
	else:
		_spawn_enemy(kind, pos)


## 找一個不是牆、而且走得到玩家的格子，回傳格子正中間
## （生在格子邊緣的話，字的身體會卡進隔壁的牆）
func _find_spawn_point() -> Vector2:
	# 在畫面邊緣外一圈的隨機位置（長方形的周長上），不管畫面多大都剛好在看不到的地方
	var half := get_viewport_rect().size / 2.0 + Vector2(SPAWN_MARGIN, SPAWN_MARGIN)
	for i in 12:
		var p: Vector2
		var along := randf() * (half.x + half.y) * 2.0
		if along < half.x * 2.0:
			p = Vector2(along - half.x, half.y * (1.0 if randf() < 0.5 else -1.0))
		else:
			p = Vector2(half.x * (1.0 if randf() < 0.5 else -1.0), along - half.x * 2.0 - half.y)
		var c := terrain.cell_of(player.position + p)
		if terrain.flow_distance(c) >= 0:
			return terrain.cell_center(c)
	return Vector2.INF


## 生一隻王：kind 種敵人的大字版，行為一樣、但會穿牆。big = 決戰的「大」字王（血 +50%、各有特殊技）
func _spawn_boss(kind: String, pos: Vector2, big: bool) -> Enemy:
	var t: Dictionary = ENEMY_TYPES[kind].duplicate()
	t["hp"] = BOSS_HP_BASE * sqrt(t["hp"] / 15.0) * (BIG_HP_MULT if big else 1.0)   # 開根號：差距不會太大
	t["speed"] = t["speed"] * BOSS_SPEED_MULT
	var tweak: float = BOSS_TWEAK.get(kind, 1.0)
	t["hp"] = t["hp"] * tweak
	t["speed"] = t["speed"] * tweak
	t["size"] = BIG_SIZE if big else BOSS_SIZE
	t["radius"] = BIG_RADIUS if big else BOSS_RADIUS
	t["damage"] = BOSS_DAMAGE
	t["gold"] = 0 if big else BOSS_GOLD
	t["ignores_walls"] = true
	t["knock_resist"] = BOSS_KNOCK_RESIST
	t["boss"] = true
	t["wobble"] = false   # 王不亂飄
	if t.get("shield", 0) > 0:
		t["shield_every"] = BIG_SHIELD_EVERY if big else BOSS_SHIELD_EVERY
		if big and kind == "魂":
			t["aura"] = true
	if big:
		match kind:
			"弓":
				t["volley"] = 5
				t["shoot_range"] = 600.0
			"弩":
				t["burst"] = 5
				t["shoot_range"] = 600.0
			"犇":
				t["dashes"] = 2
	var e := Enemy.new().setup_type(kind, t, _hp_mult())
	e.speed *= DIFFICULTIES[difficulty].speed
	e.label = ("大" + kind) if big else kind
	e.set_text(e.label)
	e.position = pos
	e.z_index = 3
	e.shoot_interval = ARROW_INTERVAL
	e.arrow_speed = ARROW_SPEED
	e.shoot_cd = randf() * ARROW_INTERVAL
	add_child(e)
	enemies.append(e)
	return e


## 王是哪一種：跟小兵一樣抽，但兩分鐘以後（第二隻王、決戰）不會是最普通的「敵」
func _pick_boss_type() -> String:
	var kind := _pick_enemy_type()
	if elapsed >= BOSS_INTERVAL * 2.0 - 1.0:
		for i in 50:
			if kind != "敵":
				break
			kind = _pick_enemy_type()
	return kind


## 越後面出現的種類越多
func _pick_enemy_type() -> String:
	var weights := {"敵": 60.0}
	if elapsed > 20.0:
		weights["鼠"] = 20.0
	if elapsed > 45.0:
		weights["甲"] = 15.0
	if elapsed > 75.0:
		weights["弓"] = 15.0
	if elapsed > 60.0:
		weights["鳥"] = 12.0
	if elapsed > 100.0:
		weights["冑"] = 10.0
	if elapsed > 120.0:
		weights["弩"] = 10.0
	if elapsed > 50.0:
		weights["魂"] = 10.0
	if elapsed > 110.0:
		weights["鬼"] = 8.0
	if elapsed > 65.0:
		weights["牛"] = 8.0
	if elapsed > 130.0:
		weights["犇"] = 6.0
	for k: String in DIFFICULTIES[difficulty].banned:
		weights.erase(k)
	var total := 0.0
	for k: String in weights:
		total += weights[k]
	var r := randf() * total
	for k: String in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "敵"


## 怪物血量倍率：隨時間成長 × 難度
func _hp_mult() -> float:
	return (1.0 + HP_GROWTH_PER_MINUTE * floorf(elapsed / 60.0)) * DIFFICULTIES[difficulty].hp


func _spawn_enemy(kind: String, pos: Vector2) -> void:
	var e := Enemy.new().setup_type(kind, ENEMY_TYPES[kind], _hp_mult())
	e.speed *= DIFFICULTIES[difficulty].speed
	e.position = pos
	e.z_index = 3 if ENEMY_TYPES[kind].get("boss", false) else 2
	e.shoot_interval = ARROW_INTERVAL
	e.arrow_speed = ARROW_SPEED
	e.shoot_cd = randf() * ARROW_INTERVAL
	add_child(e)
	enemies.append(e)


func _move_enemies(delta: float) -> void:
	for e: Enemy in enemies:
		e.tick(delta)
		if e.invuln > 0.0:
			e.invuln -= delta
		# 王魂、王鬼、大魂、大鬼：定時把無敵次數補滿
		if e.shield_every > 0.0:
			e.shield_t -= delta
			if e.shield_t <= 0.0:
				e.shield_t = e.shield_every
				e.refill_shield()
				if e.aura:
					_soul_aura(e)
		# 大弩：連射中，一發接一發
		if e.burst_left > 0:
			e.burst_cd -= delta
			if e.burst_cd <= 0.0:
				e.burst_left -= 1
				e.burst_cd = BURST_GAP
				_shoot_arrow(e)
		var to_player := player.position - e.position
		var vel: Vector2
		if e.ignores_walls:
			vel = to_player.normalized() * e.speed
			if e.wobble:
				# 魂、鬼：往玩家飄，同時左右亂晃
				vel += to_player.normalized().orthogonal() * e.sway() * e.speed * WOBBLE_AMOUNT
		else:
			# 照尋路結果走，會繞過牆
			vel = terrain.flow_direction(e.position, player.position) * e.speed
		# 弓：夠近又看得到你，就停下來放箭
		if e.ranged:
			e.shoot_cd -= delta
			if to_player.length() < e.shoot_range and _line_clear(e.position, player.position):
				vel = Vector2.ZERO
				if e.shoot_cd <= 0.0:
					e.shoot_cd = e.shoot_interval
					if e.burst > 1:
						e.burst_left = e.burst
						e.burst_cd = 0.0
					else:
						_shoot_arrow(e)
		# 牛、犇：蓄力 → 衝刺 → 喘一下
		if e.charger:
			vel = _charge_step(e, vel, to_player, delta)
		# 剛攻擊成功：原地停頓（還是會被推開、擊退）
		if e.stun > 0.0:
			e.stun -= delta
			vel = Vector2.ZERO
		# 互相推開，避免全部疊在同一點
		var push := Vector2.ZERO
		for o: Enemy in _nearby(e.position):
			if o == e:
				continue
			var d := e.position - o.position
			var dist := d.length()
			var want := e.radius + o.radius + ENEMY_GAP
			if dist > 0.0 and dist < want:
				push += d / dist * (want - dist)
		var motion := (vel + push * 5.0 + e.knock) * delta
		e.knock = e.knock.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
		if e.ignores_walls:
			e.position += motion
		else:
			var before := e.position
			e.position = terrain.slide(e.position, motion, e.radius)
			# 衝刺撞到牆就停下來
			if e.charger and e.charge_state == 2 and e.position.distance_to(before) < motion.length() * 0.3:
				_end_charge(e)


## 牛、犇的狀態：回傳這一幀的移動速度
func _charge_step(e: Enemy, vel: Vector2, to_player: Vector2, delta: float) -> Vector2:
	match e.charge_state:
		0:
			e.charge_cd -= delta
			if e.charge_cd <= 0.0 and to_player.length() < CHARGE_RANGE and _line_clear(e.position, player.position):
				# 開始蓄力：記住玩家現在的位置，之後就衝這裡
				e.charge_state = 1
				e.charge_t = CHARGE_WINDUP
				e.dashes_left = e.dashes
				e.charge_target = player.position
				e.knock = Vector2.ZERO
				if e.blaster:
					_enemy_blast(e)
				e.queue_redraw()
			return vel
		1:
			var before := e.charge_t
			e.charge_t -= delta
			# 像鬥牛：原地踩兩下（抬起來、重重踩下），然後才衝
			var k := 1.0 - e.charge_t / CHARGE_WINDUP   # 0 → 1
			var hop := 0.0
			for st in STOMP_TIMES:
				var d: float = (k - st) / STOMP_LEN
				if d > -1.0 and d < 0.0:
					hop = maxf(hop, sin((d + 1.0) * PI))   # 抬腳
			e.offset = Vector2(0, -STOMP_HEIGHT * hop)
			for st in STOMP_TIMES:
				var t_hit: float = CHARGE_WINDUP * (1.0 - st)
				if before > t_hit and e.charge_t <= t_hit:
					_stomp_dust(e)
			e.queue_redraw()
			if e.charge_t <= 0.0:
				e.charge_state = 2
				e.offset = Vector2.ZERO
				var to := e.charge_target - e.position
				e.charge_left = to.length() + CHARGE_OVERSHOOT
				e.charge_target = to.normalized()   # 衝刺時改存方向
				e.queue_redraw()
			return Vector2.ZERO
		2:
			e.knock = Vector2.ZERO   # 衝刺中不吃擊退
			var step := CHARGE_SPEED * delta
			e.charge_left -= step
			if e.charge_left <= 0.0:
				_end_charge(e)
				return Vector2.ZERO
			return e.charge_target * CHARGE_SPEED
		_:
			e.charge_t -= delta
			if e.charge_t <= 0.0:
				e.charge_state = 0
				e.charge_cd = CHARGE_COOLDOWN
			return Vector2.ZERO


## 踩地：腳邊往後噴一點塵土
func _stomp_dust(e: Enemy) -> void:
	var back := (e.position - e.charge_target).normalized()
	for i in 4:
		var dir := back.rotated(randf_range(-0.8, 0.8))
		var p := particles.add("．", e.position + Vector2(0, e.radius * 0.6), dir * randf_range(60, 120),
				0.35, 22, Color(0.7, 0.6, 0.5))
		p.drag = 3.0
	_shake(1.5)


func _end_charge(e: Enemy) -> void:
	if e.blaster:
		_enemy_blast(e)
	# 大犇：還有下一衝的話，短暫蓄力（踩一下）後再衝向玩家現在的位置
	if e.dashes_left > 1:
		e.dashes_left -= 1
		e.charge_state = 1
		e.charge_t = CHARGE_WINDUP * 0.45
		e.charge_target = player.position
		return
	e.charge_state = 3
	e.charge_t = CHARGE_REST


## 犇的爆炸：一圈小「爆」，範圍內的玩家受傷
func _enemy_blast(e: Enemy) -> void:
	audio.play("explode")
	# 跟刀落地的「震」一樣：一圈字同時出現再淡掉（不是揮擊那種旋轉掃過去）
	var fx := Fx.new()
	var count := 10
	for i in count:
		var g := _fx_glyph("爆", e.position + Vector2.from_angle(TAU * i / count) * BLAST_RADIUS * 0.8)
		g.color = e.base_color
		fx.nodes.append(g)
	_add_fx(fx, 0.3)
	_shake(4.0)
	if player.position.distance_to(e.position) < BLAST_RADIUS + PLAYER_RADIUS:
		_hurt_player(BLAST_DAMAGE)


## 大魂：放出一圈半徑 3 格的無敵領域，裡面的敵人 1 秒內完全不受傷
func _soul_aura(src: Enemy) -> void:
	audio.play("block")
	for e: Enemy in _nearby_radius(src.position, AURA_RADIUS + 30.0):
		if e.position.distance_to(src.position) <= AURA_RADIUS + e.radius:
			e.invuln = AURA_TIME
	var fx := Fx.new()
	var count := 16
	for i in count:
		var g := _fx_glyph("護", src.position + Vector2.from_angle(TAU * i / count) * AURA_RADIUS)
		g.color = COLOR_AURA
		fx.nodes.append(g)
	_add_fx(fx, AURA_TIME)


## 放箭；volley > 1 時一次放一排扇形的箭（大弓）
func _shoot_arrow(e: Enemy) -> void:
	var dir := (player.position - e.position).normalized()
	for k in e.volley:
		var offset := 0.0 if e.volley == 1 else -VOLLEY_SPREAD / 2.0 + VOLLEY_SPREAD * k / (e.volley - 1)
		var b := Bullet.new()
		b.node = Glyph.new().setup("矢", BULLET_SIZE, COLOR_ARROW)
		b.node.position = e.position
		b.node.z_index = 4
		b.vel = dir.rotated(offset) * e.arrow_speed
		b.life = ARROW_LIFETIME
		b.damage = ARROW_DAMAGE
		add_child(b.node)
		arrows.append(b)


func _move_arrows(delta: float) -> void:
	for i in range(arrows.size() - 1, -1, -1):
		var b := arrows[i]
		b.node.position += b.vel * delta
		b.life -= delta
		var done := b.life <= 0.0 or terrain.is_wall(terrain.cell_of(b.node.position))
		if not done and _player_vulnerable() and b.node.position.distance_to(player.position) < PLAYER_RADIUS + 6.0:
			_hurt_player(int(b.damage))
			done = true
		if done:
			b.node.queue_free()
			arrows.remove_at(i)


func _damage() -> float:
	return BASE_DAMAGE * damage_mult * atk_scale


## 打敵人：跳傷害數字、擊退，打死就碎開並掉落
func _damage_enemy(e: Enemy, amount: float, knock := Vector2.ZERO) -> void:
	if _block_hit(e):
		return
	audio.play("hit")
	var boss := e.is_boss
	var num := particles.add(str(int(round(amount))),
			e.position + Vector2(randf_range(-8, 8), -e.radius - 6.0),
			Vector2(randf_range(-20, 20), -70), 0.45, 33 if boss else 22, Color.WHITE)
	num.drag = 2.0
	if not (e.charger and e.charge_state == 2):   # 牛、犇衝刺中不吃擊退
		e.knock = (e.knock + knock * e.knock_resist).limit_length(KNOCK_MAX)
	if e.take_damage(amount):
		_kill_enemy(e)


## 魂、鬼還有無敵次數時，這次攻擊完全無效，跳一個「無效」
func _block_hit(e: Enemy) -> bool:
	if not e.block_hit():
		return false
	audio.play("block")
	var p := particles.add("無效", e.position + Vector2(0, -e.radius - 6.0),
			Vector2(randf_range(-20, 20), -60), 0.45, 22, e.base_color)
	p.drag = 2.0
	return true


## 死亡特效：字放大淡出，同時碎成幾個筆畫往外飛
func _shatter(e: Enemy) -> void:
	var boss := e.is_boss
	var pop := particles.add(e.label, e.position, Vector2.ZERO, 0.15, e.font_size, Color.WHITE)
	pop.grow = 4.0
	for i in (10 if boss else 4):
		var dir := Vector2.from_angle(randf() * TAU)
		var shard := particles.add(SHARDS.pick_random(), e.position + dir * 6.0,
				dir * randf_range(120, 240), randf_range(0.25, 0.4), 33 if boss else 22, e.base_color)
		shard.spin = randf_range(-12, 12)
		shard.drag = 3.0
	if boss:
		_shake(14.0)
		_hitstop(0.12)


func _kill_enemy(e: Enemy) -> void:
	if not enemies.has(e):
		return
	enemies.erase(e)
	final_bosses.erase(e)   # 決戰的王死了就從清單拿掉
	var key := e.kind
	if e.is_boss:
		key = e.label if e.label.begins_with("大") else "王"
	kills_by_kind[key] = kills_by_kind.get(key, 0) + 1
	audio.play("explode" if e.is_boss else "kill")
	var cell: Array = grid.get(_cell(e.position), [])
	cell.erase(e)
	_shatter(e)
	# 決戰中一樣掉金，但王不掉寶箱
	if e.is_boss and not final_phase:
		_spawn_chest_near(e.position)
	for i in e.gold:
		var spread := Vector2.ZERO if e.gold == 1 else Vector2(randf_range(-20, 20), randf_range(-20, 20))
		_drop_gold(e.position + spread)
	e.queue_free()
	kills += 1


# ---------- 攻擊 ----------

func _attack(delta: float) -> void:
	atk_from = player.position
	if _is_blade():
		_update_combo(delta)
		_update_zones(delta)
		_update_blade_shots(delta)
		_update_shades(delta)
	else:
		_update_cannon(delta)
	attack_cd -= delta
	if attack_cd > 0.0:
		return
	# 開局可能沒選這條：沒有刀法就不揮刀、沒有彈道就不開槍
	if (blade_lv if _is_blade() else bullet_lv) < 1:
		return
	if _is_blade():
		_slash()
	else:
		_fire()


func _fire() -> void:
	var target := _nearest_visible_enemy(AIM_RANGE)
	if target == null:
		return
	attack_cd = FIRE_INTERVAL * attack_mult
	audio.play("shoot")
	var dir := (target.position - player.position).normalized()
	var muzzle := player.position + dir * MUZZLE_DIST
	# 開槍動畫：主角往後一縮，槍口冒出「砰」
	player.offset = -dir * RECOIL
	player.queue_redraw()
	var flash := Fx.new()
	var bang := _fx_glyph("砰", muzzle, GLYPH_SIZE)
	bang.color = COLOR_BULLET
	flash.nodes.append(bang)
	_add_fx(flash, 0.12)

	# 彈道強化：Lv n 散射 2n-1 發，角度越來越廣
	var n := 2 * bullet_lv - 1
	var spread := deg_to_rad(SPREAD_DEG[bullet_lv - 1])
	for i in n:
		var offset := 0.0 if n == 1 else -spread / 2.0 + spread * i / (n - 1)
		var b := Bullet.new()
		b.node = Glyph.new().setup("＊", BULLET_SIZE, COLOR_BULLET)
		b.node.position = muzzle
		b.vel = dir.rotated(offset) * BULLET_SPEED
		b.life = BULLET_LIFETIME
		b.pierce = bullet_pierce
		b.damage = BULLET_DAMAGE * damage_mult
		add_child(b.node)
		bullets.append(b)


func _move_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		b.node.position += b.vel * delta
		b.life -= delta
		var done := terrain.is_wall(terrain.cell_of(b.node.position))  # 撞牆就消失
		for e: Enemy in _nearby(b.node.position):
			if b.hits.has(e):
				continue
			if e.position.distance_to(b.node.position) < BULLET_RADIUS + e.radius:
				b.hits.append(e)
				_damage_enemy(e, b.damage, b.vel.normalized() * KNOCK_BULLET)
				b.pierce -= 1
				if b.pierce < 0:
					done = true
				break
		if done or b.life <= 0.0:
			b.node.queue_free()
			bullets.remove_at(i)


# ---------- 人＋砲 ----------
## Lv1 一發，命中爆炸（爆炸只打一次，「爆」字留一下）　Lv2 範圍 ×2　Lv3 兩發　Lv4 範圍再 ×2
## Lv5 兩發中間再夾一發巨砲：飛 10 格後大爆炸（半徑 6 格、傷害 ×3）
func _update_cannon(delta: float) -> void:
	_move_shells(delta)
	if cannon_lv < 1:
		return
	cannon_cd -= delta
	if cannon_cd > 0.0:
		return
	var target := _nearest_visible_enemy(AIM_RANGE)
	if target == null:
		return
	cannon_cd = CANNON_INTERVAL * attack_mult
	audio.play("cannon")
	var dir := (target.position - player.position).normalized()
	var radius := CANNON_RADIUS * (2.0 if cannon_lv >= 2 else 1.0) * (2.0 if cannon_lv >= 4 else 1.0)
	var dmg := CANNON_DAMAGE * damage_mult * (1.0 + CANNON_PIERCE_BONUS * bullet_pierce)
	if cannon_lv >= 3:
		_launch_shell(dir.rotated(-CANNON_SPREAD / 2.0), radius, dmg, false)
		_launch_shell(dir.rotated(CANNON_SPREAD / 2.0), radius, dmg, false)
	else:
		_launch_shell(dir, radius, dmg, false)
	if cannon_lv >= 5:
		_launch_shell(dir, CANNON_BIG_RADIUS, dmg * CANNON_BIG_MULT, true)


func _launch_shell(dir: Vector2, radius: float, dmg: float, big: bool) -> void:
	var s := Shell.new()
	s.node = Glyph.new().setup("砲", 44 if big else BULLET_SIZE, COLOR_CANNON)
	s.node.position = player.position + dir * MUZZLE_DIST
	s.node.z_index = 4
	s.vel = dir * CANNON_SPEED * (0.8 if big else 1.0)
	s.max_dist = CANNON_BIG_DIST if big else CANNON_RANGE
	s.radius = radius
	s.damage = dmg
	s.big = big
	add_child(s.node)
	shells.append(s)


func _move_shells(delta: float) -> void:
	for i in range(shells.size() - 1, -1, -1):
		var s := shells[i]
		var step := s.vel * delta
		s.node.position += step
		s.traveled += step.length()
		var boom := s.traveled >= s.max_dist
		if not s.big and not boom:
			# 一般砲彈：撞到牆或敵人就爆
			boom = terrain.is_wall(terrain.cell_of(s.node.position))
			if not boom:
				for e: Enemy in _nearby(s.node.position):
					if e.position.distance_to(s.node.position) < BULLET_RADIUS + e.radius:
						boom = true
						break
		if boom:
			_explode(s.node.position, s.radius, s.damage, s.big)
			s.node.queue_free()
			shells.remove_at(i)


## 爆炸：範圍內的敵人各打一次、往外推；「爆」字一圈，留一下再淡掉
func _explode(pos: Vector2, radius: float, dmg: float, big: bool) -> void:
	audio.play("explode")
	for e: Enemy in _nearby_radius(pos, radius + 30.0):
		var to := e.position - pos
		if to.length() <= radius + e.radius:
			_damage_enemy(e, dmg, to.normalized() * KNOCK_SLASH)
	var fx := SlashFx.new().setup(randf() * TAU, TAU, radius, false)
	fx.glyph = "爆"
	fx.linger = EXPLOSION_LINGER
	fx.color = COLOR_CANNON
	fx.position = pos
	fx.z_index = 5
	add_child(fx)
	_shake(10.0 if big else 4.0)
	if big:
		_hitstop(0.05)


## 朝最近的敵人揮刀。刀法等級決定這一次攻擊是幾連擊、什麼形狀
##   Lv1 正常斬　Lv2 連斬　Lv3 三連斬　Lv4 雙刀連斬（剪刀合 → 開，共四刀）　Lv5 殘影斬（270°、殘留 0.5 秒）
func _slash() -> void:
	# 刀法 Lv3 以上能砍矢：有矢飛進斬擊範圍，就優先往矢砍（擋箭比打怪重要）
	var arrow := _incoming_arrow(slash_range) if blade_lv >= 3 else Vector2.INF
	if arrow != Vector2.INF:
		attack_cd = SLASH_INTERVAL * attack_mult
		_slash_at(arrow)
		return
	var target := _nearest_visible_enemy(slash_range + 14.0)
	if target == null:
		return
	attack_cd = SLASH_INTERVAL * attack_mult
	_slash_at(target.position)


## 斬擊範圍內、正在往主角飛過來的最近一支矢的位置；沒有就回傳 INF
func _incoming_arrow(reach: float) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for b in arrows:
		var to := player.position - b.node.position
		var d := to.length()
		if d > reach + 20.0 or b.vel.dot(to) <= 0.0:
			continue
		if d < best_d:
			best_d = d
			best = b.node.position
	return best


# ---------- 刀＋影 ----------
## Lv1 身後一個分身跟著揮刀（傷害 50%）　Lv2 兩個分身左右各一　Lv3 分身自己衝向附近的敵人
## Lv4 分身傷害 100%　Lv5 分身繼承本體的攻擊力與招式：刀法、斬擊波、落地震（範圍、攻速不繼承）

var _atk_stack: Array = []


## 暫時把「刀的攻擊從哪裡出」換成分身（用完一定要 _pop_atk）
func _push_atk(from: Vector2, scale: float, color: Color) -> void:
	_atk_stack.append([atk_from, atk_scale, atk_color])
	atk_from = from
	atk_scale = scale
	atk_color = color


func _pop_atk() -> void:
	var prev: Array = _atk_stack.pop_back()
	atk_from = prev[0]
	atk_scale = prev[1]
	atk_color = prev[2]


func _update_shades(delta: float) -> void:
	var want := 0 if shadow_lv < 1 else (1 if shadow_lv == 1 else 2)
	while shades.size() < want:
		var sh := Shade.new()
		sh.slot = shades.size()
		sh.node = Glyph.new().setup("刀", GLYPH_SIZE, SHADE_COLOR)
		sh.node.position = player.position
		sh.node.z_index = 9
		sh.cd = randf() * SLASH_INTERVAL
		add_child(sh.node)
		shades.append(sh)
	for sh in shades:
		_move_shade(sh, delta)
		_shade_attack(sh, delta)


## 分身的站位：Lv1 在身後；Lv2 以上左右各一
func _shade_slot_pos(sh: Shade) -> Vector2:
	var back := -facing_dir
	if shadow_lv <= 1:
		return player.position + back * SHADE_GAP
	var side := facing_dir.orthogonal() * (1.0 if sh.slot == 0 else -1.0)
	return player.position + side * SHADE_GAP + back * 12.0


func _move_shade(sh: Shade, delta: float) -> void:
	var goal := _shade_slot_pos(sh)
	if shadow_lv >= 3:
		# 自己找主角附近的敵人衝過去（不離開主角太遠）；兩個分身各找不同的敵人
		var near := _nearest_enemies(SHADE_LEASH, 2, true)
		if not near.is_empty():
			var t: Enemy = near[sh.slot % near.size()]
			goal = t.position - (t.position - sh.node.position).normalized() * (SLASH_RANGE * 0.6)
		sh.node.position = sh.node.position.move_toward(goal, SHADE_SPEED * delta)
	else:
		sh.node.position = sh.node.position.lerp(goal, minf(1.0, delta * 10.0))
	# 分身是影子：可以穿牆，但不會離主角太遠
	var off := sh.node.position - player.position
	if off.length() > SHADE_LEASH:
		sh.node.position = player.position + off.normalized() * SHADE_LEASH


func _shade_attack(sh: Shade, delta: float) -> void:
	var full := shadow_lv >= 5
	sh.cd -= delta
	if sh.cd <= 0.0:
		_push_atk(sh.node.position, 1.0, SHADE_FX_COLOR)
		var target := _nearest_visible_enemy(SLASH_RANGE + 14.0)
		if target != null:
			if full and blade_lv >= 1:
				# Lv5：繼承本體的攻擊力和招式（刀法連擊），但範圍、攻速用基本值
				sh.cd = SLASH_INTERVAL
				var keep := slash_range
				slash_range = SLASH_RANGE
				_slash_at(target.position)
				slash_range = keep
			else:
				# Lv1～4：單純一刀，用基本範圍和基本傷害
				sh.cd = SLASH_INTERVAL
				atk_scale = (SHADE_WEAK if shadow_lv < 4 else 1.0) / damage_mult
				audio.play("slash")
				var facing := (target.position - atk_from).angle()
				_hit_sector(atk_from, facing, SLASH_ARC, SLASH_RANGE, true, true)
				var fx := SlashFx.new().setup(facing, SLASH_ARC, SLASH_RANGE, false)
				fx.color = SHADE_FX_COLOR
				fx.position = atk_from
				fx.z_index = 5
				add_child(fx)
		_pop_atk()
	# Lv5：分身也有自己的斬擊波
	if full and bullet_lv >= 1:
		sh.wave_cd -= delta
		if sh.wave_cd <= 0.0:
			_push_atk(sh.node.position, 1.0, SHADE_FX_COLOR)
			if _fire_waves():
				sh.wave_cd = WAVE_INTERVAL   # 攻速不繼承
			_pop_atk()


## 照刀法等級打出一整套斬擊（主角或 Lv5 影分身都用這個，出手位置是 atk_from）
func _slash_at(target: Vector2) -> void:
	audio.play("slash")
	var facing := (target - atk_from).angle()
	var big := slash_range + COMBO_GROW

	match blade_lv:
		1:
			_do_slash(facing, SLASH_ARC, slash_range, false)
		2:
			_do_slash(facing, SLASH_ARC, slash_range, false)
			_queue_hit(COMBO_DELAY, facing, big, true, false)
		3:
			# 一刀比一刀大：第二刀大一格、第三刀再大一格
			_do_slash(facing, SLASH_ARC, slash_range, false)
			_queue_hit(COMBO_DELAY, facing, big, true, false)
			_queue_hit(COMBO_DELAY * 2.0, facing, big + COMBO_GROW, false, false)
		4:
			# 共四刀，兩刀兩刀一起：1、2 刀像剪刀合起來，3、4 刀反過來打開
			# 大小直接用三連斬第二、第三刀的大小（+1 格、+2 格）
			_scissor(facing, big, true)
			_queue_hit(COMBO_DELAY, facing, big + COMBO_GROW, false, true)
		_:
			_do_slash(facing, AFTERIMAGE_ARC, slash_range, false, AFTERIMAGE_TIME)


## 排一個之後才出的連擊。scissor 時 flag = 剪刀合起來（true）或打開（false），否則 flag = 順時針
func _queue_hit(delay: float, facing: float, reach: float, flag: bool, scissor: bool) -> void:
	combo.append({"t": delay, "facing": facing, "reach": reach, "flag": flag, "scissor": scissor,
			"from": atk_from, "scale": atk_scale, "color": atk_color})


func _update_combo(delta: float) -> void:
	for i in range(combo.size() - 1, -1, -1):
		var h: Dictionary = combo[i]
		h.t -= delta
		if h.t > 0.0:
			continue
		combo.remove_at(i)
		_push_atk(h["from"], h["scale"], h["color"])
		if h.scissor:
			_scissor(h.facing, h.reach, h.flag, false)
		else:
			_do_slash(h.facing, SLASH_ARC, h.reach, h.flag, 0.0, false)   # 後續連擊不擊退
		_pop_atk()


## 雙刀：左右各一把 150° 的刀，中間重疊 30°。
## 合（close）：兩把刀從外側往中間掃，交叉後再分開；開：反過來從中間往外掃
func _scissor(facing: float, reach: float, close: bool, knock := true) -> void:
	var offset := (SLASH_ARC - SCISSOR_OVERLAP) / 2.0
	_do_slash(facing - offset, SLASH_ARC, reach, close, 0.0, knock)
	_do_slash(facing + offset, SLASH_ARC, reach, not close, 0.0, knock)


## 一刀：扇形內的敵人都砍到。clockwise 決定特效掃的方向；
## linger > 0 時斬擊會留在原地，期間每 0.5 秒再打一次（殘影斬）
## knock：只有每次攻擊的第一下會擊退，後續連擊和殘影都不擊退
func _do_slash(facing: float, arc: float, reach: float, clockwise: bool, linger := 0.0, knock := true) -> void:
	_hit_sector(atk_from, facing, arc, reach, true, knock)

	# 刀法 Lv3 以上：斬擊範圍內飛來的矢也會被砍掉
	if blade_lv >= 3:
		_cut_arrows(atk_from, facing, arc, reach)

	# 特效：「斬」字鋪滿扇形，像刀鋒掃過去；範圍越大字越多
	var fx := SlashFx.new().setup(facing, arc, reach, clockwise)
	fx.linger = linger
	fx.color = atk_color
	fx.position = atk_from
	fx.z_index = 5
	add_child(fx)
	if linger > 0.0:
		_add_zone(atk_from, facing, arc, reach, linger, true, true)


## 把扇形內的矢砍掉（碎開飛走）
func _cut_arrows(origin: Vector2, facing: float, arc: float, reach: float) -> void:
	for i in range(arrows.size() - 1, -1, -1):
		var b := arrows[i]
		var to := b.node.position - origin
		if to.length() > reach + 8.0:
			continue
		if arc < TAU and absf(angle_difference(facing, to.angle())) > arc / 2.0:
			continue
		var shard := particles.add("矢", b.node.position, to.normalized() * 120.0, 0.25, BULLET_SIZE, COLOR_ARROW)
		shard.spin = 14.0
		b.node.queue_free()
		arrows.remove_at(i)


## 打一個扇形（arc >= TAU 就是整圈）內的所有敵人；check_walls 時隔牆打不到
func _hit_sector(origin: Vector2, facing: float, arc: float, reach: float, check_walls: bool, knock := true) -> void:
	for e: Enemy in _nearby_radius(origin, reach + 30.0):
		var to := e.position - origin
		if to.length() > reach + e.radius:
			continue
		if arc < TAU and absf(angle_difference(facing, to.angle())) > arc / 2.0:
			continue
		if check_walls and not _line_clear(origin, e.position):
			continue
		_damage_enemy(e, _damage(), to.normalized() * KNOCK_SLASH if knock else Vector2.ZERO)


# ---------- 殘留斬擊（殘影斬、空間斬擊）----------

func _add_zone(origin: Vector2, facing: float, arc: float, reach: float, life: float, check_walls: bool, cuts_arrows: bool) -> void:
	var z := Zone.new()
	z.origin = origin
	z.facing = facing
	z.arc = arc
	z.reach = reach
	z.life = life
	z.tick = ZONE_TICK
	z.check_walls = check_walls
	z.cuts_arrows = cuts_arrows
	z.scale = atk_scale
	zones.append(z)


func _update_zones(delta: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z := zones[i]
		z.life -= delta
		z.tick -= delta
		if z.cuts_arrows:
			_cut_arrows(z.origin, z.facing, z.arc, z.reach)
		if z.tick <= 0.0:
			z.tick += ZONE_TICK
			var keep := atk_scale
			atk_scale = z.scale
			_hit_sector(z.origin, z.facing, z.arc, z.reach, z.check_walls, false)   # 殘影不擊退
			atk_scale = keep
		if z.life <= 0.0:
			zones.remove_at(i)


# ---------- 刀＋彈 ----------
##   Lv1 斬擊波 8 格、穿透 2　Lv2 大斬擊波（2 倍大）　Lv3 四方大斬擊
##   Lv4 四連大斬擊波（15 格，鎖定最近 4 個敵人）　Lv5 空間斬擊（直接出現在畫面內最近 4 個敵人身上）

func _update_blade_shots(delta: float) -> void:
	# 已排好的四連斬擊波
	for i in range(wave_queue.size() - 1, -1, -1):
		var q: Dictionary = wave_queue[i]
		q.t -= delta
		if q.t <= 0.0:
			wave_queue.remove_at(i)
			_push_atk(q.get("from", player.position), q.get("scale", 1.0), atk_color)
			_launch_wave(q.angle, true, WAVE_RANGE_LONG, WAVE_SPEED_FAST)
			_pop_atk()

	if bullet_lv < 1:
		return
	wave_cd -= delta
	if wave_cd > 0.0:
		return
	if _fire_waves():
		wave_cd = WAVE_INTERVAL * attack_mult


## 照斬擊波等級射一輪（主角或 Lv5 影分身都用這個，出手位置是 atk_from）。沒有目標就回傳 false
func _fire_waves() -> bool:
	var reach := WAVE_RANGE_LONG if bullet_lv >= 4 else WAVE_RANGE
	var targets := _on_screen_enemies(RIFT_TARGETS) if bullet_lv >= 5 else _nearest_enemies(reach, 4, true)
	if targets.is_empty():
		return false
	var first: Enemy = targets[0]
	var facing := (first.position - atk_from).angle()
	match bullet_lv:
		1:
			_launch_wave(facing, false, WAVE_RANGE, WAVE_SPEED)
		2:
			_launch_wave(facing, true, WAVE_RANGE, WAVE_SPEED)
		3:
			for k in 4:
				_launch_wave(facing + PI / 2.0 * k, true, WAVE_RANGE, WAVE_SPEED)
		4:
			for k in 4:
				var t: Enemy = targets[k % targets.size()]
				wave_queue.append({"t": WAVE_BURST_GAP * k, "angle": (t.position - atk_from).angle(),
						"from": atk_from, "scale": atk_scale})
		_:
			for t: Enemy in targets:
				_rift(t.position)
	return true


func _launch_wave(angle: float, big: bool, reach: float, speed: float) -> void:
	audio.play("wave")
	var w := Wave.new()
	w.dir = Vector2.from_angle(angle)
	w.big = big
	w.reach = reach
	w.speed = speed
	w.node = WaveFx.new()
	w.node.font_size = WaveFx.BIG_SIZE if big else WaveFx.FONT_SIZE
	w.node.position = atk_from + w.dir * 20.0
	w.scale = atk_scale
	w.pierce = WAVE_PIERCE + int(upgrade_levels.get("reach", 0))   # 「廣」每級多穿 1 個
	w.node.rotation = angle
	w.node.z_index = 5
	add_child(w.node)
	waves.append(w)


func _move_waves(delta: float) -> void:
	for i in range(waves.size() - 1, -1, -1):
		var w := waves[i]
		var step := w.speed * delta
		w.node.position += w.dir * step
		w.traveled += step
		if w.traveled >= w.reach or terrain.is_wall(terrain.cell_of(w.node.position)):
			w.node.queue_free()
			waves.remove_at(i)
			continue
		var scale := WAVE_BIG_SCALE if w.big else 1.0
		var half_w := 14.0 * scale
		var half_d := 12.0 * scale
		var side := w.dir.orthogonal()
		for e: Enemy in _nearby_radius(w.node.position, half_w + 30.0):
			var id := e.get_instance_id()
			if w.hits.has(id):
				continue
			var d := e.position - w.node.position
			if absf(d.dot(w.dir)) <= half_d + e.radius and absf(d.dot(side)) <= half_w + e.radius:
				w.hits[id] = true
				_damage_enemy(e, BASE_DAMAGE * damage_mult * w.scale, w.dir * KNOCK_SLASH)
				w.pierce -= 1
				if w.pierce < 0:
					break
		if w.pierce < 0:
			w.node.queue_free()
			waves.remove_at(i)


## 空間斬擊：在敵人身上直接出現一圈斬擊打一次（無視牆），之後留 0.5 秒殘影但不再造成傷害
func _rift(pos: Vector2) -> void:
	audio.play("wave")
	# 「廣」每級讓空間斬擊的圈圈直徑 +15%
	var r := RIFT_RADIUS * (1.0 + RIFT_REACH_BONUS * int(upgrade_levels.get("reach", 0)))
	var fx := SlashFx.new().setup(randf() * TAU, TAU, r, false)
	fx.linger = RIFT_TIME
	fx.color = COLOR_RIFT
	fx.position = pos
	fx.z_index = 5
	add_child(fx)
	_hit_sector(pos, 0.0, TAU, r, false)   # 只在出現時打一次，殘影只是畫面


## 畫面內最近的幾個敵人（空間斬擊不管牆）
func _on_screen_enemies(count: int) -> Array:
	var half := get_viewport_rect().size / 2.0
	var near := enemies.filter(func(e: Enemy) -> bool:
		var d := e.position - player.position
		return absf(d.x) < half.x and absf(d.y) < half.y)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.position.distance_squared_to(player.position) < b.position.distance_squared_to(player.position))
	return near.slice(0, count)


## 範圍內最近的幾個敵人；need_sight 時中間不能隔牆
func _nearest_enemies(max_range: float, count: int, need_sight: bool) -> Array:
	var from := atk_from
	var near := enemies.filter(func(e: Enemy) -> bool:
		return e.position.distance_squared_to(from) < max_range * max_range)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.position.distance_squared_to(from) < b.position.distance_squared_to(from))
	var out := []
	for e: Enemy in near:
		if not need_sight or _line_clear(from, e.position):
			out.append(e)
			if out.size() >= count:
				break
	return out


## 人＋刀：迴旋刃繞著主角轉，碰到敵人就砍（同一隻有冷卻），也能擋下矢
##   Lv1 4 把　Lv2 兩圈各 4 把　Lv3 疾旋（一般 1 秒、加速 1 秒）　Lv4 爆旋（外圈擴大爆炸）　Lv5 一整圈刃幕
func _update_orbit(delta: float) -> void:
	var want := 0
	if not _is_blade() and blade_lv >= 1:
		want = ORBIT_PER_RING if blade_lv == 1 else ORBIT_PER_RING * 2
	while orbit_blades.size() < want:
		var g := Glyph.new().setup("刃", ORBIT_SIZE, COLOR_PLAYER)
		g.z_index = 6
		add_child(g)
		orbit_blades.append(g)
	if orbit_blades.is_empty():
		return

	# 疾旋：一般 1 秒、加速 1 秒輪流；Lv4 起在加速結束時接著爆旋
	var fast := false
	if blade_lv >= 3:
		var before := orbit_clock
		orbit_clock = fmod(orbit_clock + delta, SPIN_EVERY + SPIN_TIME)
		fast = orbit_clock >= SPIN_EVERY
		if blade_lv >= 4 and orbit_clock < before:   # 剛轉完一輪快轉
			burst_t = 0.0
			burst_done = false
	var radius := ORBIT_RADIUS
	if burst_t >= 0.0:
		burst_t += delta
		var k := burst_t / BURST_TIME
		radius += BURST_GROW * (1.0 - absf(1.0 - 2.0 * k))   # 往外擴，到一半最大，再收回
		if k >= 0.5 and not burst_done:
			burst_done = true
			_orbit_burst(_outer_radius() + BURST_GROW)
		if k >= 1.0:
			burst_t = -1.0
	orbit_angle += ORBIT_SPEED * (SPIN_MULT if fast else 1.0) * delta
	var hit_cd := SPIN_HIT_CD if fast else ORBIT_HIT_CD

	for i in orbit_blades.size():
		var g := orbit_blades[i]
		# 每 4 把一圈；外圈遠一點、錯開 45 度、反方向轉
		var ring := i / ORBIT_PER_RING
		var spin_dir := 1.0 if ring % 2 == 0 else -1.0   # 內外圈轉的方向相反
		var a := orbit_angle * spin_dir + TAU * (i % ORBIT_PER_RING) / ORBIT_PER_RING + ring * PI / ORBIT_PER_RING
		g.position = player.position + Vector2.from_angle(a) * (radius + ring * ORBIT_RING_GAP)
		# 擋矢
		for j in range(arrows.size() - 1, -1, -1):
			var b := arrows[j]
			if b.node.position.distance_to(g.position) < 20.0:
				var shard := particles.add("矢", b.node.position, -b.vel * 0.4, 0.25, BULLET_SIZE, COLOR_ARROW)
				shard.spin = 14.0
				b.node.queue_free()
				arrows.remove_at(j)
		for e: Enemy in _nearby(g.position):
			if e.position.distance_to(g.position) > 14.0 + e.radius:
				continue
			var id := e.get_instance_id()
			if elapsed - orbit_hits.get(id, -99.0) < hit_cd:
				continue
			orbit_hits[id] = elapsed
			_damage_enemy(e, _damage() * ORBIT_DAMAGE_MULT, (e.position - player.position).normalized() * KNOCK_SLASH)


## 最外圈迴旋刃的半徑
func _outer_radius() -> float:
	var rings := (orbit_blades.size() - 1) / ORBIT_PER_RING + 1
	return ORBIT_RADIUS + (rings - 1) * ORBIT_RING_GAP


## 爆旋：以主角為中心，半徑內的敵人全部吃一次爆炸傷害，外圈冒出一圈「爆」；Lv5 接著把刃射出去
func _orbit_burst(r: float) -> void:
	audio.play("explode")
	for e: Enemy in _nearby_radius(player.position, r + 30.0):
		var to := e.position - player.position
		if to.length() <= r + e.radius:
			_damage_enemy(e, _damage() * BURST_MULT * ORBIT_DAMAGE_MULT, to.normalized() * KNOCK_SLASH)
	var count := 12
	for i in count:
		var dir := Vector2.from_angle(TAU * i / count)
		var p := particles.add("爆", player.position + dir * r, dir * 60.0, 0.3, BULLET_SIZE, COLOR_BULLET)
		p.grow = 1.5
	_shake(10.0)
	_hitstop(0.04)
	if blade_lv >= 5:
		# 往四周射出一整圈刃幕
		for k in FLY_BARRAGE:   # r 就是爆炸半徑
			var dir := Vector2.from_angle(TAU * k / FLY_BARRAGE + orbit_angle)
			_launch_flying_blade(player.position + dir * r * 0.5, dir)


## 飛刃：比子彈快兩倍、飛兩倍遠，撞牆反彈，穿透數跟子彈一樣（吃「穿」升級）
func _launch_flying_blade(pos: Vector2, dir: Vector2) -> void:
	var b := Bullet.new()
	b.node = Glyph.new().setup("刃", ORBIT_SIZE, COLOR_PLAYER)
	b.node.position = pos
	b.node.z_index = 6
	b.vel = dir * BULLET_SPEED * FLY_SPEED_MULT
	b.life = BULLET_LIFETIME * FLY_RANGE_MULT / FLY_SPEED_MULT   # 兩倍快、兩倍遠 → 飛的時間一樣
	b.pierce = bullet_pierce
	b.damage = _damage() * ORBIT_DAMAGE_MULT
	add_child(b.node)
	flying_blades.append(b)


func _move_flying_blades(delta: float) -> void:
	for i in range(flying_blades.size() - 1, -1, -1):
		var b := flying_blades[i]
		b.life -= delta
		# 撞牆反彈：分 x、y 兩個方向檢查，哪個方向撞到就把那個方向反過來
		var p := b.node.position
		if not terrain.is_wall(terrain.cell_of(p)):   # 從牆裡射出來的話先讓它飛出牆，不反彈
			if terrain.is_wall(terrain.cell_of(p + Vector2(b.vel.x * delta, 0))):
				b.vel.x = -b.vel.x
			if terrain.is_wall(terrain.cell_of(p + Vector2(0, b.vel.y * delta))):
				b.vel.y = -b.vel.y
		b.node.position += b.vel * delta
		var done := b.life <= 0.0
		for e: Enemy in _nearby(b.node.position):
			if b.hits.has(e):
				continue
			if e.position.distance_to(b.node.position) < BULLET_RADIUS + e.radius:
				b.hits.append(e)
				_damage_enemy(e, b.damage, b.vel.normalized() * KNOCK_BULLET)
				b.pierce -= 1
				if b.pierce < 0:
					done = true
				break
		if done:
			b.node.queue_free()
			flying_blades.remove_at(i)


func _fx_glyph(text: String, pos: Vector2, size: int = BULLET_SIZE) -> Glyph:
	var g := Glyph.new().setup(text, size, COLOR_PLAYER)
	g.position = pos
	g.z_index = 5
	add_child(g)
	return g


func _add_fx(fx: Fx, duration: float) -> void:
	fx.life = duration
	fx.duration = duration
	effects.append(fx)


func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var fx := effects[i]
		fx.life -= delta
		for g in fx.nodes:
			g.modulate.a = clampf(fx.life / fx.duration, 0.0, 1.0)
		if fx.life <= 0.0:
			for g in fx.nodes:
				g.queue_free()
			effects.remove_at(i)


## 找最近、在範圍內、而且中間沒有牆擋住的敵人
func _nearest_visible_enemy(max_range: float) -> Enemy:
	var from := atk_from
	var sorted := enemies.filter(func(e: Enemy) -> bool:
		return e.position.distance_squared_to(from) < max_range * max_range)
	sorted.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.position.distance_squared_to(from) < b.position.distance_squared_to(from))
	for e: Enemy in sorted:
		if _line_clear(from, e.position):
			return e
	return null


func _line_clear(from: Vector2, to: Vector2) -> bool:
	var steps := int(from.distance_to(to) / (Terrain.CELL * 0.5)) + 1
	for i in range(1, steps):
		if terrain.is_wall(terrain.cell_of(from.lerp(to, float(i) / steps))):
			return false
	return true


# ---------- 金 ----------

func _drop_gold(pos: Vector2) -> void:
	var g := Glyph.new().setup("金", GOLD_SIZE, COLOR_GOLD)
	g.position = pos
	g.z_index = 1
	add_child(g)
	golds.append(g)


## 進入吸金範圍的「金」會被吸過來，碰到主角就計數並累積經驗
func _update_gold(delta: float) -> void:
	for i in range(golds.size() - 1, -1, -1):
		var g := golds[i]
		var dist := g.position.distance_to(player.position)
		if dist > pickup_range:
			continue
		if dist < PLAYER_RADIUS:
			audio.play("gold")
			gold += 1
			_gain_xp(1)
			g.queue_free()
			golds.remove_at(i)
			continue
		g.position = g.position.move_toward(player.position, GOLD_PULL_SPEED * delta)


# ---------- 天罰 ----------
## 一局只能用一次：滑鼠左鍵點任何地方，全地圖的小兵瞬間清空（王吃重傷害），空中的矢也一起清掉

func _update_smite(_delta: float) -> void:
	smite_ring.visible = false   # 全圖攻擊不需要瞄準
	if Input.is_action_just_pressed("smite") and not smite_used \
			and Engine.get_process_frames() - _ignore_click_frame > 1:
		smite_used = true
		_smite_all()


func _smite_all() -> void:
	audio.play("smite")
	for e: Enemy in enemies.duplicate():
		if e.is_boss:
			_damage_enemy(e, _damage() * BOSS_LAND_MULT)
		else:
			_kill_enemy(e)
	for b in arrows:
		b.node.queue_free()
	arrows.clear()
	# 特效：主角頭上一個大「天」，周圍一圈「罰」，整個畫面閃一下淡藍色
	var big := particles.add("天", player.position + Vector2(0, -40), Vector2(0, -30), 1.0, 132, COLOR_SMITE)
	big.grow = 0.3
	var count := 12
	for i in count:
		var dir := Vector2.from_angle(TAU * i / count)
		var p := particles.add("罰", player.position + dir * SMITE_RADIUS, dir * 400.0, 0.8, GLYPH_SIZE, COLOR_SMITE)
		p.drag = 1.5
	hurt_overlay.color = Color(COLOR_SMITE, 0.5)
	_shake(16.0)
	_hitstop(0.15)


# ---------- 打擊感 ----------

func _shake(amount: float) -> void:
	shake = maxf(shake, amount)


func _hitstop(t: float) -> void:
	hitstop = maxf(hitstop, t)


func _update_feedback(delta: float) -> void:
	if shake > 0.0:
		shake = move_toward(shake, 0.0, SHAKE_DECAY * delta)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
	if hurt_overlay.color.a > 0.0:
		hurt_overlay.color.a = move_toward(hurt_overlay.color.a, 0.0, 1.2 * delta)


# ---------- 寶箱 ----------

func _update_chests() -> void:
	if not final_phase and elapsed >= next_chest_time:
		next_chest_time += CHEST_INTERVAL
		_spawn_chest()

	for i in range(chests.size() - 1, -1, -1):
		var c := chests[i]
		if c.node.position.distance_to(player.position) < CHEST_OPEN_RANGE:
			_open_chest(c)
			chests.remove_at(i)
	_update_chest_pointer()
	_update_boss_pointers()
	_update_hearts()


# ---------- 補血愛心 ----------

func _update_hearts() -> void:
	if elapsed >= next_heal_time:
		next_heal_time += HEAL_INTERVAL
		if hearts.size() < HEAL_MAX_ON_MAP:
			_spawn_heart()
	for i in range(hearts.size() - 1, -1, -1):
		var h := hearts[i]
		if hp < max_hp and h.position.distance_to(player.position) < HEAL_PICK_RANGE:   # 滿血時不撿，留著之後用
			hp = mini(hp + HEAL_AMOUNT, max_hp)
			audio.play("heal")
			var p := particles.add("+%d" % HEAL_AMOUNT, h.position + Vector2(0, -20), Vector2(0, -60), 0.7, 33, HeartPickup.COLOR)
			p.drag = 1.5
			h.queue_free()
			hearts.remove_at(i)
	# 邊緣提示：最近的一顆在畫面外時顯示
	var best: HeartPickup = null
	var best_d := INF
	for h in hearts:
		var d := h.position.distance_squared_to(player.position)
		if d < best_d:
			best_d = d
			best = h
	var edge := _edge_point(best.position) if best != null else Vector2.INF
	heart_pointer.visible = edge != Vector2.INF
	if heart_pointer.visible:
		heart_pointer.position = edge


func _spawn_heart() -> void:
	for i in 30:
		var dist := randf_range(HEAL_MIN_DIST, HEAL_MAX_DIST)
		var cell := terrain.cell_of(player.position + Vector2.from_angle(randf() * TAU) * dist)
		if terrain.flow_distance(cell) >= 0:
			var h := HeartPickup.new()
			h.position = terrain.cell_center(cell)
			h.z_index = 5
			add_child(h)
			hearts.append(h)
			return


## 找一個附近、不是牆、走得到的位置放寶箱
func _spawn_chest() -> void:
	for i in 30:
		var dist := randf_range(CHEST_MIN_DIST, CHEST_MAX_DIST)
		var cell := terrain.cell_of(player.position + Vector2.from_angle(randf() * TAU) * dist)
		if terrain.flow_distance(cell) >= 0:
			_place_chest(terrain.cell_center(cell))
			return


## 王死掉的地方掉寶箱；王會穿牆，死在牆裡就往外找最近的空地
func _spawn_chest_near(pos: Vector2) -> void:
	var center := terrain.cell_of(pos)
	for r in 8:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := center + Vector2i(dx, dy)
				if not terrain.is_wall(c):
					_place_chest(terrain.cell_center(c))
					return


func _place_chest(pos: Vector2) -> void:
	var c := Chest.new()
	c.node = Glyph.new().setup("寶", GLYPH_SIZE, COLOR_CHEST)
	c.node.position = pos
	c.node.z_index = 1
	add_child(c.node)
	chests.append(c)


## 打開寶箱：排一次「彈 / 刀」二選一
func _open_chest(c: Chest) -> void:
	audio.play("chest")
	pending_power += 1
	var pop := particles.add("寶", c.node.position, Vector2.ZERO, 0.3, GLYPH_SIZE, COLOR_CHEST)
	pop.grow = 3.0
	c.node.queue_free()


# ---------- 寶箱強化（彈 / 刀）----------

func _open_power_up() -> void:
	pending_power -= 1
	var opts := []
	for line: String in _lines():
		if _line_level(line) < LINE_MAX:
			opts.append(line)
	opts.append("蘇")   # 蘇生：每次開寶箱都可以選，可以重複拿
	if opts.is_empty():
		# 全部都滿了：改成在身邊灑 20 個金（不補血）
		for i in 20:
			_drop_gold(player.position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 60.0))
		return
	power_choices = opts
	power_cursor = 0
	state = State.POWER_UP
	player.modulate.a = 1.0
	_show_power_up()


func _line_level(line: String) -> int:
	match line:
		"彈": return bullet_lv
		"刀": return blade_lv
		"砲": return cannon_lv
		"影": return shadow_lv
	return 0


## 這個角色有哪幾條強化線
func _lines() -> Array:
	return ["彈", "刀", "影"] if _is_blade() else ["彈", "刀", "砲"]


func _show_power_up() -> void:
	var who: String = CHARACTERS[character].glyph
	var cards := []
	for line: String in power_choices:
		if line == "蘇":
			cards.append({"icon": "蘇", "name": "蘇生", "sub": "持有 %d→%d" % [revives, revives + 1],
					"desc": "死掉時復活一次，\n回到 %d 血，\n%d 秒無敵\n（可以重複拿）" % [REVIVE_HP, int(REVIVE_INVINCIBLE)]})
			continue
		var info: Dictionary = POWER_INFO[who][line]
		var lv := _line_level(line)
		cards.append({"icon": line, "name": info.name, "sub": "Lv %d→%d" % [lv, lv + 1], "desc": info.desc[lv + 1]})
	level_cards.show_cards("選擇你的武器" if start_pick else "寶箱！選一個強化", cards, power_cursor, _pick_hint())


func _process_power_up() -> void:
	var step := 0
	if Input.is_action_just_pressed("move_left"):
		step = -1
	elif Input.is_action_just_pressed("move_right"):
		step = 1
	if step != 0:
		audio.play("ui_move")
		power_cursor = posmod(power_cursor + step, power_choices.size())
		_show_power_up()
	if Input.is_action_just_pressed("confirm"):
		audio.play("ui_ok")
		match power_choices[power_cursor]:
			"彈": bullet_lv += 1
			"刀": blade_lv += 1
			"砲": cannon_lv += 1
			"影": shadow_lv += 1
			"蘇": revives += 1
		start_pick = false
		level_cards.visible = false
		state = State.PLAYING
		_update_hud()


## 最近的寶箱在畫面外時，在畫面邊緣朝那個方向顯示一個「寶」
func _update_chest_pointer() -> void:
	var best: Chest = null
	var best_d := INF
	for c in chests:
		var d := c.node.position.distance_squared_to(player.position)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		chest_pointer.visible = false
		return
	var edge := _edge_point(best.node.position, POINTER_MARGIN)
	chest_pointer.visible = edge != Vector2.INF
	if chest_pointer.visible:
		chest_pointer.position = edge


## 王在畫面外時，在畫面邊緣朝牠的方向顯示牠的字（每隻王一個）
func _update_boss_pointers() -> void:
	var used := 0
	for e in enemies:
		if not e.is_boss:
			continue
		var edge := _edge_point(e.position, POINTER_MARGIN + 40.0)   # 「大鬼」這種兩個字比較寬
		if edge == Vector2.INF:
			continue
		if used >= boss_pointers.size():
			var g := Glyph.new().setup(e.label, POINTER_SIZE, e.base_color)
			g.modulate.a = 0.8
			g.z_index = 20
			add_child(g)
			boss_pointers.append(g)
		var ptr := boss_pointers[used]
		if ptr.text != e.label:
			ptr.set_text(e.label)
		ptr.color = e.base_color
		ptr.position = edge
		ptr.visible = true
		ptr.queue_redraw()
		used += 1
	for i in range(used, boss_pointers.size()):
		boss_pointers[i].visible = false


## target 在畫面外的話，回傳主角往 target 方向碰到畫面邊緣（往內縮一點）的位置；在畫面內回傳 INF
func _edge_point(target: Vector2, margin := 40.0) -> Vector2:
	var to := target - player.position
	var half := get_viewport_rect().size / 2.0 - Vector2(margin, margin)
	if absf(to.x) < half.x and absf(to.y) < half.y:
		return Vector2.INF
	var t := minf(half.x / maxf(absf(to.x), 0.001), half.y / maxf(absf(to.y), 0.001))
	return player.position + to * t


const FINAL_HINT_TIME := 4.0        # 決戰開始的提示顯示幾秒
const FINAL_INTRO_TIME := 2.8       # 最終決戰開場停幾秒
const INTRO_TEXT := "最終決戰"
const INTRO_CHAR_GAP := 0.5         # 每隔幾秒多跳出一個字（4 個字 1.5 秒出完，再停一下）
const CELEBRATE_TIME := 3.0         # 過關煙火放幾秒
const FIREWORK_GAP := 0.22          # 每隔幾秒放一朵
const FIREWORK_COLORS := [Color(1.0, 0.4, 0.4), Color(1.0, 0.85, 0.3), Color(0.5, 0.9, 1.0),
		Color(0.6, 1.0, 0.5), Color(0.9, 0.55, 1.0), Color(1.0, 0.6, 0.85)]


func _show_big_banner(text: String, color: Color) -> void:
	big_banner.text = text
	big_banner.add_theme_color_override("font_color", color)
	big_banner.visible = true


## 打倒最終王：剩下的敵人全部碎掉、主角無敵，放 3 秒煙火
func _start_celebration() -> void:
	celebrate = CELEBRATE_TIME
	firework_cd = 0.0
	for e: Enemy in enemies.duplicate():
		_shatter(e)
		enemies.erase(e)
		e.queue_free()
	for b in arrows:
		b.node.queue_free()
	arrows.clear()
	hud_boss.visible = false
	hud_final_hint.visible = false
	final_frame.visible = false
	hud_time.text = "過關"
	for ptr in boss_pointers:
		ptr.visible = false
	audio.stop_music()
	audio.play("win")
	_show_big_banner("過關！", Color(1.0, 0.85, 0.4))


func _update_celebration(delta: float) -> void:
	celebrate -= delta
	firework_cd -= delta
	if firework_cd <= 0.0:
		firework_cd = FIREWORK_GAP
		_firework()
	if celebrate <= 0.0:
		big_banner.visible = false
		_end(State.WON)


## 一朵煙火：在畫面裡隨機一個地方，一圈彩色的「＊」往外炸開再慢慢淡掉
func _firework() -> void:
	var half := get_viewport_rect().size * 0.4
	var c := player.position + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y * 0.6))
	var color: Color = FIREWORK_COLORS.pick_random()
	var n := 18
	var speed := randf_range(220.0, 320.0)
	for i in n:
		var dir := Vector2.from_angle(TAU * i / n + randf_range(-0.1, 0.1))
		var p := particles.add("＊" if i % 2 == 0 else "．", c, dir * speed, randf_range(0.9, 1.3), 33, color)
		p.drag = 1.8
	var core := particles.add("火", c, Vector2.ZERO, 0.3, 44, Color.WHITE)
	core.grow = 2.0
	audio.play("cannon", 0.2)


## 決戰時上方顯示每一隻最終王的血條（打倒的顯示「擊倒」），讓玩家知道要把它們全部打倒
func _update_boss_bars() -> void:
	var alive := final_bosses.duplicate()
	var parts := []
	for kind in final_roster:
		var boss: Enemy = null
		for b in alive:
			if b.label == kind:
				boss = b
				break
		if boss == null:
			parts.append("%s 擊倒" % kind)
			continue
		alive.erase(boss)
		var blocks := clampi(int(ceil(10.0 * boss.hp / boss.max_hp)), 0, 10)
		parts.append("%s %s%s" % [kind, "■".repeat(blocks), "□".repeat(10 - blocks)])
	hud_boss.text = "　　".join(parts)
	hud_boss.visible = true


## 決戰的紅框：畫面四邊一圈紅色「戰」字，慢慢一明一暗地閃
const FINAL_FRAME_CHAR := "戰"
const FINAL_FRAME_SIZE := 33        # 電腦模式；手機模式畫面已經放大一倍，用 22
const FINAL_FRAME_CELL := 44.0


func _draw_final_frame() -> void:
	var size := final_frame.size
	var pulse := 0.45 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.5)
	var color := Color(COLOR_ENEMY_BOSS, pulse)
	var fs := 22 if is_touch else FINAL_FRAME_SIZE
	var cell := 30.0 if is_touch else FINAL_FRAME_CELL
	var cols := int(size.x / cell)
	var rows := int(size.y / cell)
	var gap := Vector2(size.x - cols * cell, size.y - rows * cell) / 2.0
	var ascent := Glyph.font.get_ascent(fs)
	var height := Glyph.font.get_height(fs)
	var w := Glyph.font.get_string_size(FINAL_FRAME_CHAR, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for cx in cols:
		for cy in rows:
			if cx != 0 and cy != 0 and cx != cols - 1 and cy != rows - 1:
				continue
			var c := gap + Vector2(cx + 0.5, cy + 0.5) * cell
			final_frame.draw_string(Glyph.font, Vector2(c.x - w / 2.0, c.y + ascent - height / 2.0),
					FINAL_FRAME_CHAR, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## 主角頭上的小血條
func _draw_player_bar() -> void:
	const W := 48.0
	var y := -GLYPH_SIZE / 2.0 - 14.0
	var ratio := clampf(float(hp) / max_hp, 0.0, 1.0)
	player_bar.draw_rect(Rect2(-W / 2.0, y, W, 5), Color(0.25, 0.25, 0.25))
	player_bar.draw_rect(Rect2(-W / 2.0, y, W * ratio, 5), Color(0.9, 0.25, 0.25))


# ---------- 升級 ----------

func _xp_needed() -> int:
	return XP_FIRST_LEVEL + (level - 1) * XP_STEP


func _gain_xp(amount: int) -> void:
	xp += amount
	while xp >= _xp_needed():
		xp -= _xp_needed()
		level += 1
		pending_levels += 1


## 這個角色還能升的選項
func _available_upgrades() -> Array:
	var who: String = CHARACTERS[character].glyph
	return UPGRADES.filter(func(u: Dictionary) -> bool:
		return (u.who == "all" or u.who == who) and upgrade_levels.get(u.id, 0) < UPGRADE_MAX_LEVEL)


func _open_level_up() -> void:
	pending_levels -= 1
	var pool := _available_upgrades()
	if pool.is_empty():
		# 全部升滿了：沒有東西可選，直接跳過（不補血）
		return
	pool.shuffle()
	upgrade_choices = pool.slice(0, 3)
	audio.play("level")
	upgrade_cursor = 0
	state = State.LEVEL_UP
	player.modulate.a = 1.0
	_show_level_up()


func _show_level_up() -> void:
	var cards := []
	for u: Dictionary in upgrade_choices:
		var lv: int = upgrade_levels.get(u.id, 0)
		cards.append({"icon": u.icon, "name": u.name, "sub": "Lv %d→%d" % [lv, lv + 1], "desc": u.desc})
	var hint := _pick_hint()
	var button := ""
	if rerolls_left > 0:
		button = "重抽　剩 %d 次" % rerolls_left
		if not is_touch:
			hint += "　R 重抽"
	level_cards.show_cards("升級！　級 %d" % level, cards, upgrade_cursor, hint, "", [], button)


## 升級時重抽三張卡片（用掉一次重抽）
func reroll_upgrades() -> void:
	if state != State.LEVEL_UP or rerolls_left <= 0:
		return
	rerolls_left -= 1
	var pool := _available_upgrades()
	pool.shuffle()
	upgrade_choices = pool.slice(0, 3)
	upgrade_cursor = 0
	audio.play("chest")
	_show_level_up()


func _process_level_up() -> void:
	if Input.is_action_just_pressed("reroll"):
		reroll_upgrades()
		return
	var step := 0
	if Input.is_action_just_pressed("move_left"):
		step = -1
	elif Input.is_action_just_pressed("move_right"):
		step = 1
	if step != 0:
		audio.play("ui_move")
		upgrade_cursor = posmod(upgrade_cursor + step, upgrade_choices.size())
		_show_level_up()
	if Input.is_action_just_pressed("confirm"):
		audio.play("ui_ok")
		_apply_upgrade(upgrade_choices[upgrade_cursor].id)
		level_cards.visible = false
		state = State.PLAYING
		_update_hud()
		# 還有沒升完的級，就接著再選一次
		if pending_levels > 0:
			_open_level_up()


func _apply_upgrade(id: String) -> void:
	upgrade_levels[id] = upgrade_levels.get(id, 0) + 1
	match id:
		"haste":
			# 攻擊速度每級 +15%（不是乘上去，避免疊太快）
			attack_mult = 1.0 / (1.0 + 0.15 * upgrade_levels[id])
		"pierce":
			bullet_pierce += 1
		"reach":
			slash_range *= 1.2
		"speed":
			player_speed *= 1.12
		"vital":
			regen_per_sec += VITAL_REGEN
		"power":
			damage_mult += 0.2
		"magnet":
			pickup_range *= 1.35
		"focus":
			skill_cooldown *= 0.85
			skill_recharge = minf(skill_recharge, skill_cooldown)


# ---------- 空間格子（加速碰撞查詢）----------

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GRID_CELL), floori(p.y / GRID_CELL))


func _build_grid() -> void:
	grid.clear()
	for e: Enemy in enemies:
		var k := _cell(e.position)
		if not grid.has(k):
			grid[k] = []
		grid[k].append(e)


## 半徑 r 內可能碰到的敵人（給大範圍的判定用）
func _nearby_radius(p: Vector2, r: float) -> Array:
	var out := []
	var a := _cell(p - Vector2(r, r))
	var b := _cell(p + Vector2(r, r))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var k := Vector2i(x, y)
			if grid.has(k):
				out.append_array(grid[k])
	return out


func _nearby(p: Vector2) -> Array:
	var out := []
	var c := _cell(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var k := c + Vector2i(dx, dy)
			if grid.has(k):
				out.append_array(grid[k])
	return out


# ---------- HUD 與結束 ----------

## 蓋在最上層的全畫面濾鏡：把整個畫面（含 HUD）的亮度、彩度調低一點，看久了比較不刺眼
func _build_screen_filter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(l), c, saturation) * brightness, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("brightness", SCREEN_BRIGHTNESS)
	mat.set_shader_parameter("saturation", SCREEN_SATURATION)
	rect.material = mat
	layer.add_child(rect)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 33
	# HUD 文字加黑色外框，蓋在牆上也看得清楚，又不會擋住後面的畫面
	theme.set_constant("outline_size", "Label", 12)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	root.theme = theme
	layer.add_child(root)

	hurt_overlay = ColorRect.new()
	hurt_overlay.color = Color(1, 0, 0, 0)
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_overlay)

	final_frame = Control.new()
	final_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	final_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	final_frame.visible = false
	final_frame.draw.connect(_draw_final_frame)
	root.add_child(final_frame)

	hud_hp = Label.new()
	hud_hp.position = Vector2(24, 16)
	root.add_child(hud_hp)

	hud_skill = Label.new()
	hud_skill.position = Vector2(24, 70)
	root.add_child(hud_skill)

	hud_key_skill = Label.new()
	hud_key_skill.add_theme_font_size_override("font_size", 22)
	hud_key_skill.text = "Shift"
	hud_key_skill.position = Vector2(24, 112)
	root.add_child(hud_key_skill)
	hud_key_smite = Label.new()
	hud_key_smite.add_theme_font_size_override("font_size", 22)
	hud_key_smite.text = "滑鼠左鍵"
	hud_key_smite.position = Vector2(24, 112)
	root.add_child(hud_key_smite)

	hud_power = Label.new()
	hud_power.position = Vector2(24, 152)
	root.add_child(hud_power)

	hud_time = Label.new()
	hud_time.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_time.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_time.position.y = 16
	root.add_child(hud_time)

	hud_boss = Label.new()
	hud_boss.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_boss.add_theme_color_override("font_color", COLOR_ENEMY_BOSS)
	hud_boss.position.y = 62
	hud_boss.visible = false
	root.add_child(hud_boss)

	big_banner = Label.new()
	big_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_banner.add_theme_font_size_override("font_size", 165)
	big_banner.add_theme_constant_override("outline_size", 24)
	big_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_banner.visible = false
	root.add_child(big_banner)

	hud_final_hint = Label.new()
	hud_final_hint.text = "打倒全部最終王！"
	hud_final_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_final_hint.anchor_bottom = 0.5   # 放在畫面上半部的中間，不擋到主角
	hud_final_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_final_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_final_hint.add_theme_font_size_override("font_size", 66)
	hud_final_hint.add_theme_color_override("font_color", COLOR_ENEMY_BOSS)
	hud_final_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_final_hint.visible = false
	root.add_child(hud_final_hint)

	hud_version = Label.new()
	hud_version.text = preload("res://version.gd").TEXT
	hud_version.add_theme_font_size_override("font_size", 22)
	hud_version.modulate.a = 0.5
	hud_version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hud_version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_version.position += Vector2(-16, -12)
	root.add_child(hud_version)

	hud_kills = Label.new()
	hud_kills.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_kills.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_kills.position += Vector2(-24, 16)
	root.add_child(hud_kills)

	# 選角 / 升級 / 結束畫面：半透明黑底，文字靠左排好後整塊置中
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	root.add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	menu_label = Label.new()
	menu_label.add_theme_font_size_override("font_size", 33)
	menu_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	center.add_child(menu_label)

	# 手機觸控：畫在 HUD 上、卡片底下
	# 第一次開：有觸控螢幕就預設手機模式；之後用選角畫面選的
	if touch_mode < 0:
		var detected := DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()
		touch_mode = 1 if detected else 0
	is_touch = touch_mode == 1
	_apply_screen_scale()
	touch = TouchControls.new()
	touch.main = self
	touch.font = font
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch)
	if is_touch:
		hud_key_skill.visible = false   # 手機上有虛擬按鍵，不用寫鍵盤的鍵
		hud_key_smite.visible = false

	level_cards = UpgradeCards.new()
	level_cards.font = font
	level_cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_cards.visible = false
	root.add_child(level_cards)
	root.move_child(hud_version, -1)   # 版本號要蓋在卡片畫面上面才看得到

	pause_menu = PauseMenu.new()
	pause_menu.font = font
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.visible = false
	root.add_child(pause_menu)

	meta_menu = MetaMenu.new()
	meta_menu.font = font
	meta_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meta_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_menu.visible = false
	root.add_child(meta_menu)

	# 手機模式直拿時畫面太小：蓋一層提示請轉橫（放最上面，連卡片都蓋住）
	rotate_hint = ColorRect.new()
	rotate_hint.color = Color(0, 0, 0, 0.9)
	rotate_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var msg := Label.new()
	msg.text = "請把手機轉橫"
	msg.add_theme_font_size_override("font_size", 165)
	msg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_hint.add_child(msg)
	root.add_child(rotate_hint)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func _show_menu(text: String) -> void:
	menu_label.text = text
	menu.visible = true


func _update_hud() -> void:
	var blocks := clampi(int(ceil(10.0 * hp / max_hp)), 0, 10)
	hud_hp.text = "血 %s%s %d/%d" % ["■".repeat(blocks), "□".repeat(10 - blocks), hp, max_hp]
	var charges := "●".repeat(skill_charges) + "○".repeat(SKILL_MAX_CHARGES - skill_charges)
	var wait := "" if skill_charges == SKILL_MAX_CHARGES else " %.1f" % skill_recharge
	var smite := "○" if smite_used else "●"
	hud_skill.text = "技 %s%s　天 %s" % [charges, wait, smite]
	# 「滑鼠左鍵」對齊在「天」底下（技後面的字數會變，所以每次算位置）
	var before := "技 %s%s　" % [charges, wait]
	hud_key_smite.position.x = 24 + Glyph.font.get_string_size(before, HORIZONTAL_ALIGNMENT_LEFT, -1, 33).x
	if player_bar != null:
		player_bar.queue_redraw()
	if touch != null and is_touch:
		touch.refresh()
	var line_texts := []
	for line: String in _lines():
		line_texts.append("%s Lv%d" % [line, _line_level(line)])
	if revives > 0:
		line_texts.append("蘇 ×%d" % revives)
	hud_power.text = "　".join(line_texts)
	if final_phase:
		var counts := {}
		for b in final_bosses:
			counts[b.label] = counts.get(b.label, 0) + 1
		var parts := []
		for k: String in counts:
			parts.append("%s ×%d" % [k, counts[k]])
		hud_time.text = "決戰　" + "　".join(parts)
		hud_time.add_theme_color_override("font_color", COLOR_ENEMY_BOSS)
		_update_boss_bars()
		# 「打倒全部最終王！」顯示幾秒，最後一秒淡出
		hud_final_hint.visible = final_hint_time > 0.0 and final_intro <= 0.0   # 「最終決戰」大字出現時先不顯示
		hud_final_hint.modulate.a = clampf(final_hint_time, 0.0, 1.0)
		final_frame.visible = true
		final_frame.queue_redraw()
	else:
		hud_time.text = _fmt_time(GAME_DURATION - elapsed)
	hud_kills.text = "級 %d　金 %d/%d　擊倒 %d\n敵血 ×%.1f" % [level, xp, _xp_needed(), kills, _hp_mult()]


func _end(result: State) -> void:
	state = result
	audio.stop_music()
	audio.play("lose" if result == State.DEAD else "win")
	_update_hud()
	player.modulate.a = 1.0
	var title := "你擊敗了最終王！"
	if result == State.DEAD:
		title = "你倒下了"
		player.set_text("亡")
	if tokens_earned < 0:
		tokens_earned = Meta.tokens_for_run(elapsed, result == State.WON)
		Meta.tokens += tokens_earned
		Meta.save()
	var stats := "難度 %s　存活 %s　級 %d　擊倒 %d　金 %d　鑽 +%d（共 %d）" % [DIFFICULTIES[difficulty].name, _fmt_time(elapsed), level, kills, gold, tokens_earned, Meta.tokens]
	# 手機：要點「再來一局」按鈕才重開（避免手指誤觸直接跳過）；電腦維持原本按 Space / Enter
	if is_touch:
		level_cards.show_cards(title, _final_level_cards(), -1, "", stats, [], "再來一局")
	else:
		level_cards.show_cards(title, _final_level_cards(), -1, "按 Space / Enter 再來一局", stats)
	level_cards.set_side("擊倒", _kill_rows())


## 結算畫面右邊的擊倒統計：照 ENEMY_TYPES 的順序，只列有打倒的種類
func _kill_rows() -> Array:
	var rows := []
	for kind: String in ENEMY_TYPES:
		var count: int = kills_by_kind.get(kind, 0)
		if count > 0:
			rows.append({"glyph": kind, "color": ENEMY_TYPES[kind]["color"], "text": "× %d" % count})
	# 王、大字王
	if kills_by_kind.get("王", 0) > 0:
		rows.append({"glyph": "王", "color": COLOR_ENEMY_BOSS, "text": "× %d" % kills_by_kind["王"]})
	for k: String in BIG_KINDS:
		var count: int = kills_by_kind.get("大" + k, 0)
		if count > 0:
			rows.append({"glyph": "大" + k, "color": ENEMY_TYPES[k]["color"], "text": "× %d" % count})
	if rows.is_empty():
		rows.append({"glyph": "", "color": Color.WHITE, "text": "一隻都沒有"})
	return rows


## 結算畫面的卡片：兩條強化線，加上每一個升過的金升級
func _final_level_cards() -> Array:
	var who: String = CHARACTERS[character].glyph
	var cards := []
	for line: String in _lines():
		var info: Dictionary = POWER_INFO[who][line]
		var lv := _line_level(line)
		var desc: String = info.desc[lv] if lv < info.desc.size() else ""
		if lv == 0:
			desc = "沒有拿到"
		cards.append({"icon": line, "name": info.name, "sub": "Lv %d" % lv, "desc": desc})
	for u: Dictionary in UPGRADES:
		var lv: int = upgrade_levels.get(u.id, 0)
		if lv > 0:
			cards.append({"icon": u.icon, "name": u.name, "sub": "Lv %d" % lv, "desc": "%s\n（×%d）" % [u.desc, lv]})
	return cards


func _fmt_time(t: float) -> String:
	var s := int(ceil(t))
	return "%02d:%02d" % [s / 60, s % 60]
