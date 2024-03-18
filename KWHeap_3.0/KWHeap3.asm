;*********************************************************************
;*** *** *** ***                                       *** *** *** ***
;*** *** *** ***             KWHeap v3.0.1             *** *** *** ***
;*** *** *** ***                                       *** *** *** ***
;*********************************************************************

;*******   Куча на основе связанного списка,
;*******   размер кучи - динамически увеличивающийся,
;*******   количество потоков, её использующих - один.
;*******   В версии 3.0.1 введена возможность использования
;*******   одной пронраммой нескольких куч одновременно.


;***********     Основные функции     ***********
; CreateHeap   +
; MemAlloc
; MemReAlloc   +
; MemFree      +
; MemPut       +
; GetSize ?

; Блок памяти:
;   Служебные данные блока:
Size = 0 ;  (dword)  addr+0   размер данных и флаг занятости
Next = 4 ;  (dword)  addr+4   адрес следующего блока и флаги
Prev = 8 ;  (dword)  addr+8   адрес предыдущего блока и флаги
;   Данные блока:
;   data   ...       addr+12
INFOSIZE = 12

; Настройки ----------------------------------------------------------
HEAPSIZE0    = 4 * 1024 ; начальный размер кучи                      |
HEAPSIZESTEP = 4 * 1024 ; минимальный шаг увеличения размера кучи    |
BLOCKBRICK = 4 ; размер в байтах кирпичика данных блока памяти,      |
	       ; минимальная часть, кратно 4 по УВО,                 |
	       ; можно задавать равным 4, 8, 12, 16...               |
MINBLOCKSIZE = INFOSIZE + (2 * BLOCKBRICK) ; размер всего блока      |
;---------------------------------------------------------------------

BLOCKISBUSY  = 1 ; bit0 = 1     в Size
BLOCKISFREE  = 0 ;              в Size
FIRSTINAREA  = 1 ; bit0 = 1     в Prev    первый блок в области
LASTINAREA   = 1 ; bit0 = 1     в Next    последний блок в области
; Prev = NULL - первичный блок в куче
; Next = NULL - последний блок в куче

; ячея = блок
; .Size, .Next, .Prev, this.Size, this.Next, this.Prev в комментах -
;  - означают соответствующие служебные ячейки в текущем блоке


;---------------------------------------------------------------------
; void * CreateHeap (int size)
; Cоздать кучу размером size
; Возвращается адрес данных/дескриптор/хэндл первичного блока
; ok: eax=address, CF=0
; error: eax=0, CF=1

proc CreateHeap size
	; при size==0 берём размер по умолчанию
	mov ecx,HEAPSIZE0
	mov eax,[size]
	or  eax,eax
	; В семействo Р6 (Pentium Pro и Pentium II) добавленa cmovcc:)
	cmovz eax,ecx

	; округляем до размера страницы (4К)                       переделать!!!
	dec eax
	or  eax,0FFFh
	inc eax
	mov [size],eax

	stdcall CreateArea, eax
	    jc .error

	; eax - начало полученной памяти
	;-------------------------------------------------------------
	; делаем незанятый блок во всю область
	; он и первый и последний в куче (Prev=Next=NULL, без флагов)
	; он и первый и последний в области
	mov ecx,[size]
	sub ecx,INFOSIZE
	mov [eax + Size],ecx ; BLOCKISFREE
	mov [eax + Next],dword LASTINAREA
	mov [eax + Prev],dword FIRSTINAREA
	add eax,INFOSIZE
	; eax - хэндл кучи, первичный блок
  .error:
	ret
endp

;---------------------------------------------------------------------
; void * CreateArea (int size)  stdcall  <для внутреннего пользования>
; получает от системы кусок памяти размером в size
; ф-ция не округляет size до размера страницы)
; параметр size должен лежать в стеке
; при size=0 - ошибка
; ф-ция возвращает:
;  eax - адрес области (eax=0 - ошибка)
;  CF=0 - нет ошибки, CF=1 - ошибка

CreateArea:
	; при size = 0:
	;  Windows - размер увеличивается до размера страницы
	;  Colibri - вернёт адрес, но страницы не передадутся.
	;            а при записи в память - page fault.
	;     было такое: {--при этом в программе "cpu" нельзя
	;                  --удалить запущенный процесс}
	; ebp сохраняется

      ;  ; округлить size до 4 КБ в большую сторону (size=0...)
      ;  mov eax,[esp+4] ; size
      ;  sub eax,1
      ;  adc eax,0 ; если size = 0, то считаем, что = 1
      ;  or  eax,1024*4 - 1
      ;  inc eax
      ;  mov [esp+4],eax

	or  eax,eax
	jz  .error

	; получить память
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
	  ; в руководстве KOS о нехватке памяти не сказано...
	  ; замечания по работе менеджера памяти Колибри - внизу текста
	end if
	or eax,eax ; проверка на ошибку выделения памяти
	jz .error

	; eax = адрес области
	clc ; нет ошибки
	retn 1 * 4

  .error:
	; eax = 0
	stc ; ошибка
	retn 1 * 4 ; stdcall


;---------------------------------------------------------------------
; Разместить (получить, создать) блок памяти в куче
; void * MemAlloc (void * hheap, int size)
; {
;   в принципе, в качестве hheap можно передавать адрес любого валидного
;   блока в данной куче. поиск свободного пространства будет
;   производиться от этого блока до конца кучи.
; }

proc MemAlloc uses ebx,  hheap, size

	; округлим size до BLOCKBRICK
	mov ecx,[size]
	dec ecx
	or  ecx,BLOCKBRICK-1
	inc ecx ; ZF = ?
	mov [size],ecx

	; проверить исходную size на 0, точнее, от -BLOCKBRICK до 0
	jz .err

; если newsize = 0..MINBLOCKSIZE-1 - то преобразовать в MINBLOCKSIZE или error?

	mov eax,[hheap]  ; адрес данных первичного блока (любого блока;))
	sub eax,INFOSIZE
    .mainloop:
	; eax - адрес текущего блока, this
	; [eax+Size] = .Size и флаг занятости
	; ecx = округлённый [size]
	test [eax+Size],dword BLOCKISBUSY ; bit 0 = 1 ?
	jz  .foundfreeblock   ; нет, не занят

	; блок занят, переходим к следующему
	; тут нас не волнуют FIRATINAREA и LASTINAREA               ??
    .gonext:
	mov edx,eax   ; сохранили предыдущий this
	mov eax,[eax+Next] ; this = .Next
	mov edx,eax   ; сохранили предыдущий
	or  eax,eax   ; NULL-адрес?
	jnz .mainloop ; не нуль, есть ещё блоки

	; пройден последний блок, надо создать новую область       TO DO
	; что больше - [size] или HEAPSIZESTEP ?
	
	
      ;  ...
	push edx ; сохранили предыдущий this
	stdcall CreateArea, ? 
	pop  edx
	  jc .err ; CF=1, eax=0
	mov [edx + Next],eax ;
	or  [edx + Next],dword BLOCKISLAST
	; ..........


	ud2							   ; TO DO

    .foundfreeblock:
	; еах - адрес блока
	; ecx = [size] - округлённый размер данных запрошенный клиентом
	; сравним размеры данных нужного и найденного блоков
	; получим весь свободный остаток (если есть)
	mov edx,[eax] ; .Size
	sub edx,ecx ; edx = .Size - size
	jc .gonext  ; .Size < size, не входит!

	; блок подходит. делаем занятым
	or [eax],dword BLOCKISBUSY

	; edx - остаток
	; можем из остатка сделать доп. блок?
	cmp edx,MINBLOCKSIZE
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
	; CF = 0 (раз уж нам дали память, то eax не слишком большой)
	ret

    .err:
	xor eax,eax
	stc
	ret
endp



;---------------------------------------------------------------------
; void * MemReAlloc (void * addr, int newsize)

proc MemReAlloc uses esi edi,  addr, newsize
      ; простой вариант реализации функции
	; округлим newsize до BLOCKBRICK
	mov ecx,[newsize]
	dec ecx
	or  ecx,BLOCKBRICK-1
	inc ecx ; ZF = ?
	mov [newsize],ecx

	; проверить исходную size на 0, точнее, от -BLOCKBRICK до 0
	jz .error

; эти проверки ...
; если newsize = 0..MINBLOCKSIZE-1 - то преобразовать в MINBLOCKSIZE или error?

	mov eax,[addr]	 ; адрес данных
	sub eax,INFOSIZE ; адрес блока
	mov edx,[eax + Size] ; старый размер
	sub edx,ecx ; [.Size] - [newsize]
	jz  .equ    ; размер не меняется
	jnc .reduce ; старый больше нового

      ; старый меньше нового. увеличиваем
	; создаст новый блок после текущей ячеи (в цепочке блоков).
	;  надо или параметр hHeap, или invoke FindHead, [addr]     ??
	stdcall MemAlloc, eax, ecx ; адр.блока, [newsize]
	jc .error
	mov esi,[addr] ; адрес данных (отсюда)
	mov edi,eax    ; адрес для данных в новой ячее (сюда)
	mov ecx,[esi-INFOSIZE + Size] ; .Size & flag
	and ecx,not BLOCKISBUSY
	movsb
	push eax
	stdcall MemFree, [addr]
	pop eax ; new addr
	clc	; no error
	ret
						; флаги LASTINAREA ...???
      ; новый меньше. уменьшаем
  .reduce:
	; войдёт ли в освободившееся место новая ячея?
	; eax = адр.блока текущего
	; ecx = [newsize] новый размер данных
	; edx = разница размеров (округлена автоматически)
	cmp edx,MINBLOCKSIZE
	jc  .equ ; не войдёт. ничего не меняем
      ; уменьшим размер
	mov [eax + Size],ecx ; this.Size = newsize
	or  [eax + Size],BLOCKISBUSY ; + флаг
      ; создать блок из освободившегося места
	lea ecx,[eax+INFOSIZE + ecx] ; адрес НОВОГО блока newblock
	mov esi,[eax + Next]
	mov [ecx + Next],esi ; newblock.Next = this.Next
	mov [eax + Next],ecx ; this.Next = newblock
	mov [ecx + Prev],eax ; newblock.Prev = this
	or  edx,BLOCKISBUSY
	mov [ecx + Size],edx ; newblock.Size = разница размеров + флаг
      ; удаляем новодельный блок чтоб он слился со следующим,
      ; если это возможно
	invoke MemFree, ecx

  .equ:
	mov eax,[addr] ; оставим прежнюю ячею
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
; addr - адрес данных блока памяти, полученный от MemAlloc и подобных

proc MemFree addr

	sub [addr + Size],INFOSIZE ; this
	; снимаем флаг занятости блока
	mov eax,[addr + Size]
	and [eax + Size],dword not BLOCKISBUSY

	; проверяем Next - последний в области?
	mov edx,[eax + Next]
	test edx,LASTINAREA
	jnz  @f ; посл.в обл.
	; следующий блок занят?
	; (в edx bit0=0 здесь)
	test [edx],byte BLOCKISBUSY ; Next.Size bit0 = ?
	jnz  @f ; занят
	;stdcall MergeBlocks, eax, edx
	;----------------------------------------------- объединение
	mov ecx,[edx + Size] ; + Size == 0 и не увеличит код
	add [eax + Size],ecx ; сложили размеры
	mov ecx,[edx + Next]
	mov [eax + Next],ecx ; переместили ссылку на следующий
	;-----------------------------------------------
    @@:
	; проверяем Prev - первый в области?
	mov eax,[addr]
	mov edx,[eax + Prev]
	test edx,FIRSTINAREA
	jnz  @f ; перв.в обл.
	; предыдущий блок занят?
	; (в edx bit0=0 здесь)
	test [edx],byte BLOCKISBUSY ; Prev.Size bit0 = ?
	jnz  @f ; занят
	;stdcall MergeBlocks, edx, eax
	;----------------------------------------------- объединение
	mov ecx,[eax + Size] ; + Size == 0 и не увеличит код
	add [edx + Size],ecx ; сложили размеры
	mov ecx,[eax + Next]
	mov [edx + Next],ecx ; переместили ссылку на следующий
	;-----------------------------------------------
    @@:
	ret
endp


;---------------------------------------------------------------------
; void * MemPut (void * hheap, void * addr, int size);
; ok: CF=0, eax=адрес данных
; error: CF=1, eax=0

proc MemPut uses esi edi, hheap, addr, size
	; ? проверить size на максимум ?
	stdcall MemAlloc, [hheap], [size]
	  jc .nomem
	push eax
	mov edi,eax
	mov esi,[addr]
	mov ecx,[size]
	add ecx,INFOSIZE
	; учитывая УВO, можем так
	shr ecx,2 ; ZF зависит от результата
	rep movsd ; при ecx = 0 не выполнится ни разу
	clc	  ; CF flag are cleared
	pop eax   ; eax=addr
   .nomem:
	ret
endp
;---------------------------------------------------------------------
; замечания по работе менеджера памяти Колибри
;         mov eax,68 ; SF_SYS_MISC
;         mov ebx,12 ; SSF_MEM_ALLOC
;         mov ecx,[size]
;         int 40h
;
; при size = 0 - виснет наглухо.
; не проверяет, какой размер физической памяти в наличии.
; распределяет только виртуальные адреса (0...2ГБ-1)
; если виртуальных адресов не хватило - возвращает 0.
; как узнать, получил ты физическую память или пустой вирт.диапазон адресов -
;  - запрашивать памяти не более чем количество свободной и инициализировать её.
; пока в полученую память не записано значение, она считается свободной и
;  не передаётся приложению. Инициализировать надо каждую страницу.
; размер свободной физ. памяти:
;         mov eax,18 ; SF_SYSTEM (18)
;         mov ebx,16 ; SSF_GET_FREE_RAM (16)
;
; размер физ. памяти:
;         mov eax,18 ; SF_SYSTEM (18)
;         mov ebx,17 ; SSF_GET_TOTAL_RAM (17)
;

;---------------------------------------------------------------------