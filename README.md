# Minimal Arduino<sup>®</sup> Cross Platform Dev Env for Air-Gapped Systems

This tool is designed to deploy a [arduino-cli](https://docs.arduino.cc/arduino-cli/) based development environment into air-gapped machines (Please refer to the **Warning** in this section regarding information about Microsoft Windows<sup>®</sup> and GNU/Linux<sup>®</sup>). Optimized for development of sensitive applications in controlled environments.

<div align="center">

***Get a partner who looks at you the way Windows<sup>®</sup> looks at your RAM***

</div>

> [!WARNING]  
> * The Build-Toolkit transfer method is still bound to the ```%USERNAME%``` Environment Variable for Microsoft Windows<sup>®</sup> (Patch Coming **Soon™**)
> * Developed for native support Debian<sup>®</sup>

## Dependencies

<details>
<summary><b>Winows</b><sup>®</sup></summary>

> **NOTE**
> This section is subject to change as I add more boards to this project.


* [Arduino<sup>®</sup> CLI](https://github.com/arduino/arduino-cli/releases) (Select the latest ```arduino-cli_X.Y.Z_Windows_64bit.zip``` archive from the releases page)
* [CH340 Driver](https://www.wch-ic.com/download/CH341SER_EXE.html)
* [CP210X Driver](https://www.silabs.com/developer-tools/usb-to-uart-bridge-vcp-drivers)
* [FTDI VCP Driver](https://ftdichip.com/drivers/vcp-drivers/) ```CDM213464-FT232RL```
* [AVRDUDE](https://github.com/avrdudes/avrdude) (Download the latest ```avrdude-vX.Y-windows-x64.zip```)
* [VSCodium](https://github.com/VSCodium/vscodium)
* [Arduino<sup>®</sup> Community Extension](https://marketplace.visualstudio.com/items?itemName=vscode-arduino.vscode-arduino-community)
* [Serial Monitor Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-serial-monitor)
* [MinGW-w64](https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/8.1.0/threads-posix/seh/) (Download the ```x86_64-posix-seh``` **7z** archive)

</details>

<details>
<summary><b>GNU/Linux<sup>®</sup></b></summary>

> **NOTE**
> AVRDUDE flashing has still not been implemented but it along with and GCC Compilers for AVR<sup>®</sup> from Microchip is still listed. However this is not a requirement
> > * [AVRDUDE](https://github.com/avrdudes/avrdude/releases/) (Download the latest ***avrdude_vX.Y_Linux_64bit.tar.gz***)
> > * [Microchip AVR-GCC](https://www.microchip.com/en-us/tools-resources/develop/microchip-studio/gcc-compilers) (Select the ***AVR 8-Bit Toolchain (Linux)*** from this page)

The following is the core dependency for this project require to operate in GNU/Linux<sup>®</sup> environments. 

***GNU/Linux<sup>®</sup> refers to Debian<sup>®</sup> in this case***

* [Arduino<sup>®</sup> CLI](https://github.com/arduino/arduino-cli/releases) (Select the latest ```arduino-cli_X.Y.Z_Linux_64bit.tar.gz``` archive from the releases page)

</details>


## Special Instructions

<details>
<summary><i><b>burn:</b></i> Target options in Microsoft Windows<sup>®</sup> <i><b>Makefile</b></i></summary>

Replace the line after the ```burn:``` target with the following (choose the appropriate version from <i><b>AVR<sup>®</sup> Programming Variable</i></b> section below)

* Standard Flashing procecdure for <i><b>Microchip picoPower<sup>®</sup> ATmega328PB</b></i>
    * Since this uses <b>arduino-cli</b> it is assumed that a functioning bootloader already exists or else it will fail.
      ```makefile
      arduino-cli upload -p $(port) --verbose --fqbn $(brd) --input-file .\firmware\$(code).eep
      ```

* Bootloader Re-Flash (the default option assumes the bootloader already exists)
    * Adding ```.with_bootloader``` replaces the existing bootloader. This assumes the bootloader on the chip might be corrupted/non-existent or the user wishes to replace it by force.
      ```makefile
      avrdude -c $(pgmr) -p$(mcu) -P usb -U flash:w:./firmware/$(code).with_bootloader.hex:i -vvv -B $(btclk) -b$(brt)
      ```

<br>    

<details>
<summary><i><b>AVR<sup>®</sup> Programming Variables</i></b></summary>

><details>
><summary>Atmel<sup>®</sup> ATmega328P enhanced <i><b>AVR<sup>®</sup> RISC</b></i> (<i><b><a href="https://github.com/Optiboot">Optiboot</a></b></i> Currently maintained by <i><b><a href="https://github.com/westfw">Bill Westfield</a></b></i>)</summary>
>
> * MCU/Part Name ```m328p```
>```makefile
> lfuse   = lfuse:w:0xFF:m
> hfuse   = hfuse:w:0xDE:m
> efuse   = efuse:w:0xFD:m
> unlock  = unlock:w:0x3F:m
> lock    = lock:w:0x0F:m
>```
></details>

><details>
><summary>Atmel<sup>®</sup> ATmega328P enhanced <i><b>AVR<sup>®</sup> RISC</b></i> (Old <i><b>Arduino<sup>®</sup></b></i> Bootloader)</summary>
>
> * MCU/Part Name ```m328p```
>```makefile
> lfuse   = lfuse:w:0xFF:m
> hfuse   = hfuse:w:0xDA:m
> efuse   = efuse:w:0xFD:m
> unlock  = unlock:w:0x3F:m
> lock    = lock:w:0x0F:m
>```
></details>

><details>
><summary><i><b>Microchip </b></i>ATmega32U4 enhanced <i><b>AVR<sup>®</sup> RISC</b></i> (<i><b>Arduino<sup>®</sup> MICRO</i></b> with it's Standard Bootloader)</summary>
>
> * MCU/Part Name ```m32u4```
>```makefile
> lfuse   = lfuse:w:0xFF:m
> hfuse   = hfuse:w:0xD8:m
> efuse   = efuse:w:0xCB:m
> unlock  = unlock:w:0x3F:m
> lock    = lock:w:0x2F:m
>```
></details>

><details>
><summary><i><b>Microchip picoPower<sup>®</sup> ATmega328PB</b></i> enhanced <i><b>AVR<sup>®</sup> RISC</b></i> (Standard  Bootloader)</summary>
>
> * MCU/Part Name ```m328pb```
>```makefile
> lfuse   = lfuse:w:0xFF:m
> hfuse   = hfuse:w:0xDA:m
> efuse   = efuse:w:0xFD:m
> unlock  = unlock:w:0x3F:m
> lock    = lock:w:0xCF:m
>```
></details>
</details>
</details>

<details>
<summary><b>Deployment/Migration</b> in or between Air-Gapped <b>Debian<sup>®</sup></b> Environments</summary>

Hidden content goes here.

You can use **Markdown** inside the section too.

- Item 1
- Item 2

</details>

<details>
<summary><code>~/runtime/config.txt</code> Options for different MCUs</summary>

> [!NOTE]
> This section is subject to change as I add more boards to this project.

- Item 1
- Item 2

</details>


> [!IMPORTANT]  
> Tested and built on the following OS builds
> * Debian<sup>®</sup> 13.5 *"Trixie"*, Kernel **6.12.94+deb13-amd64**
> * Debian<sup>®</sup> 13.5 *"Trixie"*, Kernel **6.12.95+deb13-amd64**
> * Debian<sup>®</sup> 13.6 *"Trixie"*, Kernel **6.12.96+deb13-amd64**
> * LMDE 7 *"Gigi"*, Kernel **6.12.100+deb13-amd64** (based on Debian 13.0)
> * Windows<sup>®</sup> 10, version ***21H2, KB5025221*** (OS Build ***19044.2846***)
> * Windows<sup>®</sup> 11, version ***24H2, KB5079473*** (OS Build ***26100.8037***)
> * Windows<sup>®</sup> 11, version ***25H2, KB5068861*** (OS Build ***26100.7171***)
> * Windows<sup>®</sup> 11, version ***26H1, KB5124012*** (OS Build ***28000.2954***)
>
> ---
> I plan to upgrade the Microsoft Windows<sup>®</sup> scripts to match the capabilities of the GNU/Linux build along side AVRDUDE capabilities to flash Microchip Atmel<sup>®</sup> AVR<sup>®</sup> chips **Soon™**
