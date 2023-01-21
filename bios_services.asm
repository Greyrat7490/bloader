[BITS 32]
; edi = which service
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
    .printA: dd printA
    .printB: dd printB

printA:
    mov al, 65
    mov ah, 0xe
    int 0x10
    ret
printB:
    mov al, 66
    mov ah, 0xe
    int 0x10
    ret


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
