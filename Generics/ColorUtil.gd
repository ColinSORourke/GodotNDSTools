####################
# ColorUtil
# Class with some utility color functions
####################

class_name ColorUtil

static func from_RGB15(color: int) -> Color:
	var r: int = (color & 0x1F) * 8
	var g: int = (color >> 5 & 0x1F) * 8
	var b: int = (color >> 10 & 0x1F) * 8
	return Color8(r, g, b)

static func to_RGB15(color: Color) -> int:
	var byte = 0
	byte |= (color.r8 >> 3) 
	byte |= (color.g8 >> 3) << 5
	byte |= (color.b8 >> 3) << 10
	return byte

static func from_JASC_line(line: String) -> Color:
	var rgb := line.split(" ")
	if (rgb.size() != 3):
		print("Bad Jasc Line")
		return Color.WHITE
	return Color8(rgb[0].to_int(), rgb[1].to_int(), rgb[2].to_int())
	
static func to_JASC_line(color: Color) -> String:
	return "%s %s %s" % [color.r8, color.g8, color.b8]
