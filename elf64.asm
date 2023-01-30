[BITS 64]
%define elf_ph_size 0x38            ; programm header size
%define elf_sh_size 0x40            ; section header size

%define elf_entry 0x18              ; programm start addr                       (8Byte)
%define elf_programm_header 0x20    ; offset to programm headers                (8Byte)
%define elf_section_header 0x28     ; offset to section headers                 (8Byte)
%define elf_ph_num 0x38             ; programm header count                     (2Byte)
%define elf_sh_num 0x3c             ; section header count                      (2Byte)

%define elf_ph_type 0x0             ; type of programm header                   (4Byte)
%define elf_ph_addr 0x10            ; virtual addr of programm header           (8Byte)
%define elf_ph_filesize 0x20        ; programm header size in the file          (8Byte)
%define elf_ph_memsize 0x28         ; programm header size in memory            (8Byte)
%define elf_pt_load 0x1             ; loadable programm header                  (4Byte)

%define elf_sh_type 0x4             ; type of section header                    (4Byte)
%define elf_sh_addr 0x10            ; virtual addr of section                   (8Byte)
%define elf_sh_memsize 0x20         ; section size in memory                    (8Byte)
%define elf_st_nobits 0x8           ; programm space without data (bss section) (4Byte)

; ouput: rdi = addr to .bss (0 -> not found)
;        rcx = size of .bss (0 -> not found)
get_bss:
    cmp word [kernel_addr+elf_sh_num], 0
    je .use_ph

    mov rax, qword [kernel_addr+elf_section_header]
    add rax, kernel_addr

    movzx rcx, word [kernel_addr+elf_sh_num]
    .l1:
        cmp dword [rax+elf_sh_type], elf_st_nobits
        je .found

        add rax, elf_sh_size
        dec rcx
        cmp rcx, 0
        jg .l1

    .not_found:
        mov rdi, 0
        ret
    .found:
        mov rdi, qword [rax+elf_sh_addr]
        mov rcx, qword [rax+elf_sh_memsize]
        ret

; no sectors -> use last loadable programm header (get ".bss" with file and memory size diff)
.use_ph:
    call get_last_ph

    mov rcx, [rdi+elf_ph_memsize]
    sub rcx, qword [rdi+elf_ph_filesize]

    mov rax, [rdi+elf_ph_addr]
    add rax, qword [rdi+elf_ph_filesize]
    mov rdi, rax

; output: rdi = addr to last loadable programm header
get_last_ph:
    mov rdi, qword [kernel_addr+elf_programm_header]
    add rdi, kernel_addr

    ; last programm header into rdi
    movzx eax, word [kernel_addr+elf_ph_num]
    dec eax
    mov ebx, elf_ph_size
    mul ebx
    add rdi, rax

    ; last loadable programm header
    mov rcx, qword [kernel_addr+elf_ph_num]
    .l1:
        cmp dword [rdi+elf_ph_type], elf_pt_load
        je .found

        sub rdi, elf_ph_size
        dec rcx
        cmp rcx, 0
        jg .l1

    .not_found:
        mov rdi, 0
        ret
    .found:
        ret

; output: rax = elf64 file end in memory (.bss included)
get_elf_memend:
    call get_last_ph
    mov rax, qword [rdi+elf_ph_memsize]
    add rax, qword [rdi+elf_ph_addr]
    ret

zero_init_bss:
    call get_bss

    cmp rdi, 0
    je .exit        ; no .bss sector

    mov rax, 0
    shr rcx, 2      ; / 4 -> size in dwords
    cld
    rep stosd
.exit:
    ret
