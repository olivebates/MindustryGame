extends RefCounted
const VALUES := [1000, 200, 50, 20, 5, 1]
const COLORS := {1: Color("b3aaa1"), 5: Color("70b4ff"), 20: Color("fa7066"), 50: Color("ba86ed"), 200: Color("ffad57"), 1000: Color("fa87cf")}
static func split(amount: int) -> Array[int]:
	var result: Array[int] = []
	for value in VALUES:
		while amount >= value:
			result.append(value)
			amount -= value
	return result
