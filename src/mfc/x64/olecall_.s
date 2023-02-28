; This is a part of the Microsoft Foundation Classes C++ library.
; Copyright (C) Microsoft Corporation
; All rights reserved.
;
; This source code is only intended as a supplement to the
; Microsoft Foundation Classes Reference and related
; electronic documentation provided with the library.
; See these sources for detailed information regarding the
; Microsoft Foundation Classes product.

PUBLIC	_AfxDispatchCall

_TEXT	SEGMENT

;_AfxDispatchCall(AFX_PMSG /*pfn*/, void* /*pArgs*/, UINT /*nSizeArgs*/)

#ifdef _M_ARM64EC
_AfxDispatchCall PROC FRAME
#else
_AfxDispatchCall PROC
#endif

	; at this point RCX contains value of pfn, RDX contains value of pArgs 
	; and R8 contains value of nSizeArgs.
	
#ifdef _M_ARM64EC
	; Assume that on arm64EC, that pArgs/RDX will not be in the current frame, so we can't
	; manipulate the stack to set up our tail call.  It would be invalid to reinterpret pArgs
	; to be a stack, because the caller isn't done with the stack.
	; So, we have to make a new frame and copy stack data to it.

	; Save RBP and use it as the new frame pointer
	push rbp
	.pushreg rbp
	mov rbp, rsp
	.setframe rbp, 0h
	.endprolog

	; do not move the stack pointer back to RDX, because pArgs is at a location behind a thunk.
	; instead, push everything between (pArgs + nSizeArgs) and pArgs to be on top of the stack.

	; check if the stack needs shadow space.
	; RAX will hold the required shadow space.
	; at least 0x20 of space must be provided to the callee.
	mov rax, 20h
	sub rax, r8
	jge CopyStackExtraSpace

	; check if the stack will be aligned after pushing nSizeArgs of data, but not the return address.
	; alignment is guaranteed if shadow space was needed in the above check.
	mov rax, r8
	add rax, rsp
	and rax, 8h

	; if so, 0 bytes of shadow space is needed to ensure eventual 16-byte unalignment
	; (the return address unaligns it inside the CALL, and unalignment should be the final result)
	; if not, 8 bytes of shadow space is needed to ensure eventual 16-byte unalignment
	; either way, RAX now has the correct amount of space stored in it.

CopyStackExtraSpace:
	sub rsp, rax

	; nSizeArgs (R8) isn't used for anything else now, so repurpose it as a counter
	add r8, rdx

	; adjust to point at the last argument, not past it
	sub r8, 8h

CopyStackLoop:
	; copy the start of the caller's stack, up to RDX

	; check how much we have pushed
	cmp r8, rdx

	; exit if if we have pushed everything up to and including RDX
	jb CopyStackEnd

	; if not, push next element
	push qword ptr [r8]

	; increment and continue loop
	sub r8, 8h
	jmp CopyStackLoop

CopyStackEnd:
#else
	; get the return address
	mov rax, qword ptr [rsp]

	; save the return address
	mov qword ptr [rdx-8], rax

	; set the new stack pointer
	lea rsp, qword ptr [rdx-8]
#endif

	; save the pfn
	mov rax, rcx

	; set the first four float/double arguments
	movsd xmm0, qword ptr [rdx]
	movsd xmm1, qword ptr [rdx+8]
	movsd xmm2, qword ptr [rdx+16]
	movsd xmm3, qword ptr [rdx+24]

	; set the first four integer arguments [except for RDX]
	mov rcx, qword ptr [rdx]
	mov r8,  qword ptr [rdx+16]
	mov r9,  qword ptr [rdx+24]

#ifdef _M_ARM64EC
CallFunction:
	; Finally load up RDX and call the function
	mov rdx, qword ptr [rdx+8]
	call rax

	; discard the current frame
	mov rsp, rbp
	pop rbp

	; above CALL does return
	ret
#else

	; Or, finally load up RDX and jump to the function
	mov rdx, qword ptr [rdx+8]
	jmp rax

	; above JMP does not return
	; ret
#endif

_AfxDispatchCall ENDP

_TEXT	ENDS

END
