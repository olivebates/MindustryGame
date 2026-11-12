extends RichTextEffect
var bbcode := "base_stat"
func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	char_fx.color.a *= 0.4
	return true
