class_name TextParticles
extends Node2D
## 文字粒子：傷害數字、敵人碎開的筆畫、死亡時放大淡出的字。
## 全部由這一個節點畫，不會因為敵人很多就產生一大堆節點。

class Particle:
	var text: String
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: int
	var color: Color
	var rot := 0.0
	var spin := 0.0
	var grow := 0.0           # 每秒放大多少（死亡的「啵」）
	var drag := 0.0           # 每秒速度衰減比例

var particles: Array[Particle] = []


func add(text: String, pos: Vector2, vel: Vector2, life: float, size: int, color: Color) -> Particle:
	var p := Particle.new()
	p.text = text
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.size = size
	p.color = color
	particles.append(p)
	return p


func _process(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.life -= delta
		if p.life <= 0.0:
			particles.remove_at(i)
			continue
		p.pos += p.vel * delta
		p.vel *= maxf(0.0, 1.0 - p.drag * delta)
		p.rot += p.spin * delta
	queue_redraw()


func _draw() -> void:
	var font := Glyph.font
	for p in particles:
		var t := p.life / p.max_life
		var scale := 1.0 + p.grow * (p.max_life - p.life)
		var s := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.size)
		var ascent := font.get_ascent(p.size)
		draw_set_transform(p.pos, p.rot, Vector2(scale, scale))
		draw_string(font, Vector2(-s.x / 2.0, ascent - s.y / 2.0), p.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, p.size, Color(p.color, p.color.a * t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
