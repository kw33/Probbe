	format PE GUI 4.0
entry start

include 'win32a.inc'


section '.data' data readable writeable


hHeap dd 0  ;---~----~-----~----~----~----~----~----~----~----~  ? ? ?
box1 dd ?
box2 dd ?
varname db '12345678901234567890123456789012345678901234567890'
var2	db '**************************************************',0,0



;#####################################################################


section '.code' code readable writeable executable
OS equ WINDOWS
include 'KWHeap3.asm'


  start:

		pushd 4*1024		    ;  4 KB
		call CreateHeap
		mov [hHeap],eax

		stdcall MemAlloc, eax, 32-12	   ; 1
		mov [box1],eax
		stdcall MemAlloc, [hHeap], 48-12       ; 2
		mov [box2],eax

		stdcall MemPut, [hHeap], varname, 0


		stdcall MemFree, [box1]
	  ; int3
		stdcall MemFree, [box2]

	      ;  mov eax,[box1]
	      ;  and dword[eax],not BLOCKISBUSY
	      ;  mov eax,[box2]
	      ;  and dword[eax],not BLOCKISBUSY
	      ;  stdcall MergeBlocks, [box1], [box2]

		invoke	ExitProcess,0


;#####################################################################


section '.idata' import data readable writeable

  library kernel32,'KERNEL32.DLL',\
	  user32,  'USER32.DLL'

  include 'api\kernel32.inc'
  include 'api\user32.inc'



;#####################################################################

section '.edata' export data readable ; для отладки
;
 export '', \
  CreateArea, 'CreateArea', \
  MemAlloc,   'MemAlloc'   ,\
  CreateHeap, 'CreateHeap' ,\
  MemFree,    'MemFree'    ,\
  MemPut,     'MemPut'	;,\
;  KWHeapRemove,'KWHeapRemove'

;#####################################################################

;label KWHeapCreate_ at KWHeapCreate
