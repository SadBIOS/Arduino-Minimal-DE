ifeq ($(OS),Windows_NT)
code     = Arduino-Minimal-DE.ino
brd      = esp32:esp32:esp32#s3$(options)	# FQBN (fully qualified board name), example: arduino:avr:nano or esp32:esp32:esp32s3
port     = COM7							# check connected boards via device manager or "make avail" !CANNOT BE BLANK!
cuf  	 = kbin								# cleanup function (refer to the readme file) !CANNOT BE BLANK!
firmware = $(code).bin						# firmware filename (without extension)
options  = :CDCOnBoot=default,USBMode=hwcdc,UploadMode=default,CPUFreq=240
