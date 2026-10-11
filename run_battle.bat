@echo off
REM Double-click to open the P4 battle demo (placeholder-art 1v1).
set GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe
start "" "%GODOT%" --path "%~dp0." res://scenes/battle.tscn
