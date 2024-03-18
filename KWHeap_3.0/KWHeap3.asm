;*********************************************************************
;*** *** *** ***                                       *** *** *** ***
;*** *** *** ***             KWHeap v3.0.1             *** *** *** ***
;*** *** *** ***                                       *** *** *** ***
;*********************************************************************

;*******   ���� �� ������ ���������� ������,
;*******   ������ ���� - ����������� ���������������,
;*******   ���������� �������, � ������������ - ����.
;*******   � ������ 3.0.1 ������� ����������� �������������
;*******   ����� ���������� ���������� ��� ������������.


;***********     �������� �������     ***********
; CreateHeap   +
; MemAlloc
; MemReAlloc   +
; MemFree      +
; MemPut       +
; GetSize ?

; ���� ������:
;   ��������� ������ �����:
Size = 0 ;  (dword)  addr+0   ������ ������ � ���� ���������
Next = 4 ;  (dword)  addr+4   ����� ���������� ����� � �����
Prev = 8 ;  (dword)  addr+8   ����� ����������� ����� � �����
;   ������ �����:
;   data   ...       addr+12
INFOSIZE = 12

; ��������� ----------------------------------------------------------
HEAPSIZE0    = 4 * 1024 ; ��������� ������ ����                      |
HEAPSIZESTEP = 4 * 1024 ; ����������� ��� ���������� ������� ����    |
BLOCKBRICK = 4 ; ������ � ������ ��������� ������ ����� ������,      |
	       ; ����������� �����, ������ 4 �� ���,                 |
	       ; ����� �������� ������ 4, 8, 12, 16...               |
MINBLOCKSIZE = INFOSIZE + (2 * BLOCKBRICK) ; ������ ����� �����      |
;---------------------------------------------------------------------

BLOCKISBUSY  = 1 ; bit0 = 1     � Size
BLOCKISFREE  = 0 ;              � Size
FIRSTINAREA  = 1 ; bit0 = 1     � Prev    ������ ���� � �������
LASTINAREA   = 1 ; bit0 = 1     � Next    ��������� ���� � �������
; Prev = NULL - ��������� ���� � ����
; Next = NULL - ��������� ���� � ����

; ���� = ����
; .Size, .Next, .Prev, this.Size, this.Next, this.Prev � ��������� -
;  - �������� ��������������� ��������� ������ � ������� �����


;---------------------------------------------------------------------
; void * CreateHeap (int size)
; C������ ���� �������� size
; ������������ ����� ������/����������/����� ���������� �����
; ok: eax=address, CF=0
; error: eax=0, CF=1

proc CreateHeap size
	; ��� size==0 ���� ������ �� ���������
	mov ecx,HEAPSIZE0
	mov eax,[size]
	or  eax,eax
	; � ��������o �6 (Pentium Pro � Pentium II) ��������a cmovcc:)
	cmovz eax,ecx

	; ��������� �� ������� �������� (4�)                       ����������!!!
	dec eax
	or  eax,0FFFh
	inc eax
	mov [size],eax

	stdcall CreateArea, eax
	    jc .error

	; eax - ������ ���������� ������
	;-------------------------------------------------------------
	; ������ ��������� ���� �� ��� �������
	; �� � ������ � ��������� � ���� (Prev=Next=NULL, ��� ������)
	; �� � ������ � ��������� � �������
	mov ecx,[size]
	sub ecx,INFOSIZE
	mov [eax + Size],ecx ; BLOCKISFREE
	mov [eax + Next],dword LASTINAREA
	mov [eax + Prev],dword FIRSTINAREA
	add eax,INFOSIZE
	; eax - ����� ����, ��������� ����
  .error:
	ret
endp

;---------------------------------------------------------------------
; void * CreateArea (int size)  stdcall  <��� ����������� �����������>
; �������� �� ������� ����� ������ �������� � size
; �-��� �� ��������� size �� ������� ��������)
; �������� size ������ ������ � �����
; ��� size=0 - ������
; �-��� ����������:
;  eax - ����� ������� (eax=0 - ������)
;  CF=0 - ��� ������, CF=1 - ������

CreateArea:
	; ��� size = 0:
	;  Windows - ������ ������������� �� ������� ��������
	;  Colibri - ����� �����, �� �������� �� �����������.
	;            � ��� ������ � ������ - page fault.
	;     ���� �����: {--��� ���� � ��������� "cpu" ������
	;                  --������� ���������� �������}
	; ebp �����������

      ;  ; ��������� size �� 4 �� � ������� ������� (size=0...)
      ;  mov eax,[esp+4] ; size
      ;  sub eax,1
      ;  adc eax,0 ; ���� size = 0, �� �������, ��� = 1
      ;  or  eax,1024*4 - 1
      ;  inc eax
      ;  mov [esp+4],eax

	or  eax,eax
	jz  .error

	; �������� ������
	if OS eq WINDOWS
	  invoke VirtualAlloc, NULL, eax, MEM_COMMIT, PAGE_READWRITE
	else if OS eq KOLIBRI
	  mov eax,68 ; SF_SYS_MISC    44h
	  mov ebx,11 ; SSF_HEAP_INIT  0Bh
	  int 40h
	    or eax,eax
	    jz .error
	  mov eax,18 ; SF_SYSTEM (18)
	  mov ebx,16 ; SSF_GET_FREE_RAM (16)
	  int 40h

	  mov eax,68 ; SF_SYS_MISC
	  mov ebx,12 ; SSF_MEM_ALLOC
	  mov ecx,[esp+4]
	  int 40h
	  ; � ����������� KOS � �������� ������ �� �������...
	  ; ��������� �� ������ ��������� ������ ������� - ����� ������
	end if
	or eax,eax ; �������� �� ������ ��������� ������
	jz .error

	; eax = ����� �������
	clc ; ��� ������
	retn 1 * 4

  .error:
	; eax = 0
	stc ; ������
	retn 1 * 4 ; stdcall


;---------------------------------------------------------------------
; ���������� (��������, �������) ���� ������ � ����
; void * MemAlloc (void * hheap, int size)
; {
;   � ��������, � �������� hheap ����� ���������� ����� ������ ���������
;   ����� � ������ ����. ����� ���������� ������������ �����
;   ������������� �� ����� ����� �� ����� ����.
; }

proc MemAlloc uses ebx,  hheap, size

	; �������� size �� BLOCKBRICK
	mov ecx,[size]
	dec ecx
	or  ecx,BLOCKBRICK-1
	inc ecx ; ZF = ?
	mov [size],ecx

	; ��������� �������� size �� 0, ������, �� -BLOCKBRICK �� 0
	jz .err

; ���� newsize = 0..MINBLOCKSIZE-1 - �� ������������� � MINBLOCKSIZE ��� error?

	mov eax,[hheap]  ; ����� ������ ���������� ����� (������ �����;))
	sub eax,INFOSIZE
    .mainloop:
	; eax - ����� �������� �����, this
	; [eax+Size] = .Size � ���� ���������
	; ecx = ���������� [size]
	test [eax+Size],dword BLOCKISBUSY ; bit 0 = 1 ?
	jz  .foundfreeblock   ; ���, �� �����

	; ���� �����, ��������� � ����������
	; ��� ��� �� ������� FIRATINAREA � LASTINAREA               ??
    .gonext:
	mov edx,eax   ; ��������� ���������� this
	mov eax,[eax+Next] ; this = .Next
	mov edx,eax   ; ��������� ����������
	or  eax,eax   ; NULL-�����?
	jnz .mainloop ; �� ����, ���� ��� �����

	; ������� ��������� ����, ���� ������� ����� �������       TO DO
	; ��� ������ - [size] ��� HEAPSIZESTEP ?
	
	
      ;  ...
	push edx ; ��������� ���������� this
	stdcall CreateArea, ? 
	pop  edx
	  jc .err ; CF=1, eax=0
	mov [edx + Next],eax ;
	or  [edx + Next],dword BLOCKISLAST
	; ..........


	ud2							   ; TO DO

    .foundfreeblock:
	; ��� - ����� �����
	; ecx = [size] - ���������� ������ ������ ����������� ��������
	; ������� ������� ������ ������� � ���������� ������
	; ������� ���� ��������� ������� (���� ����)
	mov edx,[eax] ; .Size
	sub edx,ecx ; edx = .Size - size
	jc .gonext  ; .Size < size, �� ������!

	; ���� ��������. ������ �������
	or [eax],dword BLOCKISBUSY

	; edx - �������
	; ����� �� ������� ������� ���. ����?
	cmp edx,MINBLOCKSIZE
	jc .toosmall ; ������� ������� ���

      ; ������� ������� ��� �������� ��������������� �����
	; ������ ��� �����. ������� ������� (this) � ���. ���������
	mov [eax],dword ecx ; this.Size = size
	or  [eax],dword BLOCKISBUSY

	lea ebx,[eax+ecx+INFOSIZE]
	sub edx,INFOSIZE ; ��������. ������ ��� ������ (���.)
	mov [ebx],edx	; ���.Size = edx  not busy
	mov ecx,[eax+4] ;  this.Next
	mov [ebx+4],ecx ; ���.Next = this.Next
	mov [ebx+8],eax ; ���.Prev = this

	mov [eax+4],ebx ; this.Next = ���.
			; this.Prev �������
    .toosmall:
	; �� ������� �� ������� ����� ����
	; ������� �������� ������ ������ ��� ���������
	; �������������������
	add eax,INFOSIZE
	; CF = 0 (��� �� ��� ���� ������, �� eax �� ������� �������)
	ret

    .err:
	xor eax,eax
	stc
	ret
endp



;---------------------------------------------------------------------
; void * MemReAlloc (void * addr, int newsize)

proc MemReAlloc uses esi edi,  addr, newsize
      ; ������� ������� ���������� �������
	; �������� newsize �� BLOCKBRICK
	mov ecx,[newsize]
	dec ecx
	or  ecx,BLOCKBRICK-1
	inc ecx ; ZF = ?
	mov [newsize],ecx

	; ��������� �������� size �� 0, ������, �� -BLOCKBRICK �� 0
	jz .error

; ��� �������� ...
; ���� newsize = 0..MINBLOCKSIZE-1 - �� ������������� � MINBLOCKSIZE ��� error?

	mov eax,[addr]	 ; ����� ������
	sub eax,INFOSIZE ; ����� �����
	mov edx,[eax + Size] ; ������ ������
	sub edx,ecx ; [.Size] - [newsize]
	jz  .equ    ; ������ �� ��������
	jnc .reduce ; ������ ������ ������

      ; ������ ������ ������. �����������
	; ������� ����� ���� ����� ������� ���� (� ������� ������).
	;  ���� ��� �������� hHeap, ��� invoke FindHead, [addr]     ??
	stdcall MemAlloc, eax, ecx ; ���.�����, [newsize]
	jc .error
	mov esi,[addr] ; ����� ������ (������)
	mov edi,eax    ; ����� ��� ������ � ����� ���� (����)
	mov ecx,[esi-INFOSIZE + Size] ; .Size & flag
	and ecx,not BLOCKISBUSY
	movsb
	push eax
	stdcall MemFree, [addr]
	pop eax ; new addr
	clc	; no error
	ret
						; ����� LASTINAREA ...???
      ; ����� ������. ���������
  .reduce:
	; ����� �� � �������������� ����� ����� ����?
	; eax = ���.����� ��������
	; ecx = [newsize] ����� ������ ������
	; edx = ������� �������� (��������� �������������)
	cmp edx,MINBLOCKSIZE
	jc  .equ ; �� �����. ������ �� ������
      ; �������� ������
	mov [eax + Size],ecx ; this.Size = newsize
	or  [eax + Size],BLOCKISBUSY ; + ����
      ; ������� ���� �� ��������������� �����
	lea ecx,[eax+INFOSIZE + ecx] ; ����� ������ ����� newblock
	mov esi,[eax + Next]
	mov [ecx + Next],esi ; newblock.Next = this.Next
	mov [eax + Next],ecx ; this.Next = newblock
	mov [ecx + Prev],eax ; newblock.Prev = this
	or  edx,BLOCKISBUSY
	mov [ecx + Size],edx ; newblock.Size = ������� �������� + ����
      ; ������� ����������� ���� ���� �� ������ �� ���������,
      ; ���� ��� ��������
	invoke MemFree, ecx

  .equ:
	mov eax,[addr] ; ������� ������� ����
	clc ; no error
	ret

  .error:
	xor eax,eax
	stc
	ret
endp



;---------------------------------------------------------------------
; void MemFree (void * addr)
; ����������� ���� ������,
; addr - ����� ������ ����� ������, ���������� �� MemAlloc � ��������

proc MemFree addr

	sub [addr + Size],INFOSIZE ; this
	; ������� ���� ��������� �����
	mov eax,[addr + Size]
	and [eax + Size],dword not BLOCKISBUSY

	; ��������� Next - ��������� � �������?
	mov edx,[eax + Next]
	test edx,LASTINAREA
	jnz  @f ; ����.� ���.
	; ��������� ���� �����?
	; (� edx bit0=0 �����)
	test [edx],byte BLOCKISBUSY ; Next.Size bit0 = ?
	jnz  @f ; �����
	;stdcall MergeBlocks, eax, edx
	;----------------------------------------------- �����������
	mov ecx,[edx + Size] ; + Size == 0 � �� �������� ���
	add [eax + Size],ecx ; ������� �������
	mov ecx,[edx + Next]
	mov [eax + Next],ecx ; ����������� ������ �� ���������
	;-----------------------------------------------
    @@:
	; ��������� Prev - ������ � �������?
	mov eax,[addr]
	mov edx,[eax + Prev]
	test edx,FIRSTINAREA
	jnz  @f ; ����.� ���.
	; ���������� ���� �����?
	; (� edx bit0=0 �����)
	test [edx],byte BLOCKISBUSY ; Prev.Size bit0 = ?
	jnz  @f ; �����
	;stdcall MergeBlocks, edx, eax
	;----------------------------------------------- �����������
	mov ecx,[eax + Size] ; + Size == 0 � �� �������� ���
	add [edx + Size],ecx ; ������� �������
	mov ecx,[eax + Next]
	mov [edx + Next],ecx ; ����������� ������ �� ���������
	;-----------------------------------------------
    @@:
	ret
endp


;---------------------------------------------------------------------
; void * MemPut (void * hheap, void * addr, int size);
; ok: CF=0, eax=����� ������
; error: CF=1, eax=0

proc MemPut uses esi edi, hheap, addr, size
	; ? ��������� size �� �������� ?
	stdcall MemAlloc, [hheap], [size]
	  jc .nomem
	push eax
	mov edi,eax
	mov esi,[addr]
	mov ecx,[size]
	add ecx,INFOSIZE
	; �������� ��O, ����� ���
	shr ecx,2 ; ZF ������� �� ����������
	rep movsd ; ��� ecx = 0 �� ���������� �� ����
	clc	  ; CF flag are cleared
	pop eax   ; eax=addr
   .nomem:
	ret
endp
;---------------------------------------------------------------------
; ��������� �� ������ ��������� ������ �������
;         mov eax,68 ; SF_SYS_MISC
;         mov ebx,12 ; SSF_MEM_ALLOC
;         mov ecx,[size]
;         int 40h
;
; ��� size = 0 - ������ �������.
; �� ���������, ����� ������ ���������� ������ � �������.
; ������������ ������ ����������� ������ (0...2��-1)
; ���� ����������� ������� �� ������� - ���������� 0.
; ��� ������, ������� �� ���������� ������ ��� ������ ����.�������� ������� -
;  - ����������� ������ �� ����� ��� ���������� ��������� � ���������������� �.
; ���� � ��������� ������ �� �������� ��������, ��� ��������� ��������� �
;  �� ��������� ����������. ���������������� ���� ������ ��������.
; ������ ��������� ���. ������:
;         mov eax,18 ; SF_SYSTEM (18)
;         mov ebx,16 ; SSF_GET_FREE_RAM (16)
;
; ������ ���. ������:
;         mov eax,18 ; SF_SYSTEM (18)
;         mov ebx,17 ; SSF_GET_TOTAL_RAM (17)
;

;---------------------------------------------------------------------