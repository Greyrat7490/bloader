# simple legacy bootloader

## process
* [x] enable A20
* [x] get memory info
  * [x] memory map
  * [x] continuous memory (for BIOSes not supporting memory map)
* [x] get best vbe mode
* [x] set vbe mode
* [x] go protected mode
* [x] go long mode
* [x] load kernel from FAT16 drive (ATA only!)
  * many PCs don't support ATA anymore (including mine)
  * [ ] TODO: broader supported method (maybe AHCI?)

## build
* ```$ make```

## test it with qemu
* ```$ make run```

## debug with qemu
* ```$ make monitor```
  * ```$(qemu) info tlb```
    * all valid pages and there frames
  * ```$(qemu) info mem```
    * compact paging tables
  * ```$(qemu) info registers```
    * show all regs and there values
  * ```$(qemu) x/<num>x <addr>```
    * show num words at addr
  * ```$(qemu) x/<num>i <addr>```
    * show num instructions at addr

## create log with qemu
* ```$ make log```
  * log all interrupts (state of all regs)

## try it on a real device
*  ```$ sudo dd if=bootloader.img of=/dev/<YourDevice>``` (or any other way)
* reboot and open BIOS
* make sure legacy boot(CSM) is enabled when using uefi device
* boot into USB device
