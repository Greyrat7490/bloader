# simple legacy bootloader

## build
* run "make"

## test it with qemu
* run "make run"

## try it on a real device
* sudo dd if=bootloader.img of=/dev/"yourDevice" (or any other way)
* reboot and open BIOS
* make sure legacy boot(CSM) is enabled when using uefi device
* boot into USB device
