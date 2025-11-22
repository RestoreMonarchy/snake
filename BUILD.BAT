@ECHO OFF
REM ============================================================================
REM Build script for Snake Game
REM ============================================================================

ECHO Assembling SNAKE.ASM...
Z:\BOR\TASM.EXE SNAKE.ASM

IF ERRORLEVEL 1 GOTO ERROR

ECHO Linking SNAKE.OBJ...
Z:\BOR\TLINK.EXE SNAKE.OBJ

IF ERRORLEVEL 1 GOTO ERROR

ECHO.
ECHO Build successful! Run SNAKE.EXE to play.
GOTO END

:ERROR
ECHO.
ECHO Build failed! Check errors above.

:END
