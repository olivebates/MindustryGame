extends RefCounted
## Cargo timing and repeating belt markings share a single physical speed.
const TILE := 32.0
const TRAVEL_SECONDS := 1.0
const SPEED := TILE / TRAVEL_SECONDS
const ARROW_SPACING := TILE / 2.0
const DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

static func arrow_phase(time: float) -> float:
	return fposmod(time * SPEED, ARROW_SPACING)

static func path_point(direction: int, incoming: int, distance: float) -> Vector2:
	var output: Vector2 = DIRECTIONS[direction]
	var corner := (direction - incoming + 4) % 2 == 1
	if not corner: return output * (distance - TILE / 2.0)
	if distance < TILE / 2.0: return DIRECTIONS[incoming] * (distance - TILE / 2.0)
	return output * (distance - TILE / 2.0)

static func clip_line(start: Vector2, end: Vector2) -> PackedVector2Array:
	# Parametric clipping lets a chevron enter/leave a tile without popping.
	var delta := end - start
	var low := 0.0
	var high := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.000001:
			if absf(start[axis]) > TILE / 2.0: return PackedVector2Array()
		else:
			var first: float = (-TILE / 2.0 - start[axis]) / delta[axis]
			var second: float = (TILE / 2.0 - start[axis]) / delta[axis]
			low = maxf(low, minf(first, second))
			high = minf(high, maxf(first, second))
			if low >= high: return PackedVector2Array()
	return PackedVector2Array([start + delta * low, start + delta * high])

static func arrow_segments(direction: int, incoming: int, time: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var phase := arrow_phase(time)
	for index in range(-1, 3):
		var distance := phase + index * ARROW_SPACING
		var tip := path_point(direction, incoming, distance + 2.0)
		var tail := path_point(direction, incoming, distance - 2.0)
		var tangent := (path_point(direction, incoming, distance + 0.1) - path_point(direction, incoming, distance - 0.1)).normalized()
		var side := Vector2(-tangent.y, tangent.x) * 3.5
		for start in [tail + side, tail - side]:
			var line := clip_line(start, tip)
			if line.size() == 2: result.append(line)
	return result
