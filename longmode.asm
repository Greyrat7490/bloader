; **********************************************************
; Paging information:
; - Using Level 4 Paging
; - PML4-Table -> PDP-Table -> PD-Table -> PT-Table
; - identity mapping
; - Entry size 8 Byte
; - Table size 4KiB
; - Page size 4KiB
;
;                       Paging-Tables information
; ----------------------------------------------------------------
; |         Table Count           |  Table size / Table Entries  |
; ----------------------------------------------------------------
; |         1x PML4-Table         |   1 * 4KiB  /  1 Entry       |
; |         1x PDP-Table          |   1 * 4KiB  /  1 Entry       |
; |         1x PD-Table           |   1 * 4KiB  /  4 Entries     |
; |         4x PT-Table           |   4 * 4KiB  /  512 Entries   |
;
; |   Memory occupied by Tables   |         Memory mapped        |
; |    4 * 512 * 8Byte = 16KiB    |    512 * 4 * 4KiB = 8MiB     |
; ----------------------------------------------------------------
;
;
;       Virtual -> Physical
; ------------------------------
; |            ....            |        - ....
; |      0x7000 -> 0x7000      |        - stack, bootloader start
; |      0xf000 -> 0xf000      |        - memory map
; |     0xb8000 -> 0xb8000     |        - VGA-Text-Buffer
; |    0x100000 -> 0x100000    |        - Paging-Tables
; |    0x107000 -> 0x107000    |        - Kernel
; |    0x7fffff -> 0x7fffff    |
; | -------------------------- |        - 8MiB are mapped
; |          0x800000          |        - unmapped
; |         0xfd000000         |        - vbe framebuffer (unmapped)
; |            ....            |        - ....
; ------------------------------
;
; **********************************************************

; 0x100000 safe to use
%define PML4_addr 0x100000
%define PDP_addr  0x101000
%define PD_addr   0x102000
%define PTs_addr  0x103000


[BITS 16]
enter_long_mode:
    cli
    lgdt [gdt32.pointer]

    mov eax, cr0
    or eax, 1     ; first bit to enable protected mode
    mov cr0, eax

    jmp gdt32.code:.protected_entry

[BITS 32]
.protected_entry:
    cli
    mov ax, gdt32.data
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    call .init_paging
    call .enable_long_mode
    lgdt [gdt64.pointer]

    jmp gdt64.code:.init

.enable_long_mode:
    ; load PML4_table to cr3
    mov eax, PML4_addr
    mov cr3, eax

    ; enable Physical Address Extension (PAE) with cr4 register
    mov eax, cr4
    or eax, 1 << 5          ; bit 5 is PAE-flag
    mov cr4, eax

    ; enable long mode in the EFER MSR (Model Specific Register)
    mov ecx, 0xc0000080
    rdmsr
    or eax, 1 << 8          ; bit 8 is the long mode bit
    wrmsr

    ; enable paging mode with the cr0
    mov eax, cr0
    or eax, 1 << 31     ; set bit 31 to enable paging
    mov cr0, eax
    ret

.init_paging:
    ; map first PML4 entry
    mov eax, PDP_addr
    or eax, 11b             ; present + writable
    mov [PML4_addr], eax

    ; map first PDP entry
    mov eax, PD_addr
    or eax, 11b
    mov [PDP_addr], eax

    ; map first 4 PD entries
    mov edi, PD_addr
    mov ebx, PTs_addr
    mov ecx, 0              ; counter

    or ebx, 11b             ; present + writable
    .map_PD:
        mov [edi + ecx * 8], ebx
        add ebx, 0x1000     ; next physical address to map (4KiB steps)

        inc ecx

        cmp ecx, 4
        jl .map_PD

    ; map all 4 PT tables
    mov edi, PTs_addr
    mov ecx, 0              ; start entry
    mov ebx, 0              ; start physical address
                            ; ecx-th entry has to be ecx-th address -> identity mapping
    or ebx, 11b
    .map_PT:
        mov [edi + ecx * 8], ebx
        add ebx, 0x1000     ; next physical address to map (4KiB steps)

        inc ecx

        cmp ecx, 512 * 4    ; 512 Entries * 4 PageTables
        jl .map_PT
    ret


[BITS 64]
.init:
    mov ax, gdt64.data
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov rsp, 0x7c00

    jmp long_mode_entry


align 16
gdt32:
.null: equ $ - gdt32          ; kernel null descriptor
    dq 0
.code: equ $ - gdt32        ; ring 0 code descriptor
    dw 0xffff               ; limit (low)
    dw 0                    ; base  (low)
    db 0                    ; base  (middle)
    db 10011010b            ; present, kernel_mode, code_data_seg, code_seg, executable, read/write
    db 11001111b            ; protected mode, limit (higher 4bit)
    db 0                    ; base  (high)
.data: equ $ - gdt32        ; ring 0 data descriptor
    dw 0xffff               ; limit (low)
    dw 0                    ; base  (low)
    db 0                    ; base  (middle)
    db 10010010b            ; present, kernel_mode, code_data_seg, data_seg, executable, read/write
    db 11001111b            ; protected mode, limit (higher 4bit)
    db 0                    ; base  (high)
.pointer:
    dw $ - gdt32 - 1
    dd gdt32

align 16
gdt64:
.null: equ $ - gdt64        ; kernel null descriptor
    dq 0
.code: equ $ - gdt64        ; ring 0 code descriptor
    dw 0xffff               ; limit (low)
    dw 0                    ; base  (low)
    db 0                    ; base  (middle)
    db 10011010b            ; present, kernel_mode, code_data_seg, code_seg, executable, read/write
    db 10101111b            ; long mode, limit (higher 4bit)
    db 0                    ; base  (high)
.data: equ $ - gdt64        ; ring 0 data descriptor
    dw 0xffff               ; limit (low)
    dw 0                    ; base  (low)
    db 0                    ; base  (middle)
    db 10010010b            ; present, kernel_mode, code_data_seg, data_seg, executable, read/write
    db 10101111b            ; long mode, limit (higher 4bit)
    db 0                    ; base  (high)
.pointer:
    dw $ - gdt64 - 1
    dq gdt64
