@echo off
title RDR2 RealVR - Apply lockfree popup fix
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch_realvr.ps1"
echo.
pause
