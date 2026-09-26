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

burn:	# follow the Special Instructions from README.md for this target
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

else
SHELL := /bin/bash
root := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ard_cli_binpath := /home/uwu/Arduino-Minimal-DE/arduino-cli/arduino-cli
toolchain_root := /opt/Arduino15
udev_source := $(root)runtime/rules.txt
udev_target := /etc/udev/rules.d/99-arduino-portable.rules
config_file := $(toolchain_root)/arduino-cli.yaml
lib_master_catalog_all := $(root)master_library_catalog.txt
lib_preload_list_linux := $(root)lib_preload_list_linux.txt
lib_preload_archive_linux := $(root)runtime/lib_store/3975936.tar.gz
source_code := $(root)Arduino-Minimal-DE.ino
linux_build_conf := $(root)runtime/config.txt
vid_pid_list := $(root)runtime/vid_pid_master.txt
port := /dev/ttyACM0

default:
	@$(root)runtime/firmware_builder.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --src-code "$(source_code)" --linux-build-conf "$(linux_build_conf)" --root-path "$(root)"

flash:
	@$(root)runtime/flash_util.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --linux-build-conf "$(linux_build_conf)" --root-path "$(root)" --linux-build-conf "$(linux_build_conf)" --src-code "$(source_code)" --approved-hwid-list "$(vid_pid_list)" --port "$(port)" --auto-discovery on --verify-devices on

create_hwdb:
	@$(root)runtime/db_create.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --approved-hwid-list "$(vid_pid_list)"

sys_init:
	@$(root)runtime/init.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --udev-src "$(udev_source)" --udev-tgt "$(udev_target)" --lib-catalog $(lib_master_catalog_all)

sys_stat:
	@$(root)runtime/sys_stat.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --udev-tgt "$(udev_target)" --lib-catalog $(lib_master_catalog_all)

board_list:
	@$(root)runtime/boards.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)"

preload_libs:
	@$(root)runtime/preload.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --pre-load-list "$(lib_preload_list_linux)"

gen_missing_libs:
	@$(root)runtime/gen_missing.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --root-path "$(root)" --src-code "$(source_code)" --lib-catalog $(lib_master_catalog_all)

load_offl_libs:
	@$(root)runtime/postload.sh --binpath "$(ard_cli_binpath)" --toolchain-root "$(toolchain_root)" --config-file "$(config_file)" --offl-lib-arch "$(lib_preload_archive_linux)"

export_datstore:
	@$(root)runtime/exporduino.sh --root-path "$(root)" --source-path "$(toolchain_root)" --udev-src "$(udev_source)"

import_datstore:
	@$(root)runtime/imporduino.sh --root-path "$(root)" --toolchain-root "$(toolchain_root)" --udev-tgt "$(udev_target)"

lib_list:
	@$(ard_cli_binpath) --config-file $(config_file) lib list

board_details: # Uncomment to desired
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b arduino:avr:uno
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b arduino:avr:nano
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b arduino:avr:mega
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b arduino:avr:mega:cpu=atmega2560
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b arduino:avr:mega:cpu=atmega1280
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b MiniCore:avr:328
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b esp8266:esp8266:nodemcuv2
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b esp32:esp32:esp32
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b esp32:esp32:esp32s3
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b esp32:esp32:esp32p4
# 	@$(ard_cli_binpath) --config-file $(config_file) board details -b esp32:esp32:esp32c5
	@$(ard_cli_binpath) --config-file $(config_file) board details -b Seeeduino:samd:seeed_XIAO_m0
endif
