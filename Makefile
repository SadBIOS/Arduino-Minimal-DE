ifeq ($(OS),Windows_NT)
code     = Arduino-Minimal-DE.ino
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
