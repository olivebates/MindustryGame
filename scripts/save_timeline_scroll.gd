extends ScrollContainer
var slider: HSlider
var held := false
var moved := false
var origin := Vector2.ZERO
var scroll_origin := 0
func _ready() -> void:
	get_h_scroll_bar().value_changed.connect(func(_value: float): sync_slider())
	if is_instance_valid(slider):
		slider.value_changed.connect(func(value: float): scroll_horizontal = roundi(value * scroll_limit()))
func scroll_limit() -> float:
	var bar := get_h_scroll_bar()
	return maxf(0, bar.max_value - bar.page)
func sync_slider() -> void:
	if not is_instance_valid(slider): return
	slider.editable = scroll_limit() > 0
	slider.set_value_no_signal(float(scroll_horizontal) / maxf(1, scroll_limit()))
func scroll_to_newest() -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	scroll_horizontal = roundi(scroll_limit())
	sync_slider()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed: scroll_horizontal += -120 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 120
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				held = true
				moved = false
				origin = event.position
				scroll_origin = scroll_horizontal
			else:
				var click: bool = held and not moved and event.button_index == MOUSE_BUTTON_LEFT
				held = false
				if click:
					for card in get_child(0).get_children():
						if card is Button and card.get_global_rect().has_point(get_global_mouse_position()):
							card.pressed.emit()
							break
			accept_event()
	elif event is InputEventMouseMotion and held:
		if event.position.distance_to(origin) >= 6: moved = true
		if moved: scroll_horizontal = scroll_origin - roundi(event.position.x - origin.x)
		accept_event()
