[BITS 16]
jmp strict short boot_entry
nop

; **************************************************
; FAT16
; **************************************************
OEM_ID              db      "bloader "
BytesPerSector      dw      0x0200
SectorsPerCluster   db      8
ReservedSectors     dw      1
TotalFATs           db      2
MaxRootEntries      dw      0x0200
NumberOfSectors     dw      0
MediaDescriptor     db      0xf8
SectorsPerFAT       dw      0x0040
SectorsPerTrack     dw      0x0020
SectorsPerHead      dw      0x0040
HiddenSectors       dd      0
BigSectorsPerFAT    dd      0x00010000
DriveNumber         db      0
ReservedByte        db      0
Signature           db      0x29
VolumeID            dd      0xf4206964
VolumeLabel         db      "bloader    "
FileSystem          db      "FAT16   "
; **************************************************

[ORG 0x7c00]                ; load code into memory at 0x7c00 (es:bx)
boot_entry:
    cli
    mov sp, 0x7c00          ; set stack right before boot sector
    xor ax, ax
    mov ss, ax

    mov ds, ax              ; ORG only sets offset so set segments to 0 just to be sure
    mov es, ax
    mov fs, ax
    mov gs, ax
    sti

    mov [DriveNumber], dl   ; BIOS stores driver number in dl
    mov cl, 2               ; get 2nd sector
    mov al, 3               ; read 3 sector
    mov ch, 0               ; track
    mov dh, 0               ; head
    mov bx, stage2          ; dst (es:bx / 0x07c0:0x0200)
    call read

    jmp stage2              ; jmp to 2nd stage

%include "print.asm"
%include "read.asm"

times 510 - ($ - $$) db 0
dw 0xaa55                   ; magic number -> bootable

; ******************************************************
; 2nd stage
; ******************************************************
stage2:
    call enable_A20
    ; TODO: init_vbe
    ; TODO: get memory map

    jmp enter_protected

    %include "A20.asm"
    %include "protected.asm"

[BITS 32]
protected_entry:
    mov byte [0xb8000], 65
    mov byte [0xb8001], 0x1b

    ; TODO: loader kernel
    ; TODO: jump tp kernel

    jmp $
; ******************************************************
