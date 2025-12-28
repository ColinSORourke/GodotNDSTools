####################
# NCLR FileFormat
####################
class_name NCLR

const NCLRHeader: PackedByteArray = [
	0x4E, 0x43, 0x4C, 0x52, #NCLR Stamp
	0xFF, 0xFE, # Byte Order
	0x00, 0x01, # Version
	0x00, 0x00, 0x00, 0x00, # File Size
	0x10, 0x00, # Header size, 16
	0x01, 0x00] # Number of Chunks
const palHeader: PackedByteArray = [
	0x54, 0x54, 0x4C, 0x50, #PLTT Stamp
	0x00, 0x00, 0x00, 0x00, #Chunk Size
	0x00, 0x00, # BPP
	0x0A, 0x00, # Compnum
	0x00, 0x00, 0x00, 0x00, #0 Padding
	0x00, 0x00, 0x00, 0x00, #Palette Data Size
	0x10, 0x00, 0x00, 0x00] #Offset from TTLP + 8 to data, always 0x10
const IRColor = Color(72, 144, 160)

# 0x4E434C52, 0x4E415243 = "NCLR"
static func isNCLR(bytes: PackedByteArray) -> bool:
	if (bytes.size() < 4):
		return false
	if (bytes.decode_u32(0) != 0x4E434C52 && bytes.decode_u32(0) != 0x524C434E):
		# NOT A NCLR FILE
		return false
	return true

static func getPal(bytes: PackedByteArray) -> Palette:
	var pal := Palette.new()
	# 0x4E434C52, 0x4E415243 = "NCLR"
	if (bytes.decode_u32(0) != 0x4E434C52 && bytes.decode_u32(0) != 0x524C434E):
		# NOT A NCLR FILE
		return pal
	
	if (bytes.slice(16, 20) != palHeader.slice(0, 4)):
		print("Invalid Palette, wrong Stamp: %X" % bytes.decode_u32(16))
		return pal
	
	var sectionSize = bytes.decode_u32(20)
	var bitDepth = bytes.decode_u16(24)
	if (bitDepth == 3):
		bitDepth = 4
	
	var _compNum = bytes.decode_u8(26)
	var pltLength: int = bytes.decode_u32(32)
	var startOffset: int = bytes.decode_u32(36)
	
	if (pltLength == 0 || pltLength > sectionSize):
		pltLength = sectionSize - 0x18
	
	var numColors: int = 256
	if (pltLength/2 < numColors):
		numColors = pltLength/2
	
	var currInd: int = 0x18 + startOffset
	var i = 0
	while(i < numColors):
		pal.addColor(ColorUtil.from_RGB15(bytes.decode_u16(currInd)))
		currInd += 2
		i += 1
	
	return pal;
	
static func writeNCLR(pal: Palette) -> PackedByteArray:
	var returnBytes: PackedByteArray = []
	var size: int = pal.size() * 2
	returnBytes.append_array(NCLRHeader)
	returnBytes.encode_u32(0x8, size + 0x28)
	returnBytes.append_array(palHeader)
	returnBytes.encode_u32(0x14, size + 0x18)
	returnBytes.encode_u16(0x18, 4)
	if (pal.size() > 16):
		returnBytes.encode_u16(0x18, 8)
	returnBytes.encode_u32(0x20, size)
	returnBytes.resize(0x28 + size)
	
	var i = 0
	while (i < pal.size()):
		returnBytes.encode_u16(40 + (2 * i), ColorUtil.to_RGB15(pal.getColor(i)))
		i += 1
	return returnBytes
