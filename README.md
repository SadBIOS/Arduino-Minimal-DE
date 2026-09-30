# Minimal Arduino<sup>®</sup> Cross Platform Dev Env

This tool is designed to deploy a [arduino-cli](https://docs.arduino.cc/arduino-cli/) based development environment into air-gapped machines/systems (Please refer to the **Warning** in this section regarding information about Microsoft Windows<sup>®</sup> and GNU/Linux<sup>®</sup>). Optimized for development of sensitive applications in controlled environments.

<div align="center">

***Get a partner who looks at you the way Windows<sup>®</sup> looks at your RAM***

</div>

> [!WARNING]  
> * The Build-Toolkit transfer method is still bound to the ```%USERNAME%``` Environment Variable for Microsoft Windows<sup>®</sup> (Patch Coming **Soon™**)
> * Developed for native support Debian<sup>®</sup>

## Dependencies

<details>
<summary><b>Microsoft Winows</b><sup>®</sup></summary>

> **NOTE**<br>
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

> **NOTE**<br>
> AVRDUDE flashing has still not been implemented but it along with and GCC Compilers for AVR<sup>®</sup> from Microchip is still listed. However this is not a requirement
> > * [AVRDUDE](https://github.com/avrdudes/avrdude/releases/) (Download the latest ***avrdude_vX.Y_Linux_64bit.tar.gz***)
> > * [Microchip AVR-GCC](https://www.microchip.com/en-us/tools-resources/develop/microchip-studio/gcc-compilers) (Select the ***AVR 8-Bit Toolchain (Linux)*** from this page)

The following is the core dependency for this project require to operate in GNU/Linux<sup>®</sup> environments. 

***GNU/Linux<sup>®</sup> refers to Debian<sup>®</sup> in this case***

* [Arduino<sup>®</sup> CLI](https://github.com/arduino/arduino-cli/releases) (Select the latest ```arduino-cli_X.Y.Z_Linux_64bit.tar.gz``` archive from the releases page)

</details>


## Setup and Operation

> [!WARNING]
> * Write code in the Arduino-Minimal-DE.ino (file location **!!CANNOT!!** be changed)
> * For Microsoft Winows<sup>®</sup> put libraries in a separate folder (same directory as the .ino file)

> [!NOTE]
> As I mostly work on MCUs from the **[Espressif ESP32](https://www.espressif.com/ja-jp/home)** platform. Thus most of the instructions are written with that fact in mind.
<details>
<summary><b>Microsoft Winows</b><sup>®</sup></summary>

> <details>
> <summary><b>Environment Setup</b></summary>
>
> * Setup (after changing the `ExecutionPolicy` to allow external scripts). **PLEASE READ SCRIPT BEFORE ALLOWING ANYTHING FROM THE INTERNET.**
> > ```bash
> > make env
> > ```
> **Once everything done please run <code>make core</code> to confirm.**
> </details>

> <details>
> <summary><b>Compilation</b></summary>
>
> * Modify `brd`, `cuf` and `firmware` variables based on the instructions in the **Windows_NT** section. Then just run;
>
> > ```bash
> > make 
> > ```
> </details>

> <details>
> <summary><b>Flashing</b></summary>
>
> * Based on the values set in the previous section just run the following;
>
> > ```bash
> > make flash
> > ```
> </details>
</details>
</details>


<details>
<summary><b>GNU/Linux<sup>®</sup></b></summary>

> **NOTE**<br>
> The default script path is assumed to be in `$HOME`

> <details>
> <summary><b>Environment Setup</b></summary>
>
> * First navigate to `~/Arduino-Minimal-DE/runtime` and run;
>
> > ```bash
> > chmod +x *.sh
> > ```
>
>  * **This command is for online machines only**
>
> > ```bash
> > ./dep.sh --resolve-online
> > ```
>
> > ```bash
> > make sys_init
> > ```
> * Once `sys_init` target has been completed successfully run the following to confirm whether the system has been properly set up;
>
> > ```bash
> > make sys_stat
> > ```
> </details>

> <details>
> <summary><b>Compilation</b></summary>
>
> * While inside `~/Arduino-Minimal-DE/runtime` edit `config.txt`. Set the appropriate board name in `FQBN == ` and any other `arduino-cli` compatible compilation flags in `ADDITIONAL_OPTIONS ==`
> * Kindly Refer to the **Configuration Option** subsection in **Special Instructions**
>
> > ```bash
> > make 
> > ```
> </details>

> <details>
> <summary><b>Flashing</b></summary>
>
> * Based on the values set in the previous section just run the following;
>
> > ```bash
> > make flash
> > ```
> </details>
</details>


## Special Instructions

<details>
<summary><i><b>burn:</b></i> Target options in Microsoft Windows<sup>®</sup> <i><b>Makefile</b></i></summary>

Replace the line after the ```burn:``` target with the following (choose the appropriate version from <i><b>AVR<sup>®</sup> Programming Variable</i></b> section below)

* Standard Flashing procecdure for <i><b>Microchip picoPower<sup>®</sup> ATmega328PB</b></i>
    * Since this uses <b>arduino-cli</b> it is assumed that a functioning bootloader already exists or else it will fail.
      ```bash
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
>```cpp
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
>```cpp
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
>```cpp
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
>```cpp
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

><details>
><summary>Core/Full System Transfer</summary>
>
> * Run the following commands on the internet connected machine (assuming the shell is already inside the `runtime` directory of the toolchain root);
> > ```bash
> > ./dep.sh --build-offline
> > ```
> > > This part is for resolving dependencies onn the local machine to as **GNU make** is required for exporting full toolchain;
> > > ```bash
> > > ./dep.sh --resolve-online
> > > ```
> > > Navigate to the toolchain root and run;
> > > ```bash
> > > make sys_init
> > > ```
> > 
> > Export full toolchain (compilers and all);
> > ```bash
> > make export_datstore
> > ```
> 
> ---
> Copy the entire script root to the offline machine, this will be a file around **`10GB`**
> 
> ---
> * Run the following commands on the offline machine (assuming the shell is already inside the `runtime` directory of the toolchain root)
> > ```bash
> > ./dep.sh --resolve-online
> > ```
> > 
> > Import full toolchain (compilers and all);
> > ```bash
> > make import_datstore
> > ```
></details>

><details>
><summary>Library Transfer</summary>
>
> > **STEP 1 - Generate Missing Libraries:** `make gen_missing_libs`, **Execution Environment:** Online or Offline Machine<br>
> >  1. **Header Extraction:** Scans the target source file (`.ino`) for `#include <...>` directives.<br>
> >  2. **Local Check:** Querying `arduino-cli lib list` to determine which included libraries are already installed locally.<br>
> >  3. **Catalog Matching:** Cross-references uninstalled libraries with `master_library_catalog.txt`. If an exact match is missing, it runs a Levenshtein distance calculation to offer the top 5 closest candidates for interactive user selection.<br>
> >  4. **Manifest Creation:** Generates or updates `lib_preload_list_linux.txt` at the root directory. This file contains a unique session key (`>!< PRE-LOAD-CODE == <number>`) and the list of required library names.<br>
> > > ```bash
> > > make gen_missing_libs
> > > ```
> > <br>
> >
> > **STEP 2 - Preload Libraries:** `make preload_libs`, **Execution Environment:** Internet-Connected Machine (applicable for custom [request file](https://github.com/SadBIOS/Arduino-Minimal-DE/blob/main/lib_preload_list_linux.txt))<br>
> > 1. **Connectivity Check:** Verifies active internet connectivity via ICMP ping tests to public DNS resolvers (`1.1.1.1` / `8.8.8.8`).<br>
> > 2. **Package Download:** Parses `lib_preload_list_linux.txt` to extract the `PRE-LOAD-CODE` and the library list. Missing libraries are downloaded via `arduino-cli lib install`.<br>
> > 3. **Archive Packaging:** Copies the retrieved library directories into a temporary staging folder (`runtime/lib_store/tmp`) along with the manifest. It compresses these contents into a tarball named `<PRELOAD_CODE>.tar.gz` located inside `runtime/lib_store/`.<br>
> > ```bash
> > make preload_libs
> > ```
> > <br>
> >
> > **STEP 3 - Deploy Library Package** (`make load_offl_libs`), **Execution Environment:** Airgapped / Offline Machine
> > 1. **Prerequisite Transfer:** Transfer the generated `<PRELOAD_CODE>.tar.gz` archive to the target machine and place it inside `runtime/lib_store/`. Ensure the Makefile variable `lib_preload_archive_linux` points to this archive path
> > 1. **Archive Validation:** Unpacks the archive to a temporary directory and checks that the numeric archive filename matches the `PRE-LOAD-CODE` declared inside `lib_preload_list_linux.txt`.
> > 1. **Library Verification:** Confirms that each unpacked library directory contains a valid `library.properties` file.
> > 1. **User Directory Resolution:** Reads `arduino-cli.yaml` to identify the user's `libraries` directory (e.g., `~/Arduino/libraries`).
> > 1. **Installation:** Prompts the user for confirmation, replaces any pre-existing older versions of the libraries, and cleans up temporary working directories upon completion.
> > ```bash
> > make load_offl_libs
> > ```
></details>

</details>

<details>
<summary><b>Configuration Options</b> for different MCUs</summary>

> **NOTE**<br>
> This section is subject to change as I add more boards to this project.
> The config file lives in `~/Arduino-Minimal-DE/runtime/config.txt` (assuming the toolkit is placed in `$HOME`)
> The upload speeds are low because I am unfortunately working with a poor quality USB cable.
> > 
> > ```rust
> > FQBN == arduino:avr:nano
> > ADDITIONAL_OPTIONS == 
> > ```
> > ```rust
> > FQBN == MiniCore:avr:328
> > ADDITIONAL_OPTIONS == 
> > ```
> > ```rust
> > FQBN == esp8266:esp8266:nodemcuv2
> > ADDITIONAL_OPTIONS == 
> > ```
> > ```rust
> > FQBN == esp32:esp32:esp32
> > ADDITIONAL_OPTIONS == UploadSpeed=115200,EraseFlash=all
> > ```
> > ```rust
> > FQBN == esp32:esp32:esp32s3
> > ADDITIONAL_OPTIONS == USBMode=hwcdc,CDCOnBoot=cdc,UploadMode=cdc,UploadSpeed=115200,EraseFlash=all,FlashSize=16M,PSRAM=opi
> > ```
> > ```rust
> > FQBN == esp32:esp32:esp32p4
> > ADDITIONAL_OPTIONS == USBMode=hwcdc,CDCOnBoot=cdc,UploadMode=cdc,FlashSize=16M,PartitionScheme=app3M_fat9M_16MB,PSRAM=enabled,UploadSpeed=115200,EraseFlash=all
> > ```
> > ---
> > The ESP32C5 board works with this config but for some reason it does not auto start after a soft reset. A full power cycle is required.
> > ```rust
> > FQBN == esp32:esp32:esp32c5
> > ADDITIONAL_OPTIONS == UploadSpeed=115200,CDCOnBoot=cdc,EraseFlash=all
> > ```
> > ---
> > This board is broken at the moment. I will attempt a fix with a [ST-Link V2](https://www.st.com/en/development-tools/st-link-v2.html) via [OpenOCD](https://openocd.org/)
> > 
> > ```rust
> > FQBN == Seeeduino:samd:seeed_XIAO_m0
> > ADDITIONAL_OPTIONS == 
> > ```
</details>

---

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
> I plan to upgrade the Microsoft Windows<sup>®</sup> scripts to match the capabilities of the GNU/Linux<sup>®</sup> build along side AVRDUDE capabilities to flash Microchip Atmel<sup>®</sup> AVR<sup>®</sup> chips **Soon™**
