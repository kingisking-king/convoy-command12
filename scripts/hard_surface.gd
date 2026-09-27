extends RefCounted

# Curved and chamfered triangle meshes. These are authored surfaces, not stacked BoxMesh nodes.
# Triangles are clockwise when seen from the outside, which is Godot's front face.


func add_bevel_box(st: SurfaceTool, center: Vector3, size: Vector3, bevel: float, rot: Vector3 = Vector3.ZERO) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var b := minf(bevel, minf(hx, minf(hy, hz)) * 0.45)
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), center)
	var v := {}
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				v[_key(sx, sy, sz, "x")] = Vector3(sx * (hx - b), sy * hy, sz * hz)
				v[_key(sx, sy, sz, "y")] = Vector3(sx * hx, sy * (hy - b), sz * hz)
				v[_key(sx, sy, sz, "z")] = Vector3(sx * hx, sy * hy, sz * (hz - b))
	_face_y(st, xf, v, 1.0)
	_face_y(st, xf, v, -1.0)
	_face_x(st, xf, v, 1.0)
	_face_x(st, xf, v, -1.0)
	_face_z(st, xf, v, 1.0)
	_face_z(st, xf, v, -1.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_edge_z(st, xf, v, sx, sy)
		for sz in [-1.0, 1.0]:
			_edge_y(st, xf, v, sx, sz)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_edge_x(st, xf, v, sy, sz)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var px: Vector3 = v[_key(sx, sy, sz, "x")]
				var py: Vector3 = v[_key(sx, sy, sz, "y")]
				var pz: Vector3 = v[_key(sx, sy, sz, "z")]
				var n := Vector3(sx, sy, sz).normalized()
				if sx * sy * sz > 0.0:
					_tri(st, xf, px, py, pz, n)
				else:
					_tri(st, xf, px, pz, py, n)


func add_cylinder(st: SurfaceTool, radius: float, height: float, center: Vector3, rot: Vector3 = Vector3.ZERO, segs: int = 18) -> void:
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), center)
	var h := height * 0.5
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * radius, h, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, h, sin(a1) * radius)
		var q0 := Vector3(p0.x, -h, p0.z)
		var q1 := Vector3(p1.x, -h, p1.z)
		var n := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		_quad(st, xf, p0, p1, q1, q0, n)
		_tri(st, xf, Vector3(0, h, 0), p1, p0, Vector3.UP)
		_tri(st, xf, Vector3(0, -h, 0), q0, q1, Vector3.DOWN)


func add_taper(st: SurfaceTool, r0: float, r1: float, height: float, center: Vector3, rot: Vector3 = Vector3.ZERO, segs: int = 16) -> void:
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), center)
	var h := height * 0.5
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * r0, h, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r0, h, sin(a1) * r0)
		var q0 := Vector3(cos(a0) * r1, -h, sin(a0) * r1)
		var q1 := Vector3(cos(a1) * r1, -h, sin(a1) * r1)
		var side := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var n := _outward_side(side, p0, p1, q0)
		_quad(st, xf, p0, p1, q1, q0, n)


func add_lathe(st: SurfaceTool, profile: PackedVector2Array, center: Vector3, rot: Vector3 = Vector3.ZERO, segs: int = 18) -> void:
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), center)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var side := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		for p in profile.size() - 1:
			var r0: float = profile[p].x
			var y0: float = profile[p].y
			var r1: float = profile[p + 1].x
			var y1: float = profile[p + 1].y
			if r0 < 0.001 and r1 < 0.001:
				continue
			var p0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var q0 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var q1 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var n := _outward_side(side, p0, p1, q0)
			_quad(st, xf, p0, p1, q1, q0, n)


func add_torus(st: SurfaceTool, major: float, minor: float, center: Vector3, rot: Vector3 = Vector3.ZERO, major_seg: int = 22, minor_seg: int = 10) -> void:
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), center)
	for i in major_seg:
		var a0 := TAU * float(i) / float(major_seg)
		var a1 := TAU * float(i + 1) / float(major_seg)
		var c0 := Vector3(cos(a0) * major, 0, sin(a0) * major)
		for j in minor_seg:
			var b0 := TAU * float(j) / float(minor_seg)
			var b1 := TAU * float(j + 1) / float(minor_seg)
			var p00 := _torus_pt(major, minor, a0, b0)
			var p10 := _torus_pt(major, minor, a1, b0)
			var p11 := _torus_pt(major, minor, a1, b1)
			var p01 := _torus_pt(major, minor, a0, b1)
			var n := (p00 - c0).normalized()
			if n.dot((p10 - p00).cross(p11 - p00)) < 0.0:
				_quad(st, xf, p00, p01, p11, p10, n)
			else:
				_quad(st, xf, p00, p10, p11, p01, n)


func add_track(st: SurfaceTool, x: float, length: float, radius: float, belt: float) -> void:
	var straight := maxf(0.2, length * 0.5 - radius)
	var steps := 28
	var pts: Array = []
	var normals_y: Array = []
	for i in steps:
		var ang := TAU * float(i) / float(steps)
		var local := _track_point(ang, radius, straight)
		pts.append(local)
		normals_y.append(local["n"])
	for i in steps:
		var i2 := (i + 1) % steps
		var c: Vector3 = pts[i]["p"]
		var d: Vector3 = pts[i2]["p"]
		var n: Vector3 = normals_y[i]
		var side := Vector3(belt * 0.5, 0, 0)
		var up := n * (belt * 0.32)
		var origin := Vector3(x, 0, 0)
		var a := c + origin + side + up
		var b := d + origin + side + up
		var e := d + origin - side + up
		var f := c + origin - side + up
		_quad(st, Transform3D.IDENTITY, a, b, e, f, n)
		var a2 := c + origin + side - up * 0.2
		var b2 := d + origin + side - up * 0.2
		var e2 := d + origin - side - up * 0.2
		var f2 := c + origin - side - up * 0.2
		_quad(st, Transform3D.IDENTITY, f2, e2, b2, a2, -n)
		var outer := Vector3(signf(x), 0, 0)
		_quad(st, Transform3D.IDENTITY, a, f, f2, a2, outer)
		_quad(st, Transform3D.IDENTITY, b2, e2, e, b, outer)


func _track_point(ang: float, radius: float, straight: float) -> Dictionary:
	var z := 0.0
	var y := 0.0
	var nz := 0.0
	var ny := 0.0
	if ang < PI:
		var a := ang - PI * 0.5
		z = sin(a) * radius
		y = -cos(a) * radius
		if ang < PI * 0.5:
			z -= straight
		else:
			z += straight
		ny = -cos(a)
		nz = sin(a)
	else:
		var a2 := ang - PI * 1.5
		z = sin(a2) * radius
		y = -cos(a2) * radius
		if ang < PI * 1.5:
			z += straight
		else:
			z -= straight
		ny = -cos(a2)
		nz = sin(a2)
	return {
		"p": Vector3(0, y + radius + 0.08, z),
		"n": Vector3(0, ny, nz).normalized(),
	}


func _torus_pt(major: float, minor: float, a: float, b: float) -> Vector3:
	var rr := major + cos(b) * minor
	return Vector3(cos(a) * rr, sin(b) * minor, sin(a) * rr)


func _outward_side(side: Vector3, p0: Vector3, p1: Vector3, q0: Vector3) -> Vector3:
	var n := (p1 - p0).cross(q0 - p0)
	if n.length_squared() < 0.0000001:
		n = side
	elif n.dot(side) < 0.0:
		n = -n
	return n.normalized()


func _key(sx: float, sy: float, sz: float, axis: String) -> String:
	return "%d%d%d_%s" % [int(sx), int(sy), int(sz), axis]


func _face_y(st: SurfaceTool, xf: Transform3D, v: Dictionary, sy: float) -> void:
	var s := sy
	var ring := [
		v[_key(-1, s, -1, "z")], v[_key(-1, s, 1, "z")],
		v[_key(-1, s, 1, "x")], v[_key(1, s, 1, "x")],
		v[_key(1, s, 1, "z")], v[_key(1, s, -1, "z")],
		v[_key(1, s, -1, "x")], v[_key(-1, s, -1, "x")],
	]
	_fan(st, xf, ring, Vector3(0, sy, 0), sy < 0.0)


func _face_x(st: SurfaceTool, xf: Transform3D, v: Dictionary, sx: float) -> void:
	var s := sx
	var ring := [
		v[_key(s, -1, -1, "z")], v[_key(s, -1, -1, "y")],
		v[_key(s, 1, -1, "y")], v[_key(s, 1, -1, "z")],
		v[_key(s, 1, 1, "z")], v[_key(s, 1, 1, "y")],
		v[_key(s, -1, 1, "y")], v[_key(s, -1, 1, "z")],
	]
	_fan(st, xf, ring, Vector3(sx, 0, 0), sx < 0.0)


func _face_z(st: SurfaceTool, xf: Transform3D, v: Dictionary, sz: float) -> void:
	var s := sz
	var ring := [
		v[_key(-1, -1, s, "y")], v[_key(-1, -1, s, "x")],
		v[_key(-1, 1, s, "x")], v[_key(-1, 1, s, "y")],
		v[_key(1, 1, s, "y")], v[_key(1, 1, s, "x")],
		v[_key(1, -1, s, "x")], v[_key(1, -1, s, "y")],
	]
	_fan(st, xf, ring, Vector3(0, 0, sz), sz < 0.0)


func _edge_z(st: SurfaceTool, xf: Transform3D, v: Dictionary, sx: float, sy: float) -> void:
	var n := Vector3(sx, sy, 0).normalized()
	if sx * sy > 0.0:
		_quad(st, xf,
			v[_key(sx, sy, -1, "y")], v[_key(sx, sy, -1, "x")],
			v[_key(sx, sy, 1, "x")], v[_key(sx, sy, 1, "y")], n)
	else:
		_quad(st, xf,
			v[_key(sx, sy, -1, "x")], v[_key(sx, sy, -1, "y")],
			v[_key(sx, sy, 1, "y")], v[_key(sx, sy, 1, "x")], n)


func _edge_y(st: SurfaceTool, xf: Transform3D, v: Dictionary, sx: float, sz: float) -> void:
	var n := Vector3(sx, 0, sz).normalized()
	if sx * sz > 0.0:
		_quad(st, xf,
			v[_key(sx, -1, sz, "x")], v[_key(sx, -1, sz, "z")],
			v[_key(sx, 1, sz, "z")], v[_key(sx, 1, sz, "x")], n)
	else:
		_quad(st, xf,
			v[_key(sx, -1, sz, "z")], v[_key(sx, -1, sz, "x")],
			v[_key(sx, 1, sz, "x")], v[_key(sx, 1, sz, "z")], n)


func _edge_x(st: SurfaceTool, xf: Transform3D, v: Dictionary, sy: float, sz: float) -> void:
	var n := Vector3(0, sy, sz).normalized()
	if sy * sz > 0.0:
		_quad(st, xf,
			v[_key(-1, sy, sz, "z")], v[_key(-1, sy, sz, "y")],
			v[_key(1, sy, sz, "y")], v[_key(1, sy, sz, "z")], n)
	else:
		_quad(st, xf,
			v[_key(-1, sy, sz, "y")], v[_key(-1, sy, sz, "z")],
			v[_key(1, sy, sz, "z")], v[_key(1, sy, sz, "y")], n)


func _fan(st: SurfaceTool, xf: Transform3D, ring: Array, normal: Vector3, reverse: bool) -> void:
	var pts: Array = ring
	if reverse:
		pts = []
		for i in range(ring.size() - 1, -1, -1):
			pts.append(ring[i])
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		_tri(st, xf, c, a, b, normal)


func _quad(st: SurfaceTool, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var wound := (b - a).cross(c - a)
	if wound.dot(normal) < 0.0:
		_tri(st, xf, a, c, b, normal)
		_tri(st, xf, a, d, c, normal)
	else:
		_tri(st, xf, a, b, c, normal)
		_tri(st, xf, a, c, d, normal)


func _tri(st: SurfaceTool, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var geo := (b - a).cross(c - a)
	# Outward normal, clockwise when looking at the face. Godot culls the other winding.
	if geo.dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	var n := (xf.basis * normal).normalized()
	if n.length_squared() < 0.0000001:
		n = (xf.basis * geo).normalized()
	st.set_normal(n)
	st.set_uv(Vector2(a.x, a.z) * 0.35)
	st.add_vertex(xf * a)
	st.set_normal(n)
	st.set_uv(Vector2(b.x, b.z) * 0.35)
	st.add_vertex(xf * b)
	st.set_normal(n)
	st.set_uv(Vector2(c.x, c.z) * 0.35)
	st.add_vertex(xf * c)
