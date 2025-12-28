####################
# Nitro Header
# Header information for NDS ROMs
# Reference: https://github.com/JackHack96/jNdstool/src/main/java/nitro/NitroHeader.java
####################
class_name NitroHeader extends Resource

static var headerValues = ["gameTitle", "gameCode", "makerCode", "unitCode", "encryptionSeedSelect", "deviceCapacity", "reserved1", "dsiFlags", "ndsRegion", "romVersion", "autoStart", "arm9RomOffset", "arm9EntryAddress", "arm9RamAddress", "arm9Size", "arm7RomOffset", "arm7EntryAddress", "Arm7RamAddress", "arm7Size", "fntOffset", "fntSize", "fatOffset", "fatSize", "arm9OverlayOffset", "arm9OverlaySize", "arm7OverlayOffset", "arm7OverlaySize", "port40001A4hNormalCommand", "port40001A4hKey1Command", "iconOffset", "secureAreaChecksum", "secureAreaDelay", "arm9AutoLoad", "arm7AutoLoad", "secureAreaDisable", "usedRomSize", "headerSize", "reserved2", "reserved3", "logo", "logoChecksum", "headerChecksum", "debugRomOffset", "debugSize", "reserved4", "reserved5"]

@export var gameTitle: String
@export var gameCode: String
@export var makerCode: String
@export var unitCode: int
@export var encryptionSeedSelect: int 
@export var deviceCapacity: int
@export var reserved1: PackedByteArray
@export var dsiFlags: int
@export var ndsRegion: int
@export var romVersion: int
@export var autoStart: int

@export var arm9RomOffset: int
@export var arm9EntryAddress: int
@export var arm9RamAddress: int
@export var arm9Size: int

@export var arm7RomOffset: int
@export var arm7EntryAddress: int
@export var arm7RamAddress: int
@export var arm7Size: int

@export var fntOffset: int
@export var fntSize: int

@export var fatOffset: int
@export var fatSize: int

@export var arm9OverlayOffset: int
@export var arm9OverlaySize: int

@export var arm7OverlayOffset: int
@export var arm7OverlaySize: int

@export var port40001A4hNormalCommand: int
@export var port40001A4hKey1Command: int

@export var iconOffset: int

@export var secureAreaChecksum: int
@export var secureAreaDelay: int

@export var arm9AutoLoad: int
@export var arm7AutoLoad: int

@export var secureAreaDisable: int

@export var usedRomSize: int
@export var headerSize: int

@export var reserved2: PackedByteArray
@export var reserved3: PackedByteArray

@export var logo: PackedByteArray
@export var logoChecksum: int
@export var headerChecksum: int

@export var debugRomOffset: int
@export var debugSize: int
@export var debugRamAddress: int

@export var reserved4: int
@export var reserved5: PackedByteArray

func _init() -> void:
	
	pass

func readFile(romFile:FileAccess) -> void:
	gameTitle = romFile.get_buffer(12).get_string_from_ascii()
	gameCode = romFile.get_buffer(4).get_string_from_ascii()
	makerCode = romFile.get_buffer(2).get_string_from_ascii()
	unitCode = romFile.get_8()
	encryptionSeedSelect = romFile.get_8()
	deviceCapacity = romFile.get_8()
	reserved1 = romFile.get_buffer(7)
	dsiFlags = romFile.get_8()
	ndsRegion = romFile.get_8()
	romVersion = romFile.get_8()
	autoStart = romFile.get_8()
	
	arm9RomOffset = romFile.get_32()
	arm9EntryAddress = romFile.get_32()
	arm9RamAddress = romFile.get_32()
	arm9Size = romFile.get_32()

	arm7RomOffset = romFile.get_32()
	arm7EntryAddress = romFile.get_32()
	arm7RamAddress = romFile.get_32()
	arm7Size = romFile.get_32()
	
	fntOffset = romFile.get_32()
	fntSize = romFile.get_32()
	fatOffset = romFile.get_32()
	fatSize = romFile.get_32()

	arm9OverlayOffset = romFile.get_32()
	arm9OverlaySize = romFile.get_32()

	arm7OverlayOffset = romFile.get_32()
	arm7OverlaySize = romFile.get_32()

	port40001A4hNormalCommand = romFile.get_32()
	port40001A4hKey1Command = romFile.get_32()
	
	iconOffset = romFile.get_32()
	secureAreaChecksum = romFile.get_16()
	secureAreaDelay = romFile.get_16()
	arm9AutoLoad = romFile.get_32()
	arm7AutoLoad = romFile.get_32()
	secureAreaDisable = romFile.get_64()
	usedRomSize = romFile.get_32()
	headerSize = romFile.get_32()
	reserved2 = romFile.get_buffer(40)
	reserved3 = romFile.get_buffer(16)
	
	logo = romFile.get_buffer(156);
	logoChecksum = romFile.get_16();
	headerChecksum = romFile.get_16();
	debugRomOffset = romFile.get_32();
	debugSize = romFile.get_32();
	debugRamAddress = romFile.get_32();
	reserved4 = romFile.get_32();
	reserved5 = romFile.get_buffer(144);
	
func writeOut(romFile: FileAccess) -> void:
	var savedPos = romFile.get_position() + (12)
	romFile.store_buffer(gameTitle.to_ascii_buffer());
	romFile.seek(savedPos)
	romFile.store_buffer(gameCode.to_ascii_buffer());
	romFile.store_buffer(makerCode.to_ascii_buffer());
	romFile.store_8(unitCode);
	romFile.store_8(encryptionSeedSelect);
	romFile.store_8(deviceCapacity);
	romFile.store_buffer(reserved1);
	romFile.store_8(dsiFlags);
	romFile.store_8(ndsRegion);
	romFile.store_8(romVersion);
	romFile.store_8(autoStart);
	
	romFile.store_32(arm9RomOffset);
	romFile.store_32(arm9EntryAddress);
	romFile.store_32(arm9RamAddress);
	romFile.store_32(arm9Size);

	romFile.store_32(arm7RomOffset);
	romFile.store_32(arm7EntryAddress);
	romFile.store_32(arm7RamAddress);
	romFile.store_32(arm7Size);

	romFile.store_32(fntOffset);
	romFile.store_32(fntSize);
	romFile.store_32(fatOffset);
	romFile.store_32(fatSize);

	romFile.store_32(arm9OverlayOffset);
	romFile.store_32(arm9OverlaySize);

	romFile.store_32(arm7OverlayOffset);
	romFile.store_32(arm7OverlaySize);

	romFile.store_32(port40001A4hNormalCommand);
	romFile.store_32(port40001A4hKey1Command);

	romFile.store_32(iconOffset);
	romFile.store_16(secureAreaChecksum);
	romFile.store_16(secureAreaDelay);
	romFile.store_32(arm9AutoLoad);
	romFile.store_32(arm7AutoLoad);
	romFile.store_64(secureAreaDisable);
	romFile.store_32(usedRomSize);
	romFile.store_32(headerSize);
	romFile.store_buffer(reserved2);
	romFile.store_buffer(reserved3);
	
	savedPos = romFile.get_position() + 0x9C
	romFile.store_buffer(logo);
	romFile.seek(savedPos)
	romFile.store_16(logoChecksum);
	romFile.store_16(headerChecksum);
	romFile.store_32(debugRomOffset);
	romFile.store_32(debugSize);
	romFile.store_32(debugRamAddress);
	romFile.store_32(reserved4);
	romFile.store_buffer(reserved5);

func updateChecksum() -> void:
	var tmpHeader: PackedByteArray
	tmpHeader.resize(0x8000)
	var byteOffset: int = 0
	var b = 0
	var toPut = gameCode.to_ascii_buffer()
	while (b < toPut.size()):
		tmpHeader.encode_u8(byteOffset, toPut[b])
		b += 1
		byteOffset += 1
	b = 0
	toPut = gameTitle.to_ascii_buffer()
	while (b < toPut.size()):
		tmpHeader.encode_u8(byteOffset, toPut[b])
		b += 1
		byteOffset += 1
	b = 0	
	toPut = makerCode.to_ascii_buffer()
	while (b < toPut.size()):
		tmpHeader.encode_u8(byteOffset, toPut[b])
		b += 1
		byteOffset += 1
	tmpHeader.encode_u32(byteOffset,arm9RomOffset)
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm9EntryAddress);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm9RamAddress);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm9Size);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm7RomOffset);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm7EntryAddress);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm7RamAddress);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm7Size);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,fntOffset);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,fntSize);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,fatOffset);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,fatSize);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm9OverlayOffset);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm9OverlaySize);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm7OverlayOffset);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm7OverlaySize);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,port40001A4hNormalCommand);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,port40001A4hKey1Command);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,iconOffset);
	byteOffset += 4
	tmpHeader.encode_u16(byteOffset,secureAreaChecksum);
	byteOffset += 2
	tmpHeader.encode_u16(byteOffset,secureAreaDelay);
	byteOffset += 2
	tmpHeader.encode_u32(byteOffset,arm9AutoLoad);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,arm7AutoLoad);
	byteOffset += 4
	tmpHeader.encode_u64(byteOffset,secureAreaDisable);
	byteOffset += 8
	tmpHeader.encode_u32(byteOffset,usedRomSize);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,headerSize);
	byteOffset += 4
	b = 0
	toPut = reserved2
	while (b < toPut.size()):
		tmpHeader.encode_u8(byteOffset, toPut[b])
		b += 1
		byteOffset += 1
	b = 0
	toPut = reserved3
	while (b < toPut.size()):
		tmpHeader.encode_u8(byteOffset, toPut[b])
		b += 1
		byteOffset += 1
	b = 0
	toPut = logo
	while (b < toPut.size()):
		tmpHeader.encode_u8(byteOffset, toPut[b])
		b += 1
		byteOffset += 1
	tmpHeader.encode_u16(byteOffset,logoChecksum);
	byteOffset += 2
	tmpHeader.encode_u16(byteOffset,headerChecksum);
	byteOffset += 2
	tmpHeader.encode_u32(byteOffset,debugRomOffset);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,debugSize);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,debugRamAddress);
	byteOffset += 4
	tmpHeader.encode_u32(byteOffset,reserved4)
	byteOffset += 4
	b = 0
	toPut =reserved5
	while (b < toPut.size()):
		tmpHeader.encode_u8(byteOffset, toPut[b])
		b += 1
		byteOffset += 1
	tmpHeader = tmpHeader.slice(0, byteOffset)
	
	headerChecksum = CRC.calculateCRC16(tmpHeader.slice(0, 0x15e))
	logoChecksum = CRC.calculateCRC16(tmpHeader.slice(0xc0, 0x15c))
	secureAreaChecksum = CRC.calculateCRC16(tmpHeader.slice(arm9RomOffset, 0x8000 -arm9RomOffset))
	tmpHeader.clear()

func compare(other: NitroHeader):
	var i = 0
	while (i < headerValues.size()):
		var property = headerValues[i]
		var aValue = self.get(property)
		var bValue = other.get(property)
		if (aValue != bValue):
			print(property + " value differs!")
			print("A: " + str(aValue))
			print("B: " + str(bValue))
		i += 1
