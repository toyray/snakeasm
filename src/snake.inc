SNAKELOC STRUCT
    locX    DWORD   ?
    locY    DWORD   ?
    dir     DWORD   ?
SNAKELOC ENDS 

mFillSnakeLoc MACRO ptrSnakeLoc, x, y, direction
    push eax
    lea eax, ptrSnakeLoc
    assume eax : PTR SNAKELOC
    push x
    pop [eax].locX
    push y
    pop [eax].locY
    push direction
    pop [eax].dir
    assume eax : NOTHING
    pop eax
ENDM

mRGB MACRO red, green, blue
    xor eax, eax
    mov ah, blue
    mov al, green
    rol eax, 8
    mov al, red
ENDM        

.const
    WND_SIZE_X  equ     320
    WND_SIZE_Y  equ     240

    SNAKE_UP    equ     26h
    SNAKE_DOWN  equ     28h
    SNAKE_RIGHT equ     27h
    SNAKE_LEFT  equ     25h

    LINE_WIDTH  equ     8
    IDI_APP     equ     200