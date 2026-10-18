@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install-katago.ps1"
if errorlevel 1 echo AI installation failed. Please read the message above and retry.
pause
