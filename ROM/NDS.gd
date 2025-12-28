####################
# NDS
# GDScript parser for NDS Roms
# MUCH OF THIS CODE IS NOT MY OWN ALGORITHMS
# This is a port of a lot of excellent algorithms written by other cool people!
# Including:
	# https://github.com/JackHack96/jNdstool
	# https://github.com/VendorPC/NARCTool
####################
@warning_ignore_start("integer_division")
@warning_ignore_start("narrowing_conversion")
class_name NDS

# Main Extract Function
# https://github.com/JackHack96/jNdstool/src/main/java/nitro/ROM.java
static func extractROM(romPath: String, projPath: String) -> void:
	var projDir = DirAccess.open(projPath)
	projDir.make_dir("unpacked")
	var dirPath: String = projPath.path_join("unpacked")
	var dir = DirAccess.open(dirPath)
	
	projDir.make_dir("gd_res")
	projDir.make_dir("exported")
	
	var romFile: FileAccess = FileAccess.open(romPath, FileAccess.READ)
	var fileTree: NitroFileTree = NitroFileTree.new()
	
	var header: NitroHeader = NitroHeader.new()
	header.readFile(romFile)
	
	fileTree.readOffsets(romFile, header.fatOffset, header.fatSize)
	
	romFile.seek(header.fntOffset)
	
	fileTree.readFNT(romFile, romFile.get_position())
	fileTree.unpackFileTree(romFile, dirPath)
	
	dir.make_dir("overlays")
	var i = 0
	while (i < header.arm9OverlaySize / 0x20):
		var overlayPath = dirPath.path_join("overlays").path_join("overlay_%04d.bin" % i)
		if (!FileAccess.file_exists(overlayPath)):
			var tmpWriter: FileAccess = FileAccess.open(overlayPath, FileAccess.WRITE_READ)
			romFile.seek(fileTree.FATOffsetVecs[i].x)
			tmpWriter.store_buffer(romFile.get_buffer(fileTree.FATOffsetVecs[i].y))
			tmpWriter.close()
		i += 1
	fileTree.arm9overlayCount = i
	var arm7OvSize: int = header.arm7OverlaySize / 0x20
	i = 0
	while (i < arm7OvSize):
		var overlayPath = dirPath.path_join("overlays").path_join("overlay_%04d.bin" % i)
		if (!FileAccess.file_exists(overlayPath)):
			var tmpWriter: FileAccess = FileAccess.open(overlayPath, FileAccess.WRITE_READ)
			romFile.seek(fileTree.FATOffsetVecs[i + arm7OvSize].x)
			tmpWriter.store_buffer(romFile.get_buffer(fileTree.FATOffsetVecs[i + arm7OvSize].y))
			tmpWriter.close()
		i += 1
	fileTree.arm7overlayCount = i
	
	if (!FileAccess.file_exists(dirPath.path_join("header.bin"))):
		romFile.seek(0)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("header.bin"), FileAccess.WRITE_READ)
		tmpWriter.store_buffer(romFile.get_buffer(0x200))
		tmpWriter.close()
	
	if (!FileAccess.file_exists(dirPath.path_join("arm9.bin"))):
		romFile.seek(header.arm9RomOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm9.bin"), FileAccess.WRITE_READ)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm9Size))
		tmpWriter.close()
		
	if (!FileAccess.file_exists(dirPath.path_join("arm9ovltable.bin"))):
		romFile.seek(header.arm9OverlayOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm9ovltable.bin"), FileAccess.WRITE_READ)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm9OverlaySize))
		tmpWriter.close()
		
	if (!FileAccess.file_exists(dirPath.path_join("arm7.bin"))):
		romFile.seek(header.arm7RomOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm7.bin"), FileAccess.WRITE_READ)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm7Size))
		tmpWriter.close()
	
	if (!FileAccess.file_exists(dirPath.path_join("arm7ovltable.bin"))):
		romFile.seek(header.arm7OverlayOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm7ovltable.bin"), FileAccess.WRITE_READ)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm7OverlaySize))
		tmpWriter.close()
		
	if (!FileAccess.file_exists(dirPath.path_join("banner.bin"))):
		romFile.seek(header.iconOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("banner.bin"), FileAccess.WRITE_READ)
		tmpWriter.store_buffer(romFile.get_buffer(0x840))
		tmpWriter.close()
		
	romFile.close()
	
	print(fileTree.FATOffsetVecs.slice(129, 132))
	
	var tmp = FileAccess.open(projPath.path_join("gd_res/FNT.tres"), FileAccess.WRITE_READ)
	ResourceSaver.save(fileTree, projPath.path_join("gd_res/FNT.tres"))
	tmp.close()
	tmp = FileAccess.open(projPath.path_join("gd_res/Header.tres"), FileAccess.WRITE_READ)
	ResourceSaver.save(header, projPath.path_join("gd_res/Header.tres"))
	tmp.close()

# Utility Function
# https://github.com/JackHack96/jNdstool/src/main/java/nitro/ROM.java
static func addPadding(offset: int, padMult: int = 4) -> int:
	if (offset % padMult != 0):
		return offset + (padMult - offset % padMult)
	else:
		return offset
		
# Utility Function
static func getFileSize(path: String) -> int:
	var tmp = FileAccess.open(path, FileAccess.READ)
	var size = tmp.get_length()
	tmp.close()
	return size;

static func rebuildRom(projPath: String) -> void:
	var haveAllFiles := true
	var dirPath := projPath.path_join("unpacked")
	
	if (!DirAccess.dir_exists_absolute(dirPath.path_join("files"))):
		haveAllFiles = false
	if (!DirAccess.dir_exists_absolute(dirPath.path_join("overlays"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm9.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm9ovltable.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm7.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm7ovltable.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("header.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("banner.bin"))):
		haveAllFiles = false
		
	if (!haveAllFiles):
		print("Something has gone horribly wrong")
		return
	pass
	
	var romFile: FileAccess = FileAccess.open(projPath.path_join("GodotExport.NDS"), FileAccess.WRITE_READ)
	var reader: FileAccess
	
	var FileTree = NitroFileTree.new()
	var overlays = FileTree.readUnpackedOverlays(dirPath)
	if (FileAccess.file_exists(projPath.path_join("gd_res/FNT.tres"))):
		var oldFNT = load(projPath.path_join("gd_res/FNT.tres"))
		FileTree.originalOrder = oldFNT.originalOrder
		print("Loaded Original Order")
		print(FileTree.originalOrder.slice(0,8))
	FileTree.readUnpackedFiles(dirPath)
	
	# Store Placeholder Header
	reader = FileAccess.open(dirPath.path_join("header.bin"), FileAccess.READ)
	var header: NitroHeader = NitroHeader.new()
	header.readFile(reader)
	var h: PackedByteArray = PackedByteArray()
	h.resize(0x4000)
	romFile.store_buffer(h)
	
	# Store Arm9
	reader = FileAccess.open(dirPath.path_join("arm9.bin"), FileAccess.READ)
	header.arm9RomOffset = romFile.get_position()
	header.arm9Size = reader.get_length()
	romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm9.bin")))
	while (romFile.get_position() % 512 != 0):
		romFile.store_8(0xFF)
	
	# Store Arm9 Overlay Table
	reader = FileAccess.open(dirPath.path_join("arm9ovltable.bin"), FileAccess.READ)
	header.arm9OverlayOffset = romFile.get_position()
	header.arm9OverlaySize = reader.get_length()
	romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm9ovltable.bin")))
	while (romFile.get_position() % 512 != 0):
		romFile.store_8(0xFF)
	
	# Overlay File Offsets for File Allocation Table Later
	var ovlStarts := Vector2i(0, 0)
	# Store all Arm9 Overlays
	var i = 0
	ovlStarts.x = romFile.get_position()
	while (i < header.arm9OverlaySize / 0x20):
		reader = FileAccess.open(dirPath.path_join("overlays").path_join(overlays[i]), FileAccess.READ)
		romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("overlays").path_join(overlays[i])))
		while (romFile.get_position() % 512 != 0):
			romFile.store_8(0xFF)
		i += 1
	
	# Store Arm7
	reader = FileAccess.open(dirPath.path_join("arm7.bin"), FileAccess.READ)
	header.arm7RomOffset = romFile.get_position()
	header.arm7Size = reader.get_length()
	romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm7.bin")))
	while (romFile.get_position() % 512 != 0):
		romFile.store_8(0xFF)
	
	# Store Arm7 Overlay Table
	reader = FileAccess.open(dirPath.path_join("arm7ovltable.bin"), FileAccess.READ)
	header.arm7OverlayOffset = romFile.get_position()
	header.arm7OverlaySize = reader.get_length()
	romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm7ovltable.bin")))
	while (romFile.get_position() % 512 != 0):
		romFile.store_8(0xFF)
	
	# Store all Arm7 Overlays
	i = header.arm9OverlaySize / 0x20
	ovlStarts.y = romFile.get_position()
	while (i < header.arm9OverlaySize / 0x20 + header.arm7OverlaySize / 0x20):
		reader = FileAccess.open(dirPath.path_join("overlays").path_join(overlays[i]), FileAccess.READ)
		romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("overlays").path_join(overlays[i])))
		while (romFile.get_position() % 512 != 0):
			romFile.store_8(0xFF)
		i += 1
	
	# Store the File Name Table
	header.fntOffset = romFile.get_position()
	FileTree.writeFNT(romFile)
	header.fntSize = romFile.get_position() - header.fntOffset
	while (romFile.get_position() % 512 != 0):
		romFile.store_8(0xFF)
	
	# Calculate FIMGOffset so we can correctly adjust File Allocation Table
	var fimgOffset: int = romFile.get_position()
	fimgOffset += FileTree.FATSize
	fimgOffset = addPadding(fimgOffset, 512)
	fimgOffset += 0xA00 #Banner Size is always 0x840, padded to 512, 0xA00
	
	# Store the File Allocation Table
	header.fatOffset = romFile.get_position()
	FileTree.writeFAT(romFile, ovlStarts, fimgOffset)
	header.fatSize = romFile.get_position() - header.fatOffset
	while (romFile.get_position() % 512 != 0):
		romFile.store_8(0xFF)
	
	# Store the banner info
	header.iconOffset = romFile.get_position()
	romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("banner.bin")))
	while (romFile.get_position() % 512 != 0):
		romFile.store_8(0xFF)
	
	FileTree.writeFileTree(romFile, dirPath)
	
	var tmp = FileAccess.open(projPath.path_join("gd_res/FNT_OUT.tres"), FileAccess.WRITE_READ)
	ResourceSaver.save(FileTree, projPath.path_join("gd_res/FNT_OUT.tres"))
	tmp.close()
	
	romFile.seek(0)
	header.updateChecksum()
	header.writeOut(romFile)
	
	romFile.close()
	reader.close()
