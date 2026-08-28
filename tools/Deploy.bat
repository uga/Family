@echo off
setlocal enabledelayedexpansion

rem ---------------------------------------------------------------------------------------
rem  Family - deploy to the game clients.
rem
rem  Copies addons\Family and addons\Family_UI into every Classic client installed on this
rem  machine. Two folders, named explicitly: there is no pattern matching here, because a
rem  mirroring copy driven by a wildcard is how a wrong source folder empties a right
rem  destination one.
rem
rem  Run it on the games PC. The source is worked out from where this file lives, so a
rem  checkout mounted from the Pi needs no arguments.
rem
rem  Usage:  Deploy.bat              copy, after asking
rem          Deploy.bat /test        show what it would do, write nothing
rem          Deploy.bat /y           copy without asking
rem          Deploy.bat /era         only Classic Era      (combine with /test or /y)
rem          Deploy.bat /anni        only Anniversary
rem          Deploy.bat /mists       only Mists of Pandaria
rem          Deploy.bat /icons       also copy the icon contact sheet (tools\)
rem          Deploy.bat "folder"     use that folder as the source instead
rem ---------------------------------------------------------------------------------------

set "ADDON_1=Family"
set "ADDON_2=Family_UI"

rem A development tool, not part of Family and not in any release: the icon contact sheet,
rem which draws every candidate stock icon so a screenshot can say which ones this client
rem actually has. Only copied when /icons is asked for, and it lives under tools\ rather
rem than addons\ so that it can never be mistaken for something that ships.
set "ADDON_TOOL=FamilyIconSheet"

rem Windows refuses to run a script from a network path, so this file lives on a local disk
rem and the checkout is reached over the share.
rem
rem These three are the only lines in this file that describe one particular machine, and they
rem are left as placeholders on purpose: this copy is in a public repository, and a working
rem copy is one somebody edited for their own machine. Set them once on the machine that runs
rem the deploy - the copy here is the template, not the thing being run.
set "SRC_SHARE=\\YOUR-HOST\dev\Family-public\addons"

rem --- where the addons are coming from ---------------------------------------------------

rem This script sits in tools\, so the addons are one level up.
set "SRC=%~dp0..\addons"

for %%A in (%*) do (
	if /i not "%%~A"=="/test" if /i not "%%~A"=="/y" if /i not "%%~A"=="/era" (
		if /i not "%%~A"=="/anni" if /i not "%%~A"=="/mists" (
			if /i not "%%~A"=="/icons" set "SRC=%%~A"
		)
	)
)

rem Resolve to an absolute path, so what gets printed is what gets copied.
for %%P in ("%SRC%") do set "SRC=%%~fP"

if not exist "%SRC%\%ADDON_1%\%ADDON_1%.toc" (
	echo  Source "%SRC%" has no %ADDON_1%.toc - trying the share instead.
	set "SRC=%SRC_SHARE%"
)

rem The tools live beside the addons, wherever the addons turned out to be - including when
rem that was the share rather than a local checkout.
for %%P in ("%SRC%\..\tools") do set "SRC_TOOLS=%%~fP"

rem --- where they are going ---------------------------------------------------------------

rem Era and Anniversary share a root; Mists is often on another disk. Placeholders, for the
rem reason given above - set them to the real ones on the machine that runs this.
set "WOW=C:\World of Warcraft Classic\World of Warcraft"
set "DEST_ERA=%WOW%\_classic_era_\Interface\AddOns"
set "DEST_ANNI=%WOW%\_anniversary_\Interface\AddOns"
set "DEST_MISTS=D:\World of Warcraft\_classic_\Interface\AddOns"

set "DRYRUN="
set "NOASK="
set "ONLY="
set "ICONS="
for %%A in (%*) do (
	if /i "%%~A"=="/test"  set "DRYRUN=1"
	if /i "%%~A"=="/y"     set "NOASK=1"
	if /i "%%~A"=="/era"   set "ONLY=ERA"
	if /i "%%~A"=="/anni"  set "ONLY=ANNI"
	if /i "%%~A"=="/mists" set "ONLY=MISTS"
	if /i "%%~A"=="/icons" set "ICONS=1"
)

if defined ICONS if not exist "%SRC_TOOLS%\%ADDON_TOOL%\%ADDON_TOOL%.toc" (
	echo  /icons asked for, but "%SRC_TOOLS%\%ADDON_TOOL%" is not there - skipping it.
	set "ICONS="
)

rem The three libraries are .pkgmeta externals: CurseForge builds them into the zip and
rem addons\Family\Libs is gitignored, so a checkout has them only once tools\FetchLibs.sh has
rem been run. LibStub is the one worth testing for - without it the other two cannot publish
rem themselves and their presence would not matter anyway.
set "LIBS="
if exist "%SRC%\%ADDON_1%\Libs\LibStub\LibStub.lua" set "LIBS=1"

echo.
echo  Family - deploy
echo.
echo   source : %SRC%
echo   addons : %ADDON_1%, %ADDON_2%
if defined LIBS echo   libs   : LibStub, LibSerialize, LibDeflate
if defined ICONS echo   also   : %ADDON_TOOL% ^(development tool, not part of a release^)
if defined ONLY echo   only   : %ONLY%
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

rem --- a source with no Libs takes the clients' libraries with it -----------------------------

rem Deploying without the libraries is a legitimate thing to do - it is how the path a player
rem without them takes gets tested - but it is almost never what was meant, and /MIR makes it
rem silent: the copy reports the client's own three as extra and deletes them. One run then
rem turns Wide Family off in every client at once and says nothing about it afterwards, which
rem is what a fresh checkout did on 2026-08-27.
if not defined LIBS (
	echo  WARNING : "%SRC%\%ADDON_1%" has no Libs\LibStub\LibStub.lua.
	echo.
	echo            A checkout has no libraries until tools\FetchLibs.sh has fetched them.
	echo            This copy will DELETE the three the clients already have, and without
	echo            them Wide Family cannot send a byte and storage is uncompressed.
	echo.
)

rem --- which clients are actually installed ------------------------------------------------

set /a FOUND=0
if not defined ONLY (
	call :check "%DEST_ERA%"   "Classic Era"
	call :check "%DEST_ANNI%"  "Anniversary"
	call :check "%DEST_MISTS%" "Mists of Pandaria"
) else (
	if "%ONLY%"=="ERA"   call :check "%DEST_ERA%"   "Classic Era"
	if "%ONLY%"=="ANNI"  call :check "%DEST_ANNI%"  "Anniversary"
	if "%ONLY%"=="MISTS" call :check "%DEST_MISTS%" "Mists of Pandaria"
)

if %FOUND% EQU 0 (
	echo  ERROR : no AddOns folder found, so there is nothing to update.
	goto :failed
)
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

rem /MIR so a file deleted here disappears there too - a stale .lua still in the folder is
rem still in the .toc's world, and stale Lua is the worst kind of bug to chase.
set "RCFLAGS=/MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1"
if defined DRYRUN set "RCFLAGS=%RCFLAGS% /L"

set /a ERRORS=0
if not defined ONLY (
	call :deploy "%DEST_ERA%"   "Classic Era"
	call :deploy "%DEST_ANNI%"  "Anniversary"
	call :deploy "%DEST_MISTS%" "Mists of Pandaria"
) else (
	if "%ONLY%"=="ERA"   call :deploy "%DEST_ERA%"   "Classic Era"
	if "%ONLY%"=="ANNI"  call :deploy "%DEST_ANNI%"  "Anniversary"
	if "%ONLY%"=="MISTS" call :deploy "%DEST_MISTS%" "Mists of Pandaria"
)

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
echo  Then try:  /family        open the window
echo             /family caps   what this client can do, and how Family worked it out
if defined ICONS echo             /iconsheet     the icon contact sheet - screenshot it
goto :done

rem --- is this client installed ? ------------------------------------------------------------

:check
if exist "%~1\" (
	set /a FOUND+=1
	echo   found  : %~2
	exit /b 0
)
echo   absent : %~2
exit /b 0

rem --- copy both addons into one client -------------------------------------------------------

:deploy
set "DEST=%~1"
if not exist "%DEST%\" exit /b 0

rem A mirroring copy deletes whatever it does not recognise, so make quite sure this is an
rem AddOns folder before pointing /MIR at it.
rem
rem This compares the last 16 characters directly, rather than echoing the path into
rem findstr. Echoing a variable into a pipe carries the space that precedes the pipe along
rem with it, so a pattern anchored to the end of the line can never match - which is how
rem the first version of this guard refused all three perfectly good paths.
if "%DEST:~-1%"=="\" set "DEST=%DEST:~0,-1%"
set "TAIL=%DEST:~-16%"
if /i not "%TAIL%"=="Interface\AddOns" (
	echo    REFUSED : "%DEST%" does not end in Interface\AddOns.
	set /a ERRORS+=1
	exit /b 0
)

echo  --- %~2 ---
call :copyone "%SRC%" "%ADDON_1%"
call :copyone "%SRC%" "%ADDON_2%"
if defined ICONS call :copyone "%SRC_TOOLS%" "%ADDON_TOOL%"
exit /b 0

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
