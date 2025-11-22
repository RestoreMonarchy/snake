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
    scoreStr    DB '00000', 0   ; String buffer for score display
    msgGameOver DB 'GAME OVER! Score: ', 0
    msgRestart  DB 'Press R to restart, ESC to quit', 0
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

    ; Draw initial snake and food
    CALL DrawAllSnake

    ; Main game loop
GameLoop:
    CALL ProcessInput       ; Check for keyboard input

    ; Check if ESC was pressed (handled in ProcessInput)
    CMP AL, 27              ; ESC key
    JE ExitGame

    ; Check if game is over
    CMP BYTE PTR [gameOver], 1
    JE ExitGame

    CALL UpdateGame         ; Update game state
    CALL RenderGame         ; Draw everything
    CALL GameDelay          ; Delay for game speed

    JMP GameLoop

ExitGame:
    ; Clear screen
    CALL ClearScreen

    ; Display "GAME OVER! Score: "
    MOV DL, 20
    MOV DH, 10
    MOV BL, COLOR_SCORE
    LEA SI, msgGameOver
    CALL DrawString

    ; Display final score
    MOV AX, [score]
    LEA SI, scoreStr
    CALL NumberToString
    MOV DL, 39
    MOV DH, 10
    MOV BL, COLOR_SCORE
    LEA SI, scoreStr
    CALL DrawString

    ; Display restart message
    MOV DL, 15
    MOV DH, 12
    MOV BL, COLOR_BORDER
    LEA SI, msgRestart
    CALL DrawString

RestartWait:
    ; Wait for keypress
    MOV AH, 00h
    INT 16h

    ; Check if R key (restart)
    CMP AL, 'r'
    JE RestartGame
    CMP AL, 'R'
    JE RestartGame

    ; Check if ESC key (quit)
    CMP AL, 27
    JE QuitGame

    ; Any other key, keep waiting
    JMP RestartWait

RestartGame:
    ; Restart the game from the beginning
    JMP START

QuitGame:
    ; Show cursor again
    MOV AH, 01h             ; BIOS set cursor type
    MOV CH, 06h             ; Normal cursor
    MOV CL, 07h
    INT 10h

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
    AND AL, 0FEh                    ; Make it even (align to 2-column grid)

    MOV BL, GAME_HEIGHT
    SHR BL, 1                       ; BL = center Y
    ADD BL, BORDER_TOP
    ADD BL, 1                       ; Adjust for border

    ; Set up initial snake segments (tail to head) - horizontal spacing = 2
    ; Segment 0 (tail)
    MOV SI, 0
    MOV [snakeX + SI], AL
    SUB BYTE PTR [snakeX + SI], 4   ; Four columns to the left
    MOV [snakeY + SI], BL

    ; Segment 1 (middle)
    MOV SI, 1
    MOV [snakeX + SI], AL
    SUB BYTE PTR [snakeX + SI], 2   ; Two columns to the left
    MOV [snakeY + SI], BL

    ; Segment 2 (head)
    MOV SI, 2
    MOV [snakeX + SI], AL           ; Center position (even)
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
    AND DL, 0FEh                    ; Make it even (align to 2-column grid)
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
    PUSH CX

    MOV AH, 01h             ; BIOS keyboard - check for keystroke
    INT 16h
    JZ NoKey                ; ZF=1 means no key available

    ; Key is available, read it
    MOV AH, 00h             ; BIOS keyboard - read keystroke
    INT 16h

    ; AL contains ASCII code, AH contains scan code
    ; Check ESC key
    CMP AL, 27              ; ESC key
    JE InputDone

    ; Handle arrow keys (extended keys have scan codes in AH)
    ; Arrow keys: Up=48h, Left=4Bh, Right=4Dh, Down=50h
    ; Direction: 0=up, 1=right, 2=down, 3=left

    CMP AH, 48h             ; Up arrow
    JE SetUp
    CMP AH, 4Dh             ; Right arrow
    JE SetRight
    CMP AH, 50h             ; Down arrow
    JE SetDown
    CMP AH, 4Bh             ; Left arrow
    JE SetLeft
    JMP NoKey               ; Not an arrow key, ignore

SetUp:
    ; Can't go up if currently going down
    MOV BL, [direction]
    CMP BL, 2               ; Check if going down
    JE NoKey
    MOV BYTE PTR [nextDir], 0
    JMP NoKey

SetRight:
    ; Can't go right if currently going left
    MOV BL, [direction]
    CMP BL, 3               ; Check if going left
    JE NoKey
    MOV BYTE PTR [nextDir], 1
    JMP NoKey

SetDown:
    ; Can't go down if currently going up
    MOV BL, [direction]
    CMP BL, 0               ; Check if going up
    JE NoKey
    MOV BYTE PTR [nextDir], 2
    JMP NoKey

SetLeft:
    ; Can't go left if currently going right
    MOV BL, [direction]
    CMP BL, 1               ; Check if going right
    JE NoKey
    MOV BYTE PTR [nextDir], 3

NoKey:
InputDone:
    POP CX
    POP BX
    RET
ProcessInput ENDP

; ============================================================================
; UpdateGame - Update game logic
; ============================================================================
UpdateGame PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Update direction from buffered input
    MOV AL, [nextDir]
    MOV [direction], AL

    ; Calculate new head position based on direction
    MOV SI, [snakeHead]
    MOV DL, [snakeX + SI]       ; Current head X
    MOV DH, [snakeY + SI]       ; Current head Y

    ; Move based on direction: 0=up, 1=right, 2=down, 3=left
    MOV AL, [direction]
    CMP AL, 0
    JE MoveUp
    CMP AL, 1
    JE MoveRight
    CMP AL, 2
    JE MoveDown
    JMP MoveLeft

MoveUp:
    DEC DH
    JMP CheckNewPosition

MoveRight:
    INC DL
    INC DL              ; Move 2 columns for horizontal
    JMP CheckNewPosition

MoveDown:
    INC DH
    JMP CheckNewPosition

MoveLeft:
    DEC DL
    DEC DL              ; Move 2 columns for horizontal

CheckNewPosition:
    ; Check for wall collision
    CMP DL, BORDER_LEFT
    JLE CollisionDetected
    CMP DL, BORDER_RIGHT
    JGE CollisionDetected
    CMP DH, BORDER_TOP
    JLE CollisionDetected
    CMP DH, BORDER_BOTTOM
    JGE CollisionDetected

    ; Check for self-collision
    ; Only check if snake is long enough (length > 4)
    CMP WORD PTR [snakeLength], 4
    JLE NoSelfCollision

    PUSH CX
    PUSH DI

    ; Start from tail, check all segments except the head
    MOV DI, [snakeTail]
    MOV CX, [snakeLength]
    DEC CX                  ; Don't check the current head position

CheckSelfLoop:
    CMP CX, 0
    JLE NoSelfCollision_Pop

    ; Compare new head position with this segment
    CMP DL, [snakeX + DI]
    JNE NotThisSegment
    CMP DH, [snakeY + DI]
    JE HitSelf              ; Same position = collision!

NotThisSegment:
    INC DI
    CMP DI, MAX_SNAKE_LENGTH
    JL NoWrapCheck
    XOR DI, DI
NoWrapCheck:
    DEC CX
    JMP CheckSelfLoop

NoSelfCollision_Pop:
    POP DI
    POP CX
    JMP NoSelfCollision

HitSelf:
    POP DI
    POP CX

CollisionDetected:
    ; Set game over flag and exit
    MOV BYTE PTR [gameOver], 1
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

NoSelfCollision:
    ; No collision - continue with normal movement
    ; Increment head index (circular buffer)
    MOV SI, [snakeHead]
    INC SI
    CMP SI, MAX_SNAKE_LENGTH
    JL NoWrap
    XOR SI, SI                  ; Wrap around to 0
NoWrap:
    MOV [snakeHead], SI

    ; Store new head position
    MOV [snakeX + SI], DL
    MOV [snakeY + SI], DH

    ; Check if we ate food
    MOV AL, [foodX]
    CMP DL, AL
    JNE NoFood
    MOV AL, [foodY]
    CMP DH, AL
    JNE NoFood

    ; Ate food! Grow snake and spawn new food
    INC WORD PTR [snakeLength]
    INC WORD PTR [score]
    CALL SpawnFood
    JMP UpdateDone

NoFood:
    ; Didn't eat food, remove tail (normal movement)
    ; Erase old tail (2 characters wide)
    MOV SI, [snakeTail]
    MOV DL, [snakeX + SI]
    MOV DH, [snakeY + SI]
    MOV AL, CHAR_SPACE
    MOV BL, COLOR_BLACK
    CALL DrawChar

    ; Erase second character
    INC DL
    CALL DrawChar

    ; Move tail forward
    INC SI
    CMP SI, MAX_SNAKE_LENGTH
    JL NoTailWrap
    XOR SI, SI
NoTailWrap:
    MOV [snakeTail], SI

UpdateDone:
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
UpdateGame ENDP

; ============================================================================
; DrawAllSnake - Draw all snake segments (used initially)
; ============================================================================
DrawAllSnake PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    XOR SI, SI              ; Start at index 0
    MOV CX, [snakeLength]   ; Number of segments to draw

DrawAllLoop:
    CMP CX, 0
    JE DrawAllDone

    ; Draw snake segment (2 characters wide)
    MOV DL, [snakeX + SI]
    MOV DH, [snakeY + SI]
    MOV AL, CHAR_SNAKE
    MOV BL, COLOR_SNAKE
    CALL DrawChar

    ; Draw second character for width
    INC DL
    CALL DrawChar

    INC SI
    DEC CX
    JMP DrawAllLoop

DrawAllDone:
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
DrawAllSnake ENDP

; ============================================================================
; DrawFood - Draw the food
; ============================================================================
DrawFood PROC
    PUSH AX
    PUSH BX
    PUSH DX

    MOV DL, [foodX]
    MOV DH, [foodY]
    MOV AL, CHAR_FOOD
    MOV BL, COLOR_FOOD
    CALL DrawChar

    POP DX
    POP BX
    POP AX
    RET
DrawFood ENDP

; ============================================================================
; RenderGame - Draw the game screen
; ============================================================================
RenderGame PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    ; Only draw the new head (tail is erased in UpdateGame)
    ; Draw as 2 characters wide
    MOV SI, [snakeHead]
    MOV DL, [snakeX + SI]
    MOV DH, [snakeY + SI]
    MOV AL, CHAR_SNAKE
    MOV BL, COLOR_SNAKE
    CALL DrawChar

    ; Draw second character for width
    INC DL
    CALL DrawChar

    ; Redraw food (in case snake moved over it)
    CALL DrawFood

    ; Draw score
    CALL DrawScore

    POP SI
    POP DX
    POP BX
    POP AX
    RET
RenderGame ENDP

; ============================================================================
; DrawScore - Display the current score
; ============================================================================
DrawScore PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    ; Draw "Score: " label
    MOV DL, 2
    MOV DH, 0
    MOV BL, COLOR_SCORE
    LEA SI, msgScore
    CALL DrawString

    ; Convert score to string
    MOV AX, [score]
    LEA SI, scoreStr
    CALL NumberToString

    ; Draw score number
    MOV DL, 9
    MOV DH, 0
    MOV BL, COLOR_SCORE
    LEA SI, scoreStr
    CALL DrawString

    POP SI
    POP DX
    POP BX
    POP AX
    RET
DrawScore ENDP

; ============================================================================
; NumberToString - Convert number in AX to decimal string
; Input: AX = number, SI = buffer address (must be 6 bytes)
; Output: SI points to null-terminated string
; ============================================================================
NumberToString PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    MOV DI, SI
    ADD DI, 4               ; Start at end of buffer (5 digits)
    MOV BYTE PTR [DI+1], 0  ; Null terminator

    MOV BX, 10              ; Divisor
    MOV CX, 5               ; Number of digits

ConvertLoop:
    XOR DX, DX              ; Clear DX for division
    DIV BX                  ; AX / 10, quotient in AX, remainder in DX
    ADD DL, '0'             ; Convert to ASCII
    MOV [DI], DL            ; Store digit
    DEC DI
    DEC CX
    CMP CX, 0
    JNE ConvertLoop

    POP DI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
NumberToString ENDP

; ============================================================================
; GameDelay - Delay to control game speed
; ============================================================================
GameDelay PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Use system timer (18.2 ticks per second)
    ; Wait for 3 ticks = ~165ms
    MOV AH, 00h
    INT 1Ah                 ; Get current tick count in CX:DX
    MOV BX, DX              ; Save starting tick count
    ADD BX, 3               ; Wait for 3 ticks

WaitLoop:
    MOV AH, 00h
    INT 1Ah                 ; Get current tick count
    CMP DX, BX              ; Compare with target
    JL WaitLoop             ; Keep waiting

    POP DX
    POP CX
    POP BX
    POP AX
    RET
GameDelay ENDP

END START
