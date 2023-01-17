[BITS 16]
jmp strict short boot_entry
nop

; **********************************
; OPTIONS
%define kernel_name "KERNEL"                            ; file name of the kernel (keep allowed FAT16 file names in mind)
%define kernel_addr 0x400000                            ; default virtual addr of elf files (adjust if needed or change in linker)
%define kernel_stack_size 0x4000                        ; 16KiB
%define kernel_stack_addr (0x130000+kernel_stack_size)  ; stack top
; **********************************

; **************************************************
; FAT16
; **************************************************
%define BYTES_PER_SECTOR    0x0200
%define SECTORS_PER_CLUSTER 8
%define RESERVED_SECTORS    7
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

    mov [DriveNumber], dl   ; BIOS stores driver number in dl

    mov bx, stage2          ; dst (es:bx / 0:stage2 -> stage2)
    call loadStage2

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
    call get_memory_map
    call get_vbe_info
    call find_best_mode
    jmp enter_protected_mode

%include "A20.asm"
%include "vbe.asm"
%include "memory.asm"

[BITS 32]
protected_entry:
    call load_kernel
    jmp enter_long_mode

%include "fat16.asm"
%include "longmode.asm"
%include "elf64.asm"

[BITS 64]
long_mode_entry:
    call zero_init_bss

    mov ax, word [memory_map_len]
    mov word [boot_info.memory_map_len], ax
    mov ax, word [upper_memory_64KiB]
    mov word [boot_info.upper_memory_64KiB], ax
    mov ax, word [lower_memory_KiB]
    mov word [boot_info.lower_memory_KiB], ax
    mov eax, dword [kernel_size]
    mov dword [boot_info.kernel_size], eax

    ; pass important information as args (System V AMD64 ABI calling convention)
    mov rdi, boot_info

    mov rsp, kernel_stack_addr

    ; give control to the kernel
    jmp qword [kernel_addr+elf_entry]
; ******************************************************


boot_info:
    .memory_map:            dq memory_map_addr
    .memory_map_len:        dw 0
    .lower_memory_KiB:      dw 0
    .upper_memory_64KiB:    dw 0
    .paging_tables:         dq PML4_addr
    .gdt32:                 dq gdt32
    .gdt64:                 dq gdt64
    .biosIDT:               dq biosIDT
    .vbe_info:              dq vbe_info
    .vbe_mode_info:         dq vbe
    .kernel_addr:           dq kernel_addr
    .kernel_size:           dd 0
