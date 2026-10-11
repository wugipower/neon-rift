@echo off
REM Double-click to open the graphical stat panel (P3 visual check).
set GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe
start "" "%GODOT%" --path "%~dp0." res://scenes/stat_panel.tscn
