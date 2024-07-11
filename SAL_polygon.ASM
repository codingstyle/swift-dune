_sub_13BE9_SAL_polygon proc near
  mov	ds:word_21789, offset RESOURCE_GLOBDATA
  push	ds
  pop	es
  mov	al, [si-2]
  mov	ds:byte_23C9D, al
  mov	al, [si-1]
  mov	ds:byte_23C9C, al
  lodsb			; Load String
  cbw			; AL ->	AX (with sign)
  shl	ax, 1		; Shift	Logical	Left
  shl	ax, 1		; Shift	Logical	Left
  shl	ax, 1		; Shift	Logical	Left
  shl	ax, 1		; Shift	Logical	Left
  mov	ds:word_2178B, ax
  lodsb			; Load String
  cbw			; AL ->	AX (with sign)
  shl	ax, 1		; Shift	Logical	Left
  shl	ax, 1		; Shift	Logical	Left
  shl	ax, 1		; Shift	Logical	Left
  shl	ax, 1		; Shift	Logical	Left
  mov	ds:word_2178D, ax
  lodsw			; Load String
  mov	dx, ax
  lodsw			; Load String
  mov	bx, ax
  mov	ds:word_23C9E, dx
  mov	ds:word_23CA0, bx


loc_13C25:		; Load String
  lodsw
  push	ax
  and	ax, 3FFFh	; Logical AND
  mov	di, ax
  lodsw			; Load String
  mov	cx, ax
  call	sub_13E13	; Call Procedure

  mov	dx, di
  mov	bx, cx
  pop	ax
  test	ax, 4000h	; Logical Compare
  jz	short loc_13C25	; Jump if Zero (ZF=1)

  mov	ds:word_23CA2, di
  mov	ds:word_23CA4, cx
  mov	dx, ds:word_23C9E
  mov	bx, ds:word_23CA0
  mov	ds:word_21789, offset unk_24112
  test	ax, 8000h	; Logical Compare
  jnz	short loc_13C71	; Jump if Not Zero (ZF=0)


loc_13C57:		; Load String
  lodsw
  push	ax
  and	ax, 3FFFh	; Logical AND
  mov	di, ax
  lodsw			; Load String
  mov	cx, ax
  call	sub_13E13	; Call Procedure

  mov	dx, di
  mov	bx, cx
  pop	ax
  or	ax, ax		; Logical Inclusive OR
  jns	short loc_13C57	; Jump if Not Sign (SF=0)

  mov	dx, di
  mov	bx, cx


loc_13C71:
  mov	di, ds:word_23CA2
  mov	cx, ds:word_23CA4
  call	sub_13E13	; Call Procedure

  mov	es, ds:_word_2D08A_framebuffer_active
  push	si
  mov	bx, ds:word_23CA0
  mov	bp, ds:word_23CA4
  sub	bp, bx		; Integer Subtraction
  lea	si, RESOURCE_GLOBDATA ;	Load Effective Address
  mov	cx, bp
  mov	bp, 0
  mov	ah, ds:byte_23C9C
  and	ah, 3Eh		; Logical AND
  jz	short loc_13CA0	; Jump if Zero (ZF=1)

  mov	bp, 1


loc_13CA0:
  mov	al, 2
  mov	ds:word_2178F, ax
  mov	ah, ds:byte_23C9D
  xor	al, al		; Logical Exclusive OR
  test	ds:byte_23C9C, 1 ; Logical Compare
  jnz	short loc_13CE0	; Jump if Not Zero (ZF=0)


loc_13CB2:
  push	cx
  push	ax
  lodsw			; Load String
  mov	dx, ax
  lodsw			; Load String
  mov	cx, ax
  pop	ax

  loc_13CBB:		; Compare Two Operands
  cmp	dx, cx
  jb	short loc_13CC1	; Jump if Below	(CF=1)

  xchg	dx, cx		; Exchange Register/Memory with	Register


loc_13CC1:		; Increment by 1
  inc	cx
  sub	cx, dx		; Integer Subtraction
  jz	short loc_13CD6	; Jump if Zero (ZF=1)

  push	si
  push	bx
  mov	si, ds:word_2178F
  mov	di, ds:word_2178B
  call	ds:_ptr_22D65_gfx_vtable_func_36 ; Indirect Call Far Procedure
  pop	bx
  pop	si


loc_13CD6:		; Add
  add	ax, ds:word_2178D
  inc	bx		; Increment by 1
  pop	cx
  loop	loc_13CB2	; Loop while CX	!= 0

  pop	si
  retn			; Return Near from Procedure

; ���������������������������������������������������������������������������

loc_13CE0:
  push	cx
  push	ax
  lodsw			; Load String
  mov	dx, ax
  lodsw			; Load String
  mov	cx, ax
  pop	ax
  cmp	dx, cx		; Compare Two Operands
  jnb	short loc_13CEF	; Jump if Not Below (CF=0)

  xchg	dx, cx		; Exchange Register/Memory with	Register


loc_13CEF:		; Decrement by 1
  dec	cx
  sub	cx, dx		; Integer Subtraction
  jz	short loc_13D08	; Jump if Zero (ZF=1)

  neg	cx		; Two's Complement Negation
  push	si
  push	bx
  mov	si, ds:word_2178F
  mov	di, ds:word_2178B
  std			; Set Direction	Flag
  call	ds:_ptr_22D65_gfx_vtable_func_36 ; Indirect Call Far Procedure
  pop	bx
  pop	si
  cld			; Clear	Direction Flag


loc_13D08:		; Add
  add	ax, ds:word_2178D
  inc	bx		; Increment by 1
  pop	cx
  loop	loc_13CE0	; Loop while CX	!= 0

  pop	si
  retn			; Return Near from Procedure

_sub_13BE9_SAL_polygon endp