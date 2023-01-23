[BITS 32]
; edi = which service
; esi = packed args for service
; can only be called from protected mode (yet)
call_bios_service:
    cli
    lgdt [gdt32.pointer]
    jmp gdt32.code16:.protected_16bit
[BITS 16]
.protected_16bit:
    mov ax, gdt32.data16
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov eax, cr0
    and eax, ~1     ; disable protected mode
    mov cr0, eax

    jmp 0x0:.real_mode  ; enter real mode
.real_mode:
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    sidt [prev_idt] ; preserve idt
    lidt [biosIDT]

    sti
    ; TODO: check if edi is valid
    call [bios_services+edi*4]
    cli

    mov eax, cr0
    or eax, 1       ; enable protected mode
    mov cr0, eax

    jmp gdt32.code:.protected_entry
[BITS 32]
.protected_entry:
    mov ax, gdt32.data
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    lidt [prev_idt] ; restore idt
    sti
    ret

; idt to preserve
align 16
prev_idt:
    .len: dw 0x0
    .base: dd 0x0


bios_services:
    .set_vbe_mode:  dd set_vbe_mode
    .readCHS:       dd readCHS

[BITS 16]
; **********************************************
; read sectors using Cylinder Head Sector (CHS)
; to read_dest from boot drive (not recommanded use AHCI instead)
; input   (packed): esi = ch | dh | cl | al
; input (unpacked):
;   * ch = cylinder
;   * dh = head
;   * cl = sector
;   * al = how many sectors
; **********************************************
%define read_dest 0xa000
%define max_sectors ((0xf000 - read_dest) / BYTES_PER_SECTOR)
readCHS:
    push ax
    push bx
    push cx
    push dx

    ; TODO: check sectors count (< max_sectors / some BIOSes < 128)
    ; TODO: check cylinder boundary (some BIOSes)

    ; unpack args
    mov ax, si
    mov cl, ah
    shr esi, 16
    mov ax, si
    mov ch, ah
    mov dh, al

    mov ah, 0x2
    mov dl, byte [DriveNumber]
    mov bx, read_dest
    int 0x13
    jnc .exit

    push si
    mov si, .err_msg
    call print
    pop si
.exit:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.err_msg: db "ERROR: could not read sectors", 0xa, 0xd, 0

; *********************************
; set vbe mode
; input   (packed): esi = _ | _ |  bx  |
; input (unpacked):
;   * bx = vbe mode number
; *********************************
set_vbe_mode:
    push ax
    push bx
    mov bx, si ; unpack arg

    mov ax, 0x4f02
    or bx, 0x4000       ; enable linear framebuffer
    push es
    int 0x10            ; some bios might change es
    pop es

    cmp ax, 0x4f
    je .exit

    .err:
        push si
        mov si, .err_msg
        call print
        pop si
    .exit:
        pop bx
        pop ax
        ret

.err_msg: db "ERROR: could not set vbe mode", 0xd, 0xa, 0


[BITS 32]
; edi = addr to function to exec in real mode
exec_in_real:
    jmp gdt32.code16:.protected_16bit
.protected_16bit:
    cli
    pusha

    mov ax, gdt32.data16
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov eax, cr0
    and al, 0xfe     ; first bit to disable protected mode
    mov cr0, eax

    jmp 0x0:.real_mode  ; enter real mode
[BITS 16]
.real_mode:
    cli
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    lidt [biosIDT]
    sti
    popa
    call edi
    add sp, 2

.leave:
    cli
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
    ret
