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

const FLOW_RADIUS := 40           # 尋路範圍（格），要涵蓋畫面外的生成位置（電腦畫面 2560×1440）

var font: Font
var flow_radius := FLOW_RADIUS     # 手機模式畫面比較小，main 會依畫面大小調小（省時間）
var flow_size := FLOW_RADIUS * 2 + 1
var wall_char := WALL_CHAR       # 地獄難度改成「焰」
var wall_color := WALL_COLOR
var font_size := 33
var noise := FastNoiseLite.new()

var _center_cell := Vector2i(999999, 999999)
var _chunks := {}                 # 塊座標 -> Chunk（已經畫好的地形塊）
var _flow_origin := Vector2i.ZERO
var _flow := PackedInt32Array()   # 每格到玩家的步數，-1 = 到不了
var _flow_walls := PackedByteArray()   # 尋路範圍裡哪些格子是牆（1 = 牆）
var _flow_queue := PackedInt32Array()
var _wall_cache := {}             # 格子 -> 是不是牆（noise 算一次就記住，手機上省很多時間）
var _char_w := {}                 # 地形字的寬度（只有幾個字，量一次就好）

const WALL_CACHE_MAX := 300000    # 走太遠記太多格就清掉重記
const CHUNK := 8                  # 地形一塊幾格寬
const CHUNKS_PER_FRAME := 3       # 畫面外預先畫的塊，每一幀最多畫幾塊


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
	var v = _wall_cache.get(c)
	if v != null:
		return v
	var w := c.x * c.x + c.y * c.y > SAFE_RADIUS * SAFE_RADIUS and noise.get_noise_2d(c.x, c.y) > WALL_THRESHOLD
	if _wall_cache.size() >= WALL_CACHE_MAX:
		_wall_cache.clear()
	_wall_cache[c] = w
	return w


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
	# 用一維陣列做 BFS（不建 Vector2i、不呼叫函式），手機網頁上才不會每走一格就卡一下
	_flow_origin = cell_of(target)
	flow_size = flow_radius * 2 + 1
	var size := flow_size
	var total := size * size
	_flow.resize(total)
	_flow.fill(-1)
	_flow_walls.resize(total)
	_flow_queue.resize(total)
	var ox := _flow_origin.x - flow_radius
	var oy := _flow_origin.y - flow_radius
	var i := 0
	for y in size:
		for x in size:
			_flow_walls[i] = 1 if is_wall(Vector2i(ox + x, oy + y)) else 0
			i += 1
	var start := flow_radius * size + flow_radius
	_flow[start] = 0
	_flow_queue[0] = start
	var head := 0
	var tail := 1
	var last_row := total - size
	while head < tail:
		var c := _flow_queue[head]
		head += 1
		var d := _flow[c] + 1
		var x := c % size
		var n := c - 1
		if x > 0 and _flow[n] == -1 and _flow_walls[n] == 0:
			_flow[n] = d
			_flow_queue[tail] = n
			tail += 1
		n = c + 1
		if x < size - 1 and _flow[n] == -1 and _flow_walls[n] == 0:
			_flow[n] = d
			_flow_queue[tail] = n
			tail += 1
		n = c - size
		if c >= size and _flow[n] == -1 and _flow_walls[n] == 0:
			_flow[n] = d
			_flow_queue[tail] = n
			tail += 1
		n = c + size
		if c < last_row and _flow[n] == -1 and _flow_walls[n] == 0:
			_flow[n] = d
			_flow_queue[tail] = n
			tail += 1


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
	var x := c.x - _flow_origin.x + flow_radius
	var y := c.y - _flow_origin.y + flow_radius
	if x < 0 or y < 0 or x >= flow_size or y >= flow_size:
		return -1
	return y * flow_size + x


# ---------- 繪製 ----------

## 地形分成一塊一塊（CHUNK × CHUNK 格）畫，每塊是一個子節點：
## 畫過的塊不會再畫，走動時只畫邊緣新出現的塊，手機上才不會每走幾格就卡一下。
class Chunk:
	extends Node2D
	var terrain: Terrain
	var coord := Vector2i.ZERO

	func _draw() -> void:
		terrain._draw_chunk(self, coord)


func follow(pos: Vector2) -> void:
	_center_cell = cell_of(pos)
	var view := get_viewport_rect().size
	# 畫面看得到的塊一定要有；外面再多一圈，每一幀最多先畫幾塊（分散開來）
	var half := Vector2i(int(view.x / CELL) / 2 + 2, int(view.y / CELL) / 2 + 2)
	var lo := _chunk_of(_center_cell - half)
	var hi := _chunk_of(_center_cell + half)
	var budget := CHUNKS_PER_FRAME
	for cy in range(lo.y - 1, hi.y + 2):
		for cx in range(lo.x - 1, hi.x + 2):
			var k := Vector2i(cx, cy)
			if _chunks.has(k):
				continue
			var visible_now := cx >= lo.x and cx <= hi.x and cy >= lo.y and cy <= hi.y
			if not visible_now:
				if budget <= 0:
					continue
				budget -= 1
			var ch := Chunk.new()
			ch.terrain = self
			ch.coord = k
			add_child(ch)
			_chunks[k] = ch
	# 離太遠的塊丟掉
	for k: Vector2i in _chunks.keys():
		if k.x < lo.x - 2 or k.x > hi.x + 2 or k.y < lo.y - 2 or k.y > hi.y + 2:
			_chunks[k].queue_free()
			_chunks.erase(k)


## 牆的字、顏色或畫面大小改了：全部重畫
func refresh() -> void:
	for k: Vector2i in _chunks:
		_chunks[k].queue_redraw()


func _chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))


func _draw_chunk(ci: CanvasItem, k: Vector2i) -> void:
	var ascent := font.get_ascent(font_size)
	var height := font.get_height(font_size)
	for dy in CHUNK:
		for dx in CHUNK:
			var c := Vector2i(k.x * CHUNK + dx, k.y * CHUNK + dy)
			var text := ""
			var color := wall_color
			if is_wall(c):
				text = wall_char
			else:
				var h := absi(hash(c))
				if h % 100 >= GROUND_DENSITY:
					continue
				text = GROUND_CHARS[(h / 100) % GROUND_CHARS.size()]
				color = GROUND_COLOR
			var w: float = _char_w.get(text, -1.0)
			if w < 0.0:
				w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				_char_w[text] = w
			var center := cell_center(c)
			ci.draw_string(font, Vector2(center.x - w / 2.0, center.y + ascent - height / 2.0),
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
