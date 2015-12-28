.386
.model flat, stdcall
option casemap: none

include \MASM32\Include\Windows.inc
include \MASM32\Include\Kernel32.inc
include \MASM32\Include\User32.inc
include \MASM32\Include\Gdi32.inc
include \MASM32\Include\Masm32.inc

includelib \MASM32\Lib\Kernel32.lib
includelib \MASM32\Lib\User32.lib
includelib \MASM32\Lib\Gdi32.lib
includelib \MASM32\Lib\MASM32.lib

include snake.inc
include queue.asm

winMain         proto :DWORD, :DWORD, :DWORD, :DWORD
newGameProc     proto
timeProc        proto :DWORD, :DWORD, :DWORD, :DWORD
drawProc        proto
drawThingProc   proto
checkEatProc    proto
genNewLocProc   proto

.data?
    hInst       HINSTANCE   ?
    hWnd        HWND        ?
    hPen        HPEN        ?
    hBrush      HBRUSH      ?
    hMemDC      HDC         ?
    hBitmap     HBITMAP     ?
    
    snakeHead   SNAKELOC    <>
    snakeTail   SNAKELOC    <>
    ptEat       POINT       <>

    queue       DWORD       ?
    timerID     DWORD       ?
    
    bKeyDown    BOOLEAN     ?
    bEat        BOOLEAN     ?
    bGame       BOOLEAN     ?

.code
start:
    invoke GetModuleHandle, NULL
    mov hInst, eax
    invoke winMain, eax, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, 0

winMain proc hInstance:HINSTANCE, hPrevInstance:HINSTANCE, lpCmdLine:LPSTR, nCmdShow:UINT
    LOCAL wc        : WNDCLASSEX
    LOCAL msg       : MSG

    jmp initStrings
        szClsName   BYTE    "SnakeAsmCls",0 
        szWndName   BYTE    "snakeasm",0
initStrings:

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET wndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    push hInstance
    pop wc.hInstance
    invoke LoadIcon, hInst, IDI_APP
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    mov wc.hbrBackground, COLOR_WINDOW+1 
    mov wc.lpszMenuName, NULL 
    mov wc.lpszClassName, OFFSET szClsName

    invoke RegisterClassEx, ADDR wc

    ;; Create a window, bearing in mind that the window dimensions are inclusive of the title
    ;; bar and borders which will affect the checking of out-of-bounds conditions

    invoke CreateWindowEx, NULL, ADDR szClsName, ADDR szWndName, WS_POPUPWINDOW or WS_CAPTION, \
        0, 0, WND_SIZE_X+6, WND_SIZE_Y+25, NULL, NULL, wc.hInstance, 0

    mov hWnd, eax

    invoke ShowWindow, eax, nCmdShow
    invoke UpdateWindow, hWnd

    .WHILE TRUE
        invoke GetMessage, ADDR msg, NULL, 0, 0
        .BREAK .IF (!eax)
        invoke TranslateMessage, ADDR msg
        invoke DispatchMessage, ADDR msg
    .ENDW

    mov eax, msg.wParam
    ret                    
winMain endp

wndProc proc hwnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL   ps  : PAINTSTRUCT
    LOCAL   hdc : HDC

    .IF uMsg == WM_DESTROY

        ;; Delete all GDI objects

        invoke DeleteObject, hBitmap
        invoke DeleteDC, hMemDC

        ;; Destroy timer

        invoke KillTimer, hwnd, timerID
        
        invoke PostQuitMessage, 0
    .ELSEIF uMsg == WM_CREATE

        ;; Create memory DC for display buffer

        invoke GetDC, hwnd
        mov hdc, eax
        invoke CreateCompatibleDC, hdc
        mov hMemDC, eax
        invoke CreateCompatibleBitmap, hdc, WND_SIZE_X, WND_SIZE_Y
        mov hBitmap, eax
        invoke SelectObject, hMemDC, eax
        invoke ReleaseDC, hwnd, hdc

        ;; Start new game

        invoke newGameProc
        invoke InvalidateRect, hwnd, NULL, TRUE

    .ELSEIF uMsg == WM_PAINT
    
        invoke BeginPaint, hwnd, ADDR ps
        invoke BitBlt, eax, 0, 0, WND_SIZE_X, WND_SIZE_Y, hMemDC, 0, 0, SRCCOPY
        invoke EndPaint, hwnd, ADDR ps
        
    .ELSEIF uMsg == WM_KEYDOWN && bKeyDown == FALSE && bGame == TRUE

        ;; Check for four keys (VK_LEFT = 25h, VK_UP = 26h, VK_RIGHT = 27h, VK_DOWN = 28h)

        ;; Discard input if key pressed on same axis as snake's current movement

        .IF wParam == VK_UP || wParam == VK_DOWN
            .IF snakeHead.dir == SNAKE_UP || snakeHead.dir == SNAKE_DOWN
                jmp @F
            .ENDIF
        .ELSE
            .IF snakeHead.dir == SNAKE_LEFT || snakeHead.dir == SNAKE_RIGHT
                jmp @F
            .ENDIF                             
        .ENDIF

        ;; Add current location so that snake's tail knows when to change direction

        push wParam
        pop snakeHead.dir
        invoke queueAdd, queue, ADDR snakeHead, SIZEOF SNAKELOC
        mov bKeyDown, TRUE
    .ELSEIF uMsg == WM_LBUTTONDOWN && bGame == FALSE
        invoke newGameProc
    .ELSE
@@:    
        invoke DefWindowProc, hwnd, uMsg, wParam, lParam
        ret
    .ENDIF
    xor eax, eax
    ret                 
wndProc endp


;; This procedure is used to initialize a new game

newGameProc proc uses esi

    ;; Clear the memory context used for drawing the snake and THINGs

    invoke PatBlt, hMemDC, 0, 0,  WND_SIZE_X, WND_SIZE_Y, WHITENESS

    ;; Initialize snake head and tail locations

    mFillSnakeLoc snakeHead, 104, 8, SNAKE_RIGHT
    mFillSnakeLoc snakeTail, 0, 8, SNAKE_RIGHT

    ;; draw 7x7 rectangles to represent snake. Although each unit of the snake is 8x8 pixels
    ;; a 7x7 rectangle is drawn to make the snake look better
    
    mov esi, snakeTail.locX
    .WHILE esi <= snakeHead.locX
        invoke PatBlt, hMemDC, esi, snakeTail.locY, LINE_WIDTH-1, LINE_WIDTH-1, BLACKNESS
        add esi, 8
    .ENDW        

    ;; Initialize random seed generator
    
    invoke GetTickCount
    invoke nseed, eax

    ;; Draw the THING for the snake to Eat

    mov bEat, FALSE
    invoke drawThingProc

    ;; Initialize miscellaneous game variables

    mov bKeyDown, FALSE

    ;; Create a queue (FIFO) to store changes in direction and their location

    invoke queueCreate
    mov queue, eax

    ;; Set timer procedure
    
    invoke SetTimer, hWnd, NULL, 75,  ADDR timeProc
    mov timerID, eax

    ;; Indicate that game has started

    mov bGame, TRUE
    ret
newGameProc endp


;; This procedure is called when specified time interval is up

timeProc proc hwnd:HWND, uMsg:UINT, idEvent:UINT, dwTime:DWORD

    ;; If game is over, no processing is done. This condition is checked as killing the timer
    ;; will not remove any unprocessed WM_TIMER messages on the message queue

    cmp bGame, FALSE
    je @F

    ;; Calculate new location of snake head and check if death conditions met
    
    invoke genNewLocProc    
    cmp eax, TRUE
    je @F

    ;; Redraw head and tail of snake

    invoke drawProc

    ;; If THING has been eaten, redraw new one

    .IF bEat == TRUE
        invoke drawThingProc
    .ENDIF

    ;; Refresh display

    invoke InvalidateRect, hWnd, NULL, FALSE

    ;; Set bKeyDown to FALSE to allow key input

    mov bKeyDown, FALSE
    ret
@@:

    ;; If game is over, destroy timer and delete the queue to release all allocated memory

    invoke KillTimer, hwnd, timerID
    invoke queueRelease, queue
    mov bGame, FALSE
    ret
timeProc endp

;; This procedure is called to draw head and tail of snake

drawProc proc uses ebx ecx

    ;; Draw tail first then draw head. Check if THING has been eaten and if yes, the tail need
    ;; not be redrawn as the length of the snake has increased by 1 and the tail remains at the
    ;; same position

    invoke checkEatProc
    cmp eax, TRUE
    je @F

    invoke PatBlt, hMemDC, snakeTail.locX, snakeTail.locY, LINE_WIDTH-1, LINE_WIDTH-1, WHITENESS

    ;; Calculate next position of snake tail based on direction

    .IF [snakeTail].dir == SNAKE_UP
        sub [snakeTail].locY, LINE_WIDTH
    .ELSEIF [snakeTail].dir == SNAKE_DOWN
        add [snakeTail].locY, LINE_WIDTH
    .ELSEIF [snakeTail].dir == SNAKE_RIGHT
        add [snakeTail].locX, LINE_WIDTH        
    .ELSE
        sub [snakeTail].locX, LINE_WIDTH
    .ENDIF

@@:

    ;; Draw the snake head
    
    invoke PatBlt, hMemDC, snakeHead.locX, snakeHead.locY, LINE_WIDTH-1, LINE_WIDTH-1, BLACKNESS

    ;; Check if snake tail needs to change direction

    invoke queueView, queue, TRUE
    test eax, eax
    je @F

    assume eax: PTR SNAKELOC
    mov ebx, [eax].locX
    mov ecx, [eax].locY
    
    ;; If current location is same as the first direction change in queue, set the direction in
    ;; the snake tail structure and remove the first item in queue.

    .IF ebx == snakeTail.locX && ecx == snakeTail.locY
        push [eax].dir
        pop snakeTail.dir
        invoke queueDel, queue, NULL, NULL
    .ENDIF
    assume eax: NOTHING
@@:
    ret
drawProc endp

;; This proc generates the new location for the head and checks if the new location meets the
;; death conditions, ie. out of bounds and eating itself

genNewLocProc proc uses edx

    ;; Check if snake's head exceeds the borders of the window

    .IF [snakeHead].dir == SNAKE_UP
        sub snakeHead.locY, LINE_WIDTH
        cmp snakeHead.locY, 0
        jl dieTrue    
    .ELSEIF [snakeHead].dir == SNAKE_DOWN
        add snakeHead.locY, LINE_WIDTH
        cmp snakeHead.locY, WND_SIZE_Y
        je dieTrue
    .ELSEIF [snakeHead].dir == SNAKE_RIGHT
        add snakeHead.locX, LINE_WIDTH
        cmp snakeHead.locX, WND_SIZE_X
        je dieTrue
    .ELSE
        sub snakeHead.locX, LINE_WIDTH
        cmp snakeHead.locX, 0
        jl dieTrue
    .ENDIF

    ;; Check if snake's head touches itself. As snake's colour is black, check for black colour
    ;; (RGB Value 0). If snake tail is currently where snake head would be after moving, it 
    ;; cannot eat its tail

    mov edx, [snakeHead].locY
    mov eax, [snakeHead].locX
    .IF edx == snakeTail.locY && eax == snakeTail.locX
        return FALSE
    .ENDIF        

    invoke GetPixel, hMemDC, eax, edx
    test eax, eax
    je dieTrue  
    return FALSE
dieTrue:
    return TRUE
genNewLocProc endp

;; This procedure checks if snake head is eating the THING

checkEatProc proc uses edx
    mov edx, snakeHead.locX
    mov eax, snakeHead.locY

    .IF edx == ptEat.x && eax == ptEat.y
        mov eax, TRUE
    .ELSE
        mov eax, FALSE
    .ENDIF
    mov bEat, al
    ret
checkEatProc endp

;; This procedure draws the THING for the snake to eat

drawThingProc proc uses esi edi

    ;; bEat is equal to FALSE if it is called by WM_CREATE otherwise it is TRUE

    .IF bEat == TRUE        

        ;; Get random coordinates in multiple of eight and enusre that the colour of that
        ;; coordinate is not black, ie not occupied by the snake body

        .REPEAT
            invoke nrandom, (WND_SIZE_X/8)-1
            mov edi, eax
            shl edi, 3
            invoke nrandom, (WND_SIZE_Y/8)-1
            mov esi, eax
            shl esi, 3
            invoke GetPixel, hMemDC, edi, esi
        .UNTIL eax != 0
    .ELSE

        ;; Set starting coordinates
        
        mov edi, WND_SIZE_X/2
        mov esi, WND_SIZE_Y/2
    .ENDIF                    

    mov ptEat.x, edi
    mov ptEat.y, esi
    mov bEat, FALSE
   
    ;; Draw the THING
 
    invoke GetStockObject, LTGRAY_BRUSH
    invoke SelectObject, hMemDC, eax
    push eax
    invoke PatBlt, hMemDC, ptEat.x, ptEat.y, LINE_WIDTH-1, LINE_WIDTH-1, PATCOPY
    pop eax
    invoke SelectObject, hMemDC, eax
    ret
drawThingProc endp
end start
