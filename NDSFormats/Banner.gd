####################
# Banner Fileformat
# Format of NDS Banner Icons
####################
class_name Banner

@warning_ignore_start("integer_division")
@warning_ignore_start("int_as_enum_without_cast")

static func getImage(bytes: PackedByteArray) -> IndexedImage:
	var iconBytes = bytes.slice(0x020, 0x220)
	var returnImage = IndexedImage.new(32, 32, 4, 0)	
	NCGR.Tiled(returnImage, iconBytes)
	return returnImage

static func getPal(bytes: PackedByteArray) -> Palette:
	var pltBytes = bytes.slice(0x220, 0x240)
	var pal = Palette.new()
	var i = 0
	while(i < 16):
		pal.addColor(ColorUtil.from_RGB15(pltBytes.decode_u16(i * 2)))
		i += 1
	return pal

# This result goes from 0x20 to 0x240 in Banner.BIN
static func writeBanner(image: IndexedImage, pal: Palette) -> PackedByteArray:
	var palBytes: PackedByteArray = PackedByteArray()
	palBytes.resize(0x20)
	
	if (pal.size() > 16):
		# Too many colors
		return []
	
	if (image.width != 32 || image.height != 32):
		# Wrong size
		return []
	
	var i = 0
	while(i < pal.size()):
		palBytes.encode_u16((i * 2), ColorUtil.to_RGB15(pal.getColor(i)))
		i += 1
	
	var returnBytes := NCGR.writeTiled(image)
	#returnBytes.append_array(palBytes)
	return returnBytes
