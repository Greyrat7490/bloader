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
    call .read_root_dir

    mov si, .at_cluster_msg
    call print

    mov dx, word [tmp_dst_addr+start_cluster]       ; stores start_cluster-2 (because first 2 are reserved)
    add dx, 2
    call printh

    mov si, .file_size_msg
    call print

    mov dx, word [tmp_dst_addr+file_size]
    call printh

    ret

.at_cluster_msg: db "start cluster of file: ", 0
.file_size_msg: db "file size (in bytes): ", 0

; 0x10c00 -> sector: 9, head: 2, cylinder: 0
.read_root_dir:
    mov dl, byte [DriveNumber]
    mov al, MAX_ROOT_ENTRIES * 32 / BYTES_PER_SECTOR
    mov cl, root_dir_sector
    mov ch, root_dir_cyl
    mov dh, root_dir_head
    mov bx, tmp_dst_addr
    call readSectors
    ret

.readCluster:
    mov dl, byte [DriveNumber]
    mov al, byte [SectorsPerCluster]
    mov cl, 2               ; get 2nd sector
    mov ch, 0               ; track
    mov dh, 0               ; head
    mov bx, tmp_dst_addr
    call readSectors

.relocate:
    mov esi, tmp_dst_addr
    ; edi is already set and gets inc by movsd
    movzx ecx, byte [SectorsPerCluster]
    shl ecx, 7                              ; * 512 / 4 -> size in dwords
    cld
    rep movsd
