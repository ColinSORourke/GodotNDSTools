####################
# NARC
# Class representing a NitroArchive
# https://github.com/VendorPC/NARCTool
####################

class_name NARC

const folderIcon: Texture2D = preload("res://Assets/GameIcons/open-folder-2.svg")

const NARCHeader: PackedByteArray = [0x4E, 0x41, 0x52, 0x43, # NARC Stamp
									0xFF, 0xFE, # Byte Order
									0x00, 0x01, # Version, always 0x0100
									0x00, 0x00, 0x00, 0x00, # File Size
									0x10, 0x00, # Header Size, 16
									0x03, 0x00] # Number of Chunks (Always 3)
const FATBHeader: PackedByteArray = [0x42, 0x54, 0x41, 0x46, # FATB Stamp
									0x00, 0x00, 0x00, 0x00, # FATB Size
									0x00, 0x00, # Number of Files
									0x00, 0x00] # Zeroes
									# FATB Entry
										# u32, Start Address
										# u32, End Address
const FNTBHeader: PackedByteArray = [0x42, 0x54, 0x4E, 0x46, # FNTB Stamp
									0x00, 0x00, 0x00, 0x00, # FNTB Size
									0x00, 0x00, 0x00, 0x00, # Offset to first sub table
									0x00, 0x00, # ID of first file in Sub Table
									0x00, 0x01] # Total number of directories  
									# FNTB Entry
										# u32 offset to sub table
										# u16 ID of first file in SubTable
										# u16 ID of Parent Directory
									# FNTSub Entry
										# U8, Entry Type + Length
											# 0 = End of Sub Table
											# 1-127, File with name that Length
											# 129-256, SubDirectory with name that Length - 128
											# 128 - Reserved, do not use
										# String, Length
										# IF SubDirectory
											#U16, SubDirectory ID
const FIMGHeader: PackedByteArray = [0x47, 0x4D, 0x49, 0x46, # FIMG Stamp
									0x00, 0x00, 0x00, 0x00] # FIMG Size

# 0x4352414E, 0x4E415243 = "NARC"
static func isNarc(bytes: PackedByteArray) -> bool:
	if (bytes.size() < 4):
		return false
	if (bytes.decode_u32(0) != 0x4E415243 && bytes.decode_u32(0) != 0x4352414E):
		# NOT A NARC FILE
		return false
	return true

var myBytes: PackedByteArray
var numFiles: int = 0
var fileAllocs: Array[Vector2i] = []

var dirNames: PackedStringArray = []
var fileNames: PackedStringArray = []

var blocks: PackedInt32Array = [0, 16, 0, 0]

var uniformFileSize: bool = false

func unpack(bytes: PackedByteArray) -> void:
	myBytes = bytes
	numFiles = bytes.decode_u16(24)
	
	var currOffset := 28
	var i := 0
	
	uniformFileSize = true
	var originalSize = bytes.decode_u32(currOffset + 4) - bytes.decode_u32(currOffset)
	
	while(i < numFiles):
		var start: int = bytes.decode_u32(currOffset)
		currOffset += 4
		var end: int = bytes.decode_u32(currOffset)
		uniformFileSize = ((end - start) == originalSize) && uniformFileSize
		currOffset += 4
		fileAllocs.append(Vector2i(start, end))
		i += 1
	
	blocks[2] = currOffset
	var numDirs := bytes.decode_u16(currOffset + 14)
	
	if (bytes.decode_u32(currOffset + 8) >= 8):
		i = 0
		dirNames.resize(numDirs)
		fileNames.resize(numFiles)
		while(i < numDirs):
			var subTableOffset := bytes.decode_u32(currOffset + 8) + blocks[2] + 8
			var fileId := bytes.decode_u16(currOffset + 12)
			var size = bytes.decode_u8(subTableOffset)
			var parentName = ""
			if (i != 0):
				var _parentInd = (bytes.decode_u16(currOffset + 14) & 0x0FFF) 
				parentName = dirNames[i]
			while(size != 0):
				var name = bytes.slice(subTableOffset+1, subTableOffset + 1 + (size % 128)).get_string_from_ascii()
				if (size > 128):
					dirNames[bytes.decode_u16(subTableOffset + 1 + name.length()) & 0x0FFF] = parentName + "/" + name
					size = bytes.decode_u8(subTableOffset + 3 + name.length())
					subTableOffset += 3 + name.length()
				else:
					fileNames[fileId] = parentName + "/" + name
					fileId += 1
					size = bytes.decode_u8(subTableOffset + 1 + name.length())
					subTableOffset += 1 + name.length()
			currOffset += 8
			i += 1
	
	blocks[3] = currOffset + bytes.decode_u32(currOffset + 4)

func getFIMGData() -> PackedByteArray:
	return myBytes.slice(blocks[3] + 8)

func getFile(ind: int) -> PackedByteArray:
	if (ind >= fileAllocs.size()):
		print("NARC does not have that file")
		return []
	return myBytes.slice(blocks[3] + 8 + fileAllocs[ind].x, blocks[3] + 8 +fileAllocs[ind].y)
	
func populateTree(t: Tree) -> void:
	var rootItem = t.create_item()
	t.hide_root = true
	
	if (dirNames.size() == 0):
		var i = 0
		while (i < numFiles):
			var newFile = t.create_item(rootItem)
			newFile.set_text(0, "%s" % i)
			newFile.set_metadata(0, i)
			i += 1
	else:
		var i = 1
		var dirRoots: Array[TreeItem] = []
		dirRoots.resize(dirNames.size())
		dirRoots[0] = rootItem
		while(i < dirNames.size()):
			var parent = dirNames[i].get_base_dir()
			var parentInd = dirNames.find(parent)
			var newDir = t.create_item(dirRoots[parentInd])
			newDir.set_text(0, dirNames[i].get_file())
			newDir.set_icon(0, folderIcon)
			newDir.collapsed = true;
			dirRoots[i] = newDir
			i += 1
		
		i = 0
		while (i < fileNames.size()):
			var parent = fileNames[i].get_base_dir()
			var parentInd = dirNames.find(parent)
			var newFile = t.create_item(dirRoots[parentInd])
			newFile.set_text(0, fileNames[i].get_file())
			newFile.set_metadata(0, i)
			i += 1

func replaceFile(ind: int, newFile: PackedByteArray) -> void:
	if (ind >= fileAllocs.size()):
		print("NARC does not have that file")
		return
	
	var sizeDiff: int= fileAllocs[ind].y - fileAllocs[ind].x - newFile.size()
	
	var temp := myBytes.slice(fileAllocs[ind].y)
	myBytes.resize(fileAllocs[ind].x)
	myBytes.append_array(newFile)
	myBytes.append_array(temp)
	
	if (sizeDiff != 0):
		fileAllocs[ind].y += sizeDiff
		var fatbLoc = blocks[1] + 12 + (ind * 8)
		myBytes.encode_u32(fatbLoc + 4, fileAllocs[ind].y)
		var i = ind + 1
		while(i < fileAllocs.size()):
			fatbLoc = blocks[1] + 12 + (i * 8)
			fileAllocs[i].x += sizeDiff
			myBytes.encode_u32(fatbLoc, fileAllocs[ind].x)
			fileAllocs[i].y += sizeDiff
			myBytes.encode_u32(fatbLoc + 4, fileAllocs[ind].y)
			i += 1

	myBytes.encode_u32(8, myBytes.decode_u32(8) + sizeDiff)
	myBytes.encode_u32(blocks[3] + 4, myBytes.decode_u32(blocks[3] + 4) + sizeDiff)
