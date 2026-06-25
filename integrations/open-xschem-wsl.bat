@echo off
rem LibMan (Windows) -> Xschem (WSL) launcher for .sch / .sym / .schematic.core / .symbol.core
rem Tool Manager -> Schematic tab -> point to this .bat file (any checkout path).

setlocal EnableExtensions

if "%~1"=="" (
  echo usage: %~nx0 ^<view-file-path^>
  exit /b 1
)

wsl --cd "%~dp0" sed -i "s/\r$//" ./open-xschem-wsl.sh 2>nul
wsl --cd "%~dp0" bash ./open-xschem-wsl.sh "%~1"
