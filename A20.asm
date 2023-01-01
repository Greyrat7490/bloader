; not tested (no device where A20 is disabled per default)
enable_A20:
    call check_A20
    cmp ax, 1
    je .exit

    .bios_int:
        ; is int 0x15 to enable A20 supported
        mov ax, 0x2403
        int 0x15
        jb .fast
        cmp ah, 0
        jne .fast

        ; check A20 status with bios (another check if interrupt works)
        mov ax, 0x2402
        int 0x15
        jb .fast
        cmp ah, 0
        jne .fast

        cmp al, 1   ; A20 is active
        je .exit

        mov ax, 0x2401
        int 0x15
        jb .fast
        cmp ah, 0
        je .exit

    .fast:
        in al, 0x92
        cmp al, 2
        je .exit        ; is already set
        or al, 2
        and al, ~1      ; clear first bit
        out 0x92, al

    .exit:
        mov si, .enabled_msg
        call print
        ret

    .err:
        mov si, .err_msg
        call print
        jmp $

    .enabled_msg: db "A20 is enabled", 0xd, 0xa, 0
    .err_msg: db "could not enable A20", 0xd, 0xa, 0

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
