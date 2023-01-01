[BITS 16]
[ORG 0x0000]
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

boot_entry:
    cli
    xor ax, ax
    mov ss, ax
    mov sp, 0x7c00          ; set stack right before boot sector

    ; load code into memory at 0x7c00 (es:bx)
    ; 0x07c0:0x0000 = ((0x07c0 << 4) + 0x0000) => 0x7c00
    mov ax, 0x07c0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    sti

    mov [DriveNumber], dl   ; BIOS stores driver number in dl
    mov cl, 2               ; get 2nd sector
    mov al, 1               ; read 1 sector
    mov ch, 0               ; track
    mov dh, 0               ; head
    mov bx, 0x0200          ; dst (es:bx / 0x07c0:0x0200)
    call read

    jmp 0x07c0:0x0200       ; jmp to 2nd stage
    jmp $

%include "print.asm"
%include "read.asm"

times 510 - ($ - $$) db 0
dw 0xaa55                   ; magic number -> bootable

; ******************************************************
; 2nd stage
; ******************************************************
stage2:
    mov dx, cs
    call printh

    call check_A20
    cmp ax, 0
    je .a20_disabled

    mov si, .a20_enabled_msg
    jmp .a20_check_end

    .a20_disabled:
    mov si, .a20_disabled_msg
    .a20_check_end:

    call print

    jmp $

    .a20_enabled_msg: db "A20 is already enabled", 0xd, 0xa, 0
    .a20_disabled_msg: db "A20 is disabled", 0xd, 0xa, 0

    %include "A20.asm"
; ******************************************************
