; methode 1 (memory map / only method to get ALL available memory) ***************
; int 0x15  eax=0xe820
; ->    ES:DI = ptr to SMAP buffer (size: most of the time 20B / rare case 24B)
;       SMAP: 64bit addr | 64bit size | 32bit type (| 4bit ACPI 3.0 bitfield)
;       type 1: usable
;       type 2: unusable
;       type 3: ACPI reusable
;       type 4: ACPI NVS memory
;       type 5: bad memory
; ********************************************************************************

; methode 2 (continuous memory between 1MiB - 16MiB and above 16MiB) **************
; int 0x15  ax=0xe801
; ->    AX/CX = continuous memory between 1MiB - 16MiB (in KiB)
;       BX/DX = continuous memory above 16MiB (in 64KiB -> 4GiB cap)
;       some BIOSes might always return AX=BX=0 or CX=DX=0 (take other pair)
; ********************************************************************************

; methode 3 (continuous memory above 1MiB) ****************************************
; int 0x15  ah=0x88
; ->    AX = continuous memory above 1MiB (in KiB)
;       capped at 64MiB (some BIOSes might cap at 15MiB)
; ********************************************************************************

%define SMAP_ASCII 0x534d4150       ; ASCII for "SMAP"
%define MAX_SMAP_SIZE 24

get_memory_map:
    .method1:
        mov ebx, 0
        mov di, memory_map_addr
        mov edx, SMAP_ASCII

        .l1:
            mov eax, 0xe820
            mov ecx, MAX_SMAP_SIZE
            int 0x15

            ; error occured try next method
            jc .method2
            cmp eax, SMAP_ASCII
            jne .method2

            mov ax, word [memory_map_len]
            inc ax
            mov word [memory_map_len], ax

            add di, MAX_SMAP_SIZE

            cmp ebx, 0
            jne .l1

        mov byte [memory_info_kind], 1
        xor eax, eax
        jmp .exit

    .method2:
        xor cx, cx
        xor dx, dx

        mov ax, 0xe801
        int 0x15

        ; error occured try next method
        jc .method3
        cmp ax, 0x86    ; unsupported func
        je .method3
        cmp ax, 0x80    ; invalid command
        je .method3

        cmp cx, 0
        jne .useAXBX    ; are cx and dx valid

        mov ax, cx
        mov bx, dx

        .useAXBX:
            mov word [lower_memory_KiB], ax
            mov word [upper_memory_64KiB], bx

        mov byte [memory_info_kind], 2
        jmp .exit

    .method3:
        clc                 ; some BIOSes won't clear CF on success (so preemptive clear)
        mov ah, 0x88
        int 0x15

        jc .err
        cmp ax, 0
        je .err

        mov word [lower_memory_KiB], ax
        mov byte [memory_info_kind], 3
        jmp .exit

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

memory_info_kind: db 0          ; which method see top

memory_map_addr: dw 0xf000      ; 29KiB after bootloader start, 4KiB space
memory_map_len: dw 0            ; memory_info_kind 1: map entry count
upper_memory_64KiB: dw 0        ; memory_info_kind 2: continuous memory above 16MiB in 64KiB  (4GiB cap)
lower_memory_KiB: dw 0          ; memory_info_kind 2: continuous memory between 1MiB - 16MiB in KiB
                                ; memory_info_kind 3: continuous memory above 1MiB (might cap at 15MiB or 64MiB)
