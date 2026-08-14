.intel_syntax noprefix
.global _start

_start:
	mov rbp, rsp
push_file_to_stack:
	sub rsp, 0x400
	mov    BYTE PTR [rbp-0x400],0xa9
	mov    BYTE PTR [rbp-0x3ff],0xc9
	mov    BYTE PTR [rbp-0x3fe],0xec
	mov    BYTE PTR [rbp-0x3fd],0x30
	mov    BYTE PTR [rbp-0x3fc],0x58
	... Oh, oh, oh. Practice yourself.
	mov    BYTE PTR [rbp-0x4],0xef
	mov    BYTE PTR [rbp-0x3],0x7
	mov    BYTE PTR [rbp-0x2],0x61
	mov    BYTE PTR [rbp-0x1],0x96
deobfuscate_file:
	sub    BYTE PTR [rbp-0x17f],0x4f
	add    BYTE PTR [rbp-0x18e],0x8c
	sub    BYTE PTR [rbp-0x1e1],0x4a
	add    BYTE PTR [rbp-0xd1],0x43
	... Oh, oh, oh. Practice yourself.
	add    BYTE PTR [rbp-0x13],0xa2
	add    BYTE PTR [rbp-0x137],0x24
	add    BYTE PTR [rbp-0x108],0xf5
	sub    BYTE PTR [rbp-0x15a],0xd2
write_to_stdout:
	mov rdi, 0x1
	mov rsi, rsp
	mov rdx, 0x400
	mov rax, 0x1
	syscall
	mov rdi, 0x0
	mov rax, 0x3c
	syscall
