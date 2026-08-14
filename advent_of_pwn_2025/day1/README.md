# Day 1

### Challenge description

Every year, Santa maintains the legendary Naughty-or-Nice list, and despite the rumors, there’s no magic behind it at all—it’s pure, meticulous byte-level bookkeeping. Your job is to apply every tiny change exactly and confirm the final list matches perfectly—check it once, check it twice, because Santa does not tolerate even a single incorrect byte. At the North Pole, it’s all just static analysis anyway: even a simple objdump | grep naughty goes a long way.

### Solution

We are given a setuid ELF binary `check-list`:

```bash
$ file /challenge/check-list 
/challenge/check-list: setuid ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, BuildID[sha1]=5d72c19e489b3e5561698933e83d95330760e809, stripped
```
As always, the goal is to read `/flag`, which is own by root. `check-list` being own by root as well and setuid, our path is clear: make `check-list` read `/flag`.

Let's review the assembly code:
```bash
$ objdump -M intel -D /challenge/check-list
```

The binary starts with allocating 0x500 bytes (1280) onto the stack. It then read stdin up to 1024 bytes which are then stored onto the freshly allocated stack frame:

```asm
Disassembly of section .text:

0000000000401000 <.text>:
  401000:	48 89 e5             	mov    rbp,rsp
  401003:	48 81 ec 00 05 00 00 	sub    rsp,0x500 ; Allocate 0x500 bytes onto the stack
  40100a:	b8 00 00 00 00       	mov    eax,0x0 ; read syscall number
  40100f:	bf 00 00 00 00       	mov    edi,0x0 ; stdin file descriptor
  401014:	48 8d b5 00 fc ff ff 	lea    rsi,[rbp-0x400]
  40101b:	ba 00 04 00 00       	mov    edx,0x400 ; read up to 0x400 bytes (1024) and push them to rsi (rbp-0x400)
  401020:	0f 05                	syscall
```

Immediatly after this, a massive amount of `add` and `sub` instructions are scrambling every byte of the data read from stdin:

```asm
  401022:	80 85 81 fe ff ff 4f 	add    BYTE PTR [rbp-0x17f],0x4f
  401029:	80 ad 72 fe ff ff 8c 	sub    BYTE PTR [rbp-0x18e],0x8c
  401030:	80 85 1f fe ff ff 4a 	add    BYTE PTR [rbp-0x1e1],0x4a
  401037:	80 ad 2f ff ff ff 43 	sub    BYTE PTR [rbp-0xd1],0x43
  40103e:	80 ad ae fe ff ff 5f 	sub    BYTE PTR [rbp-0x152],0x5f
  ...
  aa1210:	80 6d ed a2          	sub    BYTE PTR [rbp-0x13],0xa2
  aa1214:	80 ad c9 fe ff ff 24 	sub    BYTE PTR [rbp-0x137],0x24
  aa121b:	80 ad f8 fe ff ff f5 	sub    BYTE PTR [rbp-0x108],0xf5
  aa1222:	80 85 a6 fe ff ff d2 	add    BYTE PTR [rbp-0x15a],0xd2
  aa1229:	80 bd 00 fc ff ff a9 	cmp    BYTE PTR [rbp-0x400],0xa9

```

Then, the binary read every byte of scramble data and compare it into an hardcoded version:

```asm
  aa1229:	80 bd 00 fc ff ff a9 	cmp    BYTE PTR [rbp-0x400],0xa9
  aa1230:	0f 85 09 33 00 00    	jne    0xaa453f
  aa1236:	80 bd 01 fc ff ff c9 	cmp    BYTE PTR [rbp-0x3ff],0xc9
  aa123d:	0f 85 fc 32 00 00    	jne    0xaa453f
  aa1243:	80 bd 02 fc ff ff ec 	cmp    BYTE PTR [rbp-0x3fe],0xec
  aa124a:	0f 85 ef 32 00 00    	jne    0xaa453f
  aa1250:	80 bd 03 fc ff ff 30 	cmp    BYTE PTR [rbp-0x3fd],0x30
  aa1257:	0f 85 e2 32 00 00    	jne    0xaa453f
  ..
  aa448f:	0f 85 aa 00 00 00    	jne    0xaa453f
  aa4495:	80 7d fe 61          	cmp    BYTE PTR [rbp-0x2],0x61
  aa4499:	0f 85 a0 00 00 00    	jne    0xaa453f
  aa449f:	80 7d ff 96          	cmp    BYTE PTR [rbp-0x1],0x96
  aa44a3:	0f 85 96 00 00 00    	jne    0xaa453f
```

If only a single byte mismatch, the binary exit early (`jne 0xaa453f`):

```asm
  aa4533:	b8 3c 00 00 00       	mov    eax,0x3c ; exit syscall number
  aa4538:	bf 00 00 00 00       	mov    edi,0x0 ; status code
  aa453d:	0f 05                	syscall
```

However, if every byte match the assembly harcoded version, the executable output a successfull message:

```asm
  aa44a9:	48 c7 c0 01 00 00 00 	mov    rax,0x1 ; write syscall number
  aa44b0:	48 c7 c7 01 00 00 00 	mov    rdi,0x1 ; stdout file descriptor
  aa44b7:	48 8d 35 48 0b 00 00 	lea    rsi,[rip+0xb48]        # 0xaa5006 ; content address
  aa44be:	48 c7 c2 31 00 00 00 	mov    rdx,0x31 ; write up to 0x31 bytes

```

```bash
$ objdump -s -j .rodata --start-address=0xaa5006 --stop-address=0xaa5037 check-list

check-list:     file format elf64-x86-64

Contents of section .rodata:
 aa5006 e29c a820436f 72726563 743a2079 6f75 ... Correct: you
 aa5016 2063 6865636b 65642069 74207477 6963  checked it twic
 aa5026 652c 20616e64 20697420 73686f77 7321 e, and it shows!
 aa5036 0a  
```

And read `/flag` content, push it onto the stack and write it back to stdout:

```asm
  aa44c7:	b8 02 00 00 00       	mov    eax,0x2 ; open syscall
  aa44cc:	48 8d 3d 2d 0b 00 00 	lea    rdi,[rip+0xb2d]        # 0xaa5000
  aa44d3:	be 00 00 00 00       	mov    esi,0x0
  aa44d8:	ba 00 00 00 00       	mov    edx,0x0
  aa44dd:	0f 05                	syscall
  aa44df:	48 83 f8 00          	cmp    rax,0x0
  aa44e3:	7c 4e                	jl     0xaa4533
  aa44e5:	49 89 c4             	mov    r12,rax
  aa44e8:	b8 00 00 00 00       	mov    eax,0x0 ; read syscall
  aa44ed:	4c 89 e7             	mov    rdi,r12 ; `/flag` file descriptor
  aa44f0:	48 8d b5 00 fb ff ff 	lea    rsi,[rbp-0x500]
  aa44f7:	ba 00 01 00 00       	mov    edx,0x100 ; read up to 0x100 bytes
  aa44fc:	0f 05                	syscall
  aa44fe:	48 83 f8 00          	cmp    rax,0x0
  aa4502:	7e 2f                	jle    0xaa4533
  aa4504:	48 89 c1             	mov    rcx,rax
  aa4507:	48 c7 c0 01 00 00 00 	mov    rax,0x1 ; write syscall
  aa450e:	48 c7 c7 01 00 00 00 	mov    rdi,0x1 ; stdout file descriptor
  aa4515:	48 8d b5 00 fb ff ff 	lea    rsi,[rbp-0x500] ; write content at this address
  aa451c:	48 89 ca             	mov    rdx,rcx ; write up to rcx bytes (rax-returned value from read syscall)
  aa451f:	0f 05                	syscall
```

```bash
$ objdump -s -j .rodata --start-address=0xaa5000 --stop-address=0xaa5005 check-list 

check-list:     file format elf64-x86-64

Contents of section .rodata:
 aa5000 2f666c61 67                          /flag 
```

At this point, this is pretty straightforward.
We have the hardcoded version of the scramble data, and the full «scrambling-process» which is invertible (only addition and substaction).
We could write a python script to parse the assembly code and retrieve the original file, but it will be much easier to work with the assembly instructions. We only have to:

- Push to the stack the scramble data version
- Invert the scramble process
- Write to stdout the retrieved original data

With a few search & replace operations and some assembly instructions, we can work with the executable assembly code and have a 100% assembly solution.

We start with allocating 0x400 bytes onto the stack and store original stack pointer into `rbp`. This will allow us to work with the offset of the executable assembly code without any changes:

```asm
.intel_syntax noprefix
.global _start

_start:
	mov rbp, rsp
push_data_to_stack:
	sub rsp, 0x400
```

Then, we turn every `cmp` original assembly instuction into a `mov`. With a one search & replace command and using source offset, we now have the scramble data stored on the stack:

```asm
	mov    BYTE PTR [rbp-0x400],0xa9
	mov    BYTE PTR [rbp-0x3ff],0xc9
	mov    BYTE PTR [rbp-0x3fe],0xec
	mov    BYTE PTR [rbp-0x3fd],0x30
    ...
	mov    BYTE PTR [rbp-0x4],0xef
	mov    BYTE PTR [rbp-0x3],0x7
	mov    BYTE PTR [rbp-0x2],0x61
	mov    BYTE PTR [rbp-0x1],0x96
```

Then, inverting the scrambling process, every `add` instruction become a `sub` and vice versa.

```asm
deobfuscate_file:
	sub    BYTE PTR [rbp-0x17f],0x4f
	add    BYTE PTR [rbp-0x18e],0x8c
	sub    BYTE PTR [rbp-0x1e1],0x4a
	add    BYTE PTR [rbp-0xd1],0x43
    ...
    add    BYTE PTR [rbp-0x13],0xa2
	add    BYTE PTR [rbp-0x137],0x24
	add    BYTE PTR [rbp-0x108],0xf5
	sub    BYTE PTR [rbp-0x15a],0xd2
```

Finally, write the unscramble content to stdout:

```asm
write_to_stdout:
	mov rdi, 0x1
	mov rsi, rsp
	mov rdx, 0x400
	mov rax, 0x1
	syscall
	mov rdi, 0x0
	mov rax, 0x3c
	syscall
```

Turn the all thing into an ELF executable:

```bash
$ as -o day1.o day1.s
$ ld -o solve day1.o
```

And here is the flag:

```bash
$ ./solve > santa-list
$ cat santa-list | /challenge/check-list
✨ Correct: you checked it twice, and it shows!
pwn.college{8uvFlMPRSyeGfXURbSw0WGPyDrc.1FO1gTMywiMygzM4EzW}
```

[Full assembly code of the solution](solution.s)
