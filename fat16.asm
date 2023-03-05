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

; output: bx = is lba supported
check_lba_supp:
    mov ah, 0x41
    mov bx, 0x55aa
    mov dl, byte [DriveNumber]
    int 0x13
    jc .no_supp
    mov bx, 1
    ret
.no_supp:
    mov bx, 0
    ret

not_found_int:
    mov si, .err_msg
    call print
    mov si, .name
    call print
    jmp $
.err_msg: db "ERROR: could not find file: ", 0
.name: db kernel_name, 0xa, 0xd, 0


[BITS 32]
; eax = lba (32bit)
; ebx = sector count (max 127)
; edi = dest addr (edi increases)
read_lba32:
    mov byte [DAPACK.blkcnt], bl
    mov dword [DAPACK.lba_lower], eax
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
    movzx ecx, byte [DAPACK.blkcnt]
    shl ecx, 7          ; * 512 / 2 -> sectors in dwords

    cld
    rep movsd
    ret

; eax = lba (32bit)
; ebx = sector count (max 127)
; edi = dest addr (edi increases)
read_chs:
    push edi
    push ebx

    call LBA_to_CHS
    mov ah, 0x02    ; read
    mov al, bl
    mov dl, byte [DriveNumber]
    mov bx, tmp_addr

    mov edi, read_int
    call exec_in_real

.relocate:
    pop eax
    pop edi

    mov esi, tmp_addr
    movzx ecx, al
    shl ecx, 7          ; * 512 / 2 -> sectors in dwords

    cld
    rep movsd
    ret

; input: eax = lba
; output: ch = cylinder
;         dh = head
;         cl = sector
LBA_to_CHS:
    push ebx

    xor dx, dx
    mov bx, word [sectors_per_cylinder]
    div bx
    mov ch, al          ; cylinder

    mov ax, dx

    xor dx, dx
    mov bx, word [SectorsPerTrack]
    div bx
    mov dh, al          ; head

    mov cl, dl
    inc cl              ; sector

    pop ebx
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

    movzx ebx, byte [SectorsPerCluster]
    call dword [read] 

    pop eax
    shl eax, 1          ; * 2 (size of one fat16 entry)

    movzx eax, word [fat_addr+eax]
    cmp eax, 0xfff8
    jle readClusterChain
    ret

read_root_dir:
    mov edi, root_dir_addr

    mov eax, root_dir_lba
    mov ebx, MAX_ROOT_ENTRIES * 32 / BYTES_PER_SECTOR
    call dword [read] 
    ret

read_fat:
    mov edi, fat_addr

    ; fat is bigger than 0x5000 Bytes -> read in 2 steps
    mov eax, fat_lba
    mov ebx, max_sectors
    call dword [read] 

    mov eax, fat_lba+max_sectors
    mov ebx, SECTORS_PER_FAT - max_sectors
    call dword [read]
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

set_read_mode: 
    ; if BIOS emulates USB as floppy LBA is not supported (DriveNumber = 0/1)
    cmp byte [DriveNumber], 1
    jbe .chs                    ; jbe (unsigned less equal)

    mov edi, check_lba_supp
    call exec_in_real
    cmp bx, 1

    je .exit
.chs:
    mov dword [read], read_chs

    ; precalculate sectors_pre_cylinder
    mov ax, word [SectorsPerTrack]
    mov bx, word [HeadsPerCylinder]
    mul bx
    mov word [sectors_per_cylinder], ax

.exit:
    ret

load_kernel:
    call set_read_mode

    call read_fat
    call read_root_dir

    call find_file

    mov ebx, dword [root_dir_addr+eax+file_size]

    movzx eax, word [root_dir_addr+eax+start_cluster]       ; stores start_cluster-2 (because 2nd is reserved)
    mov edi, kernel_addr
    call readClusterChain
    ret

read: dd read_lba32 ; default use lba (if not supported fallback to chs)

sectors_per_cylinder: dw 0

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
