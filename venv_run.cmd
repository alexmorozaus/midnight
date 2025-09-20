rem FILE: venv_run.cmd
@echo off
setlocal
set "VENV_DIR=.venv"
if exist ".env" (
  for /f "usebackq tokens=1,2* delims== eol=#" %%A in (".env") do (
    if not "%%~A"=="" set "%%~A=%%~B"
  )
)

if not exist "%VENV_DIR%\Scripts\activate.bat" (
  echo [error] venv not found at "%VENV_DIR%". Run setup_win.cmd first.
  exit /b 1
)

call "%VENV_DIR%\Scripts\activate.bat"
if errorlevel 1 (
  echo [error] Failed to activate venv.
  exit /b 1
)

echo === VENV ACTIVE ===
python --version
python -c "print('Hello from venv:', __import__('sys').executable)"
pip list

echo.
echo [ok] Done.
