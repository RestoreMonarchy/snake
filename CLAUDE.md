# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a classic Snake game written in x86 16-bit assembly language for DOS, assembled with TASM (Turbo Assembler). The entire game is contained in a single assembly file (`SNAKE.ASM`) and uses VGA text mode (80x25) for graphics.

## Building and Testing

### Quick Start (Recommended)
Simply run:
```powershell
.\run.ps1
```

This script:
1. Copies `SNAKE.ASM` and `BUILD.BAT` to `DOSBox-X/drived/`
2. Launches DOSBox-X
3. DOSBox-X autostart (`dosbox-x.conf` `[autoexec]` section) automatically:
   - Mounts `drived/` as `D:`
   - Runs `BUILD.BAT` (TASM + TLINK)
   - Launches `SNAKE.EXE` if build succeeds

### Prerequisites
- DOSBox-X emulator (included in `DOSBox-X/` directory)
- TASM and TLINK are available in DOSBox-X at `Z:\BOR\`

### Manual Build Process
If you need to build manually inside DOSBox-X:

1. **Build** (from D: drive):
   ```
   BUILD.BAT
   ```
   This runs TASM to assemble `SNAKE.ASM` → `SNAKE.OBJ`, then TLINK to link → `SNAKE.EXE`

2. **Run the game**:
   ```
   SNAKE.EXE
   ```

3. **Debug** (optional): Turbo Debugger is available at `Z:\BOR\TD.EXE`

## Code Architecture

### Memory Model
- **Small model**: Code and data in separate 64KB segments
- **Video memory**: Direct writes to segment 0B800h (VGA text mode)
- **Data structures**: All game state in `.DATA` segment

### Key Design Patterns

**Circular Buffer for Snake**: 
- Snake segments stored in parallel arrays `snakeX[]` and `snakeY[]` (max 200 segments)
- `snakeHead` and `snakeTail` indices wrap around using modulo MAX_SNAKE_LENGTH
- When snake moves: increment head index, add new position, optionally remove tail

**2-Character Wide Snake**:
- Snake is 2 characters wide (using █ character 219) to balance horizontal/vertical movement speed
- All X coordinates aligned to 2-column grid (even values using `AND AL, 0FEh`)
- Horizontal movement: `±2 columns`, Vertical movement: `±1 row`
- This ensures consistent visual speed in all directions (compensates for text mode aspect ratio)

**Direct Video Memory Access**:
- Offset calculation: `(row * 160) + (col * 2)`
- Each character = 2 bytes (character + attribute)
- No BIOS calls during gameplay for performance

**Non-blocking Input**:
- INT 16h function 01h checks for keystroke without waiting
- Direction buffered in `nextDir` to allow input between frames
- Prevents 180-degree turns (can't reverse into yourself)

### Rendering Strategy
- **Full redraw**: Entire snake redrawn each frame to prevent visual gaps at corners
- **2-char erasure**: Both characters of tail must be erased when moving
- Game border drawn once at initialization

### Collision Detection
- **Wall collision**: Check new head position against border constants
- **Self-collision**: Only checked when length > 4, compares new head against all existing segments (excluding current head)
- Both trigger `gameOver` flag

### Text Centering
When centering text on the 80-column screen, calculate position as:
```
column = (80 - total_text_length) / 2
```
Example: "GAME OVER! Score: 00000" = 24 chars → column 28

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `InitGame` | Resets game state, positions snake at center, spawns initial food |
| `UpdateGame` | Main logic: moves snake, checks collisions, handles food eating |
| `RenderGame` | Draws entire snake (fixes corner gaps), food, and score |
| `DrawAllSnake` | Initial full snake draw (used at game start) |
| `ProcessInput` | Non-blocking keyboard check, buffers direction changes |
| `SpawnFood` | Places food at pseudo-random grid-aligned position |
| `DrawChar` | Low-level: writes character+attribute to video memory |
| `DrawString` | Draws null-terminated string at position |
| `NumberToString` | Converts AX to 5-digit decimal string |
| `GameDelay` | Waits 3 timer ticks (~165ms) for game speed |

## Game Constants

Key constants that affect gameplay:
- `BORDER_LEFT/TOP/RIGHT/BOTTOM`: Game area boundaries (5, 2, 74, 23)
- `GAME_WIDTH/HEIGHT`: Playable area (68 x 20)
- `MAX_SNAKE_LENGTH`: 200 segments
- Game delay: 3 timer ticks (~165ms per frame using INT 1Ah)

## Important Implementation Details

- **Grid alignment**: All positions (snake, food) must use even X coordinates for 2-column grid
- **Snake drawing**: Always draw 2 characters for each segment
- **Food spawning**: Uses BIOS timer (INT 1Ah) for pseudo-random placement, aligned to grid
- **Score display**: Custom decimal conversion (`NumberToString`) converts AX to 5-digit string
