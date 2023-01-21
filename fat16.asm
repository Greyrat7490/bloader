%define fat_lba             RESERVED_SECTORS
%define root_dir_lba        (fat_lba + TOTAL_FATS * SECTORS_PER_FAT)

%define sec_per_cyl         (HEADS_PER_CYLINDER * SECTORS_PER_TRACK)

%define root_dir_cyl        (root_dir_lba / sec_per_cyl)
%define root_dir_head       (root_dir_lba % sec_per_cyl / SECTORS_PER_TRACK)
%define root_dir_sector     (root_dir_lba % sec_per_cyl % SECTORS_PER_TRACK + 1)    ; sector starts from 1

%define fat_cyl             (fat_lba / sec_per_cyl)
%define fat_head            (fat_lba % sec_per_cyl / SECTORS_PER_TRACK)
%define fat_sector          (fat_lba % sec_per_cyl % SECTORS_PER_TRACK + 1)


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
; cl = sector
; ch = cylinder
; dh = head
; al = sector count
; edi = dest (edi increases)
read32:
    push edi
    push eax

    mov ah, 0x02    ; read
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
    xor dx, dx
    mov bx, sec_per_cyl
    div bx
    mov ch, al          ; cylinder

    mov ax, dx

    xor dx, dx
    mov bx, SECTORS_PER_TRACK
    div bx
    mov dh, al          ; head

    mov cl, dl
    inc cl              ; sector
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
    call LBA_to_CHS

    mov al, byte [SectorsPerCluster]
    call read32

    pop eax
    shl eax, 1          ; * 2 (size of one fat16 entry)

    movzx eax, word [fat_addr+eax]
    cmp eax, 0xfff8
    jle readClusterChain
    ret

read_root_dir:
    mov edi, root_dir_addr

    mov al, MAX_ROOT_ENTRIES * 32 / BYTES_PER_SECTOR
    mov cl, root_dir_sector
    mov ch, root_dir_cyl
    mov dh, root_dir_head
    call read32
    ret

read_fat:
    mov edi, fat_addr

    ; fat is bigger than 0x5000 Bytes -> read in 2 steps
    mov al, max_sectors
    mov cl, fat_sector
    mov ch, fat_cyl
    mov dh, fat_head
    call read32

    mov eax, fat_lba+max_sectors
    call LBA_to_CHS
    mov al, SECTORS_PER_FAT
    sub al, max_sectors
    call read32
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
    mov dword [kernel_size], ebx

    movzx eax, word [root_dir_addr+eax+start_cluster]       ; stores start_cluster-2 (because 2nd is reserved)
    mov edi, kernel_addr
    call readClusterChain
    ret

kernel_size: dd 0
