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

; dw = define word (16 bit values)
; 'H' and 'i' become 16 bit character codes
; 13,10 = CR LF (new line in UEFI console)
; 0 = UTF-16 terminator
msg: dw 'H', 'i', " ", "T", "h", "e", "r", "e", 13, 10, 0

; Section text just means this section of assembly code will be loaded into the text section of memory.
; Code is loaded into memory and executed instructio by instruction to us its line by line but in memory its just a long list of data.
section .text

; Entry Point efi_main is what first runs when we run our executable program.
efi_main:
    ; Stores the old rbx on the stack
    push rbx
    ; Obtain console output interface so we can call OutputString.
    ; rdx = pointer to EFI_SYSTEM_TABLE.
    ; +64 bytes = the ConOut field inside that struct (on x64) - basically the offset to where the ConOut is located.
    ; tbx becomes SystemTable->ConOut - a pointer to the console output protocol.
    mov rbx, [rdx + 64]

    ; rbx currently points to the EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL object (ConOut).
    ; The first field in that object is a function pointer called reset.
    ; The second field is OutputString.
    ; So OutputString is at offset +8 from the start of the protocol struct (8 byte pointers on x64)
    mov rax, [rbx + 8]

    ; arg1 = ConOut (This)
    ; First argument = protocol pointer
    mov rcx, rbx
    ; arg2 = &msg (char16*)
    ; Loafs the address of message (not the contents)
    lea rdx, [msg]
    ; Rserve 32 bytes (required by UEFI x64 calling convention)
    sub rsp, 32
    ; OutputString(ConOut, msg)
    ; Calls the function pointer
    call rax
    ; Restore stack
    add rsp, 32

    ; rax is the 64 bit return value register in the x86_64 calling convention used by UEFI.
    ; UEFI expects your entry function to return an EFI_STATUS.
    ; EFI_SUCCESS is defined as 0
    ; xoring a value with its self always produces 0
    ; It is shorter/faster than mov rax, 0 on many CPUs and also avoids embedding and immediate constant.
    ; This line of code is the standard fastest way to set a register to 0
    ; This line of code basically says use rax as the return to UEFI register and return 0 which is success.
    ; But this line does not actually return it just puts success (0) in the rax register which is used by UEFI for return values.
    ; xor rax, rax
    ; Restore the original rbx value
    ; pop rbx
    ; returns from the current function to the caller.
    ; In this case the caller is UEFI firmware - specifically the UEFI loader that invoked your application entry.
    ; It uses the return address taht was pushed on the stack when UEFI called efi_main.
    ; Since rax is already 0, the firmware recieves EFI_SUCCESS
    ; using ret just says return which means it returns the value in rax to the caller which is UEFI firmware loader.
    ; ret

.hang:
    jmp .hang
    
