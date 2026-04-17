@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "VENV_PYTHON=%SCRIPT_DIR%.venv\Scripts\python.exe"

if exist "%VENV_PYTHON%" goto run_tool

py -3 --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "SYSTEM_PYTHON=py -3"
    goto create_venv
)

python --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "SYSTEM_PYTHON=python"
    goto create_venv
)

echo Error: Python 3 is required but was not found.
exit /b 1

:create_venv
%SYSTEM_PYTHON% -m venv "%SCRIPT_DIR%.venv"
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

"%VENV_PYTHON%" -m pip install -r "%SCRIPT_DIR%requirements.txt"
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

:run_tool
"%VENV_PYTHON%" "%SCRIPT_DIR%get_eap_book.py" %*
exit /b %ERRORLEVEL%
