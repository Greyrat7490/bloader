; *************************************************
; read 2nd sector from disk and load into ES:BX
; bx = dest addr
; dl = driver number (already set by BIOS)
; *************************************************
loadStage2:
    mov cl, 2                   ; start from 2nd sector
    mov al, RESERVED_SECTORS-1  ; read 5 sector
    mov ch, 0                   ; cylinder
    mov dh, 0                   ; head
    mov ah, 0x02                ; read
    int 0x13
    jc .error

    mov si, .success_msg
    call print
    ret

    .error:
        mov si, .err_msg
        call print
        mov dx, ax  ; al stores status, ah is 01
        call printh
        ret

.err_msg: db "ERROR: could not load stage2", 0xd, 0xa, 0
.success_msg: db "successfully loaded stage2", 0xd, 0xa, 0
