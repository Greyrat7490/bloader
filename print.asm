; **************
; print string
; si = string
; **************
print:
    push ax
    .l1:
        mov al, [si]
        cmp al, 0
        je .end
        mov ah, 0x0e
        int 0x10
        add si, 1
        jmp .l1
    .end:
        pop ax
        ret

; **************
; print hex
; dx = hex
; **************
printh:
    push bx
    push ax
    push cx

    mov eax, 2
    mov cl, 16

    .l1:
        sub cl, 4

        mov bx, dx
        shr bx, cl
        and bx, 0x000f
        mov bx, [.table + bx]
        mov [.pattern + eax], bl

        inc ax
        cmp ax, 6
        jne .l1

    push si
    mov si, .pattern
    call print
    pop si

    pop cx
    pop ax
    pop bx
    ret

.pattern: db '0x****', 0xa, 0xd, 0
.table: db '0123456789abcdef'
