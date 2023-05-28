;*********************************************************************
;*** *** *** ***                                       *** *** *** ***
;*** *** *** ***             KWHeap v3.0               *** *** *** ***
;*** *** *** ***                                       *** *** *** ***
;*********************************************************************

;*******   Куча на основе связанного списка,
;*******   размер кучи - динамически увеличивающийся


;***********     Основные функции     ***********
; CreateHeap
; MemAlloc
; MemReAlloc
; MemFree

; Блок памяти:
;   Служебные данные блока:
;   .Size  (dword)  addr+0   размер данных и флаг занятости
;   .Next  (dword)  addr+4
;   .Prev  (dword)  addr+8
;   Данные блока:
;   data   ...      addr+12
INFOSIZE = 12

; Настройки ----------------------------------------------------------
HEAPSIZE0    = 4 * 1024 ; начальный размер кучи                      |
HEAPSIZESTEP = 4 * 1024 ; минимальный шаг увеличения размера кучи    |
BLOCKBRICK = 4 ; размер кирпичика данных блока памяти,               |
	       ; минимальная часть,                                  |
	       ; равна степени двойки: 4, 8, 16, 32...               |
MINBLOCKSIZE = INFOSIZE + 2 * BLOCKBRICK ;                           |
;---------------------------------------------------------------------

BLOCKISBUSY = 80000000h ; bit31=1
BLOCKISFREE = 0
BLOCKISFIRST = 0
BLOCKISLAST  = 0


;---------------------------------------------------------------------
; hheap CreateHeap (int size)
; Cоздать кучу размером size

proc CreateHeap size
	; при size==0 берём размер по умолчанию
	mov ecx,HEAPSIZE0
	mov eax,[size]
	or  eax,eax
	; В семействo Р6 (Pentium Pro и Pentium II) добавленa cmovcc:)
	cmovz eax,ecx

	; округляем до размера страницы (4К)
	dec eax
	or  eax,0FFFh
	inc eax
	mov [size],eax

	stdcall CreateArea, eax
	    jc .error

	; eax - начало полученной памяти
	;-----------------------------------------------------------
	; делаем незанятый блок во всю область
	mov ecx,[size]
	sub ecx,INFOSIZE
	mov [eax],ecx ; .Size BLOCKISFREE
	mov [eax+4],dword BLOCKISLAST ; .Next
	mov [eax+8],dword BLOCKISFIRST; .Prev

	; eax - хэндл кучи
	; CF = 0
	ret

  .error:
	ud2 ;                                             ? ? ? TO DO
endp

;---------------------------------------------------------------------
; void * CreateArea (int size)  stdcall  <для внутреннего пользования>
; получает от системы кусок памяти размером в size
; (ф-ция округляет size до размера страницы)
; параметр size должен лежать в стеке
; ф-ция возвращает:
;  eax - адрес области (eax=0 - ошибка)
;  CF=0 - нет ошибки, CF=1 - ошибка

CreateArea:
	; при size = 0:
	;  Windows - размер увеличивается до размера страницы
	;  Colibri - глухая ошибка

	; округлить size до 4 КБ в большую сторону (size=0...)
	mov eax,[esp+4] ; size
	sub eax,1
	adc eax,0 ; если size = 0, то считаем, что = 1
	or  eax,1024*4 - 1
	inc eax
	mov [esp+4],eax

	; получить память
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
	  ; в руководстве KOS о нехватке памяти не сказано...
	end if
	or eax,eax ; проверка на ошибку выделения памяти
	jz .error

	; eax = адрес области
	clc ; нет ошибки
	retn 1 * 4

  .error:
	; eax = 0
	stc ; ошибка
	retn 1 * 4


;---------------------------------------------------------------------
; Разместить (получить, создать) блок памяти в куче
; void * MemAlloc (int size)

proc MemAlloc uses ebx,  size

	; округлим size до BLOCKBRICK
	mov ecx,[size]
	dec ecx
	or  ecx,BLOCKBRICK-1
	inc ecx
	mov [size],ecx

	mov eax,[hHeap] ; адрес первичного блока
    .mainloop:
	; eax - адрес текущего блока, this
	; [eax] = .Size и флаг занятости
	test [eax],dword BLOCKISBUSY ; bit 31 = 1 ?
	jz  .foundfreeblock   ; нет, не занят

	; блок занят, переходим к следующему
    .gonext:
	mov eax,[eax+4] ; this = .Next
	or  eax,eax   ; NULL-адрес?
	jnz .mainloop ; не нуль, есть ещё блоки
	; пройден последний блок, надо создать новую область     TO DO
	; . . .
	ud2

    .foundfreeblock:
	; еах - адрес блока
	; ecx = [size] - размер данных запрошенный клиентом
	; сравним размеры данных нужного и найденного блоков
	; получим весь свободный остаток (если есть)
	mov edx,[eax] ; .Size
	sub edx,ecx ; edx = .Size - size
	jc .gonext  ; .Size < size, не входит!

	; блок подходит. делаем занятым
	or [eax],dword BLOCKISBUSY

	; edx - остаток
	; можем из остатка сделать доп. блок?
	cmp edx,MINBLOCKSIZE + INFOSIZE
	jc .toosmall ; остаток слишком мал

      ; остаток годится для создания дополнительного блока
	; делаем два блока. текущий занятый (this) и доп. свободный
	mov [eax],dword ecx ; this.Size = size
	or  [eax],dword BLOCKISBUSY

	lea ebx,[eax+ecx+INFOSIZE]
	sub edx,INFOSIZE ; скоррект. размер для данных (доп.)
	mov [ebx],edx	; доп.Size = edx  not busy
	mov ecx,[eax+4] ;  this.Next
	mov [ebx+4],ecx ; доп.Next = this.Next
	mov [ebx+8],eax ; доп.Prev = this

	mov [eax+4],ebx ; this.Next = доп.
			; this.Prev оставим
    .toosmall:
	; из остатка не сделать новый блок
	; оставим исходный размер данных без изменений
	; возвращаемрезультат
	add eax,INFOSIZE
	; CF = 0
	ret

endp



;---------------------------------------------------------------------
; void * MemReAlloc (void * addr, int newsize)

proc MemReAlloc uses esi edi, addr, newsize

	mov eax,[addr]
	mov ecx,[eax] ; старый размер
	cmp ecx,[newsize]
	jnc .reduce ; старый не меньше нового
	; старый меньше нового. увеличиваем
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

	; новый меньше или равен. уменьшаем
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
; освобождает блок памяти,
; addr - адрес данных блока памяти, полученный от MemAlloc

proc MemFree addr

	sub [addr],INFOSIZE
	; снимаем флаг занятости блока
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
; void MergeBlocks addr1, addr2  <для внутреннего пользования>
; Процедура объединения двух блоков
; (addr.. - адреса блоков, а не данных)
; Подразумевается, что addr1 свободен (this в MemFree)

proc MergeBlocks addr1, addr2

	mov eax,[addr1]
	or  eax,eax ; NULL ?
	jz  .exit
	mov eax,[addr2]
	or  eax,eax ; NULL ?
	jz  .exit

	; Сначала проверяем, что блок addr2 не занят
	mov  eax,[addr2]
	test dword[eax],BLOCKISBUSY ; .Size и флаг
	jnz  .exit ; блок занят
	; Если addr1 больше, то обмениваем addr1 и addr2
	mov eax,[addr1]
	cmp eax,[addr2]
	jc  @F
	xchg eax,[addr2]
	mov  [addr1],eax
    @@:
	; Проверяем, что второй блок встык к первому
	mov eax,[addr1]
	mov ecx,[eax] ; .Size, свободен
	lea edx,[eax+ecx+INFOSIZE] ; адрес за первым блоком
	cmp edx,[addr2] ; должно быть одно и тоже
	jne .exit ; не встык
	;------ проверки завершены

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