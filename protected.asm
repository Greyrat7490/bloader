[BITS 16]
enter_protected:
    cli
    lgdt [gdt32.pointer]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp gdt32.code:.init

[BITS 32]
.init:
    mov ax, gdt32.data
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    jmp protected_entry

gdt32:
.null: equ $ - gdt32        ; kernel null descriptor
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
