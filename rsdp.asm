%define BDA 0x400
%define BDA_EBDA_BASE 0x40e         ; (word) EBDA (address >> 4) not on all BIOSes
%define BDA_KB_BEFORE_EBDA 0x413    ; (word)

%define EBDA_MIN_START 0x80000
%define EBDA_END 0xa0000

%define RSDP_SECOND_AREA_START 0xe0000
%define RSDP_SECOND_AREA_END   0xfffff

%define RSDP_REVISION_OFFSET 15     ; (byte) 0 = ACPI 1.0, 2 = ACPI 2.0 - 6.1
%define RSDP_STRUCT_SIZE 20         ; for ACPI 1.0
%define XSDP_STRUCT_SIZE 36         ; for ACPI 2.0 - 6.1
%define RSDP_REVISION_ACPI1_0 0
%define RSDP_REVISION_ACPI2_0 2

get_rsdp:
    .get_ebda1:
        xor edx, edx
        mov dx, [BDA_EBDA_BASE]
        shl edx, 4

        mov ebx, EBDA_END
        call .find

        call validate_rsdp

        cmp edi, 0
        jne .end

    .get_ebda2:
        xor edx, edx
        mov dx, [BDA_KB_BEFORE_EBDA]
        shl edx, 10

        mov ebx, EBDA_END
        call .find

        call validate_rsdp

        cmp edi, 0
        jne .end

    .find_below_1MB:
        mov edi, RSDP_SECOND_AREA_START
        mov ebx, RSDP_SECOND_AREA_END
        call .find

        call validate_rsdp
        
        cmp edi, 0
        jne .end

    .get_ebda3:
        mov edx, EBDA_MIN_START    
        mov ebx, EBDA_END
        call .find

        call validate_rsdp

    .end:
        mov dword [rsdp], edi
        cmp edi, 0
        je .err
        ret

    .err:
        jmp $

; input: edx = start_addr, ebx = last_addr
; output: edi = addr to rsdp (0 = not found)
.find:
    cld
    mov ecx, .name_len
    mov esi, .name
    mov edi, edx
    repe cmpsb
    je .found

.loop:
    cmp edi, ebx
    jge .not_found

    mov ecx, .name_len
    mov esi, .name
    repe cmpsb
    jne .loop

.found:
    sub edi, .name_len
    ret
.not_found:
    mov edi, 0
    ret

.name: db "RSD PTR "
.name_len: equ $ - .name

; input: edi = rsdp
; output: edi (0 = invalid else valid)
validate_rsdp:
    cmp edi, 0
    je .invalid

    mov ecx, RSDP_STRUCT_SIZE
    call .validate

    cmp edi, 0
    jne .valid
    .invalid:
        mov edi, 0
        ret

    .valid:
        mov bl, byte[edi+RSDP_REVISION_OFFSET]
        cmp bl, RSDP_REVISION_ACPI1_0
        jne .is_xsdp
        ret

        .is_xsdp:
            mov ecx, XSDP_STRUCT_SIZE
            call .validate
            ret

; input: edi = rsdp/xsdp, ecx = struct size
; output: edi (0 = invalid else valid)
.validate:
    xor eax, eax
    xor edx, edx
    mov ebx, ecx
    .loop_:
        mov dl, byte [edi]
        add eax, edx
        inc edi

        dec ebx
        cmp ebx, 1
        jge .loop_

    cmp al, 0
    je .valid_

    .invalid_:
        mov edi, 0
        ret
    .valid_:
        sub edi, ecx
        ret


rsdp: dd 0
