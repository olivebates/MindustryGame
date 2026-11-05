extends RefCounted
const MIN_STROKE := 3.0
static func stroke(item: CanvasItem) -> float:
	var transform := item.get_screen_transform()
	var scale := minf(transform.x.length(), transform.y.length())
	# Two grid cells retain at least three physical pixels after snapping.
	return maxf(MIN_STROKE, 4.0 / maxf(0.001, scale))
