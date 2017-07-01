

; битовое поле уже подготовлено - память дана, обнулена
; размер битового поля кратен dword (4 байт)
; соотв-но размер памяти для битового поля кратен 4 * 8 * 2^BITGRAN

; соответствие номеров битов номерам гранул
; биты побайтно в поле:
; 8 7 6 5 4 3 2 1 0 .15 14 13 12 11 10 9 .23 22 21..

; номер гранулы = номер бита * номер байта в поле
; адрес = номер гранулы * BITGRAN

; гранулярность-
; каждый бит соответствует грануле:
; BITGRAN = 0; 1 байт                   0
; BITGRAN = 1; 2 байт                   1
  BITGRAN = 2; 4 байт (dword)          11
; BITGRAN = 3; 8 байт (qword) и т.д.  111
; т.е. степень двойки

  BITGRANMASK = (1 shl BITGRAN) -1; битовая маска (2^BITGRAN)-1

; размер битового поля в 8 * 2^BITGRAN раз меньше
; для dword (4 байта) : 8 * 4 = 32 раза

;______________________________________________________
; в .data :
; Bitfield     dd ? ; адрес битового поля
; BitfieldSize dd ? ; размер поля в байтах
;______________________________________________________



;********************************************************************************
; esi - смещение адреса данных (должно быть align 2^BITGRAN) - адрес гранулы
; ecx - количество байт (округлится до гранулы)
; используются - eax, edx, edi

SetBits:
	mov ebx,0FFh ; SET
   .resetin:
	shr esi,BITGRAN ; из смещения адреса - в номер бита поля (гранулы)
	mov edx,esi
	and edx,0000000000011111b ; номер бита в дворде
	and esi,1111111111100000b ; округляем до дворда
	shr esi,3		  ; смещение дворда поля в байтах

	; из кол-ва байт в кол-во гранул (бит поля)
	; сначала округлим кол-во байт до размера гранулы в большую сторону
	sub ecx,1	    ; округляем в
	or  ecx,BITGRANMASK ; большую сторону по
	add ecx,1	    ; модулю размера грануляции
	shr ecx,BITGRAN     ; ecx - кол-во бит поля

	mov edi,[Bitfield]
   .loaddword:
	mov eax,[esi+edi] ; дворд из поля

       test ebx,ebx
       jz .resetloop ; если ebx=0, делать reset
   .setloop:
	bts eax,edx ; set
	sub ecx,1
	jz  .exit
	add edx,1
	cmp edx,32 ; 32 бита в дворде
	jnz .setloop
	jmp .nextdword

   .resetloop:
	btr eax,edx ; reset
	sub ecx,1
	jz  .exit
	add edx,1
	cmp edx,32 ; 32 бита в дворде
	jnz .resetloop

   .nextdword:	   ; следующий дворд
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
; eсx - количество байт, которые надо найти свободными подряд

FindSpace:
	; пересчитаем кол-во байт в кол-во бит поля
	sub ecx,1	    ; округляем в
	or  ecx,BITGRANMASK ; большую сторону по
	add ecx,1	    ; модулю размера грануляции
	shr ecx,BITGRAN     ; ecx - кол-во бит поля
	push ecx;есх неважно; local : [esp+8] - индекс бита, с кот. началось свободное
	push ecx	    ; local : [esp+4] - кол-во бит нужного свободного поля
	push ecx;есх неважно; local : [esp] - индекс dword-а в поле, где началось свободное

	mov esi,[Bitfield] ; адрес поля
	xor edi,edi	   ; сдвиг адреса поля
   .findbit0:	    ; ищем бит 0 - пустая гранула
	xor edx,edx ; номер бита
	mov eax,[esi+edi] ; кусочек поля
   .findbit0_32:      ; проверка 4х байт
	bt  eax,edx
	jnc .foundspace ; найден 0 бит
	; гранула занята
	add edx,1
	cmp edx,32
	jnz .findbit0_32
	; переходим к следующим 4м байтам
	add edi,4
	cmp edi,[BitfieldSize]
	jc .findbit0 ; uns edi < [BitfieldSize]
	; конец поля, пространство не найдено
   .endoffield:
	; для варианта с таблицей адресов для переносимости кучи в памяти:
	; если не установлен флаг сделанной только-что дефрагментации
	;    сделать дефрагментацию, установить флаг
	;    снова искать свободный участок
	;    если не найден, то
	;       заводим больший участок памяти
	;       переносим данные и битовое поле
	;       поправляем размеры, адреса и т.д.
	; для варианта без таблицы адресов:
	; завести ещё один участок памяти для кучи
	; надо обрабатывать массив куч                                    TO DO  ! ! !
	int3
	; ...
	; ...

   .foundspace:   ; нужны esi+edi, eax, edx
	mov [esp],edi	; сохранили индекс dword-a в поле
	mov ecx,[esp+4] ; кол-во 0 бит
	mov [esp+8],edx ; индекс бита, с кот. началось свободное
   .loop0m:
	mov eax,[esi+edi] ; придётся тут
   .loop0:
	sub ecx,1
	jz  .fit   ; достаточно свободного места
	add edx,1  ; следующий бит
	cmp edx,32
	jz  .next32 ; взять следующие 4 байта
	bt  eax,edx
	jnc .loop0
	; встретили занятое, надо искать свободное дальше
	; бит проверится там снова, пусть
	jmp .findbit0_32 ; нужны esi+edi, eax, edx
   .next32:
	xor edx,edx ; номер бита =0
	add edi,4
	cmp edi,[BitfieldSize]
	; mov eax,[esi+edi] - нельзя тут, т.к. м.б. память недоступна за пределами
	jc .loop0m ; uns edi < [BitfieldSize]
	; конец поля, не хватило свободного места
	jmp .endoffield
   .fit:
	pop eax ; это индекс dword-а в поле, где началось свободное
	shl eax,5 ; *32, теперь в еах индекс бита в поле (для бита №0 dworda)
	pop ecx ; это кол-во бит нужного свободного поля
	pop edx ; индекс бита внутри dworda, с кот. началось свободное
	add eax,edx ; полный номер бита поля (гранулы)
	shl eax,BITGRAN ; смещение адреса гранулы
	add eax,esi ; esi=[Bitfield] ; адрес свобоной памяти
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
						       ; использование:
						       ; Bit test,edx,edi
;****************************************************
; Set / Reset bit:
; eax - адрес памяти (гранулы), младшие биты отбрасываются (при BITGRAN > 0)
    ; адрес делим на степень двойки
    shr eax,BITGRAN; номер гранулы = номер бита в поле
    mov ecx,eax
    and ecx,BITGRANMASK; номер бита в байте
    xor eax,ecx; уберём номер бита -
    ; остался номер байта в поле
    bts [eax],ecx ; bit test and set  // btr // btc

;=====================================================================

; bitfield варианты операции set bit:

; eax - addr
; ecx - bit

; 1:
	bts [eax],ecx	 ; 6 latency, ? throuthput

; 2:
	mov edx,1		 ; 1 latency, 0.33 throuthput
	shl edx,cl; бит на месте ; 1 latency, 0.5 throuthput
	or [eax],edx		 ; 6 latency, 1 throuthput

; 3:
	mov edx,1		 ; 1 latency, 0.33 throuthput
	shl edx,cl; бит на месте ; 1 latency, 0.5 throuthput
	mov ecx,[eax]
	or  ecx,edx
	mov [eax],ecx

;=====================================================================
