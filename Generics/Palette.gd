####################
# Palette
# Class representing a color palette to be used as an inbetween various color formats.
####################
class_name Palette

var colors: PackedColorArray = []

var myTex: ImageTexture

func size() -> int:
	return colors.size();

func addColor(c: Color) -> void:
	colors.append(c)

func getColor(c: int, a: int = 255) -> Color:
	if (c < colors.size()):
		return Color(colors[c], a)
	else:
		#print("BAD COLOR REQUEST")
		return Color.WHITE

func replaceColor(i: int, c: Color) -> void:
	if (i < colors.size()):
		colors[i] = c

func getColorBlend(c: int, blend: float) -> Color:
	if (c + 1 < colors.size()):
		return colors[c].lerp(colors[c + 1], blend)
	else:
		return Color.WHITE
	
func genTex() -> ImageTexture:
	var i := 1
	while (i*i < colors.size()):
		i += 1
	var image := Image.create_empty(i, i, false, Image.FORMAT_RGBA8)
	var j := 0
	while (j < colors.size()):
		image.set_pixel(j % i, j/i, colors[j])
		j += 1
	return ImageTexture.create_from_image(image)

static func greyscale() -> Palette:
	var retPal := Palette.new()
	var i := 0
	while(i < 16):
		retPal.addColor(Color8(208 - 13 * i, 208 - 13 * i, 208 - 13 * i))
		i += 1
	return retPal
