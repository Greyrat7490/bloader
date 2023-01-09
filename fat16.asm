%define fat_addr            (RESERVED_SECTORS * BYTES_PER_SECTOR)
%define root_dir_addr       (fat_addr + TOTAL_FATS * SECTORS_PER_FAT * BYTES_PER_SECTOR)

%define bytes_per_cylinder  (HEADS_PER_CYLINDER * SECTORS_PER_TRACK * BYTES_PER_SECTOR)
%define bytes_per_track     (SECTORS_PER_TRACK * BYTES_PER_SECTOR)

%define root_dir_cyl        (root_dir_addr / bytes_per_cylinder)
%define root_dir_head       (root_dir_addr % bytes_per_cylinder / bytes_per_track)
%define root_dir_sector     (root_dir_addr % bytes_per_cylinder % bytes_per_track / BYTES_PER_SECTOR + 1) ; sector starts from 1

%define start_cluster 0x1a      ; offset to start_cluster
%define file_size 0x1c          ; offset to file_size

%define kernel_addr 0x120000
%define tmp_dst_addr 0xb000     ; (0xb000 - 0xf000 used)


load_kernel:
    call read_root_dir

    movzx eax, word [tmp_dst_addr+start_cluster]       ; stores start_cluster-2 (because first 2 are reserved)
    add eax, 2

    mov edi, kernel_addr
    call readCluster
    ret

.at_cluster_msg: db "start cluster of file: ", 0
.file_size_msg: db "file size (in bytes): ", 0

; 0x10c00 -> sector: 9, head: 2, cylinder: 0
read_root_dir:
    mov dl, byte [DriveNumber]
    mov al, MAX_ROOT_ENTRIES * 32 / BYTES_PER_SECTOR
    mov cl, root_dir_sector
    mov ch, root_dir_cyl
    mov dh, root_dir_head
    mov bx, tmp_dst_addr
    call readSectors
    ret

; input: eax = cluster number
; loads cluster to addr in edi and edi gets increased
readCluster:
    .to_CHS:
        mov ebx, SECTORS_PER_CLUSTER * BYTES_PER_SECTOR
        mul ebx
        add eax, root_dir_addr

        mov ebx, bytes_per_cylinder
        xor edx, edx
        div ebx
        mov ch, al  ; cylinder

        mov eax, edx
        mov ebx, bytes_per_track
        xor edx, edx
        div ebx
        push eax ; head

        mov eax, edx
        mov ebx, BYTES_PER_SECTOR
        xor edx, edx
        div ebx
        mov cl, al
        inc cl      ; sector

        pop eax     ; restore eax (head)
        mov dh, al

    mov dl, byte [DriveNumber]
    mov al, byte [SectorsPerCluster]
    mov bx, tmp_dst_addr
    call readSectors

    ret
    ; TODO: go unreal mode to access higher address
    .relocate:
        ; edi is already set and gets inc by movsd
        mov esi, tmp_dst_addr
        movzx ecx, byte [SectorsPerCluster]
        shl ecx, 7                              ; * 512 / 4 -> size in dwords
        cld
        rep movsd
    ret
