####################
# PNG FileFormat
# http://www.libpng.org/pub/png/spec/1.2/PNG-Contents.html
# Just handles Indexed PNGs atm
####################
class_name PNG

@warning_ignore_start("int_as_enum_without_cast")

const PNGSig: PackedByteArray = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] #▯PNG
const HeaderSig: PackedByteArray = [0x49, 0x48, 0x44, 0x52] #IHDR
const PaletteSig: PackedByteArray = [0x50, 0x4c, 0x54, 0x45] #PLTE
const DataSig: PackedByteArray = [0x49, 0x44, 0x41, 0x54] #IDAT
const EndSig: PackedByteArray = [0x49, 0x45, 0x4e, 0x44] #IEND
const BAD: PackedByteArray = [0x35, 0x34, 0x37] #BAD

static func isIndexed(bytes: PackedByteArray) -> bool:
	return bytes.decode_u8(0x19) == 3

static func getIdxImage(bytes: PackedByteArray) -> IndexedImage:
	if (bytes.slice(0x0, 0x8) != PNGSig):
		print("Not a PNG!")
		return IndexedImage.new(2, 2, 4, 0)
	
	if (bytes.slice(0xC, 0x10) != HeaderSig):
		print("Missing Header")
		return IndexedImage.new(2, 2, 4, 0)
	
	var width := swapEndianInt32( bytes.decode_u32(0x10) )
	var height := swapEndianInt32( bytes.decode_u32(0x14) )
	
	var valid := true && bytes.decode_u8(0x19) == 3 # Not Paletted
	valid = valid && bytes.decode_u8(0x1A) == 0 # Not Deflate
	valid = valid && bytes.decode_u8(0x1B) == 0 # Not Adaptive Filter
	valid = valid && bytes.decode_u8(0x1C) <= 1 # Bad interlace
	
	if (!valid):
		print("PNG IMPROPERLY FORMATTED")
		return IndexedImage.new(2, 2, 4, 0)
	
	var result: IndexedImage = IndexedImage.new(width, height, bytes.decode_u8(0x18), 0)
	
	var plteChunk := BAD
	var idatChunk := BAD
	var iendByte := -1
	var i := 37
	while (i < bytes.size() - 4):
		var chunkLength := swapEndianInt32( bytes.decode_u32(i - 4) )
		if (bytes.slice(i, i + 4) == PaletteSig):
			if (plteChunk != BAD):
				print("Multiple IDAT Chunks")
				return IndexedImage.new(2, 2, 4, 0)
			plteChunk = bytes.slice(i + 4, i + 4 + chunkLength)
			if(plteChunk[0] == 1 && plteChunk[1] == 1 && plteChunk[2] == 1):
				result.mode = IndexedImage.AlphaMode.ZERO
		if (bytes.slice(i, i + 4) == DataSig):
			if (idatChunk != BAD):
				print("Multiple IDAT Chunks")
				return IndexedImage.new(2, 2, 4, 0)
			idatChunk = bytes.slice(i + 4, i + 4 + chunkLength)
		if (bytes.slice(i, i + 4) == EndSig):
			iendByte = i
			i = bytes.size()
		i += 1
	
	if (plteChunk == BAD):
		print("Missing PLTE")
		return IndexedImage.new(2, 2, 4, 0)
	if (idatChunk == BAD):
		print("Missing IDAT")
		return IndexedImage.new(2, 2, 4, 0)
	if (iendByte == -1):
		print("Missing IEND")
		return IndexedImage.new(2, 2, 4, 0)
	
	var decompSize: int
	if (result.bpp == 8):
		decompSize = height * (1 + (width))
	else:
		decompSize = height * (1 + (width/2))
		
	var decompData: PackedByteArray = idatChunk.decompress(decompSize, 1)
	result.pixeldata = readPixelBuf(decompData, width, height, result.bpp)
	
	return result

static func getPalette(bytes: PackedByteArray) -> Palette:
	if (bytes.slice(0, 8) != PNGSig):
		print("Not a PNG!")
		return Palette.greyscale()
	
	if (bytes.slice(12, 16) != HeaderSig):
		print("Missing Header")
		return Palette.greyscale()
	
	var valid := true && bytes.decode_u8(25) == 3 # Not Paletted
	valid = valid && bytes.decode_u8(26) == 0 # Not Deflate
	valid = valid && bytes.decode_u8(27) == 0 # Not Adaptive Filter
	valid = valid && bytes.decode_u8(28) <= 1 # Bad interlace
	
	if (!valid):
		print("PNG IMPROPERLY FORMATTED")
		return Palette.greyscale()
	
	var result := Palette.new()
	result.bitDepth = bytes.decode_u8(24)
	
	var plteChunk := BAD
	var idatChunk := BAD
	var iendByte := -1
	var i := 37
	while (i < bytes.size() - 4):
		var chunkLength = swapEndianInt32( bytes.decode_u32(i - 4) )
		if (bytes.slice(i, i + 4) == PaletteSig):
			if (plteChunk != BAD):
				print("Multiple IDAT Chunks")
				return Palette.greyscale()
			plteChunk = bytes.slice(i + 4, i + 4 + chunkLength)
		if (bytes.slice(i, i + 4) == DataSig):
			if (idatChunk != BAD):
				print("Multiple IDAT Chunks")
				return Palette.greyscale()
			idatChunk = bytes.slice(i + 4, i + 4 + chunkLength)
		if (bytes.slice(i, i + 4) == EndSig):
			iendByte = i
			i = bytes.size()
		i += 1
	
	if (plteChunk == BAD):
		print("Missing PLTE")
		return Palette.greyscale()
	#if (idatChunk == BAD):
		#print("Missing IDAT")
		#return IndexedImage.new(2, 2)
	if (iendByte == -1):
		print("Missing IEND")
		return Palette.greyscale()
	
	i = 0
	while(i <= plteChunk.size() - 3):
		result.addColor(Color8(plteChunk[i], plteChunk[i + 1], plteChunk[i + 2]))
		i += 3
	
	return result

static func writePNGIdx(idxImage: IndexedImage, pal: Palette) -> PackedByteArray:
	var imageHead := PackedByteArray()
	imageHead.append_array(HeaderSig)
	imageHead.resize(imageHead.size() + 8)
	imageHead.encode_u32(0x4, swapEndianInt32(idxImage.width))
	imageHead.encode_u32(0x8, swapEndianInt32(idxImage.height))
	imageHead.append_array([idxImage.bpp, 3, 0, 0, 0])
	
	var paletteBuff := PackedByteArray()
	paletteBuff.append_array(PaletteSig)
	var i := 0
	if (idxImage.mode == 1):
		# This is a cheat I use for "Storing" AlphaMode Zero 
		# 	(An Indexed Image where color index 0 represents a transparent pixel)
		# The BitFormats of most IndexedImages I am working with don't have the resolution to specify
		# Color (1, 1, 1), so I use that to represent AlphaMode Zero
		paletteBuff.append_array([1, 1, 1])
		i += 1
	while (i < pal.size()):
		paletteBuff.append_array([pal.getColor(i).r8, pal.getColor(i).g8, pal.getColor(i).b8])
		i += 1
	
	var dataBuff := PackedByteArray()
	dataBuff.append_array(DataSig)
	var data := writePixelBuf(idxImage.pixeldata, idxImage.width, idxImage.height, idxImage.bpp)
	dataBuff.append_array(data.compress(1))
	
	var returnArray := PackedByteArray()
	returnArray.append_array(PNGSig)
	
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(imageHead.size()-4))
	returnArray.append_array(imageHead)
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(CRC.calculateCRC32(imageHead)))
	
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(paletteBuff.size()-4))
	returnArray.append_array(paletteBuff)
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(CRC.calculateCRC32(paletteBuff)))
	
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(dataBuff.size()-4))
	returnArray.append_array(dataBuff)
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(CRC.calculateCRC32(dataBuff)))
		
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(EndSig.size()-4))
	returnArray.append_array(EndSig)
	returnArray.resize(returnArray.size() + 4)
	returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(CRC.calculateCRC32(EndSig)))
	
	return returnArray

static func readPixelBuf(pixelBuf: PackedByteArray, w: int, h: int, bpp: int) -> PackedByteArray:
	# OutputBuffer. Intended format is that every byte is a pixel
	var output := PackedByteArray()
	output.resize(w * h)
	
	var numBytes: int = ceil(bpp * w / 8.0) + 1 # Bytes per Scanline
	var ppb: int = 8/bpp # Pixels per byte
	var idx: int = 0 # True index in the pixelbuffer
	var prevScanLine = PackedByteArray() # PreviousScanLine, for Filter types 2-4
	prevScanLine.resize(numBytes)
	
	var i: int = 0
	while (i < h):
		var scanLine := pixelBuf.slice(idx, idx + numBytes)
		var filter: = scanLine[0]
		scanLine[0] = 0 # Doing only most basic filter method - slightly inefficient
		var j: int = 1
		idx += numBytes
		while (j < scanLine.size()):
			match filter:
				1:
					scanLine[j] = scanLine[j] + scanLine[j-1] % 256
				2: 
					scanLine[j] = scanLine[j] + prevScanLine[j] % 256
				3:
					scanLine[j] = scanLine[j] + neighborAverage(scanLine[j-1], prevScanLine[j]) % 256
				4:
					scanLine[j] = scanLine[j] + paethPredictor(scanLine[j-1], prevScanLine[j], prevScanLine[j-1]) % 256

			var os: int = 0
			var coord: int = (j - 1) * ppb + i * w; 
			while(os * bpp < 8 && (j - 1) * ppb + os < w):
				output.encode_u8(coord + os, byteToPixel(scanLine[j], bpp, os))
				os += 1
			j += 1
		prevScanLine = scanLine
		i += 1
	return output

static func writePixelBuf(pixels: PackedByteArray, w: int, h: int, bpp: int) -> PackedByteArray:
	var outputBuf := PackedByteArray()
	var numBytes: int = ceil(bpp * w / 8)
	if (bpp == 8):
		outputBuf.resize( h * (1 + w) )
	else:
		outputBuf.resize( h * (1 + w/2))
		
	var i := 0
	while (i < h):
		var offset := i * (numBytes + 1) + 1
		outputBuf.encode_u8(offset - 1, 0)
		var j := 0
		while (j < numBytes):
			match bpp:
				8:
					outputBuf.encode_u8(offset + j, pixels[i * w + j])
				4:
					var byte = (pixels[i * w + j *2] << 4) | (pixels[i * w + j * 2 + 1] & 0xF)
					outputBuf.encode_u8(offset + j, byte)
				2:
					var byte = (pixels[i * w + j *2] << 2) | ((pixels[i * w + j * 2 + 1] & 0x3) << 4)
					outputBuf.encode_u8(offset + j, byte)
			j += 1
		i += 1
		
	return outputBuf

static func byteToPixel(byte: int, bpp: int, offset: int = 0) -> int:
	if (offset * bpp >= 8):
		print("BAD OFFSET")
		return 0
	match bpp:
		8:  
			return byte
		4:
			return byte >> 4 * (1-offset) & 0xf
		2: 
			return byte >> 2 * (3-offset) & 0x3
	return 0
	
# PNG FILTER NONSENSE
# https://www.libpng.org/pub/png/spec/1.2/PNG-Filters.html
static func neighborAverage(left: int, up: int) -> int:
	return floor((left+up)/2)
	
static func paethPredictor(left: int, up: int, leftup: int) -> int:
	var p: int = left + up - leftup
	var pa: int = abs(p - left)
	var pb: int = abs(p - up)
	var pc: int = abs(p - leftup)
	if (pa <= pb && pa <= pc):
		return left
	elif (pb <= pc):
		return up
	else:
		return leftup

static func swapEndianInt32(i: int) -> int:
	var b1 = (i & 0xFF000000) >> 24
	var b2 = (i & 0x00FF0000) >> 8
	var b3 = (i & 0x0000FF00) << 8
	var b4 = (i & 0x000000FF) << 24
	return b1 | b2 | b3 | b4
