@echo off
REM Double-click to open the P5 battle demo (3v3, skills/status/element/enemy-AI).
set GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe
start "" "%GODOT%" --path "%~dp0." res://scenes/battle.tscn
