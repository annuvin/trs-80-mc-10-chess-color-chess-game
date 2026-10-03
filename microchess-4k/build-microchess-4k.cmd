@echo off
setlocal
cd /d "%~dp0"
rem Telemark TASM with TASM68.TAB; substitute tasm32 if that is its name.
tasm -68 -x3 -b -g3 microchess-4k.asm microchess-4k.bin microchess-4k-tasm.lst
if errorlevel 1 exit /b 1
py -3 pack-microchess-4k.py microchess-4k.bin microchess-4k.c10
if errorlevel 1 exit /b 1
