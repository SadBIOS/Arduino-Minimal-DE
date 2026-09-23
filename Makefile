ifeq ($(OS),Windows_NT)
code     = Arduino-Minimal-DE.ino
brd      = esp32:esp32:esp32#s3$(options)	# FQBN (fully qualified board name), example: arduino:avr:nano or esp32:esp32:esp32s3
port     = COM7							# check connected boards via device manager or "make avail" !CANNOT BE BLANK!
cuf  	 = kbin								# cleanup function (refer to the readme file) !CANNOT BE BLANK!
firmware = $(code).bin						# firmware filename (without extension)
options  = :CDCOnBoot=default,USBMode=hwcdc,UploadMode=default,CPUFreq=240

# AVR only (get fuse values from boards.txt), change the hex value *:w:0x*:m (the fuse selection in avrdude is very non-intuitive)
mcu   	= m328p							# only applicable for the Arduino AVR platform
lfuse   = lfuse:w:0xFF:m
hfuse   = hfuse:w:0xDE:m
efuse   = efuse:w:0xFD:m
lckbyt  = lock:w:0x0F:m 					
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

burn:	# follow the instructions from README.md for this target
	arduino-cli upload -p $(port) --verbose --fqbn $(dev) --input-file .\firmware\$(code).with_bootloader.hex

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
