@echo off
title RDR2 RealVR - Revert lockfree popup fix
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch_realvr.ps1" -Revert
echo.
pause
