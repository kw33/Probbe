;*********************************************************************
;*** *** *** ***                                       *** *** *** ***
;*** *** *** ***             KWHeap v3.0               *** *** *** ***
;*** *** *** ***                                       *** *** *** ***
;*********************************************************************

;*******   ���� �� ������ ���������� ������,
;*******   ������ ���� - ����������� ���������������


;***********     �������� �������     ***********
; CreateHeap
; MemAlloc
; MemReAlloc
; MemFree

; ���� ������:
;   ��������� ������ �����:
;   .Size  (dword)  addr+0   ������ ������ � ���� ���������
;   .Next  (dword)  addr+4
;   .Prev  (dword)  addr+8
;   ������ �����:
;   data   ...      addr+12
INFOSIZE = 12

; ��������� ----------------------------------------------------------
HEAPSIZE0    = 4 * 1024 ; ��������� ������ ����                      |
HEAPSIZESTEP = 4 * 1024 ; ����������� ��� ���������� ������� ����    |
BLOCKBRICK = 4 ; ������ ��������� ������ ����� ������,               |
	       ; ����������� �����,                                  |
	       ; ����� ������� ������: 4, 8, 16, 32...               |
MINBLOCKSIZE = INFOSIZE + 2 * BLOCKBRICK ;                           |
;---------------------------------------------------------------------

BLOCKISBUSY = 80000000h ; bit31=1
BLOCKISFREE = 0
BLOCKISFIRST = 0
BLOCKISLAST  = 0


;---------------------------------------------------------------------
; hheap CreateHeap (int size)
; C������ ���� �������� size

proc CreateHeap size
	; ��� size==0 ���� ������ �� ���������
	mov ecx,HEAPSIZE0
	mov eax,[size]
	or  eax,eax
	; � ��������o �6 (Pentium Pro � Pentium II) ��������a cmovcc:)
	cmovz eax,ecx

	; ��������� �� ������� �������� (4�)
	dec eax
	or  eax,0FFFh
	inc eax
	mov [size],eax

	stdcall CreateArea, eax
	    jc .error

	; eax - ������ ���������� ������
	;-----------------------------------------------------------
	; ������ ��������� ���� �� ��� �������
	mov ecx,[size]
	sub ecx,INFOSIZE
	mov [eax],ecx ; .Size BLOCKISFREE
	mov [eax+4],dword BLOCKISLAST ; .Next
	mov [eax+8],dword BLOCKISFIRST; .Prev

	; eax - ����� ����
	; CF = 0
	ret

  .error:
	ud2 ;                                             ? ? ? TO DO
endp

;---------------------------------------------------------------------
; void * CreateArea (int size)  stdcall  <��� ����������� �����������>
; �������� �� ������� ����� ������ �������� � size
; (�-��� ��������� size �� ������� ��������)
; �������� size ������ ������ � �����
; �-��� ����������:
;  eax - ����� ������� (eax=0 - ������)
;  CF=0 - ��� ������, CF=1 - ������

CreateArea:
	; ��� size = 0:
	;  Windows - ������ ������������� �� ������� ��������
	;  Colibri - ������ ������

	; ��������� size �� 4 �� � ������� ������� (size=0...)
	mov eax,[esp+4] ; size
	sub eax,1
	adc eax,0 ; ���� size = 0, �� �������, ��� = 1
	or  eax,1024*4 - 1
	inc eax
	mov [esp+4],eax

	; �������� ������
	if OS eq WINDOWS
	  invoke VirtualAlloc, NULL, eax, MEM_COMMIT, PAGE_READWRITE
	else if OS eq KOLIBRI
	  mov eax,68 ; SF_SYS_MISC
	  mov ebx,11 ; SSF_HEAP_INIT
	  int 40h
	  or eax,eax
	  jz .error
	  mov eax,68 ; SF_SYS_MISC
	  mov ebx,12 ; SSF_MEM_ALLOC
	  mov ecx,[esp+4]
	  int 40h
	  ; � ����������� KOS � �������� ������ �� �������...
	end if
	or eax,eax ; �������� �� ������ ��������� ������
	jz .error

	; eax = ����� �������
	clc ; ��� ������
	retn 1 * 4

  .error:
	; eax = 0
	stc ; ������
	retn 1 * 4


;---------------------------------------------------------------------
; ���������� (��������, �������) ���� ������ � ����
; void * MemAlloc (int size)

proc MemAlloc uses ebx,  size

	; �������� size �� BLOCKBRICK
	mov ecx,[size]
	dec ecx
	or  ecx,BLOCKBRICK-1
	inc ecx
	mov [size],ecx

	mov eax,[hHeap] ; ����� ���������� �����
    .mainloop:
	; eax - ����� �������� �����, this
	; [eax] = .Size � ���� ���������
	test [eax],dword BLOCKISBUSY ; bit 31 = 1 ?
	jz  .foundfreeblock   ; ���, �� �����

	; ���� �����, ��������� � ����������
    .gonext:
	mov eax,[eax+4] ; this = .Next
	or  eax,eax   ; NULL-�����?
	jnz .mainloop ; �� ����, ���� ��� �����
	; ������� ��������� ����, ���� ������� ����� �������     TO DO
	; . . .
	ud2

    .foundfreeblock:
	; ��� - ����� �����
	; ecx = [size] - ������ ������ ����������� ��������
	; ������� ������� ������ ������� � ���������� ������
	; ������� ���� ��������� ������� (���� ����)
	mov edx,[eax] ; .Size
	sub edx,ecx ; edx = .Size - size
	jc .gonext  ; .Size < size, �� ������!

	; ���� ��������. ������ �������
	or [eax],dword BLOCKISBUSY

	; edx - �������
	; ����� �� ������� ������� ���. ����?
	cmp edx,MINBLOCKSIZE + INFOSIZE
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
	; CF = 0
	ret

endp



;---------------------------------------------------------------------
; void * MemReAlloc (void * addr, int newsize)

proc MemReAlloc uses esi edi, addr, newsize

	mov eax,[addr]
	mov ecx,[eax] ; ������ ������
	cmp ecx,[newsize]
	jnc .reduce ; ������ �� ������ ������
	; ������ ������ ������. �����������
	stdcall MemAlloc, [addr], [newsize]
	jc .error
	mov esi,[addr]
	mov edi,eax
	mov ecx,[esi] ; .Size + flag
	and ecx,not BLOCKISBUSY
	movsb
	push eax
	stdcall MemFree, [addr]
	pop eax ; new addr
	clc ; no error
	ret

	; ����� ������ ��� �����. ���������
  .reduce:
	;                                                     ;  TO DO
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
; addr - ����� ������ ����� ������, ���������� �� MemAlloc

proc MemFree addr

	sub [addr],INFOSIZE
	; ������� ���� ��������� �����
	mov eax,[addr]
	and [eax],dword not BLOCKISBUSY

	;mov eax,[addr]  ; this
	mov edx,[eax+4] ; .Next
	stdcall MergeBlocks, eax, edx

	mov eax,[addr]	; this
	mov edx,[eax+8] ; .Prev
	stdcall MergeBlocks, eax, edx
	ret
endp

;---------------------------------------------------------------------
; void MergeBlocks addr1, addr2  <��� ����������� �����������>
; ��������� ����������� ���� ������
; (addr.. - ������ ������, � �� ������)
; ���������������, ��� addr1 �������� (this � MemFree)

proc MergeBlocks addr1, addr2

	mov eax,[addr1]
	or  eax,eax ; NULL ?
	jz  .exit
	mov eax,[addr2]
	or  eax,eax ; NULL ?
	jz  .exit

	; ������� ���������, ��� ���� addr2 �� �����
	mov  eax,[addr2]
	test dword[eax],BLOCKISBUSY ; .Size � ����
	jnz  .exit ; ���� �����
	; ���� addr1 ������, �� ���������� addr1 � addr2
	mov eax,[addr1]
	cmp eax,[addr2]
	jc  @F
	xchg eax,[addr2]
	mov  [addr1],eax
    @@:
	; ���������, ��� ������ ���� ����� � �������
	mov eax,[addr1]
	mov ecx,[eax] ; .Size, ��������
	lea edx,[eax+ecx+INFOSIZE] ; ����� �� ������ ������
	cmp edx,[addr2] ; ������ ���� ���� � ����
	jne .exit ; �� �����
	;------ �������� ���������

	mov edx,[addr2]
	mov edx,[edx]	; addr2.Size
	lea ecx,[ecx+edx+INFOSIZE] ; addr1.Size + addr2.Size + INFO..
	mov [eax],ecx		   ; addr1.Size

	mov edx,[addr2]
	mov edx,[edx+4] ; addr2.Next
	mov [eax+4],edx ; addr1.Next

    .exit:
	ret
endp

;---------------------------------------------------------------------
;---------------------------------------------------------------------
;---------------------------------------------------------------------