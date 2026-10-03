@echo off
setlocal
cd /d "%~dp0"
tasm -68 -x3 -b -g3 microchess-expanded.asm microchess-expanded.bin microchess-expanded-tasm.lst
if errorlevel 1 exit /b 1
py -3 pack-expanded.py microchess-expanded.bin microchess-expanded.c10
if errorlevel 1 exit /b 1
