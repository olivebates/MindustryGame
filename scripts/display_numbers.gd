extends RefCounted
## Shared display formatting. Stored quantities and gameplay calculations stay exact.
static func format(value: float) -> String:
	var divisor := 1.0
	var suffix := ""
	if absf(value) >= 1000000 or (absf(value) >= 1000 and roundf(absf(value) / 10.0) >= 100000):
		divisor = 1000000.0
		suffix = "m"
	elif absf(value) >= 1000:
		divisor = 1000.0
		suffix = "k"
	return ("%.2f" % (value / divisor)).trim_suffix("00").trim_suffix("0").trim_suffix(".") + suffix
