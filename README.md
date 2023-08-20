# jjr

Bash script to automate operations with Joey Jr. by BennVenn on Linux machines.

## Features
- detecting Joey Jr. device
- printing information from `DEBUG.TXT` and `MODE.TXT` files
- writing to cartridge
    - rom
    - save (sram, flash, eeprom)
- copying from cartridge
  - rom
  - save
  - photos from GameBoy camera
    - blank photos are being ignored (md5sum)
    - duplicates in destination are being skipped (md5sum)
    - timestamp is added to filenames
- firmware updating
- romlist updating
- reconnecting Joey Jr.
- mode setting

# Examples
```
$ ./jjr.sh help
[ INFO ] Following options and parameters are supported:

           write  rom      <ROM_FILE>
           write  sram     <SRAM_FILE>
           write  flash    <FLASH_FILE>
           write  eeprom   <EEPROM_FILE>

           copy   rom      <DESTINATION> (optional*)
           copy   save     <DESTINATION> (optional*)
           copy   photos   <DESTINATION> (optional*)

           debug
           refresh
           set-mode        <MODE>
           update-romlist  <ROMLIST_FILE>  NOT TESTED!
           update-firmware <FIRMWARE_FILE> NOT TESTED!

           * If destination is not specified,
             file is copied to current working directory
             with timestamp before it's filename
```
```
$ ./jjr.sh
[ INFO ] Joey Jr. device found

         Device:              /dev/sda
         Mount point:         /media/hlf/BENNVENN

         Firmware version:    V2_02_29
         Mode set:            GBC

         Detected ROM:        TETRIS
         Checksum correct:    true
         ROM flashable:       false
```
```
$ ./jjr.sh write rom my_rom.gb
[ INFO ] Joey Jr. device found

         Device:              /dev/sda
         Mount point:         /media/hlf/BENNVENN

         Firmware version:    V2_02_29
         Mode set:            GBC

         Detected ROM:        Unknown
         Checksum correct:    false
         ROM flashable:       true

[ INFO ] Going to write my_rom.gb to /dev/sda

         Do you want to continue? y

[ SUCC ] Writing finished successfully
[ SUCC ] Refreshing Joey Jr...
[ SUCC ] Joey Jr. device reconnected
```