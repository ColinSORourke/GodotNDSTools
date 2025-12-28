####################
# Checksum Calculation
# https://github.com/snksoft/java-crc/blob/master/src/main/java/com/github/snksoft/crc/CRC.java
####################
class_name CRC

class param16:
	const width: int = 16
	const polynomial: int = 0x8005
	const reflectIn: bool = true
	const reflectOut: bool = true
	const init: int = 0x0000
	const finalXor: int = 0x0
	
class param32:
	const width: int = 32
	const polynomial: int = 0x04C11DB7
	const reflectIn: bool = true
	const reflectOut: bool = true
	const init: int = 0xFFFFFFFF
	const finalXor: int = 0xFFFFFFFF
	
static func calculateCRC16(data: PackedByteArray) -> int:
	var curValue: int = param16.init
	var topBit: int = 1 << (param16.width - 1)
	var mask: int = (topBit << 1) - 1
	var end: int = data.size()
	var i = 0
	while (i < end):
		var curByte = data[i] & 0x00FF
		if (param16.reflectIn):
			curByte = reflect(curByte, 8)
		i += 1
		
		var j: int = 0x80
		while (j != 0):
			var bit: int = curValue & topBit
			curValue <<= 1
			
			if ((curByte & j) != 0):
				bit ^= topBit
				
			if (bit != 0):
				curValue ^= param16.polynomial
			j >>= 1
	
	if (param16.reflectOut):
		curValue = reflect(curValue, param16.width)
		
	curValue = curValue ^ param16.finalXor
	
	return curValue & mask
		
static func calculateCRC32(data: PackedByteArray) -> int:
	var curValue: int = param32.init
	var topBit: int = 1 << (param32.width - 1)
	var mask: int = (topBit << 1) - 1
	var end: int = data.size()
	var i = 0
	while (i < end):
		var curByte = data[i] & 0x00FF
		if (param32.reflectIn):
			curByte = reflect(curByte, 8)
		i += 1
		
		var j: int = 0x80
		while (j != 0):
			var bit: int = curValue & topBit
			curValue <<= 1
			
			if ((curByte & j) != 0):
				bit ^= topBit
				
			if (bit != 0):
				curValue ^= param32.polynomial
			j >>= 1
	
	if (param32.reflectOut):
		curValue = reflect(curValue, param32.width)
		
	curValue = curValue ^ param32.finalXor
	
	return curValue & mask
		
static func reflect(orig: int, count: int) -> int:
	var ret: int = orig
	var i = 0;
	while (i < count):
		var srcbit: int = 1 << i
		var dstbit = 1 << (count - i - 1)
		if ((orig & srcbit) != 0):
			ret |= dstbit
		else:
			ret = ret & (~dstbit)
		i += 1
	return ret
