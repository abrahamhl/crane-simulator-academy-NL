extends RefCounted
## Fixed-stride telemetry recorder. Feeds the debrief, the debug overlay and
## the determinism tests (state hash over the full recorded trajectory).

const STRIDE := 12  # t, load xyz, support xyz, tension, swing_deg, wind xyz

var data := PackedFloat64Array()
var max_swing_deg := 0.0
var max_tension := 0.0
var path_length := 0.0

var _last_load := Vector3.INF


func record(t: float, load: Vector3, support: Vector3, tension: float,
		swing_deg: float, wind: Vector3) -> void:
	data.append(t)
	data.append(load.x); data.append(load.y); data.append(load.z)
	data.append(support.x); data.append(support.y); data.append(support.z)
	data.append(tension)
	data.append(swing_deg)
	data.append(wind.x); data.append(wind.y); data.append(wind.z)
	max_swing_deg = maxf(max_swing_deg, swing_deg)
	max_tension = maxf(max_tension, tension)
	if _last_load.is_finite():
		path_length += _last_load.distance_to(load)
	_last_load = load


func count() -> int:
	return data.size() / STRIDE


func state_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(data.to_byte_array())
	return ctx.finish().hex_encode()


func to_csv(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_line("t,load_x,load_y,load_z,sup_x,sup_y,sup_z,tension_n,swing_deg,wind_x,wind_y,wind_z")
	var n := count()
	for i in n:
		var row := PackedStringArray()
		for j in STRIDE:
			row.append("%.6f" % data[i * STRIDE + j])
		f.store_line(",".join(row))
	f.close()
	return true
