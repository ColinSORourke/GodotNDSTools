####################
# NitroFileTree
# GDScript parser for the FileTree in NDS ROMS
# Stores a Dictionary Representation of the Tree as a Resource 
# so table & metadata does not need to be reconstructed
# Reference:
# https://github.com/JackHack96/jNdstool/src/main/java/nitro/NitroDirectory.java
# https://github.com/JackHack96/jNdstool/src/main/java/nitro/FNT.java
####################
class_name NitroFileTree extends Resource

enum NitroType {DIR, BIN, NARC, NCGR, NCLR, BMD0, BTX0, NCSR, NANR, NMAR, NCMR, NCER, FATB, FNTB, FIMG}

# Hex Codes -> File Extensions/Stamps
const extensionDict: Dictionary = {
	0x424D4430 : NitroType.BMD0,
	0x30444D42 : NitroType.BMD0,
	
	0x42545830 : NitroType.BTX0,
	0x30585442 : NitroType.BTX0,
	
	0x4E534352 : NitroType.NCSR,
	0x5243534E : NitroType.NCSR,
	
	0x4E434C52 : NitroType.NCLR,
	0x524C434E : NitroType.NCLR,
	
	0x4E434752 : NitroType.NCGR,
	0x5247434E : NitroType.NCGR,
	
	0x4E414E52 : NitroType.NANR,
	0x524E414E : NitroType.NANR,
	
	0x4E4D4152 : NitroType.NMAR,
	0x52414D4E : NitroType.NMAR,
	
	0x4E4D4352 : NitroType.NCMR,
	0x52434D4E : NitroType.NCMR,
	
	0x4E434552 : NitroType.NCER,
	0x5245434E : NitroType.NCER,
	
	0x4E415243 : NitroType.NARC,
	0x4352414E : NitroType.NARC,
	
	0x42544146 : NitroType.FATB,
	0x46415442 : NitroType.FATB,
	
	0x42544E46 : NitroType.FNTB,
	0x464E5442 : NitroType.FNTB,
	
	0x474D4946 : NitroType.FIMG,
	0x46494D47 : NitroType.FIMG
}

var FNT: Dictionary = {
	"files": {"Name": "Files", "id": 0xf000, "fileType": NitroType.DIR, "Files": [], "Directories": []},
	"SampleFile": {"Name": "SampleFile", "id": 0, "fileType": NitroType.BIN, "offsetVec": Vector2i(0,0)}
}

var minOS: int = -1
var maxOS: int = -1

@export var numDirs: int = 1
@export var numFiles: int = 0
@export var subTableSize: int = 0
@export var originalOrder: PackedStringArray

# File Allocation Table
# https://github.com/JackHack96/jNdstool/src/main/java/nitro/FAT.java
# Takes a RomFile, the offset of the FAT, the size of the FAT
# Does NOT return to initial position

# Offset stored in format {start, size}
	# End is thus derived start + size
@export var FATOffsetVecs: Array
@export var FATSize: int
@export var arm7overlayCount: int = 0
@export var arm9overlayCount: int = 0
@export var overlayCount: int = 0

func readOffsets(romFile: FileAccess, fOffset: int, fSize: int):
	FATSize = fSize
	FATOffsetVecs = []
	FATOffsetVecs.resize(fSize/8)
	
	romFile.seek(fOffset)
	var i: int = 0
	while (i < FATSize / 8):
		var start: int = romFile.get_32()
		var end: int = romFile.get_32()
		FATOffsetVecs[i] = Vector2i(start, end - start)
		i += 1

func writeFAT(romFile: FileAccess, ovlStart: Vector2i, treeStart: int):
	var i = 0
	while (i < FATOffsetVecs.size()):
		var start = FATOffsetVecs[i].x
		var end = FATOffsetVecs[i].x + FATOffsetVecs[i].y
		if (i < arm7overlayCount):
			start += ovlStart.y
			end += ovlStart.y
		elif (i < overlayCount):
			start += ovlStart.x
			end += ovlStart.x
		else:
			start += treeStart
			end += treeStart
		romFile.store_32(start)
		romFile.store_32(end)
		i += 1

func readFNT(romFile: FileAccess, origin: int) -> void:
	minOS = romFile.get_length()
	var dfsQueue: PackedStringArray = ["files"]
	
	while (dfsQueue.size() > 0):
		var currPath = dfsQueue[0]
		dfsQueue.remove_at(0)
		
		romFile.seek(origin + (8 * (FNT[currPath].id & 0xFFF)) )
		var subTableOffset: int = romFile.get_32()
		var fileId: int = romFile.get_16()
		romFile.seek(origin + subTableOffset)
		var header: int = romFile.get_8()
	
		while (header & 0x7F != 0):
			var dirCount = 0
			var nameBytes: String = romFile.get_buffer(header & 0x7F).get_string_from_ascii()
			if (header > 0x7F):
				var newID: int = romFile.get_16()
				var newDir = {"Name": nameBytes, "id": newID, "fileType": NitroType.DIR, "Files": [], "Directories": []}
				addChild(currPath, newDir)
				dfsQueue.insert(dirCount, currPath.path_join(nameBytes))
				dirCount += 1
			else:
				var osVec = Vector2(FATOffsetVecs[fileId])
				var newFile = {"Name": nameBytes, "id": fileId, "fileType": NitroType.BIN, "offsetVec": osVec}
				addChild(currPath, newFile)  
				addFileOrder(currPath.path_join(nameBytes), osVec.x)
				fileId += 1
			
			header = romFile.get_8()

func writeFNT(romFile: FileAccess) -> void: 
	var fntMainTable: PackedByteArray = []
	var fntSubTable: PackedByteArray = []
	
	fntMainTable.resize(numDirs * 8)
	fntSubTable.resize(subTableSize)
	
	var mainByteOffset := 0
	var subByteOffset := 0
	
	var dfsQueue = ["files"]
	var parentQueue = [FNT["files"].id]
	
	while (dfsQueue.size() > 0):
		var currDir = dfsQueue[0]
		var parDirId = parentQueue[0]
		parentQueue.remove_at(0)
		dfsQueue.remove_at(0)
		
		var dirObj = FNT[currDir]
		fntMainTable.encode_u32(mainByteOffset, fntMainTable.size() + subByteOffset)
		mainByteOffset += 4
		fntMainTable.encode_u16(mainByteOffset, getFirstFileId(currDir))
		mainByteOffset += 2
		fntMainTable.encode_u16(mainByteOffset, parDirId)
		mainByteOffset += 2
		
		var i := 0
		for dir in FNT[currDir].Directories:
			var subDirObj = FNT[currDir.path_join(dir)]
			fntSubTable.encode_u8(subByteOffset, 128 + subDirObj.Name.length())
			subByteOffset += 1
			encodeASCIIBuffer(fntSubTable, subByteOffset, subDirObj.Name.to_ascii_buffer())
			subByteOffset += subDirObj.Name.length()
			fntSubTable.encode_u16(subByteOffset, subDirObj.id)
			subByteOffset += 2
			
			if (!dfsQueue.has(currDir.path_join(dir))):
				parentQueue.insert(i, dirObj.id)
				dfsQueue.insert(i, currDir.path_join(dir))
			i += 1
			
		for file in FNT[currDir].Files:
			var fileObj = FNT[currDir.path_join(file)]
			fntSubTable.encode_u8(subByteOffset, fileObj.Name.length())
			subByteOffset += 1
			encodeASCIIBuffer(fntSubTable, subByteOffset, fileObj.Name.to_ascii_buffer())
			subByteOffset += fileObj.Name.length()
		
		fntSubTable.encode_u8(subByteOffset, 0)
		subByteOffset += 1
	
	romFile.store_buffer(fntMainTable)
	romFile.store_buffer(fntSubTable)

func encodeASCIIBuffer(pb: PackedByteArray, offset: int, ab: PackedByteArray) -> void:
	var i = 0
	while(i < ab.size()):
		pb.encode_u8(offset + i, ab[i])
		i += 1

func getFirstFileId(p: String) -> int:
	var path = p
	var currDirObj = FNT[p]
	while (true):
		if (currDirObj.Files.size() > 0):
			return FNT[path.path_join(currDirObj.Files[0])].id
		elif (currDirObj.Directories.size() > 0):
			path = path.path_join(currDirObj.Directories[0])
			currDirObj = FNT[path]
			
		else:
			return -1
	return -1

func writeFileTree(romFile: FileAccess, currPath: String) -> void:
	var _fileTreeStart := romFile.get_position()
	var _filesWritten = 0
	
	var i = 0
	while (i < originalOrder.size()):
		if (FileAccess.file_exists( currPath.path_join(originalOrder[i]) ) ):
			var fileBytes = FileAccess.get_file_as_bytes(currPath.path_join(originalOrder[i]))
			romFile.store_buffer(fileBytes)
			while (romFile.get_position() % 512 != 0):
				romFile.store_8(0xFF)
			_filesWritten += 1
		i += 1
	
	var dfsQueue = ["files"]
	while (dfsQueue.size() > 0):
		var currDir = dfsQueue[0]
		dfsQueue.remove_at(0)
		
		i = 0
		for dir in FNT[currDir].Directories:
			dfsQueue.insert(i, currDir.path_join(FNT[currDir].Directories[i]))
			i += 1
			
		for file in FNT[currDir].Files:
			if (currDir.path_join(file) not in originalOrder):
				if (FileAccess.file_exists( currPath.path_join(currDir.path_join(file)) ) ):
					var fileBytes = FileAccess.get_file_as_bytes(currPath.path_join(currDir.path_join(file)))
					romFile.store_buffer(fileBytes)
					while (romFile.get_position() % 512 != 0):
						romFile.store_8(0xFF)
					_filesWritten += 1

func unpackFileTree(romFile: FileAccess, rootPath: String) -> void:
	var dfsQueue: PackedStringArray = ["files"]
	while (dfsQueue.size() > 0):
		var fntPath = dfsQueue[0]
		dfsQueue.remove_at(0)
		
		var fullPath = rootPath.path_join(fntPath)
		
		if (FNT[fntPath].fileType == NitroType.DIR):
			if (!FileAccess.file_exists(fullPath)):
				DirAccess.make_dir_absolute(fullPath)
			var i: int = 0
			while (i < FNT[fntPath].Directories.size()):
				dfsQueue.insert(i, fntPath.path_join(FNT[fntPath].Directories[i]))
				i += 1
			i = 0
			while (i < FNT[fntPath].Files.size()):
				dfsQueue.insert(i, fntPath.path_join(FNT[fntPath].Files[i]))
				i += 1
		else:
			if (!FileAccess.file_exists(fullPath)):
				var newFile = FileAccess.open(fullPath, FileAccess.WRITE_READ)
				romFile.seek(FNT[fntPath].offsetVec.x)
				var newBuffer = romFile.get_buffer(FNT[fntPath].offsetVec.y)
				newFile.store_buffer(newBuffer)
				newFile.close()

func addFileOrder(name: String, position: int) -> void:
	if (position < minOS):
		originalOrder.insert(0, name)
		minOS = position
		return
	if (position > maxOS):
		originalOrder.append(name)
		maxOS = position
		return
	
	var i = 1
	while (i < originalOrder.size()):
		if (position < FNT[originalOrder[i]].offsetVec.x):
			originalOrder.insert(i, name)
			return
		i += 1
	

func readUnpackedOverlays(root: String) -> PackedStringArray:
	var ovlDir = DirAccess.open(root.path_join("overlays"))
	var files = ovlDir.get_files()
	files.sort()
	var i = 0
	var currOffset = 0
	FATOffsetVecs = PackedVector2Array()
	overlayCount = files.size()
	FATOffsetVecs.resize(overlayCount)
	FATSize = overlayCount * 8
	while (i < files.size()):
		var temp = FileAccess.open(root.path_join("overlays".path_join(files[i])), FileAccess.READ)
		var size: int = temp.get_length()
		temp.close()
		FATOffsetVecs[i] = Vector2i(currOffset, size)
		currOffset += size
		if (currOffset % 512 != 0): 
			currOffset += (512 - (currOffset % 512))
		i += 1
	return files

# StartOffset = OverlaysSize
func readUnpackedFiles(root: String) -> void:
	var dfsQueue: PackedStringArray = ["files"]
	var currDirId := 0xf000
	var currFileId := overlayCount
	var currOffset := 0
	
	var originalOffsets := []
	originalOffsets.resize(originalOrder.size())
	
	var i = 0
	while (i < originalOrder.size()):
		if (FileAccess.file_exists( root.path_join(originalOrder[i]) ) ):
			var temp = FileAccess.open(root.path_join(originalOrder[i]), FileAccess.READ)
			var size: int = temp.get_length()
			var osVec = Vector2i(currOffset, size)
			currOffset += size
			if (currOffset % 512 != 0): 
				currOffset += (512 - (currOffset % 512))
			originalOffsets[i] = osVec
		else:
			originalOrder[i] = "File Missing"
		i += 1
	
	while (dfsQueue.size() > 0):
		var currPath = dfsQueue[0]
		dfsQueue.remove_at(0)
		FNT[currPath].id = currDirId
		currDirId += 1
		
		var currDir = DirAccess.open(root.path_join(currPath))
		var dirList = currDir.get_directories()
		dirList.sort()
		var files = currDir.get_files()
		files.sort()
		if (!dirList.is_empty()):
			i = 0
			while (i < dirList.size()):
				#id is temporary and wrong
				var newDir = {"Name": dirList[i], "id": currDirId, "fileType": NitroType.DIR, "Files": [], "Directories": []}
				addChild(currPath, newDir)
				dfsQueue.insert(i, currPath.path_join(newDir.Name))
				i += 1
		
		if (!files.is_empty()):
			files.sort()
			i = 0
			while (i < files.size()):
				var originalInd = originalOrder.find(currPath.path_join(files[i]))
				if (originalInd != -1):
					var osVec = originalOffsets[originalInd]
					var newFile = {"Name": files[i], "id": currFileId, "fileType": NitroType.BIN, "offsetVec": osVec}
					addChild(currPath, newFile)
					FATOffsetVecs.push_back(osVec)
					FATSize += 8
				else:
					var temp = FileAccess.open(root.path_join(currPath.path_join(files[i])), FileAccess.READ)
					var size: int = temp.get_length()
					temp.close()
					var osVec = Vector2i(currOffset, size)
					currOffset += size
					if (currOffset % 512 != 0): 
						currOffset += (512 - (currOffset % 512))
					var newFile = {"Name": files[i], "id": currFileId, "fileType": NitroType.BIN, "offsetVec": osVec}
					addChild(currPath, newFile)  
					FATOffsetVecs.push_back(osVec)
					FATSize += 8
				currFileId += 1
				i += 1
		subTableSize += 1

func addChild(parent: String, child: Dictionary) -> void:
	if (FNT[parent].fileType != NitroType.DIR):
		# throw error
		return
	
	FNT[parent.path_join(child.Name)] = child
	if (child.fileType == NitroType.DIR):
		FNT[parent].Directories.append(child.Name)
		subTableSize += child.Name.length() + 3
		numDirs += 1
	else:
		FNT[parent].Files.append(child.Name)
		subTableSize += child.Name.length() + 1  
		numFiles += 1

func checkFileType(path: String, file: PackedByteArray) -> void:
	var fileSig = file.decode_u32(0)
	if (fileSig in extensionDict.keys()):
		FNT[path].fileType = extensionDict[fileSig]
