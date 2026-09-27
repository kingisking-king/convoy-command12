extends Control

var route = null
var blips: Array = []
var lead := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(210, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(p_route, p_blips: Array, p_lead: float) -> void:
	route = p_route
	blips = p_blips
	lead = p_lead
	queue_redraw()


func _draw() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.05, 0.78)
	bg.border_color = Color(0.55, 0.48, 0.28, 0.8)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	if route == null or route.pts.size() < 2:
		return
	var bounds: Rect2 = route.bounds(30.0)
	var pad := 12.0
	var poly := PackedVector2Array()
	for p in route.pts:
		poly.append(_map(p.x, p.z, bounds, pad))
	if poly.size() >= 2:
		draw_polyline(poly, Color(0.86, 0.72, 0.38), 2.0, true)
	var start := _map(route.pts[0].x, route.pts[0].z, bounds, pad)
	var endp := _map(route.pts[route.pts.size() - 1].x, route.pts[route.pts.size() - 1].z, bounds, pad)
	draw_circle(start, 3.5, Color(0.75, 0.85, 0.7))
	draw_circle(endp, 4.0, Color(0.45, 0.9, 0.5))
	if route.total > 0.0:
		var sm: Dictionary = route.sample(lead)
		var lp: Vector3 = sm["pos"]
		draw_circle(_map(lp.x, lp.z, bounds, pad), 3.2, Color(0.96, 0.95, 0.88))
	for blip in blips:
		draw_circle(_map(float(blip["x"]), float(blip["z"]), bounds, pad), float(blip["r"]), blip["color"])


func _map(x: float, z: float, bounds: Rect2, pad: float) -> Vector2:
	var u := (x - bounds.position.x) / maxf(bounds.size.x, 1.0)
	var v := (z - bounds.position.y) / maxf(bounds.size.y, 1.0)
	return Vector2(pad + u * (size.x - pad * 2.0), size.y - pad - v * (size.y - pad * 2.0))
