;; This file contains the implementation of a queue and its associated operations, add and delete
;; items as well as create and release to allocate and free memory associated with the queue. 
;; View queue allows viewing of the first or last items in the queue

;; * NOTE : Uses MASM32 library function MemCopy()

QUEUE TYPEDEF   DWORD

queueCreate     proto
queueAdd        proto :PTR QUEUE, :DWORD, :DWORD
queueDel        proto :PTR QUEUE, :DWORD, :DWORD
queueView       proto :PTR QUEUE, :DWORD
queueRelease    proto :PTR QUEUE

;; Macro to return a value in EAX

return  MACRO value
    mov eax, value
    ret
ENDM    

;; MACRO to allocate memory 

mAlloc  MACRO size
    invoke GlobalAlloc, GMEM_FIXED, size
ENDM

;; MACRO to free memory
mFree   MACRO hMem
    push eax
    invoke GlobalFree, hMem
    pop eax
ENDM

;;  Structure for queue items

QUEUEITEM STRUCT
    ptrData     DWORD   ?
    ptrNextItem DWORD   ?
QUEUEITEM ENDS

.code

;; This procedure allocates eight bytes of memory to store the address of the first and last 
;; queue items and initializes both values to NULL before returning address to caller

queueCreate proc
    mAlloc 8
    test eax, eax
    jne @F
    return FALSE
@@:        
    mov dword ptr [eax], NULL
    mov dword ptr [eax+4], NULL
    return eax
queueCreate endp


;; This procedure allocates memory for the queue item structure as well as its data and adds it
;; to the top of the queue. Data for the queue is supplied by ptrData, a pointer the the buffer
;; that contains the data and dwDataSize containing the size of the data supplied

queueAdd proc uses edx ptrQueue:PTR QUEUE, ptrData:DWORD, dwDataSize:DWORD

    ;; Allocate memory for queue structure
    
    mAlloc 12
    test eax, eax
    jne @F
    return FALSE
@@:

    ;; Allocate memory for data

    push eax
    mAlloc dwDataSize
    jne @F
    pop eax
    return FALSE
@@:
    mov edx, eax

    ;; Copy data to allocated memory for data

    invoke MemCopy, ptrData, edx, dwDataSize 
    pop eax

    ;; Copy all data to queue item structure

    assume eax: PTR QUEUEITEM
    mov [eax].ptrData, edx
    mov [eax].ptrNextItem, NULL

    ;; Update previous queue item to point to this item

    mov edx, ptrQueue
    mov edx, dword ptr [edx+4]
    test edx, edx
    je @F 
    mov (QUEUEITEM PTR [edx]).ptrNextItem, eax
@@:    

    ;; Update queue position. If item is first item, set head to address of item
    
    assume eax : NOTHING
    mov edx, dword ptr [ptrQueue]
    cmp dword ptr [edx], NULL
    jne @F
    mov dword ptr [edx], eax
@@:    
    mov edx, dword ptr [ptrQueue]
    mov dword ptr [edx+4], eax
    ret
queueAdd endp


;; This procedure deletes the first item in the queue off the queue. Returns FALSE if queue is 
;; empty, otherwise return TRUE. Copies dwDataSize bytes of the data of the first item into
;; the buffer specified by ptrData and frees the memory associated with its queue item structure
;; and data

queueDel proc uses edx ptrQueue: PTR QUEUE, ptrData: DWORD, dwDataSize: DWORD
    mov eax, ptrQueue
    mov eax, dword ptr [eax]
    test eax, eax
    jne @F
    return FALSE
@@:    
    assume eax: PTR QUEUEITEM

    ;; Copy data in item
    
    .IF ptrData != NULL
        invoke MemCopy, [eax].ptrData, ptrData, dwDataSize
    .ENDIF        

    ;; Free memory associated with data 
    
    push [eax].ptrNextItem
    mFree [eax].ptrData

    ;; Free memory associated with queue item structure
    
    mFree eax
    assume eax: NOTHING

    ;; Update queue position. If item deleted is last item, set queue head to NULL

    mov edx, ptrQueue
    cmp dword ptr [edx+4], eax
    jne @F
    mov dword ptr [edx+4], NULL
@@:
    pop eax
    mov dword ptr [edx], eax
    return TRUE
queueDel endp


;; This procedure returns data in the first or last item of the queue. Returns FALSE if queue is
;; empty, otherwise return address of data in queue item. The item is not popped off the queue

queueView proc ptrQueue: PTR QUEUE, dwFirstItem:DWORD
    mov eax, ptrQueue
    .IF dwFirstItem == TRUE
        mov eax, dword ptr [eax]
    .ELSE
        mov eax, dword ptr [eax+4]
    .ENDIF            
    test eax, eax
    jne @F
    return FALSE        
@@:    
    mov eax, (QUEUEITEM PTR [eax]).ptrData
    ret
queueView endp


;; This proc iterates thorugh the queue and frees all memory associated with the data and 
;; queueitem structure. Use to free all memory when the queue is no longer used

queueRelease proc uses esi ptrQueue:PTR QUEUE
    mov esi, ptrQueue
    mov esi, dword ptr [esi]
    push esi
    .WHILE esi != NULL
        assume esi: PTR QUEUEITEM

        ;; mFree memory associated with data 

        mFree [esi].ptrData
        push [esi].ptrNextItem
        assume esi: NOTHING
        
        ;; mFree memory associated with queue item structure
        
        mFree esi
        pop esi

    .ENDW

    ;; Free queue head and tail pointers
    
    pop esi
    mFree esi
    ret
queueRelease endp