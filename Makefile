code     = Arduino.ino
brd      = esp32:esp32:esp32#s3$(options)	# FQBN (fully qualified board name), example: arduino:avr:nano or esp32:esp32:esp32s3
port     = COM7							# check connected boards via device manager or "make avail" !CANNOT BE BLANK!
cuf  	 = kbin								# cleanup function (refer to the readme file) !CANNOT BE BLANK!
firmware = $(code).bin						# firmware filename (without extension)
options  = :CDCOnBoot=default,USBMode=hwcdc,UploadMode=default,CPUFreq=240



# AVR only (get fuse values from boards.txt), change the hex value *:w:0x*:m (the fuse selection in avrdude is very non-intuitive)
mcu   	= m328pb						# only applicable for the Arduino AVR platform
lfuse 	= lfuse:w:0xFF:m
hfuse 	= hfuse:w:0xDA:m
efuse 	= efuse:w:0xFD:m
lckbyt 	= lock:w:0xCF:m 					
pgmr 	= usbasp
btclk 	= 93.75							# bit clock (8kHz = 93.75)
brt 	= 115200						# baud rate

default:
	powershell -command ".\runtime\cleanup.ps1 nuke"
	arduino-cli compile --verbose --fqbn $(brd) $(code) --output-dir .
	powershell -command ".\runtime\cleanup.ps1 $(cuf)"
	powershell -command "Remove-Item -Path \"$$env:LOCALAPPDATA\\arduino\\\" -Recurse -Force -Verbose"
	arduino-cli board list

clean:
	powershell -command ".\runtime\cleanup.ps1 nuke"

resolve:
	powershell -command ".\runtime\resolver.ps1"

flash:
	arduino-cli upload -p $(port) --verbose --fqbn $(brd) --input-file .\firmware\$(firmware)

burn:	# only one can be uncommented at a time
# add .with_bootloader if bootloader is not required (the following command is for advanced users recommended for bootloader-less systems and the stupid 328pb)
#	avrdude -c $(pgmr) -p $(mcu) -P usb -U flash:w:./firmware/$(code).with_bootloader.hex:i -vvv -B $(btclk) -b $(brt)
# keep the previous line commented and is for normal use (given bootloader exists)
#	arduino-cli upload -p $(port) --verbose --fqbn $(dev) --input-file .\firmware\$(code).with_bootloader.hex
# the next command is the the most stupid line in existance (native upload for m328pb)
	arduino-cli upload -p $(port) --verbose --fqbn $(brd) --input-file .\firmware\$(code).eep

boot:	# usbasp required (must compile a blank sketch for that board first)
	avrdude -c $(pgmr) -P usb -p $(mcu) -e -vvv -B $(btclk) -b $(brt)
	avrdude -c $(pgmr) -p $(mcu) -P usb -U $(lfuse) -U $(hfuse) $(efuse) -B $(btclk) -b $(brt) -vvv
	avrdude -c $(pgmr) -p $(mcu) -P usb -U flash:w:./firmware/$(code).with_bootloader.hex:i -vvv -B $(btclk) -b $(brt)
	avrdude -c $(pgmr) -p $(mcu) -P usb -U $(lckbyt) -B $(btclk) -b $(brt) -vvv


check:	# usbasp required
	avrdude -c $(pgmr) -p $(mcu) -P usb -B $(btclk) -b $(brt) -U hfuse:r:-:h -U lfuse:r:-:h -U efuse:r:-:h -U lock:r:-:h

erase:	# usbasp required
	avrdude -c $(pgmr) -P usb -p $(mcu) -e -vvv -B $(btclk) -b $(brt)

env:
	powershell -command ".\runtime\init.ps1 setup"
	powershell -command ".\runtime\init.ps1 lib_build"

core:
	powershell -command ".\runtime\init.ps1 corestat"

lib:
	powershell -command ".\runtime\init.ps1 libstat"

avail:
	arduino-cli board list

eval:
	avrdude -c $(pgmr) -p $(mcu) -vvv

details:
	arduino-cli board details --fqbn $(brd)


# M328PB (Standard)
# lfuse   = lfuse:w:0xFF:m
# hfuse   = hfuse:w:0xDA:m
# efuse   = efuse:w:0xFD:m
# unlock  = unlock:w:0x3F:m
# lock    = lock:w:0xCF:m

# M328P (Optiboot)
# lfuse   = lfuse:w:0xFF:m
# hfuse   = hfuse:w:0xDE:m
# efuse   = efuse:w:0xFD:m
# unlock  = unlock:w:0x3F:m
# lock    = lock:w:0x0F:m

# M328P (Old Bootloader)
# lfuse   = lfuse:w:0xFF:m
# hfuse   = hfuse:w:0xDA:m
# efuse   = efuse:w:0xFD:m
# unlock  = unlock:w:0x3F:m
# lock    = lock:w:0x0F:m

# M32U (Pro Micro)
# lfuse   = lfuse:w:0xFF:m
# hfuse   = hfuse:w:0xD8:m
# efuse   = efuse:w:0xCB:m
# unlock  = unlock:w:0x3F:m
# lock    = lock:w:0x2F:m


# ESP32 Variants
# options for C3 SuperMini CDCOnBoot=cdc,USBMode=hwcdc fqbn esp32:esp32:nologo_esp32c3_super_mini
# options for S3 N16R8 and WaveShare Matrix CDCOnBoot=cdc,USBMode=hwcdc,UploadMode=cdc fqbn esp32:esp32:esp32s3
# options for NodeMCU V3 baud=3000000 fqbn esp8266:esp8266:nodemcuv2
# ESP32S3 BLE CDCOnBoot=default,USBMode=hwcdc,UploadMode=default,CPUFreq=240
# ESP32P4 espressif:esp32:esp32p4 (options will be added later)
