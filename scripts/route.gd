extends RefCounted

var pts: PackedVector3Array = PackedVector3Array()
var cum: PackedFloat32Array = PackedFloat32Array()
var total: float = 0.0

func _init(level: Dictionary) -> void:
	_build(level)
	_measure()


func _build(level: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level["seed"])
	var length: float = float(level["length"])
	var style := str(level["biome"])
	var pos := Vector3.ZERO
	var heading := 0.0
	pts = PackedVector3Array()
	pts.push_back(pos)
	var traveled := 0.0
	var step := 16.0
	while traveled < length:
		if style == "mountain":
			var phase := fposmod(traveled, 200.0)
			var target := -1.15
			if phase >= 90.0 and phase <= 110.0:
				target = lerpf(-1.15, 1.15, (phase - 90.0) / 20.0)
			elif phase > 110.0:
				target = 1.15
			heading = lerpf(heading, target, 0.5)
		elif style == "forest":
			heading += rng.randf_range(-0.38, 0.38)
			heading = clampf(heading, -1.05, 1.05)
		else:
			heading += rng.randf_range(-0.2, 0.2)
			heading *= 0.92
			heading = clampf(heading, -0.62, 0.62)
		var dir := Vector3(sin(heading), 0.0, cos(heading))
		pos += dir * step
		pts.push_back(pos)
		traveled += step


func _measure() -> void:
	cum = PackedFloat32Array()
	cum.push_back(0.0)
	total = 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
		cum.push_back(total)


func sample(dist: float) -> Dictionary:
	var dir := Vector3(0, 0, 1)
	var pos := Vector3.ZERO
	if pts.size() < 2:
		return {"pos": pos, "dir": dir, "right": Vector3.RIGHT}
	var d0: Vector3 = pts[1] - pts[0]
	d0.y = 0.0
	if d0.length() < 0.001:
		d0 = Vector3(0, 0, 1)
	d0 = d0.normalized()
	var dend: Vector3 = pts[pts.size() - 1] - pts[pts.size() - 2]
	dend.y = 0.0
	if dend.length() < 0.001:
		dend = d0
	dend = dend.normalized()
	if dist <= 0.0:
		pos = pts[0] + d0 * dist
		dir = d0
	elif dist >= total:
		pos = pts[pts.size() - 1] + dend * (dist - total)
		dir = dend
	else:
		var i := 0
		while i < cum.size() - 2 and cum[i + 1] < dist:
			i += 1
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := b - a
		var seglen: float = cum[i + 1] - cum[i]
		var t := 0.0 if seglen < 0.0001 else (dist - cum[i]) / seglen
		pos = a.lerp(b, t)
		dir = seg.normalized() if seg.length() > 0.001 else d0
	var right := Vector3(dir.z, 0.0, -dir.x)
	if right.length() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	pos.y = 0.0
	return {"pos": pos, "dir": dir, "right": right}


func point(dist: float, lateral: float = 0.0) -> Vector3:
	var s: Dictionary = sample(dist)
	return s["pos"] + s["right"] * lateral


func distance_to_route(p: Vector3) -> float:
	var best := 1.0e9
	if pts.is_empty():
		return best
	var d0: Vector3 = sample(0.0)["dir"]
	var back: Vector3 = pts[0] - d0 * 90.0
	best = minf(best, _dist_seg(p, back, pts[0]))
	for i in range(pts.size() - 1):
		best = minf(best, _dist_seg(p, pts[i], pts[i + 1]))
	var dend: Vector3 = sample(total)["dir"]
	var ahead: Vector3 = pts[pts.size() - 1] + dend * 40.0
	best = minf(best, _dist_seg(p, pts[pts.size() - 1], ahead))
	return best


func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var ap := Vector3(p.x - a.x, 0.0, p.z - a.z)
	var denom := ab.length_squared()
	var t := 0.0 if denom < 0.0001 else clampf(ap.dot(ab) / denom, 0.0, 1.0)
	var closest := Vector3(a.x, 0.0, a.z) + ab * t
	return Vector2(p.x, p.z).distance_to(Vector2(closest.x, closest.z))


func bounds(margin: float) -> Rect2:
	var min_x := 1.0e9
	var max_x := -1.0e9
	var min_z := 1.0e9
	var max_z := -1.0e9
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	min_z -= 90.0
	return Rect2(min_x - margin, min_z - margin, (max_x - min_x) + margin * 2.0, (max_z - min_z) + margin * 2.0)
