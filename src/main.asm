; Sets the code the be of 64 bit format
BITS 64
; Tells NASM to use RIP-Relative addressing by default for memory references.
; On x86-64, position-independant code uses RIP-relative addressing.
; UEFI loads your .EFI at an address chosen by firmware - you do not control it.
; So absolute addresses are dangerous.
; RIP-Relative addressing keeps your code relocatable and correct.
; Absolute addressing braks in UEFI so setting relative addressing is required.
DEFAULT REL

; Setting efi_main label to be global so that it is accessible outside this file.
; Allows nasm/linker to see that it is a global label and allowed to be used in some way outside of this file.
; efi_main is the entry point of our assembly program so setting it to global here is just making sure the assembler and linker can access it.
global efi_main

; section data just means this section will go to the data part of memory where it stores data for our program.
section .data
; dq = 8 bytes storage (a pointer on x64) - UEFI will put the protocol pointer here
LoadedImageProtocol dq 0

; Result of protocol
SimpleFileSystemProtocol dq 0

; Result of protocol
RootDirectory dq 0

KernelFile dq 0

KernelPath:
    dw 'k','e','r','n','e','l','.','b','i','n',0

; kernel.bin file contents
KernelBuffer dq 0

; GUI is just a very large id number - unique identifies something.
LoadedImageGUID:
    dd 0x5B1B31A1
    dw 0x9562
    dw 0x11D2
    db 0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B

SimpleFileSystemGUID:
    dd 0x0964E5B2
    dw 0x6459
    dw 0x11D2
    db 0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B

FileInfoGUID:
    dd 0x09576E92
    dw 0x6D3F
    dw 0x11D2
    db 0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B

; All file info
FileInfoBuffer times 256 db 0
; File size info
FileInfoBufferSize dq 256
; kernel file size
KernelSize dq 0

boot_msg: dw 'B','O','O','T','L','O','A','D','E','R',' ','O','K',13,10,0

; Section text just means this section of assembly code will be loaded into the text section of memory.
; Code is loaded into memory and executed instructio by instruction to us its line by line but in memory its just a long list of data.
section .text

; Entry Point efi_main is what first runs when we run our executable program.
efi_main:

    ; ====== Store Important Data ======

    ; r13 = ImageHandle
    mov r13, rcx

    ; rbx = SystemTable
    mov rbx, rdx

    ; ====== STEP 00 - Get the boot service pointer - BootServices ======
    ; I need the boot services pointer to perform other steps

    ; r12 = SystemTable->BootServices
    mov r12, [rbx + 0x68]

    ; ====== STEP 01 - Find out which device my kernel.bin file is - HandleProtocol ======
    ; I can do this via the boot services pointer

   
    
    ; Function Call

    ; Loads HandleProtocol function pointer into rax
    mov rax, [r12 + 0x98]

    ; ARG 1 - ImageHandle
    mov rcx, r13
    ; ARG 2 - GUID
    lea rdx, [LoadedImageGUID]
    ; ARG 3 - Location to Store the result pointer
    lea r8, [LoadedImageProtocol]

    ; Add 32 bytes shadow space
    sub rsp, 32
    ; Calls HandleProtocol function
    call rax
    ; Remove 32 bytes shadow space
    add rsp, 32

    ; r14 = LoadedImageProtocol
    mov r14, [LoadedImageProtocol]

    ; r15 = DeviceHandle - This tells me what device I am on
    mov r15, [r14 + 0x18]

    ; ====== STEP 02 - Getting Access to the File System - Simple File System Protocol ======
    ; I have got the device but I cannot open any files yet.
    ; This protocol lets me:
    ; - open the root directory
    ; - open files
    ; - read files

     ; TEMP OUTPUT TEST
    ; Print BOOTLOADER OK
    mov rcx, [rbx + 64]        ; ConOut
    mov rax, [rcx + 8]        ; OutputString
    ; arg1 = ConOut (This)
    ; First argument = protocol pointer
    mov r10, rcx
    lea rdx, [boot_msg]          ; UTF-16 string

    sub rsp, 32
    call rax
    add rsp, 32

    ; rcx = DeviceInstance/DeviceHandle
    mov rcx, r15
    ; Load address of GUID
    lea rdx, [SimpleFileSystemGUID]
    ; Load address of result data variable
    lea r8, [SimpleFileSystemProtocol]

    ; Add 32 bytes of shadow space
    sub rsp, 32
    ; Call HandleProtocol Function
    call rax
    ; Remove 32 bytes shadow space
    add rsp, 32

    ; r14 = contents of SimpleFileSystemProtocol
    mov r14, [SimpleFileSystemProtocol]

    ; ====== STEP 03 - Give me the Root Directory - Open Volume ======

    ; rax = OpenVolume Function Pointer
    mov rax, [r14 + 0x08]
    ; ARG 1 = r14
    mov rcx, r14
    ; ARG 2 = Address of RootDirectory
    lea rdx, [RootDirectory]

    ; Add Shadow Space
    sub rsp, 32
    ; Call Function OpenVolume()
    call rax
    ; Remove Shadow Space
    add rsp, 32

    ; r14 = contents of RootDirectory
    mov r14, [RootDirectory]

    ; ====== STEP 04 - Open File ======

    ; Get Open() function pointer and store in rax
    mov rax, [r14 + 0x08]

    ; ARG 1 - rcx = r14 / RootDirectory
    mov rcx, r14
    ; ARG 2 - rdx = &KernelFile
    lea rdx, [KernelFile]
    ; ARG 3 - r8 = &KernelPath
    lea r8, [KernelPath]
    ; ARG 4 - r9 = 1 - 1 = Read Only Mode
    mov r9, 1

    ; Add Shadow Space
    sub rsp, 40
    ; ARG 5 - Attributes - passed through the stack
    mov qword [rsp + 32], 0
    ; Call open() function
    call rax
    ; Remove shadow spacing
    add rsp, 40

    ; Load the file protocol pointer (this is the opened kernel.bin handle)
    mov r14, [KernelFile]

    ; ====== STEP 05 - Get File Info ======

    ; Load the GetInfo function pointer into rax
    mov rax, [r14 + 0x40]
    ; GetInfo(This, &FileInfoGUID, &FileInfoBufferSize, &FileInfoBuffer)
    mov rcx, r14
    lea rdx, [FileInfoGUID]
    lea r8, [FileInfoBufferSize]
    lea r9, [FileInfoBuffer]

    ; Function Call Convention
    sub rsp, 32
    call rax
    add rsp, 32

    ; Loading kernel file size into rax
    mov rax, [FileInfoBuffer + 0x30]
    ; Storing the kernel file size in KernelSize
    mov [KernelSize], rax

    ; ====== STEP 06 - Allocate Memory for kernel.bin ======

    ; rax = AllocatePool Function Pointer
    mov rax, [r12 + 0x40]
    ; rcx = memory type (2 = loader data)
    mov rcx, 2
    ; rdx = size of kernel.bin
    mov rdx, [KernelSize]
    ; r8 = address where UEFI writes allocated pointer
    lea r8, [KernelBuffer]

    ; Function Calling Convention
    sub rsp, 32
    call rax
    add rsp, 32

    ; ====== STEP 07 - Read bytes from the file into memory ======

    ; load file handle again
    mov r14, [KernelFile]
    ; rax = Read function pointer
    mov rax, [r14 + 0x20]
    ; rcx = file handle
    mov rcx, r14
    ; rdx = address of kernel size
    lea rdx, [KernelSize]
    ; r8 = actual allocated memory pointer
    mov r8, [KernelBuffer]

    ; Function Calling Convetion
    sub rsp, 32
    call rax
    add rsp, 32

    

    ; ====== STEP 08 - Jump into the file and execute the code ======
    
    ; pass SystemTable to kernel in RDI TEMPORARY CODE
    mov rdi, rbx

    mov rax, [KernelBuffer]
    ; jmp rax

    ; rax is the 64 bit return value register in the x86_64 calling convention used by UEFI.
    ; UEFI expects your entry function to return an EFI_STATUS.
    ; EFI_SUCCESS is defined as 0
    ; xoring a value with its self always produces 0
    ; It is shorter/faster than mov rax, 0 on many CPUs and also avoids embedding and immediate constant.
    ; This line of code is the standard fastest way to set a register to 0
    ; This line of code basically says use rax as the return to UEFI register and return 0 which is success.
    ; But this line does not actually return it just puts success (0) in the rax register which is used by UEFI for return values.
    xor rax, rax
    ; returns from the current function to the caller.
    ; In this case the caller is UEFI firmware - specifically the UEFI loader that invoked your application entry.
    ; It uses the return address taht was pushed on the stack when UEFI called efi_main.
    ; Since rax is already 0, the firmware recieves EFI_SUCCESS
    ; using ret just says return which means it returns the value in rax to the caller which is UEFI firmware loader.
    ret

; .hang:
;     jmp .hang
    
