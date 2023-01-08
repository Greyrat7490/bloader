; ***********************************
; read sector from disk into ES:BX
; cl = first sector
; ch = cylinder
; dh = head
; dl = driver number
; al = number of sectors to read
; ***********************************
readSectors:
    mov ah, 0x02 ; read
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

.err_msg: db "ERROR: could not read sectors", 0xd, 0xa, 0
.success_msg: db "sucessfully read sectors", 0xd, 0xa, 0
