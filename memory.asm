; methode 1 **********************************************************************
; int 0x15  eax=0xe820
; ->    ES:DI = ptr to SMAP buffer (size: most of the time 20B / rare case 24B)
;       SMAP: 64bit addr | 64bit size | 32bit type (| 4bit ACPI 3.0 bitfield)
;       type 1: usable
;       type 2: unusable
;       type 3: ACPI reusable
;       type 4: ACPI NVS memory
;       type 5: bad memory
; ********************************************************************************

; methode 2 **********************************************************************
; int 0x15  ax=0xe801
; ->    AX/CX = continues memory between 1MiB - 16MiB (in KiB)
;       BX/DX = continues memory above 16MiB (in 64KiB)
;       some BIOSes might always return AX=BX=0 or CX=DX=0 (take other pair)
; ********************************************************************************

; methode 3 **********************************************************************
; int 0x15  ah=0x88
; ->    AX = continues memory above 1MiB (in KiB)
;       some BIOSes might cap at 15MiB or 64MiB
; ********************************************************************************

%define MEMORY_MAP_ADDR 0xf000      ; 29KiB after bootloader start, 4KiB space
%define SMAP_ASCII 0x534d4150       ; ASCII for "SMAP"
%define MAX_SMAP_SIZE 24

get_memory_map:
    .method1:
        mov ebx, 0
        mov di, MEMORY_MAP_ADDR
        mov edx, SMAP_ASCII
        .l1:
            mov eax, 0xe820
            mov ecx, MAX_SMAP_SIZE
            int 0x15

            jc .method2
            cmp eax, SMAP_ASCII
            jne .method2            ; error occured try next method

            mov ax, word [memory_map_len] 
            inc ax
            mov word [memory_map_len], ax

            add di, MAX_SMAP_SIZE

            cmp ebx, 0
            jne .l1
        xor eax, eax
        jmp .exit

    .method2:
        ; TODO: in work
        mov si, .wip1_msg
        call print

    .method3:
        ; TODO: in work
        mov si, .wip2_msg
        call print

    .err:
        mov si, .err_msg
        call print
        jmp $
    .exit:
        mov si, .success_msg
        call print
        ret

.err_msg: db "ERROR: could not get memory map", 0xd, 0xa, 0
.success_msg: db "successfully loaded memory map", 0xd, 0xa, 0
.wip1_msg: db "TODO: method2", 0xd, 0xa, 0
.wip2_msg: db "TODO: method3", 0xd, 0xa, 0

memory_map_len: dw 0
