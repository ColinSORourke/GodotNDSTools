####################
# BTX FileFormat
# https://github.com/scurest/BTXViewer/blob/master/viewer.html#L168
####################
class_name BTX

@warning_ignore_start("int_as_enum_without_cast")

const BTX0Header: PackedByteArray = [
	0x42, 0x54, 0x58, 0x30, # BTX0 Stamp
	0xFF, 0xFE, # Byte Order
	0x01, 0x00, # Version
	0x00, 0x00, 0x00, 0x00, # FileSize
	0x10, 0x00, # Header Size, 16
	0x01, 0x00, # Number of Chunks
	0x14, 0x00, 0x00, 0x00] # Offset to TEX0
const TEX0Header: PackedByteArray = [
	0x54, 0x45, 0x58, 0x30, # TEX0 Stamp
	0x00, 0x00, 0x00, 0x00, # TEX0 Chunk Size
	0x00, 0x00, 0x00, 0x00, # 0 Padding
	0x00, 0x00, # Tex Data size / 8
	0x3C, 0x00, # Offset to Texture Dict from TEX0 (always 03CH)
	0x00, 0x00, 0x00, 0x00, # 0 Padding
	0x00, 0x00, 0x00, 0x00, # Texture Data Offset
	0x00, 0x00, 0x00, 0x00, # 0 Padding
	0x00, 0x00, # CompTexDataSize / 12 (I am not writing this so it will be 0)
	0x3C, 0x00, # Offset to Texture Dict from TEX0 (always 03CH)
	0x00, 0x00, 0x00, 0x00, # 0 Padding
	0x00, 0x00, 0x00, 0x00, # CompTex Offset 1
	0x00, 0x00, 0x00, 0x00, # CompTex Offset 2
	0x00, 0x00, 0x00, 0x00, # 0 Padding
	0x00, 0x00, # Palette Data Size / 8
	0x00, 0x00, # ???
	0x00, 0x00, 0x00, 0x00, # Palette Dict Offset
	0x00, 0x00, 0x00, 0x00] # Palette Data Offset

class texData:
	var name: String
	var width: int
	var height: int
	var dataOffset: int
	var format: int
	var alpha0: bool
	var data: Vector2i
	var data2: Vector2i
	var byteLength: int
	
	func _init(n: String, texpar: int) -> void:
		name = n
		dataOffset = (texpar & 0xffff) << 3 # Bit 0-16, Address of TEX0 Start
		width = 8 << ((texpar >> 20) & 7) # Bit 20-22, Texture Width, SH-Left 8
		height = 8 << ((texpar >> 23) & 7) # Bit 23-25, Texture Height, SH-Left 8
		format = (texpar >> 26) & 7 # Bit 26-28, Texture Format
		alpha0 = (texpar >> 29) & 1 # Bit 29, if Palette Color 0 is Transparent
		
		var paramBinary = []
		paramBinary.append(String.num_int64(alpha0, 2))
		paramBinary.append(String.num_int64(format, 2).lpad(3, "0"))
		
		var i = 0
		
		while(height >> 4 + i != 0):
			i += 1
		paramBinary.append(String.num_int64(i, 2).lpad(3, "0"))
		i = 0
		while(width >> 4 + i != 0):
			i += 1
		paramBinary.append(String.num_int64(i, 2).lpad(3, "0"))
		paramBinary.append(String.num_int64(dataOffset >> 3, 2).lpad(16, "0"))
		match(format):
			0:
				byteLength = 0
			1, 4, 6:
				byteLength = width * height
			2, 5: 
				byteLength = (width * height) >> 2
			3:
				byteLength = (width * height) >> 1
			7:
				byteLength = (width * height) << 1

	func setData(texBlock: int, texBlock2: int = -1) -> void:
		data = Vector2i(texBlock + dataOffset, texBlock + dataOffset + byteLength)
		if (texBlock2 != -1):
			data2 = Vector2i(texBlock + (dataOffset>>1), texBlock2 + (dataOffset>>1) + (byteLength>>1))

	func _to_string() -> String:
		return "%s, w: %s, h: %s" % [name, width, height]

class palData:
	var name: String
	var data: Vector2i
	var numColors: int
	
	func _init(n: String, d: Vector2i) -> void:
		name = n
		data = d
		numColors = (d.y - d.x) / 2
	
	func _to_string() -> String:
		return "%s" % name

class compressedTexel:
	var texelBlock: int #4 Byte Integer. Every 2 bits is a texel
	var palBlock: int #2 Byte integer. Bits 0-13 Palatte Data, bits 14-15 is Texel Mode
	
	var mode: Callable
	var palOffset: int
	var palSize: int
	var texels: PackedByteArray
	var palData: PackedByteArray
	
	func _init(b: int, p: int):
		texelBlock = b
		palBlock = p
		
		match (palBlock >> 14) & 3:
			0:
				palSize = 6
				mode = mode0
			1:
				palSize = 4
				mode = mode1
			2: 
				palSize = 8
				mode = mode2
			3:
				palSize = 4
				mode = mode3
		
		palOffset = (palBlock & 0x3FFF) << 1
		
		texels = PackedByteArray()
		texels.resize(16)
		var i = 0
		while (i < 16):
			texels.append( (texelBlock >> i * 2) & 3 )
			i += 1
	
	func getTexel(t: int) -> Color:
		return mode.call(texels[t])
	
	func mode0(t: int) -> Color:
		if (t == 3):
			return Color.TRANSPARENT
		return ColorUtil.from_RGB15(palData.decode_u16(2 * t))
		
	func mode1(t: int) -> Color:
		if (t == 3):
			return Color.TRANSPARENT
		if (t == 2):
			var color0 = ColorUtil.from_RGB15(palData.decode_u16(0))
			var color1 = ColorUtil.from_RGB15(palData.decode_u16(2))
			return color0.lerp(color1, 0.5)
		return ColorUtil.from_RGB15(palData.decode_u16(2 * t))
	#
	func mode2(t: int) -> Color:
		return ColorUtil.from_RGB15(palData.decode_u16(2 * t))
		
	func mode3(t: int) -> Color:
		var color0 = ColorUtil.from_RGB15(palData.decode_u16(0))
		var color1 = ColorUtil.from_RGB15(palData.decode_u16(2))
		if (t == 3):
			return color1.lerp(color0, 0.375)
		if (t == 2):
			return color0.lerp(color1, 0.375)
		if (t == 1):
			return color1
		return color0

# 0x42545830, 0x30585442 = "BTX0"
static func isBTX(bytes: PackedByteArray) -> bool:
	if (bytes.size() < 4):
		return false
	if (bytes.decode_u32(0) != 0x42545830 && bytes.decode_u32(0) != 0x30585442):
		return false
	return true

static func getTexSet(bytes: PackedByteArray) -> TextureSet:
	var bom = bytes.decode_u16(0x4)
	var version = bytes.decode_u16(0x6)
	var _fileSize = bytes.decode_u32(0x8)
	var hdrSize = bytes.decode_u16(0xC)
	var numBlocks = bytes.decode_u16(0xE)
	
	var result = TextureSet.new()
	
	if (bom != 0xfeff || version > 2 || hdrSize != 16 || numBlocks != 1):
		print("Bad File Header")
		result.badResult = true
		return result
	
	var blockOffset = bytes.decode_u32(0x10)
	if (bytes.decode_u32(blockOffset) != 0x30584554):
		print("Bad Tex0 stamp")
		result.badResult = true
		return result
	
	var tex0Chunk= bytes.slice(blockOffset)
	var textureList = getTex0Dict(tex0Chunk)
	var paletteList = getTex0Pals(tex0Chunk)
	
	var mySet = TextureSet.new()
		
	var i = 0
	var fullPaletteBlock = tex0Chunk.slice(paletteList[0].data.x);
	while (i < fullPaletteBlock.size()):
		mySet.fullPalette.addColor(ColorUtil.from_RGB15(fullPaletteBlock.decode_u16(i)))
		i +=2 
	
	i = 0
	while (i < paletteList.size()):
		var currPalette = paletteList[i]
		var start = (currPalette.data.x - paletteList[0].data.x)/2
		mySet.addPalette(currPalette.name, start, currPalette.numColors)
		i += 1
	
	i = 0
	var alreadyRead = []
	while (i < textureList.size()):
		var currTexture = textureList[i]
		var readInd = alreadyRead.find(currTexture.data.x)
		if (readInd == -1):
			if (currTexture.format != 5):
				var texBytes = tex0Chunk.slice(currTexture.data.x, currTexture.data.y)
				mySet.addSprite(readTexBytes(currTexture, texBytes), currTexture.format)
			else:
				var texBytesA = tex0Chunk.slice(currTexture.data.x, currTexture.data.y)
				var texBytesB = tex0Chunk.slice(currTexture.data2.x, currTexture.data2.y)
				mySet.addSprite(readTexBytes5(currTexture, texBytesA, texBytesB, fullPaletteBlock), currTexture.format)
			mySet.addFrame(Vector2i(alreadyRead.size(), 0), currTexture.name)
			alreadyRead.append(currTexture.data.x)
		else:
			mySet.addFrame(Vector2i(readInd, 0), currTexture.name)
		
		i += 1
	
	return mySet

static func getTex0Dict(bytes:PackedByteArray) -> Array[texData]:
	var texDictOffset = bytes.decode_u16(0xE)
	var texDataOffset = bytes.decode_u32(0x14)
	var texture5Data1Ofs = bytes.decode_u32(0x24)
	var texture5Data2Ofs = bytes.decode_u32(0x28)
	
	var dictBytes = bytes.slice(texDictOffset)
	var count = dictBytes[1]
	var valSize = dictBytes.decode_u16(0xC + 0x4*count)
	var valOffset = 0x10 + 0x4*count
	var nameOffset = valOffset + count*valSize
	var textures: Array[texData] = []
	
	var i = 0
	while(i < count):
		var name = dictBytes.slice(nameOffset, nameOffset + 16).get_string_from_ascii()
		var params = dictBytes.decode_u32(valOffset)
		textures.append(texData.new(name, params))
		if (textures[i].format == 5):
			textures[i].setData(texture5Data1Ofs, texture5Data2Ofs)
		elif (textures[i].format != 0):
			textures[i].setData(texDataOffset)
		valOffset += valSize
		nameOffset += 0x10
		i += 1
	
	return textures

static func getTex0Pals(bytes: PackedByteArray) -> Array[palData]:
	var palDataSize = bytes.decode_u16(0x30)
	var palDataOffset = bytes.decode_u32(0x38)
	var _palDataEnd = palDataOffset + (palDataSize << 3)
	var palDictOffset = bytes.decode_u32(0x34)
	
	var dictBytes = bytes.slice(palDictOffset)
	var count = dictBytes[1]
	var valSize = dictBytes.decode_u16(0xC + 0x4*count)
	var valOffset = 0x10 + 0x4*count
	var nameOffset = valOffset + count*valSize
	var palettes: Array[palData] = []
	var i = 0
	while(i < count):
		var name = bytes.slice(palDictOffset + nameOffset, palDictOffset +nameOffset + 16).get_string_from_ascii()
		var palOffset = bytes.decode_u16(palDictOffset + valOffset) << 3
		var palFormat = bytes.decode_u16(palDictOffset + valOffset + 2)
		var palSize = 0x10
		
		# "Unknown (usually 0, sometimes 1)  ;unrelated to number of colors"
		# ---https://problemkaputt.de/gbatek.htm#dsfiles3dvideobtx0nsbtxtexturedata
		# This seems incorrect - an example I looked at did have a singular palette with 1 have 4 colors instead of 16
		# However I also see a palette with 0 on this byte, that is only 8 colors long due to being at the end of the file
		# None of this currently causes any errors. So I am inclined to leave it be?
		if (palFormat == 1):
			palSize = 0x4
		palettes.append(palData.new(name, Vector2i(palDataOffset + palOffset, palDataOffset + palOffset + 2 * palSize))) 
		valOffset += valSize
		nameOffset += 0x10
		i += 1
	
	return palettes

static func readPalBytes(bytes: PackedByteArray) -> Palette:
	var retPalette = Palette.new()
	var i = 0
	while(i < bytes.size() - 1):
		retPalette.addColor(ColorUtil.from_RGB15(bytes.decode_u16(i)))
		i += 2
	return retPalette

static func readTexBytes(td: texData, bytes: PackedByteArray):
	var retImage;
	var i = 0
	if (td.format == 0):
		# no texture
		retImage = IndexedImage.new(2, 2, 4, 0)
	
	# WARNING: UNTESTED CODE
	if (td.format == 1):
		# A315 Texture with Transparency
		# Each Texel is 1 byte, 8 bits. Bit 0-4, Color Index, Bit 5-8 Alpha 
		retImage = IndexedImage.new(td.width, td.height, 5, IndexedImage.AlphaMode.DATA)
		retImage.set_region(0, 0, td.width, td.height, bytes)
	
	if (td.format == 2):
		# Paletted Texture, with 2 BitDepth
		# Each Texel is 2 bits, 
		#retImage = IndexedImage.new(td.width, td.height, 2)
		retImage = IndexedImage.new(td.width, td.height, 2, int(td.alpha0))
		retImage.set_region(0, 0, td.width, td.height, bytes)
	
	if (td.format == 3):
		# Paletted Texture, with 4 BitDepth
		# Each Texel is 4 bits, 
		#retImage = IndexedImage.new(td.width, td.height, 4)
		retImage = IndexedImage.new(td.width, td.height, 4, int(td.alpha0))
		retImage.set_region(0, 0, td.width, td.height, bytes)
			
	if (td.format == 4):
		# Paletted Texture, with 8 BitDepth
		# Each Texel is 8 bits, 
		retImage = IndexedImage.new(td.width, td.height, 8, int(td.alpha0))
		retImage.set_region(0, 0, td.width, td.height, bytes)
	
	if (td.format == 5):
		# This shouldn't be called. Is handled as a separate case.
		retImage = IndexedImage.new(2, 2, 4, 0)
		
	# WARNING: UNTESTED CODE
	if (td.format == 6):
		# A513 Texture with Transparency
		# Each Texel is 1 byte, 8 bits. Bit 0-2, Color Index, Bit 3-8 Alpha 
		retImage = IndexedImage.new(td.width, td.height, 3, IndexedImage.AlphaMode.DATA)
		retImage.set_region(0, 0, td.width, td.height, bytes)
		
	# WARNING: UNTESTED CODE
	if (td.format == 7):
		# Direct Color Texture
		# Each Texel is 2 Bytes, bit 0-4 Red, bit 5-9 Green, bit 10-14 Blue, bit 15, Transparent?
		retImage = Image.create_empty(td.width, td.height, false, Image.FORMAT_RGBA8)
		while (i < bytes.size()):
			var color = bytes.decode_u16(i)
			retImage.setPixel(i % td.width, i / td.width, ColorUtil.from_RGB15(color))
			i += 2
		
	return retImage

# There is no way to represent this format as an IndexedImage or ColoredImage that can be successfully converted back to BTX
# This is due to each 'block' having a limited palette of at most 4 colors, and there being no way of enforcing a 'palette per block'
# WARNING: Untested code
static func readTexBytes5(td: texData, bytesA: PackedByteArray, bytesB: PackedByteArray, palBlock: PackedByteArray) -> ImageWrap:
	var retImage := ImageWrap.new(td.width, td.height, 4, false)
	var numBlocksX: int = td.width >> 2
	var numBlocksY: int = td.height >> 2
	var texelBlocks: Array[compressedTexel] = []
	var i = 0
	while (i < numBlocksX * numBlocksY):
		var block: int = bytesA.decode_u32(i * 4)
		var extra: int = bytesB.decode_u16(i * 2)
		texelBlocks.append(compressedTexel.new(block, extra))
		texelBlocks[i].palData = palBlock.slice(texelBlocks[i].palOffset, texelBlocks[i].palOffset + texelBlocks[i].palSize)
		
		var j: int = 0
		var blockX: int = i % numBlocksX
		var blockY: int = i / numBlocksX
		while (j < 16):
			var x = j % 4
			var y = j / 4
			retImage.setPixel(blockX + x, blockY + y, texelBlocks[i].getTexel(j))
			j += 1
		i += 1
	
	return retImage

static func getTexParamsA(img) -> int:
	var shrtWidth = 0
	while(img.width >> 4 + shrtWidth != 0):
		shrtWidth += 1
	var shrtHeight = 0
	while(img.height >> 4 + shrtHeight != 0):
		shrtHeight += 1
	
	var format = 7
	if (img is IndexedImage):
		match(img.bpp):
			2:
				format = 2
			4: 
				format = 3
			8: 
				format = 4
			3:
				format = 6
			5:
				format = 1
	var params = 0
	if (img is IndexedImage):
		params |= (int(img.mode == 1) << 12)
	params |= (format << 10)
	params |= (shrtHeight << 7)
	params |= (shrtWidth << 4)
	
	return params

static func getTexParamsB(img) -> int:
	var params = 0
	params |= img.width
	params |= img.height << 11
	params |= 1 << 31
	return params

static func writeBTX(ts: TextureSet) -> PackedByteArray:
	var retBytes := PackedByteArray()
	retBytes.append_array(BTX0Header)
	retBytes.append_array(TEX0Header)
	
	var texDictSize = getDictSize(ts.frames.size(), 8)
	var palDictSize = getDictSize(ts.palettes.size(), 4)
	var texDataSize = 0
	var texParams = PackedByteArray()
	texParams.resize(ts.frames.size() * 8)
	var palDataSize = ts.fullPalette.size() * 2
	var palParams = PackedByteArray()
	palParams.resize(ts.frames.size() * 4)
	var i = 0
	var spriteOffsets = []
	while(i < ts.sprites.size()):
		spriteOffsets.append(texDataSize)
		if (ts.sprites[i] is IndexedImage):
			texDataSize += ts.sprites[i].get_packed_size()
		else:
			texDataSize += ts.sprites[i].width * ts.sprites[i].height * 2
		i += 1
	i = 0
	while (i < ts.frames.size()):
		texParams.encode_u16(i * 8 + 2, getTexParamsA(ts.sprites[ts.frames[i].x]))
		texParams.encode_u16(i * 8, spriteOffsets[ts.frames[i].x]/8)
		texParams.encode_u32(i * 8 + 4, getTexParamsB(ts.sprites[ts.frames[i].x]))
		i += 1
	
	retBytes.encode_u16(0x20, texDataSize/8)
	retBytes.encode_u32(0x28, 0x3C + texDictSize + palDictSize) # Offset to Texture Data
	retBytes.encode_u16(0x44, palDataSize/8)
	retBytes.encode_u32(0x38, 0x3C + texDictSize + palDictSize + texDataSize)
	retBytes.encode_u32(0x3C, 0x3C + texDictSize + palDictSize + texDataSize)
	retBytes.encode_u32(0x48, 0x3C + texDictSize) # Offset to palDict
	var palDataOffset = 0x3C + texDictSize + palDictSize + texDataSize
	retBytes.encode_u32(0x4C, palDataOffset) # Offset to PalData
	
	i = 0
	while(i < ts.paletteStarts.size()):
		palParams.encode_u16(i * 4, (ts.paletteStarts[i] * 2) / 8)
		i += 1
	
	retBytes.append_array(writeDict(ts.frameNames, texParams))
	retBytes.append_array(writeDict(ts.paletteNames, palParams))
	
	i = 0
	while(i < ts.sprites.size()):
		if (ts.sprites[i] is IndexedImage):
			retBytes.append_array(ts.sprites[i].get_packed_data())
		else:
			var packedFormat7 := PackedByteArray()
			packedFormat7.resize(ts.sprites[i].width * ts.sprites[i].height * 2)
			var j = 0
			while(j < ts.sprites[i].width * ts.sprites[i].height):
				packedFormat7.encode_u16(j*2, ColorUtil.to_RGB15(ts.sprites[i].get_pixel(j % ts.sprites[i].width, j / ts.sprites[i].width)))
				j += 1
			retBytes.append_array(packedFormat7)
		i += 1
	
	i = 0
	var packedPalette := PackedByteArray()
	packedPalette.resize(ts.fullPalette.size() * 2)
	while (i < ts.fullPalette.size()):
		packedPalette.encode_u16(i*2, ColorUtil.to_RGB15(ts.fullPalette.getColor(i)))
		i += 1
	retBytes.append_array(packedPalette)
	
	retBytes.encode_u32(8, retBytes.size())
	retBytes.encode_u32(24, retBytes.size() - 20)
	
	return retBytes
	
static func getDictSize(n: int, s: int) -> int:
	return 12 + (4*n) + 4 + (n*s) + (n*16)
	
static func writeDict(names: PackedStringArray, paramData: PackedByteArray) -> PackedByteArray:
	var retBytes := PackedByteArray()
	retBytes.resize(8)
	
	retBytes.encode_u8(1, names.size())
	retBytes.encode_u16(2, 12 + (4 * names.size()) + 4 + paramData.size() + (16*names.size()))
	retBytes.encode_u16(4, 8)
	retBytes.encode_u16(6, 12 + (4 * names.size()))
	
	var pTree = PatriciaTree.new()
	var i = 0
	while(i < names.size()):
		pTree.addNode(names[i])
		i += 1
	
	retBytes.append_array(pTree.writeTree())
	
	retBytes.append_array([0x00, 0x00, 0x00, 0x00])
	retBytes.encode_u16(retBytes.size() - 4, paramData.size()/names.size())
	retBytes.encode_u16(retBytes.size() - 2, 4 + paramData.size())
	retBytes.append_array(paramData)
	
	i = 0
	while(i < names.size()):
		var nameBuffer = names[i].to_ascii_buffer()
		nameBuffer.resize(16)
		retBytes.append_array(nameBuffer)
		i += 1
	
	return retBytes
	
static func replaceFrame(btx: PackedByteArray, ind: int, img) -> void:
	var numFrames = btx.decode_u8(0x51)
	if (ind >= numFrames):
		print("Frame %s does not exist in the given BTX" % ind)
		return
	
	var texParamLoc = 0x5C + (4 * numFrames) + 4 + (8 * ind)
	var texDataLoc = btx.decode_u32(0x28)
	
	var texParam = btx.decode_u16(texParamLoc + 2)
	
	if (texParam != getTexParamsA(img)):
		print("Img wrong format for given Frame")
		return
	
	var offset = btx.decode_u16(texParamLoc) << 3
	
	var imgBytes = PackedByteArray()
	if (img is IndexedImage):
		imgBytes = img.get_packed_data()
	elif(img is Image):
		imgBytes.resize(img.width * img.height * 2)
		var j = 0
		while(j < img.width * img.height):
			imgBytes.encode_u16(j*2, ColorUtil.to_RGB15(img.get_pixel(j % img.width, j / img.width)))
			j += 1
	
	var right = btx.slice(texDataLoc + offset + imgBytes.size())
	btx.resize(texDataLoc + offset)
	btx.append_array(imgBytes)
	btx.append_array(right)

static func replacePalette(btx: PackedByteArray, ind: int, pal: Palette):
	var numFrames = btx.decode_u8(0x51)
	var palDictLoc = 0x5C + (4 * numFrames) + 4 + (8 * numFrames) + (16 * numFrames)
	var numPals = btx.decode_u8(palDictLoc + 1)
	if (ind >= numPals):
		print("Palette %s does not exist in the given BTX" % ind)
		return
	
	var dataOffset = btx.decode_u32(0x4C)
	var palOffset = btx.decode_u16(palDictLoc + 12 + (4 * numPals) + 4 + (4 * numPals)) << 3
	var i = 0
	while(i < pal.size()):
		btx.encode_u16(dataOffset + palOffset + (i * 2), ColorUtil.to_RGB15(pal.getColor(i)))
		i += 1
	
# Patricia Tree Testing
const PatriciaTreeInput: PackedStringArray = ["babyboy1.1", "babyboy1.10", "babyboy1.11", "babyboy1.12", "babyboy1.13", "babyboy1.14", "babyboy1.15", "babyboy1.16", "babyboy1.2", "babyboy1.3", "babyboy1.4", "babyboy1.5", "babyboy1.6", "babyboy1.7", "babyboy1.8", "babyboy1.9"]
const PatriciaTreeOutput: PackedByteArray = [
	0x7F, 0x01, 0x00, 0x00, 
	0x55, 0x02, 0x0B, 0x01,
	0x4D, 0x00, 0x03, 0x00,
	0x4B, 0x04, 0x0A, 0x0E,
	0x4A, 0x05, 0x07, 0x0A,
	0x49, 0x02, 0x06, 0x08,
	0x48, 0x05, 0x06, 0x09,
	0x49, 0x08, 0x09, 0x0C,
	0x48, 0x04, 0x08, 0x0B,
	0x48, 0x07, 0x09, 0x0D,
	0x48, 0x03, 0x0A, 0x0F,
	0x52, 0x0C, 0x0F, 0x05,
	0x51, 0x0D, 0x0E, 0x03,
	0x50, 0x01, 0x0D, 0x02,
	0x50, 0x0C, 0x0E, 0x04,
	0x51, 0x10, 0x0F, 0x07,
	0x50, 0x0B, 0x10, 0x06]

const BTX2TreeInput: PackedStringArray = ["tree01_re", "tree01_un", "tree01gs", "sea_on", "sea_un", "cliff01gs", "fence_b", "grass02", "grass02_r"]
const BTX2TreeOuput: PackedByteArray = [
	0x7F, 0x01, 0x00, 0x00,
	0x46, 0x02, 0x07, 0x00,
	0x3E, 0x03, 0x02, 0x02,
	0x36, 0x04, 0x03, 0x06,
	0x35, 0x05, 0x04, 0x07,
	0x2E, 0x00, 0x06, 0x03,
	0x24, 0x05, 0x06, 0x04,
	0x44, 0x08, 0x09, 0x05,
	0x43, 0x01, 0x08, 0x01,
	0x40, 0x09, 0x07, 0x08]

const BTX3TreeInput: PackedStringArray = ["tree01_re", "tree01_un", "tree01", "sea_f02_pl", "sea_un", "cliff01", "fence_b_pl", "grass02_pl", "grass02_r_pl"]
const BTX3TreeOuput: PackedByteArray = [
	0x7F, 0x01, 0x00, 0x00,
	0x5E, 0x02, 0x01, 0x08, #1
	0x4E, 0x03, 0x08, 0x03, #2
	0x46, 0x04, 0x07, 0x00, #3
	0x35, 0x05, 0x04, 0x05, #4
	0x2E, 0x06, 0x05, 0x04, #5
	0x2D, 0x00, 0x06, 0x02, #6
	0x43, 0x03, 0x07, 0x01, #7
	0x36, 0x09, 0x08, 0x06, #8
	0x24, 0x02, 0x09, 0x07] #9

static func testPatriciaTree() -> void:
	var pTree = PatriciaTree.new()
	var i = 0
	while (i < BTX3TreeInput.size()):
		pTree.addNode(BTX3TreeInput[i])
		i += 1
	
	var output := pTree.writeTree()
	i = 0
	while (i < output.size()):
		var slice = output.slice(i, i + 4)
		print("[%X, %X, %X, %X]" % [slice[0], slice[1], slice[2], slice[3]])
		i += 4

class PatriciaTree:
	var numNodes: int = 0
	var rootNode: PatTreeNode
	
	func _init() -> void:
		rootNode = PatTreeNode.new("ERROR", 0)
		rootNode.testBit = 0x7F
	
	func addNode(s: String) -> void:
		var newNode = PatTreeNode.new(s, numNodes + 1)
		newNode.left = rootNode
		if (numNodes == 0):
			rootNode.left = newNode
			numNodes += 1
			return
		
		var prev = rootNode
		var curr = rootNode.left

		var bitDiff = findBitDiff(curr.myString, s)
		while(abs(bitDiff) <= curr.testBit):
			var stepRight: bool = getBit(curr.testBit, s)
			var next = curr.right
			if (!stepRight):
				next = curr.left
			if (next.testBit >= curr.testBit):
				break;
			else:
				prev = curr
				curr = next
			bitDiff = findBitDiff(curr.myString, s)
		
		if (abs(bitDiff) > curr.testBit):
			newNode.testBit = abs(bitDiff)
			if(getBit(prev.testBit, s)):
				prev.right = newNode
				numNodes += 1
			else:
				prev.left = newNode
				numNodes += 1
				
			if (!getBit(newNode.testBit, s)):
				newNode.left = newNode
				newNode.right = curr
			else:
				newNode.left = curr
		else:
			
			newNode.testBit = min(newNode.testBit, abs(bitDiff))
			
			var temp
			if (getBit(curr.testBit, s)):
				temp = curr.right
				curr.right = newNode
				
				numNodes += 1
			else:
				temp = curr.left
				curr.left = newNode
				numNodes += 1
			
			if (newNode.testBit == curr.testBit):
				newNode.testBit = getNextBit(newNode.testBit, temp.myString, newNode.myString)
			
			if (!getBit(newNode.testBit, s)):
				newNode.left = newNode
				newNode.right = temp
			else:
				newNode.left = temp
		
	func writeTree() -> PackedByteArray:
		var retBytes: PackedByteArray = [0x7F, 0x01, 0x00, 0x00]
		
		var nodeQueue = [rootNode.left]
		var parsedNodes = [rootNode]
		while (nodeQueue.size() > 0):
			var curr = nodeQueue[0]
			nodeQueue.remove_at(0)
			parsedNodes.append(curr)
			
			var insertInd = 0
			if (curr.left.testBit < curr.testBit):
				nodeQueue.insert(insertInd, curr.left)
				insertInd += 1
			if (curr.right.testBit < curr.testBit):
				nodeQueue.insert(insertInd, curr.right)
		
		var i = 1
		while(i < parsedNodes.size()):
			var node = parsedNodes[i]
			retBytes.append_array([node.testBit, 0x00, 0x00, node.stringInd - 1])
			var j = 0
			while (j < parsedNodes.size()):
				var otherNode = parsedNodes[j]
				if (otherNode.stringInd == node.left.stringInd):
					retBytes.encode_u8(retBytes.size() - 3, j)
				if (otherNode.stringInd == node.right.stringInd):
					retBytes.encode_u8(retBytes.size() - 2, j)
				j += 1
			
			i += 1
		
		return retBytes
	
	static func getBit(bit: int, s: String) -> bool:
		if (bit/8 >= s.length()):
			return false # 0
		else:
			var byte = s.unicode_at(bit/8)
			return (byte >> (bit % 8) & 0x01 != 0)
	
	static func getNextBit(startBit: int, s1: String, s2: String) -> int:
		var i = startBit - 1
		while(i >= 0):
			if (!getBit(i, s1) && getBit(i, s2)):
				return i
			i -= 1
		
		
		return 0
	
	static func leastSigBit(s: String) -> int:
		var bit = s.length() * 8 - 1
		var c = s.unicode_at(s.length() - 1)
		var i = 0
		while ( (c << i) & 0x80 == 0):
			bit -= 1
			i += 1
		return bit
	
	static func findBitDiff(s1: String, s2: String) -> int:
		if (s1.length() > s2.length()):
			return leastSigBit(s1)
		elif(s2.length() > s1.length()):
			return -leastSigBit(s2)
		else:
			var i = s1.length() - 1
			var bit = (s1.length() - 1) * 8
			while (i >= 0):
				if (s1[i] != s2[i]):
					var char1 = s1.unicode_at(i)
					var char2 = s2.unicode_at(i)
					var j = 7
					while (j >= 0):
						if ((char1 & 0x80) == (char2 & 0x80)):
							# Bit is the same
							char1 <<= 1
							char2 <<= 1
							j -= 1
						elif (char1 & 0x80):
							# s1 has 1 at this bit
							return bit + j
						else:
							# s2 has 1 at this bit
							return -(bit + j)
				else:
					bit -= 8
					i -= 1
		return 0

class PatTreeNode:
	var testBit: int = 0x00
	var myString: String
	var stringInd: int
	var left: PatTreeNode
	var right: PatTreeNode
	
	func _init(s: String, i: int) -> void:
		myString = s
		stringInd = i
		testBit = PatriciaTree.leastSigBit(s)
		right = self
