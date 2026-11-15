extends RefCounted
static var cache: Dictionary = {}
# Rename visible prose only; resource IDs and asset paths remain save-compatible.
static func format(value: String) -> String:
	if cache.has(value): return cache[value]
	var tags := RegEx.new()
	tags.compile("(\\[[^\\]]*\\]|res://[^ ]+)")
	var result := ""
	var cursor := 0
	for tag in tags.search_all(value):
		result += prose(value.substr(cursor, tag.get_start() - cursor)) + tag.get_string().replace("res://assets/items/verdite.svg", "res://assets/items/plutonium.svg")
		cursor = tag.get_end()
	result += prose(value.substr(cursor))
	if cache.size() >= 512: cache.clear()
	cache[value] = result
	return result
static func prose(value: String) -> String:
	var plutonium := RegEx.create_from_string("(?i)\\bverdite\\b")
	value = plutonium.sub(value, "plutonium", true)
	for pair in [["pink material", "Pink Stuff"], ["pink stuff", "Pink Stuff"], ["pink(?!\\s+stuff)", "Pink Stuff"], ["copper", "chicken nuggets"], ["iron", "fish scales"], ["ores", "resources"], ["ore deposit", "resource deposit"], ["ore", "resources"]]:
		var pattern := RegEx.new()
		pattern.compile("(?i)\\b" + pair[0] + "\\b")
		value = pattern.sub(value, pair[1], true)
	return value.replace("an resource", "a resource").replace("An resource", "A resource")
