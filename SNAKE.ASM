; ============================================================================
; SNAKE GAME - DOS 16-bit Assembly (TASM)
; ============================================================================
; Classic Snake game for DOS using VGA text mode
; Controls: Arrow keys to move, ESC to quit
; ============================================================================

.MODEL SMALL
.STACK 100h

.DATA
    ; Video memory segment
    VIDEO_SEG   EQU 0B800h      ; VGA text mode segment

    ; Game area dimensions
    BORDER_LEFT     EQU 5       ; Left border column
    BORDER_TOP      EQU 2       ; Top border row
    BORDER_RIGHT    EQU 74      ; Right border column
    BORDER_BOTTOM   EQU 23      ; Bottom border row
    GAME_WIDTH      EQU 68      ; Playable width (74-5-1)
    GAME_HEIGHT     EQU 20      ; Playable height (23-2-1)

    ; Colors (attribute bytes: high nibble = background, low nibble = foreground)
    COLOR_BORDER    EQU 0Eh     ; Yellow
    COLOR_SNAKE     EQU 0Ah     ; Light green
    COLOR_FOOD      EQU 0Ch     ; Light red
    COLOR_SCORE     EQU 0Fh     ; White
    COLOR_BLACK     EQU 00h     ; Black

    ; Characters
    CHAR_BORDER_H   EQU 205     ; ═ horizontal border
    CHAR_BORDER_V   EQU 186     ; ║ vertical border
    CHAR_CORNER_TL  EQU 201     ; ╔ top-left corner
    CHAR_CORNER_TR  EQU 187     ; ╗ top-right corner
    CHAR_CORNER_BL  EQU 200     ; ╚ bottom-left corner
    CHAR_CORNER_BR  EQU 188     ; ╝ bottom-right corner
    CHAR_SNAKE      EQU 219     ; █ solid block
    CHAR_FOOD       EQU 004     ; ♦ diamond
    CHAR_SPACE      EQU 32      ; space

    ; Messages
    msgTitle    DB 'S N A K E   G A M E', 0
    msgScore    DB 'Score: ', 0
    msgGameOver DB 'GAME OVER! Press any key...', 0
    msgPaused   DB 'PAUSED - Press P to continue', 0

    ; Game state
    MAX_SNAKE_LENGTH EQU 200    ; Maximum snake segments

    ; Snake data - using two arrays for X and Y coordinates
    snakeX      DB MAX_SNAKE_LENGTH DUP(0)  ; X coordinates
    snakeY      DB MAX_SNAKE_LENGTH DUP(0)  ; Y coordinates
    snakeLength DW 0                         ; Current snake length
    snakeHead   DW 0                         ; Index of head in array
    snakeTail   DW 0                         ; Index of tail in array

    ; Direction: 0=up, 1=right, 2=down, 3=left
    direction   DB 1                         ; Start moving right
    nextDir     DB 1                         ; Next direction (for input buffering)

    ; Food position
    foodX       DB 0
    foodY       DB 0

    ; Game variables
    score       DW 0                         ; Current score
    gameOver    DB 0                         ; 0=playing, 1=game over
    growFlag    DB 0                         ; 1=snake should grow this frame

.CODE

; ============================================================================
; Main Program Entry Point
; ============================================================================
START:
    MOV AX, @DATA           ; Initialize data segment
    MOV DS, AX

    ; Set video mode to 80x25 text mode (mode 3)
    MOV AH, 00h             ; BIOS video - set mode
    MOV AL, 03h             ; 80x25 text mode
    INT 10h                 ; Call BIOS

    ; Hide cursor
    MOV AH, 01h             ; BIOS set cursor type
    MOV CH, 20h             ; Invisible cursor
    MOV CL, 00h
    INT 10h

    ; Clear screen
    CALL ClearScreen

    ; Initialize game
    CALL InitGame

    ; Draw initial screen
    CALL DrawBorder
    CALL DrawTitle

    ; Main game loop
GameLoop:
    CALL ProcessInput       ; Check for keyboard input

    ; Check if ESC was pressed (handled in ProcessInput)
    CMP AL, 27              ; ESC key
    JE ExitGame

    CALL UpdateGame         ; Update game state
    CALL RenderGame         ; Draw everything
    CALL GameDelay          ; Delay for game speed

    JMP GameLoop

ExitGame:
    ; Show cursor again
    MOV AH, 01h             ; BIOS set cursor type
    MOV CH, 06h             ; Normal cursor
    MOV CL, 07h
    INT 10h

    ; Clear screen
    CALL ClearScreen

    ; Display game over message centered
    MOV DL, 26              ; Column (centered approximately)
    MOV DH, 12              ; Row (middle of screen)
    MOV BL, COLOR_SCORE     ; White text
    LEA SI, msgGameOver
    CALL DrawString

    ; Wait for keypress before exit
    MOV AH, 00h
    INT 16h

    ; Return to DOS
    MOV AH, 4Ch             ; DOS function - terminate
    MOV AL, 00h             ; Return code 0
    INT 21h

; ============================================================================
; ClearScreen - Clear the entire screen with black background
; ============================================================================
ClearScreen PROC
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH ES

    ; Point ES:DI to video memory
    MOV AX, VIDEO_SEG
    MOV ES, AX
    XOR DI, DI              ; Start at offset 0

    ; Clear 2000 words (80x25 = 2000 characters)
    MOV CX, 2000
    MOV AX, 0020h           ; Space character with black attribute
    REP STOSW               ; Fill video memory

    POP ES
    POP DI
    POP CX
    POP AX
    RET
ClearScreen ENDP

; ============================================================================
; DrawChar - Draw a character at X,Y position with color
; Input: DL=column, DH=row, AL=character, BL=color attribute
; ============================================================================
DrawChar PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH ES

    ; Save character and color in safe place
    MOV CL, AL          ; CL = character
    MOV CH, BL          ; CH = color

    ; Point ES to video memory
    MOV AX, VIDEO_SEG
    MOV ES, AX

    ; Calculate offset = (row * 160) + (col * 2)
    ; Row is in DH, Column is in DL
    MOV AL, DH          ; AL = row
    MOV AH, 0           ; Clear AH
    MOV BL, 160         ; 160 bytes per row
    MUL BL              ; AX = row * 160 (8-bit multiply!)

    MOV BL, DL          ; BL = column
    MOV BH, 0           ; Clear BH
    SHL BX, 1           ; BX = column * 2

    ADD AX, BX          ; AX = (row * 160) + (col * 2)
    MOV DI, AX          ; DI = offset

    ; Write character and attribute to video memory
    MOV AL, CL          ; AL = character
    MOV AH, CH          ; AH = color
    MOV ES:[DI], AX     ; Write both bytes at once

    POP ES
    POP DI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
DrawChar ENDP

; ============================================================================
; DrawString - Draw null-terminated string at X,Y position
; Input: DL=column, DH=row, SI=string address, BL=color
; ============================================================================
DrawString PROC
    PUSH AX
    PUSH DX
    PUSH SI

DrawStringLoop:
    LODSB                   ; Load byte from DS:SI into AL, increment SI
    CMP AL, 0               ; Check for null terminator
    JE DrawStringDone

    CALL DrawChar           ; Draw character
    INC DL                  ; Move to next column
    JMP DrawStringLoop

DrawStringDone:
    POP SI
    POP DX
    POP AX
    RET
DrawString ENDP

; ============================================================================
; DrawBorder - Draw the game border
; ============================================================================
DrawBorder PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV BL, COLOR_BORDER    ; Yellow border

    ; Draw top-left corner
    MOV DL, BORDER_LEFT
    MOV DH, BORDER_TOP
    MOV AL, CHAR_CORNER_TL
    CALL DrawChar

    ; Draw top border
    MOV CX, GAME_WIDTH
    INC DL
DrawTopBorder:
    MOV AL, CHAR_BORDER_H
    CALL DrawChar
    INC DL
    LOOP DrawTopBorder

    ; Draw top-right corner
    MOV AL, CHAR_CORNER_TR
    CALL DrawChar

    ; Draw sides
    MOV CX, GAME_HEIGHT
    INC DH
DrawSides:
    PUSH CX

    ; Left side
    MOV DL, BORDER_LEFT
    MOV AL, CHAR_BORDER_V
    CALL DrawChar

    ; Right side
    MOV DL, BORDER_RIGHT
    MOV AL, CHAR_BORDER_V
    CALL DrawChar

    INC DH
    POP CX
    LOOP DrawSides

    ; Draw bottom-left corner
    MOV DL, BORDER_LEFT
    MOV AL, CHAR_CORNER_BL
    CALL DrawChar

    ; Draw bottom border
    MOV CX, GAME_WIDTH
    INC DL
DrawBottomBorder:
    MOV AL, CHAR_BORDER_H
    CALL DrawChar
    INC DL
    LOOP DrawBottomBorder

    ; Draw bottom-right corner
    MOV AL, CHAR_CORNER_BR
    CALL DrawChar

    POP DX
    POP CX
    POP BX
    POP AX
    RET
DrawBorder ENDP

; ============================================================================
; DrawTitle - Draw the game title at top
; ============================================================================
DrawTitle PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    MOV DL, 30              ; Centered position
    MOV DH, 0               ; Top row
    MOV BL, COLOR_SCORE     ; White text
    LEA SI, msgTitle
    CALL DrawString

    POP SI
    POP DX
    POP BX
    POP AX
    RET
DrawTitle ENDP

; ============================================================================
; InitGame - Initialize game state
; ============================================================================
InitGame PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    ; Reset game variables
    MOV WORD PTR [score], 0
    MOV BYTE PTR [gameOver], 0
    MOV BYTE PTR [growFlag], 0
    MOV BYTE PTR [direction], 1     ; Moving right
    MOV BYTE PTR [nextDir], 1

    ; Initialize snake in the middle of the game area
    ; Start with 3 segments, moving right
    MOV WORD PTR [snakeLength], 3
    MOV WORD PTR [snakeHead], 2     ; Head at index 2
    MOV WORD PTR [snakeTail], 0     ; Tail at index 0

    ; Calculate starting position (center of game area)
    MOV AL, GAME_WIDTH
    SHR AL, 1                       ; AL = center X
    ADD AL, BORDER_LEFT
    ADD AL, 1                       ; Adjust for border

    MOV BL, GAME_HEIGHT
    SHR BL, 1                       ; BL = center Y
    ADD BL, BORDER_TOP
    ADD BL, 1                       ; Adjust for border

    ; Set up initial snake segments (tail to head)
    ; Segment 0 (tail)
    MOV SI, 0
    MOV [snakeX + SI], AL
    SUB BYTE PTR [snakeX + SI], 2   ; Two cells to the left
    MOV [snakeY + SI], BL

    ; Segment 1 (middle)
    MOV SI, 1
    MOV [snakeX + SI], AL
    DEC BYTE PTR [snakeX + SI]      ; One cell to the left
    MOV [snakeY + SI], BL

    ; Segment 2 (head)
    MOV SI, 2
    MOV [snakeX + SI], AL           ; Center position
    MOV [snakeY + SI], BL

    ; Place initial food
    CALL SpawnFood

    POP SI
    POP CX
    POP BX
    POP AX
    RET
InitGame ENDP

; ============================================================================
; SpawnFood - Place food at a random empty location
; ============================================================================
SpawnFood PROC
    PUSH AX
    PUSH BX
    PUSH DX

    ; For now, use a simple pseudo-random position
    ; In a real implementation, we'd check for collisions with snake

    ; Get a pseudo-random number using BIOS timer
    MOV AH, 00h
    INT 1Ah                         ; Get system time, CX:DX = tick count

    ; Use DL for X position
    MOV AX, DX
    XOR DX, DX
    MOV BX, GAME_WIDTH
    SUB BX, 2                       ; Leave some margin
    DIV BX                          ; DX = remainder (0 to GAME_WIDTH-3)
    ADD DL, BORDER_LEFT
    ADD DL, 2
    MOV [foodX], DL

    ; Use timer for Y position
    MOV AH, 00h
    INT 1Ah
    MOV AX, CX                      ; Use CX this time
    XOR DX, DX
    MOV BX, GAME_HEIGHT
    SUB BX, 2
    DIV BX
    ADD DL, BORDER_TOP
    ADD DL, 2
    MOV [foodY], DL

    POP DX
    POP BX
    POP AX
    RET
SpawnFood ENDP

; ============================================================================
; ProcessInput - Check for keyboard input (non-blocking)
; ============================================================================
ProcessInput PROC
    PUSH BX

    MOV AH, 01h             ; BIOS keyboard - check for keystroke
    INT 16h
    JZ NoKey                ; ZF=1 means no key available

    ; Key is available, read it
    MOV AH, 00h             ; BIOS keyboard - read keystroke
    INT 16h

    ; AL contains ASCII code, AH contains scan code
    ; For now, just check ESC
    CMP AL, 27              ; ESC key
    JE InputDone

    ; TODO: Handle arrow keys (check AH for scan codes)
    ; Up=48h, Left=4Bh, Right=4Dh, Down=50h

NoKey:
InputDone:
    POP BX
    RET
ProcessInput ENDP

; ============================================================================
; UpdateGame - Update game logic
; ============================================================================
UpdateGame PROC
    PUSH AX

    ; TODO: Move snake, check collisions, update score, etc.

    POP AX
    RET
UpdateGame ENDP

; ============================================================================
; RenderGame - Draw the game screen
; ============================================================================
RenderGame PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Draw all snake segments
    XOR SI, SI              ; Start at index 0
    MOV CX, [snakeLength]   ; Number of segments to draw

DrawSnakeLoop:
    CMP CX, 0
    JE DrawSnakeDone

    ; Get X,Y for this segment
    MOV DL, [snakeX + SI]
    MOV DH, [snakeY + SI]
    MOV AL, CHAR_SNAKE
    MOV BL, COLOR_SNAKE
    CALL DrawChar

    INC SI
    DEC CX
    JMP DrawSnakeLoop

DrawSnakeDone:
    ; Draw food
    MOV DL, [foodX]
    MOV DH, [foodY]
    MOV AL, CHAR_FOOD
    MOV BL, COLOR_FOOD
    CALL DrawChar

    ; TODO: Draw score

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
RenderGame ENDP

; ============================================================================
; GameDelay - Delay to control game speed
; ============================================================================
GameDelay PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Simple delay loop - adjust for desired speed
    MOV CX, 0002h           ; High word of delay
    MOV DX, 0000h           ; Low word of delay
DelayLoop:
    DEC DX
    JNZ DelayLoop
    DEC CX
    JNZ DelayLoop

    POP DX
    POP CX
    POP BX
    POP AX
    RET
GameDelay ENDP

END START
