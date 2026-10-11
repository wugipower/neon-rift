@echo off
REM Double-click to run all self-tests (P3 data / P4 core / P5 systems / P6 content + full-campaign sim).
set GODOT=D:\Godot\Godot_v4.7.2-stable_win64_console.exe

echo [1/6] Building class cache (import) ...
"%GODOT%" --headless --path "%~dp0." --import

echo [2/6] test_p3 (data framework) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p3.tscn

echo [3/6] test_p4 (battle core) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p4.tscn

echo [4/6] test_p5 (battle systems) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p5.tscn

echo [5/6] test_p6 (content / save / progression) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p6.tscn

echo [6/7] test_p7 (battle item commands) ...
"%GODOT%" --headless --quit-after 600 --path "%~dp0." res://tests/test_p7.tscn

echo [7/7] sim_campaign (auto-play whole game, must reach ending) ...
"%GODOT%" --headless --quit-after 3000 --path "%~dp0." res://tests/sim_campaign.tscn

echo.
echo Finished. Look for the [PASS] or [FAIL] lines above.
pause
