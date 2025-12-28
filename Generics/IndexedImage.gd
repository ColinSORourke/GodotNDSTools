####################
# IndexedImage
# Class representing an IndexedImage to be used as an inbetween various image formats.
####################

class_name IndexedImage

enum AlphaMode {
	NONE, ## No Alpha Data
	ZERO, ## Color 0 is Transparent
	DATA, ## There is Alpha Data Buffer
}

var pixeldata: PackedByteArray
var alphadata: PackedByteArray

var width: int
var height: int
var bpp: int = 4 ## Bits per pixel
var ppb: int = 2 ## Pixels per byte
var mode: AlphaMode = AlphaMode.NONE

var err_count: int = 0 ## counts out of bounds pixel requests.

func _init(w: int, h: int, b: int, m: AlphaMode) -> void:
	if (w <= 0):
		print("Bad Width, defaulting to 32")
		w = 32
	if (h <= 0):
		print("Bad height, defaulting to 32")
		h = 32
	if (b <= 0):
		print("Bad bpp, defaulting to 4")
		b = 4
	
	width = w
	height = h
	bpp = b
	mode = m
	
	if (bpp == 2 || bpp == 4):
		ppb = 8 / bpp
	
	if (b == 3 || b == 5) && mode != AlphaMode.DATA:
		print("Bits Per Pixel of 3 & 5 expects AlphaMode.DATA. Image may misbehave")
	
	pixeldata = PackedByteArray()
	pixeldata.resize(width * height)
	alphadata = PackedByteArray()
	alphadata.resize(width * height)
	alphadata.fill(255)

func set_pixel(x: int, y: int, c: int) -> void:
	if (x >= width || y >= height || x < 0 || y < 0):
		err_count += 1
		return
	
	if (c >= 2 ** bpp):
		err_count += 1
		return
	
	pixeldata[y * width + x] = c
	
func set_pixel_alpha(x: int, y: int, a: int) -> void:
	if (mode == AlphaMode.NONE):
		err_count += 1
		return
	
	if (x >= width || y >= height):
		err_count += 1
		return
	
	alphadata[y * width + x] = a

func set_pixel_byte(x: int, y: int, byte: int) -> void:
	var color: int = 0
	var alpha: int = 255
	match(bpp):
		2:
			color = byte >> (x % 4) * 2 & 0x3 
		4:
			color = byte >> (x % 2) * 4 & 0xF
		8:
			color = byte
		3:
			color = (byte & 0xE0) >> 5
			alpha = (byte & 0x1F) << 3
		5:
			color = (byte & 0xF8) >> 3
			alpha = (byte & 0x07) << 5
	
	set_pixel(x, y, color)
	if (mode == AlphaMode.DATA):
		set_pixel_alpha(x, y, alpha)
	if (mode == AlphaMode.ZERO && color == 0):
		set_pixel_alpha(x, y, 0)

func pack_pixels(x: int, y: int) -> int:
	var pix: int = 1
	if (bpp == 2 || bpp == 4):
		pix = 8 / bpp
	if (x > width - pix || y >= height):
		return 0
	
	var byte: int = 0
	var ind: int = y * width + x
	match(bpp):
		2:
			byte |= pixeldata[ind]
			byte |= pixeldata[ind + 1] << 2
			byte |= pixeldata[ind + 2] << 4
			byte |= pixeldata[ind + 3] << 6
		4:
			byte |= pixeldata[ind]
			byte |= pixeldata[ind + 1] << 4
		8:
			byte = pixeldata[ind]
		3:
			byte |= pixeldata[ind] << 5
			byte |= alphadata[ind] >> 3
		5:
			byte |= pixeldata[ind] << 3
			byte |= alphadata[ind] >> 5
	return byte

func get_packed_data() -> PackedByteArray:
	var retBytes := PackedByteArray()
	retBytes.resize(width * height / ppb)
	
	var i := 0
	while(i < pixeldata.size()):
		#print("Packing Pixels %s, %s into Byte %s" % [i % width, i / width, i/ppb])
		retBytes[i/ppb] = pack_pixels(i % width, i / width)
		i += ppb
	
	return retBytes

func get_packed_size() -> int:
	return width * height / ppb

func get_region(x: int, y: int, w: int, h: int) -> PackedByteArray:
	if (x + w > width || y + h > height || x < 0 || y < 0 || w < 0 || h < 0):
		print("Selected Region (%s, %s, %s, %s) is out of bounds" % [x, y, w, h])
		return []
	
	var retBytes := PackedByteArray()
	var i := 0
	while (i < h):
		var j := 0
		while (j < w):
			retBytes.append(pack_pixels(x + j, y + i))
			j += ppb
		i += 1
	
	return retBytes

func set_region(x: int, y: int, w: int, h: int, r_bytes: PackedByteArray) -> void:
	if (x + w > width || y + h > height || x < 0 || y < 0 || w < 0 || h < 0):
		print("Selected Region (%s, %s, %s, %s) is out of bounds" % [x, y, w, h])
		return
	
	if (w * h / ppb != r_bytes.size()):
		print("Given bytes does not match given region size (%s, %s, %s)" % [r_bytes.size(), w*h, bpp])
		return
	
	var i := 0
	while (i < h):
		var j := 0
		while (j < w):
			var ind: int = (i * w / ppb) + (j / ppb)
			set_pixel_byte(x + j, y + i, r_bytes[ind])
			j += 1
		i += 1
	
func create_texture(pal: Palette) -> ImageTexture:
	if (pal.size() !=  2 ** bpp):
		print("Palette does not have enough colors (%s), image may look wrong" % pal.size())
	
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var i := 0
	while (i < pixeldata.size()):
		image.set_pixel(i % width, i / width, pal.getColor(pixeldata[i], alphadata[i]))
		i += 1
	
	return ImageTexture.create_from_image(image)
