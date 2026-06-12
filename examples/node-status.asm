; OpenClaw node status reporter (x86-64 Linux, NASM)
section .data
    msg     db  "OpenClaw node localhost:8080 -> OK", 10
    msglen  equ $ - msg

section .text
    global _start

_start:
    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    mov     rsi, msg
    mov     rdx, msglen
    syscall

    mov     rax, 60         ; sys_exit
    xor     rdi, rdi        ; status 0
    syscall
