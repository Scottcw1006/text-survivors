class_name Terrain
extends Node2D
## 地形：無限大的格子世界。
## - 「牆」用 noise 產生成一團一團的地形，會擋住玩家、敵人和子彈
## - 空地上稀疏地鋪暗色的「草 艸 石」
## - 每隔一段時間從玩家位置做一次 BFS，算出「往玩家走的路」，讓敵人會繞牆

const CELL := 36.0
const WALL_CHAR := "牆"
const WALL_COLOR := Color(0.85, 0.85, 0.85)
const WALL_THRESHOLD := 0.28      # 越小牆越多
const NOISE_FREQUENCY := 0.07     # 越小牆團越大
const SAFE_RADIUS := 5            # 出生點附近幾格保證沒牆
const GROUND_CHARS := ["草", "艸", "石", "．"]
const GROUND_DENSITY := 8         # 百分之幾的空地有草
const GROUND_COLOR := Color(1, 1, 1, 0.12)

const FLOW_RADIUS := 40           # 尋路範圍（格），要涵蓋畫面外的生成位置（畫面 2560×1440）
const FLOW_SIZE := FLOW_RADIUS * 2 + 1

var font: Font
var wall_char := WALL_CHAR       # 地獄難度改成「焰」
var wall_color := WALL_COLOR
var font_size := 33
var noise := FastNoiseLite.new()

var _center_cell := Vector2i(999999, 999999)
var _flow_origin := Vector2i.ZERO
var _flow := PackedInt32Array()   # 每格到玩家的步數，-1 = 到不了


func _init() -> void:
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = NOISE_FREQUENCY


# ---------- 查詢 ----------

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func is_wall(c: Vector2i) -> bool:
	if c.x * c.x + c.y * c.y <= SAFE_RADIUS * SAFE_RADIUS:
		return false
	return noise.get_noise_2d(c.x, c.y) > WALL_THRESHOLD


## 半徑 r 的圓放在 p 會不會卡進牆
func overlaps_wall(p: Vector2, r: float) -> bool:
	var a := cell_of(p - Vector2(r, r))
	var b := cell_of(p + Vector2(r, r))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var c := Vector2i(x, y)
			if not is_wall(c):
				continue
			var lo := Vector2(c) * CELL
			var closest := p.clamp(lo, lo + Vector2(CELL, CELL))
			if closest.distance_squared_to(p) < r * r:
				return true
	return false


## 嘗試移動，撞牆的那個軸就不動（可以沿著牆滑）
func slide(pos: Vector2, motion: Vector2, r: float) -> Vector2:
	# 已經卡在牆裡的話就放行，讓它能自己走出來（保險，正常不會發生）
	if overlaps_wall(pos, r):
		return pos + motion
	var p := pos
	p.x += motion.x
	if overlaps_wall(p, r):
		p.x = pos.x
	p.y += motion.y
	if overlaps_wall(p, r):
		p.y = pos.y
	return p


# ---------- 尋路（flow field）----------

func update_flow(target: Vector2) -> void:
	_flow_origin = cell_of(target)
	_flow.resize(FLOW_SIZE * FLOW_SIZE)
	_flow.fill(-1)
	var queue: Array[Vector2i] = [_flow_origin]
	_flow[_flow_index(_flow_origin)] = 0
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while head < queue.size():
		var c := queue[head]
		head += 1
		var d := _flow[_flow_index(c)]
		for dir in dirs:
			var n := c + dir
			var i := _flow_index(n)
			if i < 0 or _flow[i] != -1 or is_wall(n):
				continue
			_flow[i] = d + 1
			queue.append(n)


## 從格子 c 走到玩家要幾步，-1 = 到不了或超出尋路範圍
func flow_distance(c: Vector2i) -> int:
	var i := _flow_index(c)
	return -1 if i < 0 else _flow[i]


## 站在 p 的敵人應該往哪個方向走
func flow_direction(p: Vector2, target: Vector2) -> Vector2:
	var c := cell_of(p)
	var d := flow_distance(c)
	if d <= 1:
		return (target - p).normalized()
	var best := c
	var best_d := d
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n := c + Vector2i(dx, dy)
			# 斜走時兩側都要是空地，避免卡在牆角
			if dx != 0 and dy != 0 and (is_wall(c + Vector2i(dx, 0)) or is_wall(c + Vector2i(0, dy))):
				continue
			var nd := flow_distance(n)
			if nd >= 0 and nd < best_d:
				best_d = nd
				best = n
	if best == c:
		return (target - p).normalized()
	return (cell_center(best) - p).normalized()


func _flow_index(c: Vector2i) -> int:
	var x := c.x - _flow_origin.x + FLOW_RADIUS
	var y := c.y - _flow_origin.y + FLOW_RADIUS
	if x < 0 or y < 0 or x >= FLOW_SIZE or y >= FLOW_SIZE:
		return -1
	return y * FLOW_SIZE + x


# ---------- 繪製 ----------

func follow(pos: Vector2) -> void:
	var c := cell_of(pos)
	if c != _center_cell:
		_center_cell = c
		queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var cols := int(view.x / CELL) / 2 + 2
	var rows := int(view.y / CELL) / 2 + 2
	var ascent := font.get_ascent(font_size)
	var height := font.get_height(font_size)
	for dx in range(-cols, cols + 1):
		for dy in range(-rows, rows + 1):
			var c := _center_cell + Vector2i(dx, dy)
			var text := ""
			var color := wall_color
			var size := font_size
			if is_wall(c):
				text = wall_char
			else:
				var h := absi(hash(c))
				if h % 100 >= GROUND_DENSITY:
					continue
				text = GROUND_CHARS[(h / 100) % GROUND_CHARS.size()]
				color = GROUND_COLOR
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var center := cell_center(c)
			draw_string(font, Vector2(center.x - w / 2.0, center.y + ascent - height / 2.0),
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
