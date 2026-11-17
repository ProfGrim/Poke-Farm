@echo off
setlocal
set "ENGINE=%~dp0..\..\work\godot-bench\engine\Godot_v4.7.2-stable_win64.exe"
if exist "%ENGINE%" (
 start "" "%ENGINE%" --path "%~dp0." --resolution 900x580
) else (
 echo Open project.godot in Godot 4.7.2 to run Shiny Ranch.
 pause
)
