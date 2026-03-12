@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem WHAT THIS DOES
rem - Overwrites MovieList.txt each run (no appending/duplicates)
rem - Numbers correctly with dynamic zero-padding based on total count
rem - Prints folder list to console (stdout) AND writes to file
rem - Supports an IGNORE list (skip, do not count)
rem - Supports a RECURSE list (treat as containers: list all subfolders recursively; skip the container itself)
rem - Supports a RECURSE-SKIP list for **leaf names** to ignore during recursion (e.g., "Subs", "Sample")
rem - Validates IGNORE/RECURSE entries; missing entries produce red warnings and a boxed red summary after save
rem - Colorized console:
rem     * Normal folder lines -> GREEN (stdout)
rem     * Recursed subfolder lines -> ORANGE/YELLOW (parents) + GREEN (leaf); '\' in PINK (stdout)
rem     * Warnings/Errors & boxed lines -> RED (stderr)
rem     * Box separators (_______) -> PURPLE (stderr)
rem
rem HOW TO EDIT THE LISTS
rem - Scroll to the very bottom of this file and edit between these labels:
rem       :__IGNORE_LIST__          ...        :__END_IGNORE__
rem       :__RECURSE_LIST__         ...        :__END_RECURSE__
rem       :__RECURSE_SKIP_LIST__    ...        :__END_RECURSE_SKIP__
rem - One folder/name per line. Exact spelling.
rem - You may optionally end a line with a semicolon ';' (it will be stripped).
rem - Empty lines are ignored. Lines starting with ';' or '::' are ignored.
rem - RECURSE_SKIP matches **leaf folder names** only (case-insensitive).
rem
rem NOTES
rem - All paths are relative to the folder where this .bat lives.
rem - If ANSI colors ever look odd, you can force plain output by setting NOANSI=1 (see color init block).
rem ============================================================

rem --- Always operate from the script's own directory
cd /d "%~dp0"
set "ROOT=%CD%"
set "OUTPUT_FILE=MovieList.md"

rem ============================================================
rem Initialize ANSI color sequences (for per-line colors)
rem ============================================================
set "ESC="
for /f "delims=" %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"

if defined NOANSI (
  set "C_RED="
  set "C_GRN="
  set "C_ORG="
  set "C_PNK="
  set "C_PRP="
  set "C_RST="
) else (
  rem colour: normal|brighter
  rem red: 31|91
  set "C_RED=%ESC%[31m"
  rem green: 32|92
  set "C_GRN=%ESC%[32m"
  rem orange-ish: bright yellow 93 (closest ANSI to orange)
  set "C_ORG=%ESC%[93m"
  rem pink/magenta: use bright magenta 95
  set "C_PNK=%ESC%[95m"
  rem purple: 35|95
  set "C_PRP=%ESC%[35m"
  set "C_RST=%ESC%[0m"
)

rem ============================================================
rem Build list files by reading THIS script between markers
rem ============================================================
set "IGNORE_FILE=%ROOT%\__ignore.lst"
set "RECURSE_FILE=%ROOT%\__recurse.lst"
set "RSKIP_FILE=%ROOT%\__recurseskip.lst"
set "IGNORE_CLEAN=%ROOT%\__ignore.clean"
set "RECURSE_CLEAN=%ROOT%\__recurse.clean"
set "RSKIP_CLEAN=%ROOT%\__recurseskip.clean"

for %%F in ("%IGNORE_FILE%" "%RECURSE_FILE%" "%RSKIP_FILE%" "%IGNORE_CLEAN%" "%RECURSE_CLEAN%" "%RSKIP_CLEAN%") do (if exist "%%~fF" del /f /q "%%~fF" >nul 2>&1)

set "IN_IGNORE="
set "IN_RECURSE="
set "IN_RSKIP="

for /f "usebackq delims=" %%L in ("%~f0") do (
  if "%%L"==":__IGNORE_LIST__"         set "IN_IGNORE=1"  & set "IN_RECURSE=" & set "IN_RSKIP="
  if "%%L"==":__END_IGNORE__"          set "IN_IGNORE="
  if "%%L"==":__RECURSE_LIST__"        set "IN_RECURSE=1" & set "IN_IGNORE="  & set "IN_RSKIP="
  if "%%L"==":__END_RECURSE__"         set "IN_RECURSE="
  if "%%L"==":__RECURSE_SKIP_LIST__"   set "IN_RSKIP=1"   & set "IN_IGNORE="  & set "IN_RECURSE="
  if "%%L"==":__END_RECURSE_SKIP__"    set "IN_RSKIP="

  if defined IN_IGNORE (
    if not "%%L"=="" if not "%%L"==":__IGNORE_LIST__" if not "%%L"==":__END_IGNORE__" (
      echo %%L| findstr /r /b /c:";" /c:"::" >nul || >>"%IGNORE_FILE%" echo %%L
    )
  )
  if defined IN_RECURSE (
    if not "%%L"=="" if not "%%L"==":__RECURSE_LIST__" if not "%%L"==":__END_RECURSE__" (
      echo %%L| findstr /r /b /c:";" /c:"::" >nul || >>"%RECURSE_FILE%" echo %%L
    )
  )
  if defined IN_RSKIP (
    if not "%%L"=="" if not "%%L"==":__RECURSE_SKIP_LIST__" if not "%%L"==":__END_RECURSE_SKIP__" (
      echo %%L| findstr /r /b /c:";" /c:"::" >nul || >>"%RSKIP_FILE%" echo %%L
    )
  )
)

rem ============================================================
rem Normalize and validate lists:
rem  - trim, strip optional trailing ';', drop blanks/comments
rem  - verify folder exists (IGNORE/RECURSE only); collect missing for error box (stderr)
rem ============================================================
set "ERROR_FLAG=0"
set "MISSING_IGNORE="
set "MISSING_RECURSE="

if exist "%IGNORE_FILE%" (
  for /f "usebackq tokens=* delims=" %%I in ("%IGNORE_FILE%") do (
    set "LINE=%%I"
    if not "!LINE!"=="" if /i not "!LINE:~0,1!"==";" if /i not "!LINE:~0,2!"=="::" (
      if "!LINE:~-1!"==";" set "LINE=!LINE:~0,-1!"
      for /f "tokens=* delims=" %%T in ("!LINE!") do set "LINE=%%T"
      if not "!LINE!"=="" (
        if exist "!ROOT!\!LINE!\" (
          >>"%IGNORE_CLEAN%" echo !LINE!
        ) else (
          set "ERROR_FLAG=1"
          if defined MISSING_IGNORE (set "MISSING_IGNORE=!MISSING_IGNORE!, !LINE!") else set "MISSING_IGNORE=!LINE!"
          1>&2 echo %C_RED%[WARN]%C_RST% Ignore entry not found: "!LINE!"
        )
      )
    )
  )
)

if exist "%RECURSE_FILE%" (
  for /f "usebackq tokens=* delims=" %%I in ("%RECURSE_FILE%") do (
    set "LINE=%%I"
    if not "!LINE!"=="" if /i not "!LINE:~0,1!"==";" if /i not "!LINE:~0,2!"=="::" (
      if "!LINE:~-1!"==";" set "LINE=!LINE:~0,-1!"
      for /f "tokens=* delims=" %%T in ("!LINE!") do set "LINE=%%T"
      if not "!LINE!"=="" (
        if exist "!ROOT!\!LINE!\" (
          >>"%RECURSE_CLEAN%" echo !LINE!
        ) else (
          set "ERROR_FLAG=1"
          if defined MISSING_RECURSE (set "MISSING_RECURSE=!MISSING_RECURSE!, !LINE!") else set "MISSING_RECURSE=!LINE!"
          1>&2 echo %C_RED%[WARN]%C_RST% Recurse entry not found: "!LINE!"
        )
      )
    )
  )
)

rem -- RECURSE-SKIP: normalize only (no existence validation; matches by leaf name)
if exist "%RSKIP_FILE%" (
  for /f "usebackq tokens=* delims=" %%I in ("%RSKIP_FILE%") do (
    set "LINE=%%I"
    if not "!LINE!"=="" if /i not "!LINE:~0,1!"==";" if /i not "!LINE:~0,2!"=="::" (
      if "!LINE:~-1!"==";" set "LINE=!LINE:~0,-1!"
      for /f "tokens=* delims=" %%T in ("!LINE!") do set "LINE=%%T"
      if not "!LINE!"=="" >>"%RSKIP_CLEAN%" echo !LINE!
    )
  )
)

rem ============================================================
rem Helper: exact one-line membership using findstr /x (case-insensitive)
rem   call :InList "file" "Candidate Name" -> sets MATCH=1 or 0
rem ============================================================
set "MATCH="
goto :__COLORHELP__

:InList
set "MATCH=0"
if not exist "%~1" exit /b
findstr /i /x /c:"%~2" "%~1" >nul 2>&1 && set "MATCH=1"
exit /b

rem ============================================================
rem Build mixed-color path for recursive entries:
rem - Input:  call :ColorizeRel "!REL!"
rem - Output: COLOREDPATH (parents ORANGE, '\' PINK, leaf GREEN)
rem ============================================================
:ColorizeRel
set "PATHLEFT=%~1"
set "COLOREDPATH="
:__CL_NEXT
for /f "tokens=1* delims=\\" %%a in ("%PATHLEFT%") do (
  set "SEG=%%a"
  set "REST=%%b"
)
if defined REST (
  set "COLOREDPATH=!COLOREDPATH!!C_ORG!!SEG!!C_RST!!C_PNK!\!C_RST!"
  set "PATHLEFT=!REST!"
  goto :__CL_NEXT
) else (
  set "COLOREDPATH=!COLOREDPATH!!C_GRN!!SEG!!C_RST!"
)
exit /b

:__COLORHELP__
rem ============================================================
rem PRE-SCAN: compute TOTAL items that will be listed (for padding)
rem - Applies RECURSE-SKIP to **leaf names** during recursion
rem - 'dir' stderr silenced to avoid transient "File Not Found"
rem ============================================================
:__PRESCAN__
set /a TOTAL=0

for /f "delims=" %%D in ('dir /b /ad 2^>nul ^| sort') do (
  call :InList "%IGNORE_CLEAN%" "%%D"
  set "IS_IGNORED=!MATCH!"

  call :InList "%RECURSE_CLEAN%" "%%D"
  set "IS_RECURSED=!MATCH!"

  if "!IS_IGNORED!"=="1" (
    rem skip
  ) else if "!IS_RECURSED!"=="1" (
    for /f "delims=" %%P in ('dir /b /ad /s "%%D" 2^>nul ^| sort') do (
      if /I not "%%~fP"=="%ROOT%\%%D" (
        for %%Z in ("%%~fP") do set "LEAF=%%~nxZ"
        call :InList "%RSKIP_CLEAN%" "!LEAF!"
        if not "!MATCH!"=="1" set /a TOTAL+=1
      )
    )
  ) else (
    set /a TOTAL+=1
  )
)

rem Determine WIDTH = number of digits in TOTAL (min 1)
set "TOTAL_STR=!TOTAL!"
set /a WIDTH=0
if not defined TOTAL_STR set "TOTAL_STR=0"
:__LENLOOP__
if defined TOTAL_STR (
  set "TOTAL_STR=!TOTAL_STR:~1!"
  set /a WIDTH+=1
  if defined TOTAL_STR goto :__LENLOOP__
)
if %WIDTH% LSS 1 set WIDTH=1

rem ============================================================
rem Start fresh output; header to file and console (unstyled header)
rem ============================================================
if exist "%OUTPUT_FILE%" del /f /q "%OUTPUT_FILE%" >nul 2>&1
(
  echo Number - Folder Name
  echo ---------------------------
)>"%OUTPUT_FILE%"

echo Number - Folder Name
1>&2 echo %C_PRP%_____________________________________________________%C_RST%

rem ============================================================
rem Enumerate top-level folders with IGNORE/RECURSE logic
rem  - Normal folders -> GREEN
rem  - Recursed subfolders -> ORANGE parents + GREEN leaf; '\' PINK
rem  - RECURSE-SKIP applied to leaf names
rem  - File lines are plain (no ANSI)
rem ============================================================
set /a FOLDER_COUNTER=1

for /f "delims=" %%D in ('dir /b /ad 2^>nul ^| sort') do (
  call :InList "%IGNORE_CLEAN%" "%%D"
  set "IS_IGNORED=!MATCH!"

  call :InList "%RECURSE_CLEAN%" "%%D"
  set "IS_RECURSED=!MATCH!"

  if "!IS_IGNORED!"=="1" (
    rem Skip entirely
  ) else if "!IS_RECURSED!"=="1" (
    for /f "delims=" %%P in ('dir /b /ad /s "%%D" 2^>nul ^| sort') do (
      if /I not "%%~fP"=="%ROOT%\%%D" (
        for %%Z in ("%%~fP") do set "LEAF=%%~nxZ"
        call :InList "%RSKIP_CLEAN%" "!LEAF!"
        if not "!MATCH!"=="1" (
          set "REL=%%~fP"
          set "REL=!REL:%ROOT%\=!"
          rem Build zero-padded number of width WIDTH
          set "NUM=000000000000!FOLDER_COUNTER!"
          set "NUM=!NUM:~-%WIDTH%!"
          rem Colored console path
          call :ColorizeRel "!REL!"
          echo %C_ORG%!NUM! - %C_RST%!COLOREDPATH!
          rem File (plain)
          >>"%OUTPUT_FILE%" echo !NUM! - !REL!
          set /a FOLDER_COUNTER+=1
        )
      )
    )
  ) else (
    rem Normal top-level folder
    set "NUM=000000000000!FOLDER_COUNTER!"
    set "NUM=!NUM:~-%WIDTH%!"
    echo %C_GRN%!NUM! - %%D%C_RST%
    >>"%OUTPUT_FILE%" echo !NUM! - %%D
    set /a FOLDER_COUNTER+=1
  )
)

echo(
echo Movie list has been (re)generated in: "%ROOT%\%OUTPUT_FILE%"
echo(

rem ============================================================
rem Boxed error summary printed to STDERR (RED text, PURPLE lines)
rem ============================================================
if "%ERROR_FLAG%"=="1" (
  1>&2 echo %C_PRP%_____________________________________________________%C_RST%
  if defined MISSING_IGNORE (
    1>&2 echo %C_RED%ERROR:%C_RST% The following IGNORE entries were not found:
    1>&2 echo   %MISSING_IGNORE%
    1>&2 echo(
  )
  if defined MISSING_RECURSE (
    1>&2 echo %C_RED%ERROR:%C_RST% The following RECURSE entries were not found:
    1>&2 echo   %MISSING_RECURSE%
    1>&2 echo(
  )
  1>&2 echo %C_PRP%_____________________________________________________%C_RST%
)

rem ============================================================
rem Cleanup temp files and pause
rem ============================================================
for %%F in ("%IGNORE_FILE%" "%RECURSE_FILE%" "%RSKIP_FILE%" "%IGNORE_CLEAN%" "%RECURSE_CLEAN%" "%RSKIP_CLEAN%") do (if exist "%%~fF" del /f /q "%%~fF" >nul 2>&1)

pause
exit /b 0

rem ============================================================
rem ===================== USER LISTS BELOW =====================
rem
rem HOW TO USE:
rem  - Put ONE folder name per line, exactly as it appears under this .bat
rem  - Optional semicolon ';' at the end (it will be stripped)
rem  - Lines starting with ';' or '::' are comments (ignored)
rem  - Empty lines are allowed (ignored)
rem  - IGNORE_LIST -> these are skipped entirely and do NOT increment the counter
rem  - RECURSE_LIST -> these are treated as containers: the container itself
rem                    is NOT listed, but all of its subfolders ARE listed,
rem                    recursively, with relative paths like "Container\Child\..."
rem  - RECURSE_SKIP_LIST -> **leaf** folder names to skip inside recursion
rem                         (e.g., Subs, Sample). Case-insensitive.
rem ============================================================

:__IGNORE_LIST__
; Your IGNORE entries (one per line; ';' optional):

:__END_IGNORE__

:__RECURSE_LIST__
; Your RECURSE container entries (one per line; ';' optional):

:__END_RECURSE__

:__RECURSE_SKIP_LIST__
; Leaf subfolder names to skip during recursion (one per line; ';' optional):
Subs
Sample
Language Options


:__END_RECURSE_SKIP__
