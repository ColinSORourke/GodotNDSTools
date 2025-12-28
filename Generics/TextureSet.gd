####################
# TextureSet
# Class representing a set of Images and Palettes.
####################

class_name TextureSet

@warning_ignore_start("int_as_enum_without_cast")

var frameNames: PackedStringArray = []
var frames: Array[Vector2i] = []
var sprites: Array = []
var spriteFormats: PackedByteArray = []

var paletteNames: PackedStringArray = []
var fullPalette := Palette.new()
var paletteStarts := PackedByteArray()
var palettes: Array[Palette] = []

var currFrame: ImageTexture
var currFrameInd: int
var currPalInd: int

var fullWidth: int = 0
var fullHeight: int = 0

func addFrame(f: Vector2i, n: String) -> void:
	if (f.x < sprites.size() && f.y < palettes.size()):
		frameNames.append(n)
		var i = 0
		while (i < palettes.size()):
			if (n == paletteNames[i] || n + "_pl" == paletteNames[i]):
				f.y = i
				break;
			i += 1
		frames.append(f)

func addSprite(img, f: int) -> void:
	sprites.append(img)
	spriteFormats.append(f)	
	fullHeight += img.height
	if (img.width > fullWidth):
		fullWidth = img.width
	
func addPalette(n: String, start: int, numColors: int) -> void:
	var subPal := Palette.new()
	var i = start
	while(i < start + numColors && i < fullPalette.size()):
		subPal.addColor(fullPalette.getColor(i))
		i += 1
	
	palettes.append(subPal)
	paletteStarts.append(start)
	paletteNames.append(n)
	
func currFrameInfo() -> Array:
	if (sprites.is_empty()):
		return [-1, -1, -1]
	var spriteInd = frames[currFrameInd].x
	return [sprites[spriteInd].width, sprites[spriteInd].height, spriteFormats[spriteInd]]
	
func currPaletteInfo() -> Array:
	if (palettes.is_empty()):
		return [-1]
	return[palettes[currPalInd].size()]

func setFrame(f: int, p: int = -1) -> void:
	
	if (f < frames.size()):
		if (p < 0 || p > palettes.size()):
			p = frames[f].y
		if (spriteFormats[frames[f].x] == 7 || spriteFormats[frames[f].x] == 5):
			currFrame = ImageTexture.create_from_image(sprites[frames[f].x])
		else:
			
			currFrame = sprites[frames[f].x].create_texture(palettes[p])
		currFrameInd = f
		currPalInd = p
		
func replaceSprite(img, frame: int = -1) -> bool:
	if (frame == -1):
		frame = currFrameInd
	var sprite = sprites[frames[frame].x]
	
	if (sprite.bitDepth != img.bitDepth):
		#print("BitDepth mismatch")
		return false
	
	if (sprite.width != img.width || sprite.height != img.height):
		#print("Dimension mismatch")
		return false
		
	sprites[frames[frame].x] = img
	return true

func replacePalette(pal: Palette, ind: int = -1) -> bool:
	if (ind == -1):
		ind = currPalInd
	
	if(palettes[ind].bitDepth != pal.bitDepth):
		return false
	
	palettes[ind] = pal
	
	var i = 0
	while(i < pal.size()):
		fullPalette.replaceColor(paletteStarts[ind] + i, pal.getColor(i))
		i += 1
	
	return true

func getCurrSprite() -> Variant:
	return sprites[frames[currFrameInd].x]
	
func getCurrFormat() -> int:
	return spriteFormats[frames[currFrameInd].x]

func getCurrPal() -> Palette:
	return palettes[currPalInd]

func getPalName() -> String:
	return paletteNames[currPalInd]

func getFrameName() -> String:
	return frameNames[currFrameInd]
	
func canSpriteSheet() -> bool:
	if (sprites.size() == 0):
		# Cannot produce a spritesheet with no sprites
		return false
	if (spriteFormats[0] == 5):
		# BTX Format 5, Compressed Texel Blocks, is not bijective to Indexed PNG
		return false
	if (spriteFormats[0] == 1 || spriteFormats[0] == 1):
		# BTX Formats 1 & 6 are Indexed with a full alpha channel, forbidden PNG
		return false
	var i = 1
	while (i < spriteFormats.size()):
		if (spriteFormats[i] != spriteFormats[0]):
			# Cannot produce an indexed PNG with inconsistent formats
			return false
		i += 1
	return true
	
func getSpriteSheet():
	var i = 0
	var currPos := Vector2i(0, 0)
	var bpp = 4;
	if (spriteFormats[0] == 7):
		var image = Image.create_empty(fullWidth, fullHeight, false, Image.FORMAT_RGBA8)
		while(i < sprites.size()):
			image.blit_rect(sprites[i].myImage, sprites[i].get_rect(), currPos)
			currPos.y += sprites[i].height
			i += 1
		return image
	
	var retIndex = IndexedImage.new(fullWidth, fullHeight, bpp, 0)
	while(i < sprites.size()):
		retIndex.blit_image(currPos.x, currPos.y, sprites[i])
		currPos.y += sprites[i].height
		i += 1
	retIndex.myPal = palettes[currPalInd]
	return retIndex
	
