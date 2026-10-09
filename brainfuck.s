.equ IR_SIZE, 24
.equ OUTPUT_SIZE, 128
.equ DESC_SIZE, 16

.section .bss

.align 16
tape:
    .skip 30000

.align 16
outputBuffer:
    .skip OUTPUT_SIZE
outputBufferEnd:

.align 16
irBuffer:
    .skip 3145728

.align 16
bracketStack:
    .skip 65536

#generic linear loop descriptions go here
.align 16
linearDescriptors:
    .skip 2097152

.align 8
descriptorPtr:
    .skip 8

#temporary coefficient table used while analysing one loop
#offsets -128..127 become indexes 0..255
.align 16
linearCoeff:
    .skip 256


.section .text
.global brainfuck


#each IR record is now:
#+0  handler address
#+8  argument 1
#+16 argument 2
.macro NEXT
    addq $IR_SIZE, %r12
    jmp *(%r12)
.endm


brainfuck:
    pushq %rbp
    movq %rsp, %rbp

    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    subq $8, %rsp

    movq %rdi, %rbx              #bf source

    leaq irBuffer(%rip), %r12     #where we build our interpreted IR
    leaq bracketStack(%rip), %r15 #keeps track of normal loops

    leaq linearDescriptors(%rip), %rax
    movq %rax, descriptorPtr(%rip)


compileLoop:
    movb (%rbx), %al

    testb %al, %al
    je compileDone

    cmpb $'+', %al
    je compileAddSub

    cmpb $'-', %al
    je compileAddSub

    cmpb $'>', %al
    je compileMove

    cmpb $'<', %al
    je compileMove

    cmpb $'.', %al
    je compileOutput

    cmpb $',', %al
    je compileInput

    cmpb $'[', %al
    je compileOpen

    cmpb $']', %al
    je compileClose

    incq %rbx
    jmp compileLoop



#collapse + and - into one interpreted operation
compileAddSub:
    xorl %ecx, %ecx


compileAddSubLoop:
    movb (%rbx), %al

    cmpb $'+', %al
    je compilePlus

    cmpb $'-', %al
    je compileMinus

    jmp compileAddSubDone


compilePlus:
    incl %ecx
    incq %rbx
    jmp compileAddSubLoop


compileMinus:
    decl %ecx
    incq %rbx
    jmp compileAddSubLoop


compileAddSubDone:
    testb %cl, %cl
    je compileLoop

    leaq opAdd(%rip), %rax
    movq %rax, (%r12)

    movb %cl, 8(%r12)

    addq $IR_SIZE, %r12
    jmp compileLoop



#same thing for pointer movement
compileMove:
    xorq %rcx, %rcx


compileMoveLoop:
    movb (%rbx), %al

    cmpb $'>', %al
    je compileRight

    cmpb $'<', %al
    je compileLeft

    jmp compileMoveDone


compileRight:
    incq %rcx
    incq %rbx
    jmp compileMoveLoop


compileLeft:
    decq %rcx
    incq %rbx
    jmp compileMoveLoop


compileMoveDone:
    testq %rcx, %rcx
    je compileLoop

    leaq opMove(%rip), %rax
    movq %rax, (%r12)

    movq %rcx, 8(%r12)

    addq $IR_SIZE, %r12
    jmp compileLoop



compileOutput:
    leaq opOutput(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    incq %rbx

    jmp compileLoop



compileInput:
    leaq opInput(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    incq %rbx

    jmp compileLoop



compileOpen:
    #cheap exact optimisations first cuz these handlers are tiny

    cmpb $'-', 1(%rbx)
    je checkClearMinus

    cmpb $'+', 1(%rbx)
    je checkClearPlus

    cmpb $'>', 1(%rbx)
    je checkScanRight

    cmpb $'<', 1(%rbx)
    je checkScanLeft

    jmp checkTransfer1



checkClearMinus:
    cmpb $']', 2(%rbx)
    jne checkTransfer1

    leaq opClear(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    addq $3, %rbx

    jmp compileLoop



checkClearPlus:
    cmpb $']', 2(%rbx)
    jne checkTransfer1

    leaq opClear(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    addq $3, %rbx

    jmp compileLoop



checkScanRight:
    cmpb $']', 2(%rbx)
    jne checkTransfer1

    leaq opScanRight(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    addq $3, %rbx

    jmp compileLoop



checkScanLeft:
    cmpb $']', 2(%rbx)
    jne checkTransfer1

    leaq opScanLeft(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    addq $3, %rbx

    jmp compileLoop



checkTransfer1:
    #[->+<]

    cmpb $'-', 1(%rbx)
    jne checkTransfer2

    cmpb $'>', 2(%rbx)
    jne checkTransfer2

    cmpb $'+', 3(%rbx)
    jne checkTransfer2

    cmpb $'<', 4(%rbx)
    jne checkTransfer2

    cmpb $']', 5(%rbx)
    jne checkTransfer2

    leaq opTransfer1(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    addq $6, %rbx

    jmp compileLoop



checkTransfer2:
    #[->++<]

    cmpb $'-', 1(%rbx)
    jne checkDuplicate

    cmpb $'>', 2(%rbx)
    jne checkDuplicate

    cmpb $'+', 3(%rbx)
    jne checkDuplicate

    cmpb $'+', 4(%rbx)
    jne checkDuplicate

    cmpb $'<', 5(%rbx)
    jne checkDuplicate

    cmpb $']', 6(%rbx)
    jne checkDuplicate

    leaq opTransfer2(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    addq $7, %rbx

    jmp compileLoop



checkDuplicate:
    #[->+>+<<]

    cmpb $'-', 1(%rbx)
    jne tryLinearLoop

    cmpb $'>', 2(%rbx)
    jne tryLinearLoop

    cmpb $'+', 3(%rbx)
    jne tryLinearLoop

    cmpb $'>', 4(%rbx)
    jne tryLinearLoop

    cmpb $'+', 5(%rbx)
    jne tryLinearLoop

    cmpb $'<', 6(%rbx)
    jne tryLinearLoop

    cmpb $'<', 7(%rbx)
    jne tryLinearLoop

    cmpb $']', 8(%rbx)
    jne tryLinearLoop

    leaq opDuplicate(%rip), %rax
    movq %rax, (%r12)

    addq $IR_SIZE, %r12
    addq $9, %rbx

    jmp compileLoop



#this is the big optimisation
#try to describe ANY simple linear loop algebraically
tryLinearLoop:

    #clear temporary coefficient table
    leaq linearCoeff(%rip), %rdi
    xorq %rax, %rax
    movq $32, %rcx
    rep stosq

    leaq linearCoeff(%rip), %r9

    leaq 1(%rbx), %r8            #r8 scans inside the loop
    xorl %ecx, %ecx              #relative tape pointer = 0


linearScan:
    movb (%r8), %al

    testb %al, %al
    je linearFail

    cmpb $']', %al
    je linearEnd

    #nested loop means this isnt one simple linear transform
    cmpb $'[', %al
    je linearFail

    #io inside the loop also kills this optimisation
    cmpb $'.', %al
    je linearFail

    cmpb $',', %al
    je linearFail

    cmpb $'>', %al
    je linearRight

    cmpb $'<', %al
    je linearLeft

    cmpb $'+', %al
    je linearPlus

    cmpb $'-', %al
    je linearMinus

    #comments etc can js be ignored
    incq %r8
    jmp linearScan



linearRight:
    incl %ecx

    cmpl $127, %ecx
    jg linearFail

    incq %r8
    jmp linearScan



linearLeft:
    decl %ecx

    cmpl $-128, %ecx
    jl linearFail

    incq %r8
    jmp linearScan



linearPlus:
    movl %ecx, %edx
    addl $128, %edx

    incb (%r9,%rdx,1)

    incq %r8
    jmp linearScan



linearMinus:
    movl %ecx, %edx
    addl $128, %edx

    decb (%r9,%rdx,1)

    incq %r8
    jmp linearScan



linearEnd:
    #pointer needs to come back to where it started
    testl %ecx, %ecx
    jne linearFail

    #source cell must lose exactly 1 each iteration
    #0xff = -1 mod 256
    cmpb $0xFF, 128(%r9)
    jne linearFail


    #now convert coefficient table into a tiny descriptor list
    movq descriptorPtr(%rip), %r11
    movq %r11, %r14              #remember start of this descriptor
    xorq %r10, %r10              #number of destinations

    xorl %esi, %esi


descriptorBuild:
    cmpl $256, %esi
    je descriptorDone

    cmpl $128, %esi              #dont include source cell itself
    je descriptorNext

    movzbl (%r9,%rsi,1), %eax

    testb %al, %al
    je descriptorNext

    #convert table index back to signed tape offset
    movslq %esi, %rdx
    subq $128, %rdx

    movq %rdx, (%r11)            #destination offset
    movb %al, 8(%r11)            #multiplier

    addq $DESC_SIZE, %r11
    incq %r10


descriptorNext:
    incl %esi
    jmp descriptorBuild



descriptorDone:
    movq %r11, descriptorPtr(%rip)

    #one interpreted op now represents the ENTIRE bf loop
    leaq opLinear(%rip), %rax
    movq %rax, (%r12)

    movq %r14, 8(%r12)           #descriptor pointer
    movq %r10, 16(%r12)          #how many destinations

    addq $IR_SIZE, %r12

    leaq 1(%r8), %rbx            #skip whole loop including ]

    jmp compileLoop



linearFail:
    #couldnt prove it safe so js treat it as normal bf
    jmp compileNormalOpen



compileNormalOpen:
    leaq opJumpZero(%rip), %rax
    movq %rax, (%r12)

    movq $0, 8(%r12)

    movq %r12, (%r15)
    addq $8, %r15

    addq $IR_SIZE, %r12

    incq %rbx
    jmp compileLoop



compileClose:
    leaq bracketStack(%rip), %rax

    cmpq %rax, %r15
    je syntaxError

    subq $8, %r15

    movq (%r15), %rax

    leaq opJumpNonZero(%rip), %rdx
    movq %rdx, (%r12)

    #closing ] jumps to first instruction inside [
    leaq IR_SIZE(%rax), %rdx
    movq %rdx, 8(%r12)

    #opening [ jumps to first instruction after ]
    leaq IR_SIZE(%r12), %rdx
    movq %rdx, 8(%rax)

    addq $IR_SIZE, %r12

    incq %rbx
    jmp compileLoop



compileDone:
    leaq bracketStack(%rip), %rax

    cmpq %rax, %r15
    jne syntaxError

    leaq opEnd(%rip), %rax
    movq %rax, (%r12)


    #zero whole bf tape
    leaq tape(%rip), %rdi
    xorq %rax, %rax
    movq $3750, %rcx
    rep stosq


    #runtime registers
    leaq tape(%rip), %r13

    leaq outputBuffer(%rip), %r14
    leaq outputBufferEnd(%rip), %r15

    leaq irBuffer(%rip), %r12

    #start the interpreter
    jmp *(%r12)



opAdd:
    movb 8(%r12), %al
    addb %al, (%r13)

    NEXT



opMove:
    addq 8(%r12), %r13

    NEXT



opClear:
    movb $0, (%r13)

    NEXT



opTransfer1:
    movb (%r13), %al

    addb %al, 1(%r13)
    movb $0, (%r13)

    NEXT



opTransfer2:
    movb (%r13), %al

    addb %al, %al
    addb %al, 1(%r13)

    movb $0, (%r13)

    NEXT



opDuplicate:
    movb (%r13), %al

    addb %al, 1(%r13)
    addb %al, 2(%r13)

    movb $0, (%r13)

    NEXT



#generic algebraic loop handler
#still INTERPRETED, this is js one smarter IR instruction
opLinear:
    movzbl (%r13), %r9d

    testb %r9b, %r9b
    je linearRuntimeDone

    movq 8(%r12), %r8            #descriptor list
    movq 16(%r12), %rcx          #number of destinations

    testq %rcx, %rcx
    je linearRuntimeClear


linearRuntimeLoop:
    movq (%r8), %rdx             #relative destination cell
    movzbl 8(%r8), %esi          #multiplier

    movl %r9d, %eax
    imull %esi, %eax

    #only low byte matters cuz bf cells wrap mod 256
    addb %al, (%r13,%rdx,1)

    addq $DESC_SIZE, %r8

    decq %rcx
    jne linearRuntimeLoop


linearRuntimeClear:
    movb $0, (%r13)


linearRuntimeDone:
    NEXT



opScanRight:
    cmpb $0, (%r13)
    je scanRightDone

    incq %r13
    jmp opScanRight


scanRightDone:
    NEXT



opScanLeft:
    cmpb $0, (%r13)
    je scanLeftDone

    decq %r13
    jmp opScanLeft


scanLeftDone:
    NEXT



opOutput:
    movb (%r13), %al

    movb %al, (%r14)
    incq %r14

    cmpq %r15, %r14
    jne outputDone

    call flushOutput


outputDone:
    NEXT



opInput:
    call flushOutput

    xorq %rax, %rax
    xorq %rdi, %rdi

    movq %r13, %rsi
    movq $1, %rdx

    syscall

    cmpq $1, %rax
    je inputDone

    movb $0, (%r13)


inputDone:
    NEXT



opJumpZero:
    cmpb $0, (%r13)
    je jumpZeroTaken

    NEXT


jumpZeroTaken:
    movq 8(%r12), %r12
    jmp *(%r12)



opJumpNonZero:
    cmpb $0, (%r13)
    jne jumpNonZeroTaken

    NEXT


jumpNonZeroTaken:
    movq 8(%r12), %r12
    jmp *(%r12)



opEnd:
    call flushOutput

    xorq %rax, %rax

    addq $8, %rsp

    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx

    movq %rbp, %rsp
    popq %rbp

    ret



flushOutput:
    leaq outputBuffer(%rip), %rsi

    movq %r14, %rdx
    subq %rsi, %rdx

    testq %rdx, %rdx
    je flushDone


flushWrite:
    movq $1, %rax
    movq $1, %rdi

    syscall

    testq %rax, %rax
    jle flushReset

    addq %rax, %rsi
    subq %rax, %rdx

    jne flushWrite


flushReset:
    leaq outputBuffer(%rip), %r14


flushDone:
    ret



syntaxError:
    movq $1, %rax

    addq $8, %rsp

    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx

    movq %rbp, %rsp
    popq %rbp

    ret
