%define fat_lba            RESERVED_SECTORS
%define root_dir_lba       (fat_lba + TOTAL_FATS * SECTORS_PER_FAT)

%define start_cluster 0x1a      ; offset to start_cluster
%define file_size 0x1c          ; offset to file_size

%define root_dir_addr 0x120000  ; (0x120000 - 0x124000)
%define fat_addr 0x124000       ; (0x124000 - 0x12c000)

[BITS 64]
; eax = LBA
; bl = size in sector (0 -> 256)
; rdi = dest addr
readATA:
    ; ports 0x1f0 - 0x1f7 for primary ATA harddisk controller
    mov edx, 0x1f3      ; LBA 0 - 7 bits port
    out dx, al

    mov edx, 0x1f4      ; LBA 8 - 15 bits port
    shr eax, 8
    out dx, al

    mov edx, 0x1f5      ; LBA 16 - 23 bits port
    shr eax, 8
    out dx, al

    mov edx, 0x1f6      ; LBA 24 - 27 bits port
    shr eax, 8
    or al, 11100000b    ; bit 4 for master, bit 6 for LBA mode, bit 7 and 5 for old ATA drives (backward compatibility)
    out dx, al

    mov edx, 0x1f2      ; sector count port
    mov al, bl
    out dx, al

    mov edx, 0x1f7      ; command/status port
    mov al, 0x20        ; read with retry
    out dx, al

    mov ecx, 4          ; 4 retries
.wait:
    in al, dx
    test al, 0x80
    jne .retry          ; is BSY flag set
    test al, 8
    jne .recv           ; is sector buffer ready
.retry:
    dec ecx
    cmp ecx, 0
    jg .wait
.recv:
    in al, dx
    test al, 0x80
    jne .recv
    test al, 0x21
    jne .err
.ready:
    mov rcx, BYTES_PER_SECTOR / 2
    mov rdx, 0x1f0      ; ATA data port
    rep insw

    mov edx, 0x1f7      ; status port
    in al, dx           ; wait 400ns
    in al, dx
    in al, dx
    in al, dx

    dec bl
    cmp bl, 0
    jg .recv            ; read next sector
    ret
.err:
    stc ; carry flag to indicate an error
    ret

; eax = cluster number
; rdi = dest addr
; output: loads clusters to dest addr (rdi increases)
readClusterChain:
    push rax
    add eax, 2
    movzx ebx, byte [SectorsPerCluster]
    mul ebx
    add eax, root_dir_lba

    call readATA

    pop rax
    shl eax, 1          ; * 2 (size of one fat16 entry)

    movzx eax, word [fat_addr+eax]
    cmp eax, 0xfff8
    jle readClusterChain
    ret

read_root_dir:
    mov bl, MAX_ROOT_ENTRIES * 32 / BYTES_PER_SECTOR
    mov eax, root_dir_lba
    mov rdi, root_dir_addr
    call readATA
    ret

read_fat:
    mov bl, SECTORS_PER_FAT
    mov eax, fat_lba
    mov rdi, fat_addr
    call readATA
    ret

load_kernel:
    call read_fat
    call read_root_dir

    movzx eax, word [root_dir_addr+start_cluster]       ; stores start_cluster-2 (because 2nd is reserved)

    mov rdi, kernel_addr
    call readClusterChain
    ret
