# simple legacy bootloader

## process
* [x] enable A20
* [x] get memory info
  * [x] memory map
  * [x] continuous memory (for BIOSes not supporting memory map)
* [x] get best vbe mode
* [x] set vbe mode
* [x] go protected mode
* [ ] go long mode
* [ ] load kernel from FAT16 drive

## build
* run "make"

## test it with qemu
* run "make run"

## try it on a real device
* sudo dd if=bootloader.img of=/dev/"yourDevice" (or any other way)
* reboot and open BIOS
* make sure legacy boot(CSM) is enabled when using uefi device
* boot into USB device
