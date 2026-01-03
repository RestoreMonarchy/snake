using System;

class SnakeGame
{
    // Video memory segment (in C# we'll use Console instead)
    const int VIDEO_SEG = 0xB800;

    // Game area dimensions
    const int BORDER_LEFT = 5;
    const int BORDER_TOP = 2;
    const int BORDER_RIGHT = 74;
    const int BORDER_BOTTOM = 23;
    const int GAME_WIDTH = 68;
    const int GAME_HEIGHT = 20;

    // Colors (Console colors instead of attribute bytes)
    const ConsoleColor COLOR_BORDER = ConsoleColor.Yellow;
    const ConsoleColor COLOR_SNAKE = ConsoleColor.Green;
    const ConsoleColor COLOR_FOOD = ConsoleColor.Red;
    const ConsoleColor COLOR_SCORE = ConsoleColor.White;
    const ConsoleColor COLOR_BLACK = ConsoleColor.Black;

    // Characters
    const char CHAR_BORDER_H = '═';   // 205
    const char CHAR_BORDER_V = '║';   // 186
    const char CHAR_CORNER_TL = '╔';  // 201
    const char CHAR_CORNER_TR = '╗';  // 187
    const char CHAR_CORNER_BL = '╚';  // 200
    const char CHAR_CORNER_BR = '╝';  // 188
    const char CHAR_SNAKE = '█';      // 219
    const char CHAR_FOOD = '♦';       // 004
    const char CHAR_SPACE = ' ';      // 32

    // Messages
    static string msgTitle = "S N A K E   G A M E";
    static string msgScore = "Score: ";
    static string msgGameOver = "GAME OVER! Score: ";
    static string msgRestart = "Press R to restart, ESC to quit";

    // Game state
    const int MAX_SNAKE_LENGTH = 200;

    // Snake data - two arrays for X and Y coordinates (mirrors snakeX[] and snakeY[])
    static byte[] snakeX = new byte[MAX_SNAKE_LENGTH];
    static byte[] snakeY = new byte[MAX_SNAKE_LENGTH];
    static int snakeLength = 0;
    static int snakeHead = 0;
    static int snakeTail = 0;

    // Direction: 0=up, 1=right, 2=down, 3=left
    static byte direction = 1;   // Start moving right
    static byte nextDir = 1;     // Buffered input

    // Food position
    static byte foodX = 0;
    static byte foodY = 0;

    // Game variables
    static int score = 0;
    static bool gameOver = false;

    // Random for food placement (replaces INT 1Ah timer-based randomness)
    static Random random = new Random();

    // ============================================================================
    // Main Program Entry Point (mirrors START:)
    // ============================================================================
    static void Main(string[] args)
    {
    START:
        // Set video mode (Console setup)
        Console.SetWindowSize(80, 25);
        Console.SetBufferSize(80, 25);
        Console.CursorVisible = false;  // Hide cursor (mirrors MOV CH, 20h)

        // Clear screen
        ClearScreen();

        // Initialize game
        InitGame();

        // Draw initial screen
        DrawBorder();
        DrawTitle();

        // Draw initial snake and food
        DrawAllSnake();

        // Main game loop (mirrors GameLoop:)
        while (true)
        {
            byte key = ProcessInput();

            // Check if ESC was pressed
            if (key == 27)
                goto ExitGame;

            // Check if game is over
            if (gameOver)
                goto ExitGame;

            UpdateGame();
            RenderGame();
            GameDelay();
        }

    ExitGame:
        // Clear screen
        ClearScreen();

        // Display "GAME OVER! Score: "
        DrawString(28, 10, msgGameOver, COLOR_SCORE);

        // Display final score
        string scoreStr = score.ToString("D5");
        DrawString(47, 10, scoreStr, COLOR_SCORE);

        // Display restart message
        DrawString(24, 12, msgRestart, COLOR_BORDER);

    RestartWait:
        // Wait for keypress
        ConsoleKeyInfo keyInfo = Console.ReadKey(true);

        // Check if R key (restart)
        if (keyInfo.KeyChar == 'r' || keyInfo.KeyChar == 'R')
            goto START;

        // Check if ESC key (quit)
        if (keyInfo.Key == ConsoleKey.Escape)
            goto QuitGame;

        // Any other key, keep waiting
        goto RestartWait;

    QuitGame:
        // Show cursor again
        Console.CursorVisible = true;

        // Return to OS (program ends)
        return;
    }

    // ============================================================================
    // ClearScreen - Clear the entire screen with black background
    // ============================================================================
    static void ClearScreen()
    {
        // Mirrors: MOV CX, 2000 / MOV AX, 0020h / REP STOSW
        Console.BackgroundColor = COLOR_BLACK;
        Console.Clear();
    }

    // ============================================================================
    // DrawChar - Draw a character at X,Y position with color
    // Input: col, row, character, color
    // Mirrors the offset calculation: (row * 160) + (col * 2)
    // ============================================================================
    static void DrawChar(int col, int row, char character, ConsoleColor color)
    {
        Console.SetCursorPosition(col, row);
        Console.ForegroundColor = color;
        Console.Write(character);
    }

    // ============================================================================
    // DrawString - Draw null-terminated string at X,Y position
    // Mirrors: LODSB / CMP AL, 0 / JE done / CALL DrawChar / INC DL / JMP loop
    // ============================================================================
    static void DrawString(int col, int row, string str, ConsoleColor color)
    {
        int currentCol = col;
        foreach (char c in str)
        {
            DrawChar(currentCol, row, c, color);
            currentCol++;
        }
    }

    // ============================================================================
    // DrawBorder - Draw the game border
    // ============================================================================
    static void DrawBorder()
    {
        int col, row;

        // Draw top-left corner
        DrawChar(BORDER_LEFT, BORDER_TOP, CHAR_CORNER_TL, COLOR_BORDER);

        // Draw top border (mirrors: MOV CX, GAME_WIDTH / DrawTopBorder: LOOP)
        col = BORDER_LEFT + 1;
        for (int cx = GAME_WIDTH; cx > 0; cx--)
        {
            DrawChar(col, BORDER_TOP, CHAR_BORDER_H, COLOR_BORDER);
            col++;
        }

        // Draw top-right corner
        DrawChar(col, BORDER_TOP, CHAR_CORNER_TR, COLOR_BORDER);

        // Draw sides (mirrors: MOV CX, GAME_HEIGHT / DrawSides: LOOP)
        row = BORDER_TOP + 1;
        for (int cx = GAME_HEIGHT; cx > 0; cx--)
        {
            // Left side
            DrawChar(BORDER_LEFT, row, CHAR_BORDER_V, COLOR_BORDER);
            // Right side
            DrawChar(BORDER_RIGHT, row, CHAR_BORDER_V, COLOR_BORDER);
            row++;
        }

        // Draw bottom-left corner
        DrawChar(BORDER_LEFT, row, CHAR_CORNER_BL, COLOR_BORDER);

        // Draw bottom border
        col = BORDER_LEFT + 1;
        for (int cx = GAME_WIDTH; cx > 0; cx--)
        {
            DrawChar(col, row, CHAR_BORDER_H, COLOR_BORDER);
            col++;
        }

        // Draw bottom-right corner
        DrawChar(col, row, CHAR_CORNER_BR, COLOR_BORDER);
    }

    // ============================================================================
    // DrawTitle - Draw the game title at top
    // ============================================================================
    static void DrawTitle()
    {
        DrawString(30, 0, msgTitle, COLOR_SCORE);
    }

    // ============================================================================
    // InitGame - Initialize game state
    // ============================================================================
    static void InitGame()
    {
        // Reset game variables
        score = 0;
        gameOver = false;
        direction = 1;      // Moving right
        nextDir = 1;

        // Initialize snake in the middle of the game area
        // Start with 3 segments, moving right
        snakeLength = 3;
        snakeHead = 2;      // Head at index 2
        snakeTail = 0;      // Tail at index 0

        // Calculate starting position (center of game area)
        // Mirrors: MOV AL, GAME_WIDTH / SHR AL, 1 / ADD AL, BORDER_LEFT / AND AL, 0FEh
        byte centerX = (byte)(GAME_WIDTH >> 1);  // SHR = divide by 2
        centerX += BORDER_LEFT;
        centerX += 1;
        centerX &= 0xFE;    // AND with 11111110 - make even (align to 2-column grid)

        byte centerY = (byte)(GAME_HEIGHT >> 1);
        centerY += BORDER_TOP;
        centerY += 1;

        // Set up initial snake segments (tail to head) - horizontal spacing = 2
        // Segment 0 (tail)
        snakeX[0] = (byte)(centerX - 4);
        snakeY[0] = centerY;

        // Segment 1 (middle)
        snakeX[1] = (byte)(centerX - 2);
        snakeY[1] = centerY;

        // Segment 2 (head)
        snakeX[2] = centerX;
        snakeY[2] = centerY;

        // Place initial food
        SpawnFood();
    }

    // ============================================================================
    // SpawnFood - Place food at a random empty location
    // Mirrors INT 1Ah timer-based pseudo-random
    // ============================================================================
    static void SpawnFood()
    {
        // Random X position (mirrors: DIV BX / ADD DL, BORDER_LEFT / AND DL, 0FEh)
        int x = random.Next(GAME_WIDTH - 2);
        x += BORDER_LEFT + 2;
        x &= 0xFE;          // Make even (align to 2-column grid)
        foodX = (byte)x;

        // Random Y position
        int y = random.Next(GAME_HEIGHT - 2);
        y += BORDER_TOP + 2;
        foodY = (byte)y;
    }

    // ============================================================================
    // ProcessInput - Check for keyboard input (non-blocking)
    // Mirrors: INT 16h AH=01h (check) then AH=00h (read)
    // ============================================================================
    static byte ProcessInput()
    {
        // Non-blocking check (mirrors: MOV AH, 01h / INT 16h / JZ NoKey)
        if (!Console.KeyAvailable)
            return 0;   // NoKey

        // Key is available, read it (mirrors: MOV AH, 00h / INT 16h)
        ConsoleKeyInfo keyInfo = Console.ReadKey(true);

        // Check ESC key
        if (keyInfo.Key == ConsoleKey.Escape)
            return 27;

        // Handle arrow keys
        // Mirrors the scan code checks: CMP AH, 48h / JE SetUp / etc.
        switch (keyInfo.Key)
        {
            case ConsoleKey.UpArrow:    // SetUp:
                // Can't go up if currently going down
                if (direction != 2)
                    nextDir = 0;
                break;

            case ConsoleKey.RightArrow: // SetRight:
                // Can't go right if currently going left
                if (direction != 3)
                    nextDir = 1;
                break;

            case ConsoleKey.DownArrow:  // SetDown:
                // Can't go down if currently going up
                if (direction != 0)
                    nextDir = 2;
                break;

            case ConsoleKey.LeftArrow:  // SetLeft:
                // Can't go left if currently going right
                if (direction != 1)
                    nextDir = 3;
                break;
        }

        return 0;   // NoKey / InputDone
    }

    // ============================================================================
    // UpdateGame - Update game logic
    // ============================================================================
    static void UpdateGame()
    {
        // Update direction from buffered input
        // Mirrors: MOV AL, [nextDir] / MOV [direction], AL
        direction = nextDir;

        // Get current head position
        // Mirrors: MOV SI, [snakeHead] / MOV DL, [snakeX + SI] / MOV DH, [snakeY + SI]
        int si = snakeHead;
        int dl = snakeX[si];    // New head X
        int dh = snakeY[si];    // New head Y

        // Move based on direction: 0=up, 1=right, 2=down, 3=left
        // Mirrors the CMP AL, 0 / JE MoveUp / etc.
        switch (direction)
        {
            case 0: // MoveUp
                dh--;
                break;
            case 1: // MoveRight
                dl += 2;    // Move 2 columns for horizontal
                break;
            case 2: // MoveDown
                dh++;
                break;
            case 3: // MoveLeft
                dl -= 2;    // Move 2 columns for horizontal
                break;
        }

        // CheckNewPosition:
        // Check for wall collision
        // Mirrors: CMP DL, BORDER_LEFT / JLE CollisionDetected / etc.
        if (dl <= BORDER_LEFT || dl >= BORDER_RIGHT ||
            dh <= BORDER_TOP || dh >= BORDER_BOTTOM)
        {
            // CollisionDetected:
            gameOver = true;
            return;
        }

        // Check for self-collision (only if length > 4)
        // Mirrors: CMP WORD PTR [snakeLength], 4 / JLE NoSelfCollision
        if (snakeLength > 4)
        {
            int di = snakeTail;
            int cx = snakeLength - 1;   // Don't check current head

            // CheckSelfLoop:
            while (cx > 0)
            {
                // Compare new head position with this segment
                if (dl == snakeX[di] && dh == snakeY[di])
                {
                    // HitSelf:
                    gameOver = true;
                    return;
                }

                // NotThisSegment:
                di++;
                if (di >= MAX_SNAKE_LENGTH)
                    di = 0;     // Wrap around (XOR DI, DI)
                cx--;
            }
        }

        // NoSelfCollision:
        // Increment head index (circular buffer)
        // Mirrors: INC SI / CMP SI, MAX_SNAKE_LENGTH / JL NoWrap / XOR SI, SI
        si = snakeHead;
        si++;
        if (si >= MAX_SNAKE_LENGTH)
            si = 0;     // Wrap around
        snakeHead = si;

        // Store new head position
        snakeX[si] = (byte)dl;
        snakeY[si] = (byte)dh;

        // Check if we ate food
        // Mirrors: MOV AL, [foodX] / CMP DL, AL / JNE NoFood
        if (dl == foodX && dh == foodY)
        {
            // Ate food! Grow snake and spawn new food
            snakeLength++;
            score++;
            SpawnFood();
            return;     // JMP UpdateDone (skip tail removal = growth)
        }

        // NoFood:
        // Didn't eat food, remove tail (normal movement)
        // Erase old tail (2 characters wide)
        si = snakeTail;
        int tailX = snakeX[si];
        int tailY = snakeY[si];
        DrawChar(tailX, tailY, CHAR_SPACE, COLOR_BLACK);
        DrawChar(tailX + 1, tailY, CHAR_SPACE, COLOR_BLACK);

        // Move tail forward
        // Mirrors: INC SI / CMP SI, MAX_SNAKE_LENGTH / JL NoTailWrap / XOR SI, SI
        si++;
        if (si >= MAX_SNAKE_LENGTH)
            si = 0;     // Wrap around
        snakeTail = si;

        // UpdateDone: (implicit return)
    }

    // ============================================================================
    // DrawAllSnake - Draw all snake segments (used initially)
    // ============================================================================
    static void DrawAllSnake()
    {
        // Mirrors: XOR SI, SI / MOV CX, [snakeLength]
        int si = 0;
        int cx = snakeLength;

        // DrawAllLoop:
        while (cx > 0)
        {
            // Draw snake segment (2 characters wide)
            int x = snakeX[si];
            int y = snakeY[si];
            DrawChar(x, y, CHAR_SNAKE, COLOR_SNAKE);
            DrawChar(x + 1, y, CHAR_SNAKE, COLOR_SNAKE);

            si++;
            cx--;
        }

        // Also draw the food
        DrawFood();
    }

    // ============================================================================
    // DrawFood - Draw the food
    // ============================================================================
    static void DrawFood()
    {
        DrawChar(foodX, foodY, CHAR_FOOD, COLOR_FOOD);
    }

    // ============================================================================
    // RenderGame - Draw the game screen
    // ============================================================================
    static void RenderGame()
    {
        // Only draw the new head (tail is erased in UpdateGame)
        // Mirrors: MOV SI, [snakeHead] / MOV DL, [snakeX + SI]
        int si = snakeHead;
        int x = snakeX[si];
        int y = snakeY[si];

        // Draw as 2 characters wide
        DrawChar(x, y, CHAR_SNAKE, COLOR_SNAKE);
        DrawChar(x + 1, y, CHAR_SNAKE, COLOR_SNAKE);

        // Redraw food (in case snake moved over it)
        DrawFood();

        // Draw score
        DrawScore();
    }

    // ============================================================================
    // DrawScore - Display the current score
    // ============================================================================
    static void DrawScore()
    {
        // Draw "Score: " label
        DrawString(2, 0, msgScore, COLOR_SCORE);

        // Convert score to string (mirrors NumberToString)
        string scoreStr = score.ToString("D5");  // 5-digit padded

        // Draw score number
        DrawString(9, 0, scoreStr, COLOR_SCORE);
    }

    // ============================================================================
    // GameDelay - Delay to control game speed
    // Mirrors: INT 1Ah wait for 3 ticks (~165ms)
    // ============================================================================
    static void GameDelay()
    {
        // 3 ticks at 18.2 ticks/second = ~165ms
        System.Threading.Thread.Sleep(165);
    }
}
