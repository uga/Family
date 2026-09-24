@echo off
setlocal enabledelayedexpansion

rem ---------------------------------------------------------------------------------------
rem  Family - deploy the midnight branch to the Midnight client, and to nothing else.
rem
rem  Copies addons\Family and addons\Family_UI, and tools\FamilySurface, into the one Retail
rem  client on this machine. Three folders, named explicitly, for the reason Deploy.bat gives:
rem  a mirroring copy driven by a wildcard is how a wrong source folder empties a right
rem  destination one.
rem
rem  **Only Midnight, and never the Classic clients.** This branch's addons carry Midnight's
rem  interface number and its unreleased changes; Deploy.bat is what puts Family on Era,
rem  Anniversary and Mists, from main. Asked for by Alberto, 2026-09-24, to try the branch at
rem  home before any beta (docs\MIDNIGHT.md section 46).
rem
rem  Usage:  DeployMidnight.bat              copy, after asking
rem          DeployMidnight.bat /test        show what it would do, write nothing
rem          DeployMidnight.bat /y           copy without asking
rem          DeployMidnight.bat "folder"     use that folder as the source instead
rem ---------------------------------------------------------------------------------------

set "ADDON_1=Family"
set "ADDON_2=Family_UI"

rem The Midnight probe. Not part of Family and never in a release. The two tools Deploy.bat
rem carries, FamilyProbe and FamilyIconSheet, are left out: their .toc files stop at Mists, so
rem Midnight would list them as out of date and not load them.
set "ADDON_TOOL_1=FamilySurface"

rem Windows refuses to run a script from a network path, so this file lives on a local disk and
rem the checkout is reached over the share - the midnight worktree's, not main's. A placeholder,
rem as in Deploy.bat: set it once on the machine that runs the deploy.
set "SRC_SHARE=\\YOUR-HOST\dev\Family-retail\addons"

rem --- where the addons are coming from ---------------------------------------------------

rem This script sits in tools\, so the addons are one level up.
set "SRC=%~dp0..\addons"

rem Anything that is not one of the flags is the source folder.
for %%A in (%*) do (
	if /i not "%%~A"=="/test" if /i not "%%~A"=="/y" set "SRC=%%~A"
)

for %%P in ("%SRC%") do set "SRC=%%~fP"

if not exist "%SRC%\%ADDON_1%\%ADDON_1%.toc" (
	echo  Source "%SRC%" has no %ADDON_1%.toc - trying the share instead.
	set "SRC=%SRC_SHARE%"
)

for %%P in ("%SRC%\..\tools") do set "SRC_TOOLS=%%~fP"

rem --- where they are going ---------------------------------------------------------------

rem The Retail client's AddOns folder, as Alberto gave it 2026-09-24.
set "DEST_MIDNIGHT=E:\Giochi\World of Warcraft\_retail_\Interface\AddOns"

set "DRYRUN="
set "NOASK="
for %%A in (%*) do (
	if /i "%%~A"=="/test" set "DRYRUN=1"
	if /i "%%~A"=="/y"    set "NOASK=1"
)

set "TOOL_1="
if exist "%SRC_TOOLS%\%ADDON_TOOL_1%\%ADDON_TOOL_1%.toc" (
	set "TOOL_1=1"
) else (
	echo  "%SRC_TOOLS%\%ADDON_TOOL_1%" is not there - leaving it out.
)

set "LIBS="
if exist "%SRC%\%ADDON_1%\Libs\LibStub\LibStub.lua" set "LIBS=1"

echo.
echo  Family - deploy to Midnight
echo.
echo   source : %SRC%
echo   addons : %ADDON_1%, %ADDON_2%
if defined LIBS echo   libs   : LibStub, LibSerialize, LibDeflate
if defined TOOL_1 echo   tools  : %ADDON_TOOL_1% ^(the Midnight probe, not part of a release^)
echo   to     : %DEST_MIDNIGHT%
if defined DRYRUN echo.& echo   TEST RUN - nothing will be written.
echo.

rem --- refuse to run if the source is not what it claims to be -----------------------------

if not exist "%SRC%\%ADDON_1%\%ADDON_1%.toc" (
	echo  ERROR : "%SRC%" is not Family's addons folder ^(no %ADDON_1%\%ADDON_1%.toc^).
	goto :failed
)
if not exist "%SRC%\%ADDON_2%\%ADDON_2%.toc" (
	echo  ERROR : "%SRC%" has no %ADDON_2%\%ADDON_2%.toc.
	goto :failed
)

rem A source from main would copy a Family that Midnight does not load. The midnight branch's
rem .toc lists 120100; if this one does not, it is the wrong checkout.
findstr /r /c:"^## Interface:.*120100" "%SRC%\%ADDON_1%\%ADDON_1%.toc" >nul
if errorlevel 1 (
	echo  ERROR : "%SRC%\%ADDON_1%\%ADDON_1%.toc" does not list Midnight's interface, 120100.
	echo          This is not the midnight branch - Deploy.bat is the one for main.
	goto :failed
)

if not defined LIBS (
	echo  NOTE : "%SRC%\%ADDON_1%" has no Libs\LibStub\LibStub.lua.
	echo         A checkout has no libraries until tools\FetchLibs.sh has fetched them.
	echo         Family runs without them; Wide Family cannot send, and storage is
	echo         uncompressed. Any the Midnight client already has will be removed.
	echo.
)

rem --- is the client installed ? -----------------------------------------------------------

if not exist "%DEST_MIDNIGHT%\" (
	echo  ERROR : "%DEST_MIDNIGHT%" is not there, so there is nothing to update.
	goto :failed
)
echo   found  : Midnight
echo.

if not defined DRYRUN if not defined NOASK (
	echo  Close World of Warcraft first, or it will keep using the addons it
	echo  already has loaded.
	echo.
	choice /c YN /n /m "  Copy now? [Y/N] "
	if errorlevel 2 goto :cancelled
	echo.
)

rem --- copy ---------------------------------------------------------------------------------

rem /MIR so a file deleted here disappears there too, aimed at each named folder and never at
rem AddOns itself: whatever else is installed in the client is not touched.
set "RCFLAGS=/MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1"
if defined DRYRUN set "RCFLAGS=%RCFLAGS% /L"

set /a ERRORS=0
set "DEST=%DEST_MIDNIGHT%"
if "%DEST:~-1%"=="\" set "DEST=%DEST:~0,-1%"

rem The same guard as Deploy.bat's, for the same reason: /MIR deletes what it does not
rem recognise, so the folder has to be an AddOns folder before anything is pointed at it.
set "TAIL=%DEST:~-16%"
if /i not "%TAIL%"=="Interface\AddOns" (
	echo    REFUSED : "%DEST%" does not end in Interface\AddOns.
	goto :failed
)

echo  --- Midnight ---
call :copyone "%SRC%" "%ADDON_1%"
call :copyone "%SRC%" "%ADDON_2%"
if defined TOOL_1 call :copyone "%SRC_TOOLS%" "%ADDON_TOOL_1%"

echo.
if %ERRORS% GTR 0 (
	echo  FINISHED WITH %ERRORS% ERROR^(S^) - read the messages above.
	goto :done
)
if defined DRYRUN (
	echo  Test run finished. Nothing was written.
	goto :done
)
echo  Done. Start the game, or /reload if it was already running.
echo.
echo  Then try:  /console scriptErrors 1   so that an error is shown, not swallowed
echo             /family                  open the window
if defined TOOL_1 echo             /familysurface           ask the client again
goto :done

:copyone
robocopy "%~1\%~2" "%DEST%\%~2" %RCFLAGS%
rem robocopy: below 8 is success of some kind, 8 and above is a real failure.
if errorlevel 8 (
	echo    ERROR copying %~2
	set /a ERRORS+=1
	exit /b 0
)
echo    %~2
exit /b 0

:cancelled
echo  Cancelled. Nothing was copied.
goto :done

:failed
set /a ERRORS=1

:done
echo.
pause
endlocal
