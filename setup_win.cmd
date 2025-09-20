rem FILE: setup_win.cmd
@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Midnight REST API - one-click run ===

rem ---------- STEP 1: Load configuration ----------
echo [STEP 1/12] Loading configuration .env and defaults...
set "PY_VERSION=3.12.6"
set "VENV_DIR=.venv"
set "REQUIREMENTS=requirements.txt"
set "HOST=127.0.0.1"
set "PORT=5000"
set "DEBUG=0"
set "APP_MODULE=app"
set "APP_OBJECT=app"

if not defined PIP_DEFAULT_TIMEOUT set "PIP_DEFAULT_TIMEOUT=60"
if not defined PIP_DISABLE_PIP_VERSION_CHECK set "PIP_DISABLE_PIP_VERSION_CHECK=1"
if not defined PIP_NO_INPUT set "PIP_NO_INPUT=1"
if not defined PIP_PROGRESS_BAR set "PIP_PROGRESS_BAR=off"
if not defined PIP_QUIET set "PIP_QUIET=2"

set "PIP_FLAGS=-q"
if "%DEBUG%"=="1" set "PIP_FLAGS=" & set "PIP_QUIET="

if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    set "k=%%~A"
    set "v=%%~B"
    if defined k (
      for /f "tokens=* delims= " %%Z in ("!v!") do set "v=%%~Z"
      set "!k!=!v!"
    )
  )
)

set "TOOLS_DIR=.tools"
set "DL_DIR=%TOOLS_DIR%\downloads"
set "PY_INSTALLER=%DL_DIR%\python-%PY_VERSION%-amd64.exe"
set "PY_URL=https://www.python.org/ftp/python/%PY_VERSION%/python-%PY_VERSION%-amd64.exe"

rem ---------- STEP 2: Locate Python interpreter ----------
echo [STEP 2/12] Locating Python interpreter...
set "PY_CMD="
for /f "tokens=1,2 delims=." %%M in ("%PY_VERSION%") do set "PY_MM=%%M.%%N"

py -%PY_MM% -c "import sys;print(sys.version)" >nul 2>&1
if not errorlevel 1 ( set "PY_CMD=py -%PY_MM%" & echo [info] Using launcher exact minor: !PY_CMD! )
if "!PY_CMD!"=="" (
  py -3 -c "import sys;print(sys.version)" >nul 2>&1 && (set "PY_CMD=py -3" & echo [info] Using launcher default: !PY_CMD!)
)
if "!PY_CMD!"=="" (
  python -c "import sys;print(sys.version)" >nul 2>&1 && (set "PY_CMD=python" & echo [info] Using python from PATH: !PY_CMD!)
)

rem ---------- STEP 3: Ensure Python installed ----------
echo [STEP 3/12] Ensuring Python is installed...
if "!PY_CMD!"=="" (
  echo [warn] No Python found. Installing %PY_VERSION% per-user...
  if not exist "%DL_DIR%" mkdir "%DL_DIR%" >nul 2>&1
  powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_INSTALLER%' -UseBasicParsing; exit 0 } catch { Write-Host $_; exit 1 }"
  if errorlevel 1 ( echo [error] Download failed. & exit /b 1 )
  "%PY_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=0 Include_launcher=1 Include_test=0
  if errorlevel 1 ( echo [error] Python installer failed. & exit /b 1 )
  py -%PY_MM% -c "import sys;print(sys.version)" >nul 2>&1 && set "PY_CMD=py -%PY_MM%"
  if "!PY_CMD!"=="" py -3 -c "import sys;print(sys.version)" >nul 2>&1 && set "PY_CMD=py -3"
  if "!PY_CMD!"=="" python -c "import sys;print(sys.version)" >nul 2>&1 && set "PY_CMD=python"
  if "!PY_CMD!"=="" ( echo [error] Python still not found after install. & exit /b 1 )
)

rem ---------- STEP 4: Probe Python version ----------
echo [STEP 4/12] Probing Python version...
!PY_CMD! --version
for /f "tokens=1-3 delims=. " %%A in ('!PY_CMD! -c "import sys;print(sys.version_info[0],sys.version_info[1],sys.version_info[2])"') do (
  set "PY_MAJ=%%A" & set "PY_MIN=%%B" & set "PY_PAT=%%C"
)
if not defined PY_MAJ ( echo [error] Failed to read Python version. & exit /b 1 )
if %PY_MAJ% LSS 3 ( echo [error] Python >= 3.10 required. Found %PY_MAJ%.%PY_MIN%.%PY_PAT%. & exit /b 1 )
if %PY_MAJ% EQU 3 if %PY_MIN% LSS 10 ( echo [error] Python >= 3.10 required. Found %PY_MAJ%.%PY_MIN%.%PY_PAT%. & exit /b 1 )

rem ---------- STEP 5: Check stdlib venv ----------
echo [STEP 5/12] Checking stdlib venv...
!PY_CMD! -c "import venv" >nul 2>&1
set "HAS_VENV=0"
if not errorlevel 1 set "HAS_VENV=1"

rem ---------- STEP 6: Create or reuse venv ----------
echo [STEP 6/12] Creating or reusing virtual environment...
if "!HAS_VENV!"=="1" (
  if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo [info] Creating venv at "%VENV_DIR%" - stdlib
    !PY_CMD! -m venv "%VENV_DIR%"
    if errorlevel 1 ( echo [warn] stdlib venv failed; switching to virtualenv... & set "HAS_VENV=0" )
  ) else (
    echo [info] Reusing existing venv: %VENV_DIR%
  )
)

rem ---------- STEP 7: Fallback to virtualenv ----------
echo [STEP 7/12] Applying fallback ensurepip and virtualenv if required...
if "!HAS_VENV!"=="0" (
  !PY_CMD! -c "import ensurepip" >nul 2>&1
  if errorlevel 1 (
    echo [warn] ensurepip unavailable; reinstalling Python components...
    if not exist "%DL_DIR%" mkdir "%DL_DIR%" >nul 2>&1
    powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command ^
      "try { Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_INSTALLER%' -UseBasicParsing; exit 0 } catch { Write-Host $_; exit 1 }"
    if errorlevel 1 ( echo [error] Download failed. & exit /b 1 )
    "%PY_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=0 Include_launcher=1 Include_test=0
    if errorlevel 1 ( echo [error] Python installer failed. & exit /b 1 )
  ) else (
    !PY_CMD! -m ensurepip --upgrade
  )
  !PY_CMD! -m pip install --upgrade pip virtualenv %PIP_FLAGS%
  if errorlevel 1 ( echo [error] pip/virtualenv install failed. & exit /b 1 )
  if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo [info] Creating venv at "%VENV_DIR%" - virtualenv
    !PY_CMD! -m virtualenv "%VENV_DIR%"
    if errorlevel 1 ( echo [error] virtualenv creation failed. & exit /b 1 )
  )
)

rem ---------- STEP 8: Activate venv ----------
echo [STEP 8/12] Activating virtual environment...
call "%VENV_DIR%\Scripts\activate.bat"
if errorlevel 1 ( echo [error] Failed to activate venv. & exit /b 1 )
set "VENV_PY=%VENV_DIR%\Scripts\python.exe"

echo [info] VENV ACTIVE: %VENV_DIR%
"%VENV_PY%" --version
"%VENV_PY%" -c "import sys,site; print('python exe:', sys.executable); print('site-packages:', (site.getsitepackages()[0] if hasattr(site,'getsitepackages') else 'n/a'))"

rem ---------- STEP 9: Upgrade pip ----------
echo [STEP 9/12] Upgrading pip...
"%VENV_PY%" -m pip install --upgrade pip %PIP_FLAGS%
if errorlevel 1 (
  echo [warn] pip upgrade failed; retry with default PyPI index...
  set "PIP_INDEX_URL=https://pypi.org/simple"
  "%VENV_PY%" -m pip install --upgrade pip %PIP_FLAGS%
  if errorlevel 1 ( echo [error] pip upgrade failed again. & exit /b 1 )
)

rem ---------- STEP 10: Install requirements ----------
echo [STEP 10/12] Installing dependencies from requirements...
if exist "%REQUIREMENTS%" (
  for %%I in ("%REQUIREMENTS%") do if %%~zI gtr 0 (
    echo [info] Installing from "%REQUIREMENTS%"...
    "%VENV_PY%" -m pip install -r "%REQUIREMENTS%" %PIP_FLAGS%
    if errorlevel 1 (
      echo [warn] Install failed; retry with default PyPI index...
      set "PIP_INDEX_URL=https://pypi.org/simple"
      "%VENV_PY%" -m pip install -r "%REQUIREMENTS%" %PIP_FLAGS%
      if errorlevel 1 ( echo [error] Requirements install failed again. & exit /b 1 )
    )
  ) else (
    echo [info] "%REQUIREMENTS%" is empty. Skipping deps.
  )
) else (
  echo [info] No requirements file. Skipping deps.
)

rem ---------- STEP 11: Launch Flask app ----------
echo [STEP 11/12] Launching Flask application...
set "FLASK_RUN_HOST=%HOST%"
set "FLASK_RUN_PORT=%PORT%"
set "FLASK_SKIP_DOTENV=1"
echo [RUN] Starting server at http://%HOST%:%PORT%  DEBUG=%DEBUG%
set "PYCODE=import os,sys,importlib; sys.path.insert(0, os.getcwd()); m=os.getenv('APP_MODULE','%APP_MODULE%'); o=os.getenv('APP_OBJECT','%APP_OBJECT%'); mod=importlib.import_module(m); app=getattr(mod,o); app.run(host=os.getenv('HOST','%HOST%'), port=int(os.getenv('PORT','%PORT%')), debug=(os.getenv('DEBUG','%DEBUG%')=='1'))"
"%VENV_PY%" -c "%PYCODE%"
set "RC=%ERRORLEVEL%"

rem ---------- STEP 12: Exit code ----------
echo [STEP 12/12] Handling server exit status...
if not "%RC%"=="0" (
  echo [error] Server process exited with code %RC%.
  exit /b 1
)

echo [ok] Server stopped normally.
exit /b 0
