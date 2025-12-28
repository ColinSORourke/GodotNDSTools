####################
# JASC FileFormat
# https://liero.nl/lierohack/docformats/other-jasc.html
####################
class_name JASC

static func getPal(jasc: PackedStringArray) -> Palette:
	var pal := Palette.new()
	if(jasc[0] != "JASC-PAL"):
		# NOT A JASC PALETTE
		return
	var i := 3
	while (i < jasc.size() - 1):
		pal.addColor(ColorUtil.from_JASC_line(jasc[i]))
		i += 1
		
	return pal;
	
static func writeJasc(pal: Palette) -> PackedStringArray:
	var returnArray := PackedStringArray()
	returnArray.append("JASC-PAL")
	returnArray.append("0100")
	returnArray.append("256")
	var i := 0
	while (i < pal.size()):
		returnArray.append(ColorUtil.to_JASC_line(pal.getColor(i)))
		i += 1
	return returnArray
