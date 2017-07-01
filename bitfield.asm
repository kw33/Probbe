

; ������� ���� ��� ������������ - ������ ����, ��������
; ������ �������� ���� ������ dword (4 ����)
; �����-�� ������ ������ ��� �������� ���� ������ 4 * 8 * 2^BITGRAN

; ������������ ������� ����� ������� ������
; ���� �������� � ����:
; 8 7 6 5 4 3 2 1 0 .15 14 13 12 11 10 9 .23 22 21..

; ����� ������� = ����� ���� * ����� ����� � ����
; ����� = ����� ������� * BITGRAN

; �������������-
; ������ ��� ������������� �������:
; BITGRAN = 0; 1 ����                   0
; BITGRAN = 1; 2 ����                   1
  BITGRAN = 2; 4 ���� (dword)          11
; BITGRAN = 3; 8 ���� (qword) � �.�.  111
; �.�. ������� ������

  BITGRANMASK = (1 shl BITGRAN) -1; ������� ����� (2^BITGRAN)-1

; ������ �������� ���� � 8 * 2^BITGRAN ��� ������
; ��� dword (4 �����) : 8 * 4 = 32 ����

;______________________________________________________
; � .data :
; Bitfield     dd ? ; ����� �������� ����
; BitfieldSize dd ? ; ������ ���� � ������
;______________________________________________________



;********************************************************************************
; esi - �������� ������ ������ (������ ���� align 2^BITGRAN) - ����� �������
; ecx - ���������� ���� (���������� �� �������)
; ������������ - eax, edx, edi

SetBits:
	mov ebx,0FFh ; SET
   .resetin:
	shr esi,BITGRAN ; �� �������� ������ - � ����� ���� ���� (�������)
	mov edx,esi
	and edx,0000000000011111b ; ����� ���� � ������
	and esi,1111111111100000b ; ��������� �� ������
	shr esi,3		  ; �������� ������ ���� � ������

	; �� ���-�� ���� � ���-�� ������ (��� ����)
	; ������� �������� ���-�� ���� �� ������� ������� � ������� �������
	sub ecx,1	    ; ��������� �
	or  ecx,BITGRANMASK ; ������� ������� ��
	add ecx,1	    ; ������ ������� ����������
	shr ecx,BITGRAN     ; ecx - ���-�� ��� ����

	mov edi,[Bitfield]
   .loaddword:
	mov eax,[esi+edi] ; ����� �� ����

       test ebx,ebx
       jz .resetloop ; ���� ebx=0, ������ reset
   .setloop:
	bts eax,edx ; set
	sub ecx,1
	jz  .exit
	add edx,1
	cmp edx,32 ; 32 ���� � ������
	jnz .setloop
	jmp .nextdword

   .resetloop:
	btr eax,edx ; reset
	sub ecx,1
	jz  .exit
	add edx,1
	cmp edx,32 ; 32 ���� � ������
	jnz .resetloop

   .nextdword:	   ; ��������� �����
	mov [esi+edi],eax
	add esi,4
	xor edx,edx
	jmp .loaddword
   .exit:
	mov [esi+edi],eax
	ret


;********************************************************************************

ResetBits:
	xor ebx,ebx
	jmp SetBits.resetin


;********************************************************************************
; e�x - ���������� ����, ������� ���� ����� ���������� ������

FindSpace:
	; ����������� ���-�� ���� � ���-�� ��� ����
	sub ecx,1	    ; ��������� �
	or  ecx,BITGRANMASK ; ������� ������� ��
	add ecx,1	    ; ������ ������� ����������
	shr ecx,BITGRAN     ; ecx - ���-�� ��� ����
	push ecx;��� �������; local : [esp+8] - ������ ����, � ���. �������� ���������
	push ecx	    ; local : [esp+4] - ���-�� ��� ������� ���������� ����
	push ecx;��� �������; local : [esp] - ������ dword-� � ����, ��� �������� ���������

	mov esi,[Bitfield] ; ����� ����
	xor edi,edi	   ; ����� ������ ����
   .findbit0:	    ; ���� ��� 0 - ������ �������
	xor edx,edx ; ����� ����
	mov eax,[esi+edi] ; ������� ����
   .findbit0_32:      ; �������� 4� ����
	bt  eax,edx
	jnc .foundspace ; ������ 0 ���
	; ������� ������
	add edx,1
	cmp edx,32
	jnz .findbit0_32
	; ��������� � ��������� 4� ������
	add edi,4
	cmp edi,[BitfieldSize]
	jc .findbit0 ; uns edi < [BitfieldSize]
	; ����� ����, ������������ �� �������
   .endoffield:
	; ��� �������� � �������� ������� ��� ������������� ���� � ������:
	; ���� �� ���������� ���� ��������� ������-��� ��������������
	;    ������� ��������������, ���������� ����
	;    ����� ������ ��������� �������
	;    ���� �� ������, ��
	;       ������� ������� ������� ������
	;       ��������� ������ � ������� ����
	;       ���������� �������, ������ � �.�.
	; ��� �������� ��� ������� �������:
	; ������� ��� ���� ������� ������ ��� ����
	; ���� ������������ ������ ���                                    TO DO  ! ! !
	int3
	; ...
	; ...

   .foundspace:   ; ����� esi+edi, eax, edx
	mov [esp],edi	; ��������� ������ dword-a � ����
	mov ecx,[esp+4] ; ���-�� 0 ���
	mov [esp+8],edx ; ������ ����, � ���. �������� ���������
   .loop0m:
	mov eax,[esi+edi] ; ������� ���
   .loop0:
	sub ecx,1
	jz  .fit   ; ���������� ���������� �����
	add edx,1  ; ��������� ���
	cmp edx,32
	jz  .next32 ; ����� ��������� 4 �����
	bt  eax,edx
	jnc .loop0
	; ��������� �������, ���� ������ ��������� ������
	; ��� ���������� ��� �����, �����
	jmp .findbit0_32 ; ����� esi+edi, eax, edx
   .next32:
	xor edx,edx ; ����� ���� =0
	add edi,4
	cmp edi,[BitfieldSize]
	; mov eax,[esi+edi] - ������ ���, �.�. �.�. ������ ���������� �� ���������
	jc .loop0m ; uns edi < [BitfieldSize]
	; ����� ����, �� ������� ���������� �����
	jmp .endoffield
   .fit:
	pop eax ; ��� ������ dword-� � ����, ��� �������� ���������
	shl eax,5 ; *32, ������ � ��� ������ ���� � ���� (��� ���� �0 dworda)
	pop ecx ; ��� ���-�� ��� ������� ���������� ����
	pop edx ; ������ ���� ������ dworda, � ���. �������� ���������
	add eax,edx ; ������ ����� ���� ���� (�������)
	shl eax,BITGRAN ; �������� ������ �������
	add eax,esi ; esi=[Bitfield] ; ����� �������� ������
      ret

;****************************************************

macro Bit SetResetTest, AddrReg, Reg2  {
	  Reg2x equ Reg2
	  if Reg2 eq
	    purge Reg2x
	    Reg2x equ ecx
	  end if

	shr AddrReg,BITGRAN
	mov Reg2x,AddrReg
	and Reg2x,BITGRANMASK
	xor AddrReg,Reg2x
	   if SetResetTest eq set
	bts [AddrReg],Reg2x
	   end if
	   if SetResetTest eq reset
	btr [AddrReg],Reg2x
	   end if
	   if SetResetTest eq test
	bt [AddrReg],Reg2x
	   end if

}
						       ; �������������:
						       ; Bit test,edx,edi
;****************************************************
; Set / Reset bit:
; eax - ����� ������ (�������), ������� ���� ������������� (��� BITGRAN > 0)
    ; ����� ����� �� ������� ������
    shr eax,BITGRAN; ����� ������� = ����� ���� � ����
    mov ecx,eax
    and ecx,BITGRANMASK; ����� ���� � �����
    xor eax,ecx; ����� ����� ���� -
    ; ������� ����� ����� � ����
    bts [eax],ecx ; bit test and set  // btr // btc

;=====================================================================

; bitfield �������� �������� set bit:

; eax - addr
; ecx - bit

; 1:
	bts [eax],ecx	 ; 6 latency, ? throuthput

; 2:
	mov edx,1		 ; 1 latency, 0.33 throuthput
	shl edx,cl; ��� �� ����� ; 1 latency, 0.5 throuthput
	or [eax],edx		 ; 6 latency, 1 throuthput

; 3:
	mov edx,1		 ; 1 latency, 0.33 throuthput
	shl edx,cl; ��� �� ����� ; 1 latency, 0.5 throuthput
	mov ecx,[eax]
	or  ecx,edx
	mov [eax],ecx

;=====================================================================
