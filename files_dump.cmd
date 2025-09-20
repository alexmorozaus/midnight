rem FILE: files_dump.cmd
@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: Settings
set "OUTPUT=files_dump.txt"
set "DUMP_TIMESTAMP=0"

:: Extra (non-.py) files to include explicitly (relative to script dir)
set EXTRA=^
 ".env" ^
 "requirements.txt" ^
 "README.md" ^
 "setup_win.cmd" ^
 "venv_run.cmd"

:: Substrings of directories to skip (matched anywhere in full path, case-insensitive)
:: Each token must have backslashes around, e.g. \.venv\
set "SKIP_TOKENS=\.venv\ \venv\ \.vnv\ \.git\ \__pycache__\ \.pytest_cache\ \.idea\ \.vscode\ \node_modules\"

:: Resolve script directory as root
set "ROOT=%~dp0"
pushd "%ROOT%" >nul

:: Optional timestamped output filename
if "%DUMP_TIMESTAMP%"=="1" (
  set "STAMP=%DATE%_%TIME%"
  set "STAMP=%STAMP:/=-%"
  set "STAMP=%STAMP:\=-%"
  set "STAMP=%STAMP:.=-%"
  set "STAMP=%STAMP:,=-%"
  set "STAMP=%STAMP: =0%"
  set "STAMP=%STAMP::=-%"
  set "OUTPUT=files_dump_%STAMP%.txt"
)

:: Prepare output (UTF-8)
chcp 65001 >nul
if exist "%OUTPUT%" del /q "%OUTPUT%" 2>nul

>>"%OUTPUT%" echo === PROJECT FILE DUMP ===
>>"%OUTPUT%" echo Root: %CD%
>>"%OUTPUT%" echo Generated: %DATE% %TIME%
>>"%OUTPUT%" echo(

:: Dump explicit extra files first (no duplicates with .py)
for %%F in (%EXTRA%) do (
  if exist "%%~F" (
    set "EXT=%%~xF"
    set "CMT=#"
    if /I "!EXT!"==".cmd" set "CMT=rem"
    if /I "!EXT!"==".bat" set "CMT=rem"

    >>"%OUTPUT%" echo ------------------------------------------------------------
    >>"%OUTPUT%" echo !CMT! FILE: %%~F
    type "%%~F">>"%OUTPUT%"
    >>"%OUTPUT%" echo(
  ) else (
    >>"%OUTPUT%" echo ------------------------------------------------------------
    >>"%OUTPUT%" echo # FILE: %%~F MISSING
    >>"%OUTPUT%" echo # not found
    >>"%OUTPUT%" echo(
  )
)

:: Recursively dump all Python sources (*.py), skipping unwanted directories
for /R "%CD%" %%F in (*.py) do (
  set "FULL=%%~fF"
  set "REL=!FULL:%CD%\=!"
  if "!REL!"=="" set "REL=%%~nxF"

  :: Skip if path contains any token from SKIP_TOKENS
  set "SKIP=0"
  for %%T in (%SKIP_TOKENS%) do (
    if /I not "!FULL:%%T=!"=="!FULL!" set "SKIP=1"
  )

  :: Also skip OUTPUT itself (safety)
  for %%O in ("%OUTPUT%") do (
    if /I "!FULL!"=="%%~fO" set "SKIP=1"
  )

  if "!SKIP!"=="0" (
    >>"%OUTPUT%" echo ------------------------------------------------------------
    >>"%OUTPUT%" echo # FILE: !REL!
    type "%%~fF">>"%OUTPUT%"
    >>"%OUTPUT%" echo(
  )
)

>>"%OUTPUT%" echo ------------------------------------------------------------
>>"%OUTPUT%" echo [ok] wrote "%OUTPUT%"

echo [ok] Dump created: "%OUTPUT%"
popd >nul
exit /b 0
