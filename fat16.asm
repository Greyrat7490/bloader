%define fat_lba            RESERVED_SECTORS
%define root_dir_lba       (fat_lba + TOTAL_FATS * SECTORS_PER_FAT)

%define start_cluster 0x1a      ; offset to start_cluster
%define file_size 0x1c          ; offset to file_size

%define kernel_addr 0x128000
%define fat_addr 0x120000       ; (0x120000 - 0x128000)
%define root_dir_addr 0xb000    ; (0xb000 - 0xf000)

[BITS 64]
; eax = LBA
; cl = sector count
; rdi = dest addr
readSectors64:
    ; ports 0x1f0 - 0x1f7 for primary ATA harddisk controller
    mov ebx, eax

    mov edx, 0x1f6      ; LBA 24 - 27 bits port
    shr eax, 24
    or al, 11100000b    ; for LBA mode
    out dx, al

    mov edx, 0x1f2      ; sector count port
    mov al, cl
    out dx, al

    mov edx, 0x1f3      ; LBA 0 - 7 bits port
    mov al, bl
    out dx, al

    mov edx, 0x1f4      ; LBA 8 - 15 bits port
    mov eax, ebx
    shr eax, 8
    out dx, al

    mov edx, 0x1f5      ; LBA 16 - 23 bits port
    mov eax, ebx
    shr eax, 16
    out dx, al

    mov edx, 0x1f7      ; command port
    mov al, 0x20        ; read with retry
    out dx, al

.wait:
    in al, dx
    test al, 8
    jz .wait            ; wait until sector buffer is ready

    mov eax, 512 / 2
    xor bx, bx
    mov bl, cl
    mul bx              ; sectors in words

    mov ecx, eax
    mov rdx, 0x1f0      ; ATA data port
    rep insw

    ret

load_kernel:
    ; TODO: read FAT

    call read_root_dir

    movzx eax, word [root_dir_addr+start_cluster]       ; stores start_cluster-2 (because first 2 are reserved)
    add eax, 2

    mov rdi, kernel_addr
    call readClusters
    ret

.at_cluster_msg: db "start cluster of file: ", 0
.file_size_msg: db "file size (in bytes): ", 0

read_root_dir:
    mov cl, 1
    mov eax, root_dir_lba
    mov rdi, root_dir_addr
    call readSectors64
    ret

; input: eax = cluster number
; loads cluster to addr in rdi and rdi gets increased
readClusters:
    movzx ebx, byte [SectorsPerCluster]
    mov cl, bl
    mul ebx
    add eax, root_dir_lba
    call readSectors64
    ; TODO: get next cluster from FAT
    ; TODO: if < 0xfff8 repeat
    ret
