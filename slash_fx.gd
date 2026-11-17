class_name SlashFx
extends Node2D
## 刀的斬擊特效：用「斬」字鋪滿整個扇形攻擊範圍，
## 像刀鋒從一邊掃到另一邊，掃過的字亮起後淡出。
## 斬字是一圈一圈排的，範圍變大時圈數和每圈的字數都會跟著變多。

const CHAR := "斬"
const FONT_SIZE := 22
const SPACING := 24.0          # 字與字的間距，決定斬字密度
const INNER := 30.0            # 最內圈離主角多遠（避開主角本身）
const SWEEP_TIME := 0.07       # 刀鋒從一邊掃到另一邊的時間
const FADE_TIME := 0.10        # 每個字被掃到之後多久淡出
const LINGER_ALPHA := 0.45     # 殘留期間的亮度

var facing := 0.0
var arc := PI * 2.0 / 3.0
var reach := 108.0
var color := Color.WHITE
var linger := 0.0             # > 0：掃完之後留在原地幾秒（殘影斬、空間斬擊）
var clockwise := false         # 畫面上的順/逆時針（Godot 的 y 軸朝下，角度變大 = 順時針）

var _time := 0.0
var _marks: Array = []         # [{pos, angle_t, edge}]，angle_t = 0~1 在扇形中的位置


func setup(f: float, a: float, r: float, cw: bool) -> SlashFx:
	facing = f
	arc = a
	reach = r
	clockwise = cw
	_build_marks()
	return self


func _build_marks() -> void:
	_marks.clear()
	var r := INNER
	while r <= reach + 0.1:
		# 每一圈依弧長決定放幾個字，範圍越大字越多
		var count := maxi(2, int(round(arc * r / SPACING)) + 1)
		for i in count:
			var t := float(i) / (count - 1)
			var a := facing - arc / 2.0 + arc * t
			_marks.append({
				"pos": Vector2.from_angle(a) * r,
				"t": t,
				"edge": r + SPACING > reach,   # 最外圈是刀鋒，畫亮一點
			})
		r += SPACING


func _process(delta: float) -> void:
	_time += delta
	if _time > SWEEP_TIME + linger + FADE_TIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := Glyph.font
	var sweep := clampf(_time / SWEEP_TIME, 0.0, 1.0)
	var ascent := font.get_ascent(FONT_SIZE)
	var height := font.get_height(FONT_SIZE)
	var w := font.get_string_size(CHAR, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	for m: Dictionary in _marks:
		var t: float = m.t if clockwise else 1.0 - m.t
		if t > sweep:
			continue
		# 這個字被刀鋒掃到的時間點，之後慢慢淡出
		var since := _time - t * SWEEP_TIME
		var alpha: float
		if linger <= 0.0:
			alpha = clampf(1.0 - since / FADE_TIME, 0.0, 1.0)
		elif since < FADE_TIME:
			alpha = lerpf(1.0, LINGER_ALPHA, since / FADE_TIME)
		elif since < linger:
			alpha = LINGER_ALPHA * (0.8 + 0.2 * sin(_time * 20.0 + t * 6.0))  # 殘影微微閃動
		else:
			alpha = LINGER_ALPHA * clampf(1.0 - (since - linger) / FADE_TIME, 0.0, 1.0)
		if not m.edge:
			alpha *= 0.55
		var p: Vector2 = m.pos
		draw_string(font, Vector2(p.x - w / 2.0, p.y + ascent - height / 2.0), CHAR,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(color, alpha))
