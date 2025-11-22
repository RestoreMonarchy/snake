================================================================================
SNAKE GAME - DOS 16-bit Assembly
================================================================================

A classic Snake game written in x86 16-bit assembly for DOS using TASM.

CONTROLS:
  Arrow Keys - Move snake
  ESC        - Quit game

HOW TO BUILD:
  1. Open DOSBox-X
  2. Mount this directory (e.g., MOUNT C C:\Users\micha\source\repos\wsb\snake)
  3. Navigate to C:
  4. Run: BUILD.BAT

HOW TO RUN:
  SNAKE.EXE

FILES:
  SNAKE.ASM  - Main source code
  BUILD.BAT  - Build script
  SNAKE.OBJ  - Object file (generated)
  SNAKE.EXE  - Executable (generated)
  README.TXT - This file

DEVELOPMENT PHASES:
  [X] Phase 1: Basic program structure
  [X] Phase 2: Video system (direct VGA memory)
  [X] Phase 3: Game state initialization
  [X] Phase 4: Keyboard input
  [X] Phase 5: Main game loop
  [X] Phase 6: Snake movement
  [ ] Phase 7: Collision detection
  [X] Phase 8: Food & growth
  [ ] Phase 9: Polish & features
  [ ] Phase 10: Testing

CURRENT STATUS:
  - Game is now playable!
  - Snake moves smoothly with arrow key controls
  - Food eating and growth mechanics working
  - Timer-based delay using INT 1Ah (~165ms per frame)
  - Efficient rendering: only head drawn each frame, tail erased
  - Prevention of 180-degree turns (can't reverse direction)
  - Next: Add collision detection (walls and self-collision)

TECHNICAL DETAILS:
  - Target: DOS 16-bit real mode
  - Assembler: Borland TASM
  - Video: VGA Text Mode 80x25
  - Memory Model: SMALL
  - Video Memory: 0xB800:0000

================================================================================
