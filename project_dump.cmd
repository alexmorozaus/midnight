@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=."
set "OUTPUT=project_files.txt"
set "EXCLUDE_DIRS=.venv;.git;.svn;.hg;.idea;.vscode;.tox;.pytest_cache;.mypy_cache;__pycache__;node_modules;dist;build;venv;env;.tools;downloads"

for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "OUT=%ROOT%\%OUTPUT%"
if exist "%OUT%" del /f /q "%OUT%" >nul 2>&1

> "%OUT%" echo === PROJECT FILE LIST ===
>>"%OUT%" echo Root: %ROOT%
>>"%OUT%" echo Generated: %DATE% %TIME%
>>"%OUT%" echo.

set "EXCLUDE_DIRS_LIST=%EXCLUDE_DIRS:;= %"

for /f "usebackq delims=" %%F in (`dir "%ROOT%" /S /B /A:-D`) do (
  set "FULL=%%~fF"
  if /I not "!FULL!"=="%OUT%" (
    set "SKIP="
    for %%D in (%EXCLUDE_DIRS_LIST%) do (
      if not defined SKIP (
        if /I not "!FULL:\%%D\=!"=="!FULL!" set "SKIP=1"
      )
    )
    if not defined SKIP echo !FULL!>>"%OUT%"
  )
)

echo Done. Output: "%OUT%"
endlocal
