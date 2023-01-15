# simple legacy bootloader

## procedure
* [x] enable A20
* [x] get memory info
  * [x] memory map
  * [x] continuous memory (for BIOSes not supporting memory map)
* [x] check vbe support
* [x] get best vbe mode
* [x] enter protected mode
* [x] load kernel from FAT16 drive (file named "KERNEL")
* [x] enter long mode
* [x] pass important information (in rdi)
* [x] give control to the kernel (elf64 file)

## build
* ```$ make``` / ```$ make release```
  * creates a bootable image without any kernel inside

## test it with qemu
* ```$ make test```
  * creates a bootable image with a test kernel inside (test.asm)
  * test.asm just prints "BLOADER" to the screen

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
* ```$ make``` / ```$ make release```
* ```$ sudo dd if=build/bloader.img of=/dev/<YourDevice>``` (or any other way)
* put your elf64 kernel into the root directory and call it "KERNEL" (or change name in OPTIONS)
* reboot and open BIOS
* make sure legacy boot(CSM) is enabled when using uefi device
* boot into USB device
