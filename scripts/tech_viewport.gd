extends ScrollContainer
var graph: Control
var canvas: Control
var bounds := Rect2(Vector2.ZERO, Vector2.ONE)
var zoom := 1.0
var panning := false
var left_pending := false
var left_origin := Vector2.ZERO
var pan_button := MOUSE_BUTTON_NONE
var list_mode := false
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var pointer := get_local_mouse_position()
	if event is InputEventMouse: pointer = get_global_transform_with_canvas().affine_inverse() * event.position
	var inside := Rect2(Vector2.ZERO, size).has_point(pointer)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and inside:
				left_pending = true
				left_origin = event.position
			elif not event.pressed:
				left_pending = false
				if panning and pan_button == MOUSE_BUTTON_LEFT:
					panning = false
					clear_button_presses(graph)
					get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] and (inside or panning):
			panning = event.pressed
			pan_button = event.button_index
			get_viewport().set_input_as_handled()
		elif inside and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if list_mode: scroll_vertical += -80 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 80
			else: zoom_at(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, pointer)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if left_pending and not panning and event.position.distance_to(left_origin) >= 6:
			panning = true
			pan_button = MOUSE_BUTTON_LEFT
			clear_button_presses(graph)
		if panning:
			var movement := get_global_transform_with_canvas().basis_xform_inv(event.relative)
			scroll_horizontal -= roundi(movement.x)
			scroll_vertical -= roundi(movement.y)
			layout_graph()
			get_viewport().set_input_as_handled()
func clear_button_presses(node: Node) -> void:
	if node == null: return
	if node is BaseButton:
		node.set_pressed_no_signal(false)
		node.set_meta("held", false)
	for child in node.get_children(): clear_button_presses(child)
func configure(content: Control, region: Rect2) -> void:
	graph = content
	if list_mode: zoom = 1.0
	bounds = region if list_mode else region.grow(maxf(size.x, size.y) / (2 * zoom))
	if canvas == null:
		canvas = Control.new()
		canvas.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(canvas)
		if graph.get_parent() != null: graph.get_parent().remove_child(graph)
		canvas.add_child(graph)
	layout_graph()
func layout_graph() -> void:
	if graph == null: return
	var extent := bounds.size * zoom
	canvas.custom_minimum_size = extent.max(size)
	graph.scale = Vector2.ONE * zoom
	graph.position = -bounds.position * zoom + ((size) - extent).max(Vector2.ZERO) / 2
	scroll_horizontal = clampi(scroll_horizontal, 0, maxi(0, ceili(extent.x - size.x)))
	scroll_vertical = clampi(scroll_vertical, 0, maxi(0, ceili(extent.y - size.y)))
func center_on_tech(point: Vector2) -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	layout_graph()
	var offset := point * zoom + graph.position - size / 2
	scroll_horizontal = roundi(offset.x)
	scroll_vertical = roundi(offset.y)
	layout_graph()
func show_list_section(section_y: float) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not list_mode: return
	layout_graph()
	scroll_horizontal = 0
	scroll_vertical = maxi(0, roundi(section_y - 112))
func zoom_at(factor: float, point: Vector2) -> void:
	if graph == null or list_mode: return
	var before := (point + Vector2(scroll_horizontal, scroll_vertical) - graph.position) / zoom
	zoom = clampf(zoom * factor, 0.35, 1.5)
	layout_graph()
	var offset := before * zoom + graph.position - point
	scroll_horizontal = maxi(0, roundi(offset.x))
	scroll_vertical = maxi(0, roundi(offset.y))
	layout_graph()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			panning = event.pressed
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if list_mode: scroll_vertical += -80 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 80
			else: zoom_at(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, event.position)
			accept_event()
	elif event is InputEventMouseMotion and panning:
		scroll_horizontal -= roundi(event.relative.x)
		scroll_vertical -= roundi(event.relative.y)
		layout_graph()
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor, event.position)
		accept_event()
	elif event is InputEventPanGesture:
		scroll_horizontal += roundi(event.delta.x * 24)
		scroll_vertical += roundi(event.delta.y * 24)
		layout_graph()
		accept_event()

