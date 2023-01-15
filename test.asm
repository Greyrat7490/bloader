[BITS 64]
global _start
section .text

_start:
    mov byte [0xb8000], 66
    mov byte [0xb8001], 0x1b
    mov byte [0xb8002], 76
    mov byte [0xb8003], 0x1b
    mov byte [0xb8004], 79
    mov byte [0xb8005], 0x1b
    mov byte [0xb8006], 65
    mov byte [0xb8007], 0x1b
    mov byte [0xb8008], 68
    mov byte [0xb8009], 0x1b
    mov byte [0xb800a], 69
    mov byte [0xb800b], 0x1b
    mov byte [0xb800c], 82
    mov byte [0xb800d], 0x1b
    jmp $
