; return: ax = is A20 enabled
check_A20:
    push ds
    push es

    xor ax, ax
    mov es, ax

    not ax
    mov ds, ax

    ; 0x500 - 0x600 is guaranteed to be free after BIOS initialization
    ; preserve values anyway just to be sure
    mov di, 0x0500
    mov si, 0x0510

    ; save values
    mov al, byte [es:di]
    push ax
    mov al, byte [ds:si]
    push ax

    ; without A20 would result in same address with segment 0xffff
    ; 0xffff << 4 + 0x0510 = 0x100500 (A20) / 0x0500 (no A20)
    mov byte [es:di], 0x00
    mov byte [ds:si], 0x69
    cmp byte [es:di], 0x69

    ; restore values
    pop ax
    mov byte [es:di], al
    pop ax
    mov byte [ds:si], al

    mov ax, 0
    je .exit
    mov ax, 1   ; no wrapping around -> A20 is enabled

    .exit:
        pop es
        pop ds
        ret
