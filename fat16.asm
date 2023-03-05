%define fat_lba             RESERVED_SECTORS
%define root_dir_lba        (fat_lba + TOTAL_FATS * SECTORS_PER_FAT)

%define start_cluster 0x1a      ; offset to start_cluster
%define file_size 0x1c          ; offset to file_size
%define file_name_size 8

%define root_dir_addr 0x120000  ; (0x120000 - 0x124000)
%define fat_addr 0x124000       ; (0x124000 - 0x12c000)

%define tmp_addr 0xa000         ; (0xa000 - 0xf000)
%define max_sectors ((0xf000 - tmp_addr) / BYTES_PER_SECTOR)

[BITS 16]
read_int:
    int 0x13
    jc .err
    cmp ah, 0
    jne .err
    ret
.err:
    mov si, .err_msg
    call print
    jmp $
.err_msg: db "ERROR: could not read cluster", 0xa, 0xd, 0

not_found_int:
    mov si, .err_msg
    call print
    mov si, .name
    call print
    jmp $
.err_msg: db "ERROR: could not find file: ", 0
.name: db kernel_name, 0xa, 0xd, 0


[BITS 32]
; TODO: check LBA extension suppport
; TODO: fallback to CHS if not supported
; edi = dest addr (edi increases)
read_lba32:
    push edi

    mov ax, 0
    mov ds, ax
    mov ax, DAPACK
    mov si, ax

    ; read (lba 48bit mode)
    ; if supported should always work (BIOS converts to CHS for drives which only support CHS)
    mov ah, 0x42
    mov dl, byte [DriveNumber]

    mov edi, read_int
    call exec_in_real

.relocate:
    pop edi

    mov esi, tmp_addr
    movzx ecx, word [DAPACK.blkcnt]
    shl ecx, 7          ; * 512 / 2 -> sectors in dwords

    cld
    rep movsd
    ret

; eax = cluster number
; edi = dest addr
; output: loads clusters to dest addr (edi increases)
readClusterChain:
    push eax

    add eax, 2
    movzx ebx, byte [SectorsPerCluster]
    mul ebx
    add eax, root_dir_lba

    mov dword [DAPACK.lba_lower], eax
    movzx ax, byte [SectorsPerCluster]
    mov word [DAPACK.blkcnt], ax
    call read_lba32

    pop eax
    shl eax, 1          ; * 2 (size of one fat16 entry)

    movzx eax, word [fat_addr+eax]
    cmp eax, 0xfff8
    jle readClusterChain
    ret

read_root_dir:
    mov edi, root_dir_addr

    mov word [DAPACK.blkcnt], MAX_ROOT_ENTRIES * 32 / BYTES_PER_SECTOR
    mov dword [DAPACK.lba_lower], root_dir_lba
    call read_lba32
    ret

read_fat:
    mov edi, fat_addr

    ; fat is bigger than 0x5000 Bytes -> read in 2 steps
    mov dword [DAPACK.lba_lower], fat_lba
    mov word [DAPACK.blkcnt], max_sectors
    call read_lba32

    mov dword [DAPACK.lba_lower], fat_lba+max_sectors
    mov word [DAPACK.blkcnt], SECTORS_PER_FAT - max_sectors
    call read_lba32
    ret

; find file in root dir named "KERNEL" (kernel_name)
; output: eax = root dir offset
find_file:
    cld
    mov eax, 0
    mov ecx, .name_len
    mov edi, root_dir_addr
    mov esi, .name
    rep cmpsb
    jne .loop
    ret

.loop:
    add eax, 32     ; 32 = entry size / next entry
    cmp eax, MAX_ROOT_ENTRIES
    jg .not_found

    mov ecx, .name_len
    lea edi, [root_dir_addr+eax]
    mov esi, .name
    rep cmpsb
    jne .loop
    ret

.not_found:
    mov edi, not_found_int
    call exec_in_real
    jmp $

.name: db kernel_name
.name_len: equ $ - .name

load_kernel:
    call read_fat
    call read_root_dir

    call find_file

    mov ebx, dword [root_dir_addr+eax+file_size]

    movzx eax, word [root_dir_addr+eax+start_cluster]       ; stores start_cluster-2 (because 2nd is reserved)
    mov edi, kernel_addr
    call readClusterChain
    ret

DAPACK:
    db 0x10     ; DAPACK size
    db 0        ; reserved (always 0)
.blkcnt:        ; sector count (after read/write set to actual value)
    dw 0
.dest:
    dw tmp_addr ; offset
	dw 0        ; segment
.lba_lower: 
    dd 0        ; lower 32bit lba
.lba_upper:
    dd 0        ; upper 16bit lba
