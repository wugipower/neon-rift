@echo off
REM Double-click to run all self-tests (P3 data + P4 battle core + P5 battle systems).
set GODOT=D:\Godot\Godot_v4.7.2-stable_win64_console.exe

echo [1/4] Building class cache (import) ...
"%GODOT%" --headless --path "%~dp0." --import

echo [2/4] Running test_p3 (data framework) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p3.tscn

echo [3/4] Running test_p4 (battle core) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p4.tscn

echo [4/4] Running test_p5 (battle systems: status/skill/AI/equip/exp) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p5.tscn

echo.
echo Finished. Look for the [PASS] or [FAIL] lines above.
pause
