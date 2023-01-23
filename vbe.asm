get_vbe_info:
    mov ax, 0x4f00
    mov di, vbe_info
    push es             ; some bios might override es (just to be safe)
    int 0x10            ; vbe bios interupt
    pop es

    cmp ax, 0x004f
    jne .error
        mov si, .success_msg
        call print
        ret
    .error:
        mov si, .err_msg
        call print
        jmp $

.err_msg: db "ERROR: VBE is not supported", 0xd, 0xa, 0x0
.success_msg: db "VBE is supported", 0xd, 0xa, 0x0

get_mode_info:
    mov ax, word [fs:si]
    cmp ax, 0xffff              ; end of mode list
    je .exit

    mov cx, ax
    mov ax, 0x4f01
    mov di, vbe_mode_info
    push es
    int 0x10
    pop es

    cmp ax, 0x004f
    je .exit

    .err:
        mov dx, word [fs:si]

        push si
        mov si, .err_msg
        call print
        call printh
        pop si
    .exit:
        ret

.err_msg: db "ERROR: could not get vbe mode info ", 0


find_best_mode:
    mov si, word [vbe_info.video_modes]    ; offset to mode info
    mov fs, word [vbe_info.video_modes+2]  ; segment to mode info

    .start:
        call get_mode_info
        cmp ax, 0xffff
        je .exit                            ; no modes left

        cmp byte [vbe_mode_info.bpp], 24    ; only 24bit colors (or better)
        jl .next

        mov ax, word [vbe_mode_info.width]  ; highest resolution
        cmp ax, word [vbe.width]
        jl .next

        mov ax, word [fs:si]
        mov word [vbe.mode], ax

        mov ax, word [vbe_mode_info.width]
        mov word [vbe.width], ax

        mov ax, word [vbe_mode_info.pitch]
        mov word [vbe.pitch], ax

        mov ax, word [vbe_mode_info.height]
        mov word [vbe.height], ax

        mov al, byte [vbe_mode_info.bpp]
        mov byte [vbe.bpp], al

        mov eax, dword [vbe_mode_info.framebuffer]
        mov dword [vbe.framebuffer], eax

    .next:
        add si, 2
        jmp .start

    .exit:
        ret

vbe:
    .mode:          dw 0
    .framebuffer    dd 0
    .pitch:         dw 0
    .width:         dw 0
    .height:        dw 0
    .bpp:           db 0

vbe_mode_info:
    .attributes     dw 0            ; bit 7 indicates linear framebuffer support
    .unused         times 14 db 0   ; not needed
    .pitch          dw 0            ; bytes per line
    .width          dw 0
    .height         dw 0
    .unused2        times 3 db 0
    .bpp            db 0            ; bits per pixel
    .unused3        times 14 db 0
    .framebuffer    dd 0
    .reserved       times 212 db 0

vbe_info:
    .signature      db "VBE2"       ; indicate support for VBE 2.0+
    .version        dw 0            ; VBE version (high byte is major version, low byte is minor version)
    .oem            dd 0
    .capabilities   dd 0            ; card capabilities (bitfield)
    .video_modes    dd 0            ; pointer to supported video modes (offset + segment)
    .video_memory   dw 0            ; video memory in 64KB blocks
    .software_rev   dw 0
    .vendor         dd 0
    .product_name   dd 0
    .product_rev    dd 0
    .reserved       times 222 db 0
    .oem_data       times 256 db 0
