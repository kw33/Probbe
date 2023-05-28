;*********************************************************************
;*** *** *** ***       Heap library for KolibriOS      *** *** *** ***
;*** *** *** ***                 KWHeap3               *** *** *** ***
;*********************************************************************

; За каждой функцией закреплён свой ординал.
; В любой версии этой библиотеки ординал функции не изменяется.


format MS COFF

public EXPORTS

section '.flat' code readable align 16

;include '../../../../macros.inc'
;include '../../../../proc32.inc'
include 'macro\proc32.inc' ; для компиляции из-под Windows
;include 'debug.inc'

OS equ KOLIBRI
include 'KWHeap3.asm'



align 16

hHeap dd ?
EXPORTS:
	dd szHeapCreate, CreateHeap   ; ord 0
	dd szHeapAlloc,  MemAlloc     ; ord 1
	dd szHeapReAlloc,MemReAlloc   ; ord 2
	dd szHeapFree,	 MemFree      ; ord 3
    ;    dd szHeapPut,    KWHeapPut      ; ord 4
    ;    dd szHeapDelete, KWHeapDelete   ; ord 5
	dd	   0,	 0

szHeapCreate  db 'HeapCreate',0
szHeapAlloc   db 'HeapAlloc',0
szHeapReAlloc db 'HeapReAlloc',0
szHeapFree    db 'HeapFree',0
;szHeapPut     db 'HeapPut',0
;szHeapDelete  db 'HeapDelete',0

