@echo off
REM Double-click to run the P3 data-framework self-test.
REM Edit GODOT below if your Godot console exe is in another folder.
set GODOT=D:\Godot\Godot_v4.7.2-stable_win64_console.exe

echo [1/2] Building class cache (import) ...
"%GODOT%" --headless --path "%~dp0." --import

echo [2/2] Running test_p3 ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p3.tscn

echo.
echo Finished. Look for the [PASS] or [FAIL] line in the output above.
pause
