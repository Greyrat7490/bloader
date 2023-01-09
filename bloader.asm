[BITS 16]
jmp strict short boot_entry
nop

; **************************************************
; FAT16
; **************************************************
%define BYTES_PER_SECTOR    0x0200
%define SECTORS_PER_CLUSTER 8
%define RESERVED_SECTORS    6
%define TOTAL_FATS          2
%define MAX_ROOT_ENTRIES    0x0200
%define SECTORS_PER_FAT     0x0040
%define SECTORS_PER_TRACK   63
%define HEADS_PER_CYLINDER  16

OEM_ID              db      "bloader "
BytesPerSector      dw      BYTES_PER_SECTOR
SectorsPerCluster   db      SECTORS_PER_CLUSTER
ReservedSectors     dw      RESERVED_SECTORS
TotalFATs           db      TOTAL_FATS
MaxRootEntries      dw      MAX_ROOT_ENTRIES
NumberOfSectors     dw      0
MediaDescriptor     db      0xf8
SectorsPerFAT       dw      SECTORS_PER_FAT
SectorsPerTrack     dw      SECTORS_PER_TRACK
HeadsPerCylinder    dw      HEADS_PER_CYLINDER
HiddenSectors       dd      0
BigSectorsPerFAT    dd      0x00010000
DriveNumber         db      0
Reserved            db      0
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

    mov [DriveNumber], dl       ; BIOS stores driver number in dl
    mov cl, 2                   ; start from 2nd sector
    mov al, RESERVED_SECTORS-1  ; read 5 sector
    mov ch, 0                   ; cylinder
    mov dh, 0                   ; head
    mov bx, stage2              ; dst (es:bx / 0:stage2 -> stage2)
    call readSectors

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
    ; TODO: go unreal mode to put access higher addr (needed to load kernel)
    call get_memory_map
    call load_kernel
    ; call init_vbe

    jmp enter_long_mode

.mem_info_kind_msg: db "memory info kind: ", 0
.mmap_len_msg: db "memory map len: ", 0

%include "A20.asm"
%include "vbe.asm"
%include "memory.asm"
%include "fat16.asm"
%include "longmode.asm"

[BITS 64]
long_mode_entry:
    ; only tmp for testing
    mov edi, kernel_addr
    mov esi, tmp_dst_addr
    movzx ecx, byte [SectorsPerCluster]
    shl ecx, 7                              ; * 512 / 4 -> size in dwords
    cld
    rep movsd

    ; call fill_screen32

    jmp $
    jmp kernel_addr

fill_screen32:    ; only works with 32 bpp
    cld
    mov eax, 0x41336e
    mov edi, dword [vbe.framebuffer]
    movzx ecx, word [vbe.width]
    rep stosd

    movzx ebx, word [vbe.height]
    .l1:
        movzx ecx, word [vbe.width]
        rep stosd

        dec ebx
        cmp ebx, 1
        jg .l1
    ret
; ******************************************************
