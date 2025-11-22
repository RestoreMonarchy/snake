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
  [X] Phase 7: Collision detection
  [X] Phase 8: Food & growth
  [X] Phase 9: Polish & features
  [X] Phase 10: Testing

CURRENT STATUS:
  - Game is 100% COMPLETE and fully polished!
  - Snake moves smoothly with arrow key controls
  - Food eating and growth mechanics working perfectly
  - Timer-based delay using INT 1Ah (~165ms per frame)
  - Efficient rendering: only head drawn each frame, tail erased
  - Prevention of 180-degree turns (can't reverse direction)
  - Wall collision detection - game ends when hitting borders
  - Self-collision detection - game ends when snake hits itself
  - Live score display during gameplay (top-left corner)
  - Final score shown on game over screen
  - Restart option: Press R to play again, ESC to quit
  - Professional number-to-string conversion for score display

COMPLETED FEATURES:
  ✓ All core gameplay mechanics
  ✓ Polish and visual enhancements
  ✓ Score tracking and display
  ✓ Restart functionality
  ✓ Clean game over screen

GAME IS READY TO PLAY!

TECHNICAL DETAILS:
  - Target: DOS 16-bit real mode
  - Assembler: Borland TASM
  - Video: VGA Text Mode 80x25
  - Memory Model: SMALL
  - Video Memory: 0xB800:0000

================================================================================
