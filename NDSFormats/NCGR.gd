####################
# NCGR FileFormat
# https://github.com/AdAstra-LD/DS-Pokemon-Rom-Editor
####################
class_name NCGR

@warning_ignore_start("integer_division")
@warning_ignore_start("int_as_enum_without_cast")

const NCGRHeader: PackedByteArray = [
	0x52, 0x47, 0x43, 0x4E, # NCGR stamp
	0xFF, 0xFE, # Byte Order
	0x00, 0x01, # Version
	0x00, 0x00, 0x00, 0x00, # File Size
	0x10, 0x00, # Header size, 16
	0x01, 0x00] # Number of Chunks
const charHeader: PackedByteArray = [
	0x52, 0x41, 0x48, 0x43, # CHAR stamp
	0x00, 0x00, 0x00, 0x00, # Chunk Size
	0xFF, 0xFF, # Image Width >> 3 or 0xFFFF
	0xFF, 0xFF, # Image Height >> 3 or 0xFFFF
	0x03, 0x00, 0x00, 0x00, # Bit Depth - 3 = 4bpp, 4 = 8bpp
	0x00, 0x00, # Zero unless CPOS
	0x00, 0x00, # Zero unless CPOS
	0x00, # 1 for Scanned, 0 for Tiled
	0x00, # Zero
	0x00, # Zero 
	0x00, # Zero
	0x00, 0x00, 0x00, 0x00, # Data size in bytes (File size - 48), unless CPOS
	0x18, 0x00, 0x00, 0x00] # Offset from CHAR + 8 to Data, always 18

# 0x4E434752, 0x5247434E = "NCGR"
static func isNCGR(bytes: PackedByteArray) -> bool:
	if (bytes.size() < 4):
		return false
	if (bytes.decode_u32(0) != 0x4E434752 && bytes.decode_u32(0) != 0x5247434E):
		# NOT A NCGR FILE
		return false
	return true

static func findSquare(size) -> Vector2i:
	var square: float = sqrt(float(size))
	if (is_equal_approx(square, roundf(square))):
		return Vector2i(int(square), int(square))
	else:
		var numX = min(size, 0x100)
		return Vector2i(numX, size/numX)

static func getSprite(bytes: PackedByteArray, frontToBack := true, customNTiles := Vector2i(-1, -1)) -> IndexedImage:
	var width: int
	var height: int
	var bpp: int = 4 if bytes.decode_u32(28) == 3 else 8
	var scanned: bool = bytes.decode_u8(36) == 1
	var datasize: int = bytes.decode_u32(40)
	if (bytes.decode_u16(24) == 0xFFFF):
		if (bpp == 4):
			var squareSize = findSquare(datasize * 2)
			width = squareSize.x
			height = squareSize.y
		else:
			var squareSize = findSquare(datasize)
			width = squareSize.x
			height = squareSize.y
	else:
		height = bytes.decode_u16(24) * 8
		width = bytes.decode_u16(26) * 8

	var encKey: int = 0
	var returnImage := IndexedImage.new(width, height, bpp, 0)
	if (scanned):
		encKey = Scanned(returnImage, frontToBack, bytes.slice(48, 48 + datasize))
	else:
		Tiled(returnImage, bytes.slice(48, 48 + datasize))
		
	return returnImage

static func decrypt(frontToBack: bool, arr: PackedByteArray) -> int:
	var key: int = 0
	if (frontToBack):
		key = arr.decode_u16(0)
		var i = 0
		while(i < arr.size()):
			arr.encode_u16(i, arr.decode_u16(i) ^ (key & 0xFFFF))
			key *= 1103515245
			key += 24691
			i += 2
			
	else:
		key = arr.decode_u16(arr.size() - 2)
		var i = arr.size() - 2
		while (i >= 0):
			arr.encode_u16(i, arr.decode_u16(i) ^ (key & 0xFFFF))
			key *= 1103515245;
			key += 24691;
			i -= 2
			
	return (key & 0xFFFF)
	
static func encrypt(encKey: int, frontToBack: bool, arr: PackedByteArray) -> int:
	if (frontToBack):
		var i = arr.size() - 2
		while(i >= 0):
			encKey = (encKey - 24691) * 4005161829
			arr.encode_u16(i, arr.decode_u16(i) ^ (encKey & 0xFFFF))
			i -= 2
			
	else:
		var i = 0
		while (i <= arr.size() - 2):
			encKey = (encKey - 24691) * 4005161829
			arr.encode_u16(i, arr.decode_u16(i) ^ (encKey & 0xFFFF))
			i += 2
	encKey = (encKey - 24691) * 4005161829
	return encKey

static func Scanned(img: IndexedImage, ftb: bool, bytes: PackedByteArray) -> int:
	var encryptKey: int = decrypt(ftb, bytes)
	img.set_region(0, 0, img.width, img.height, bytes)
	return encryptKey

static func Tiled(img: IndexedImage, bytes: PackedByteArray) -> void:
	var chunkSize = 64 if img.bpp == 8 else 32
	var y := 0
	var chunksCounted := 0
	while (y < img.height):
		var x := 0
		while (x < img.width):
			img.set_region(x, y, 8, 8, bytes.slice(chunksCounted * chunkSize, (chunksCounted + 1) * chunkSize))
			chunksCounted += 1
			x += 8
		y += 8

static func writeNCGR(img: IndexedImage, scanned: bool = true, ftb: bool = true, encryptionKey: int = 500) -> PackedByteArray:
	var retBytes := PackedByteArray()
	retBytes.append_array(NCGRHeader)
	retBytes.append_array(charHeader)
	
	if (scanned):
		retBytes.append_array(writeScanned(img, ftb, encryptionKey))
		retBytes.encode_u16(24, img.height >> 3)
		retBytes.encode_u16(26, img.width >> 3)
		retBytes.encode_u8(36, 1)
	else:
		retBytes.append_array(writeTiled(img))
	
	retBytes.encode_u32(8, retBytes.size())
	retBytes.encode_u32(20, retBytes.size() - 16)
	retBytes.encode_u32(40, retBytes.size() - 48)
	if (img.bpp == 8):
		retBytes.encode_u32(28, 4)
	
	return retBytes

# This result goes after the Char Block Header in NCGR
static func writeScanned(img: IndexedImage, ftb: bool, encKey: int) -> PackedByteArray:
	var bytes = img.get_packed_data()
	encrypt(encKey, ftb, bytes)
	return bytes

# This result goes after the Char Block Header in NCGR
static func writeTiled(img: IndexedImage) -> PackedByteArray:
	var bytes := PackedByteArray()
	var y := 0
	while (y < img.height):
		var x := 0
		while (x < img.width):
			var region = img.get_region(x, y, 8, 8)
			bytes.append_array(region)
			x += 8
		y += 8
	return bytes
