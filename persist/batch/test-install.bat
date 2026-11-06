@echo off
echo.
echo #############################################################################
echo This is a .BAT file for testing "wine-docker"!
echo This one checks that the software installed in the image is available.
echo #############################################################################
echo.
set ERR=0
set SYS64=C:\windows\system32
set SYS32=C:\windows\syswow64
set FONTS=C:\windows\Fonts
set WTLOG=Z:%WINEPREFIX:/=\%\winetricks.log

echo [Applications]
call :file "Notepad++" "C:\Program Files\Notepad++\notepad++.exe"
call :file "Firefox" "C:\Program Files\Mozilla Firefox\firefox.exe"
echo.

echo [Drives]
call :file "Drive D:" "D:\"
echo.

echo [Wine Mono / Gecko]
call :file "Wine Mono" "C:\windows\mono\mono-2.0\lib\mono\4.5\mscorlib.dll"
call :gecko "Wine Gecko x86_64" "%SYS64%\gecko"
call :gecko "Wine Gecko x86" "%SYS32%\gecko"
echo.

echo [Visual C++ (winetricks)]
call :file "vcrun2026 x64" "%SYS64%\mfc140u.dll"
call :file "vcrun2026 x86" "%SYS32%\mfc140u.dll"
call :file "vcrun2013 x64" "%SYS64%\mfc120u.dll"
call :file "vcrun2013 x86" "%SYS32%\mfc120u.dll"
call :file "vcrun2010 x64" "%SYS64%\mfc100u.dll"
call :file "vcrun2010 x86" "%SYS32%\mfc100u.dll"
call :verb vcrun2026
call :verb vcrun2013
call :verb vcrun2010
echo.

echo [Fonts (winetricks)]
call :file "corefonts" "%FONTS%\arial.ttf"
call :file "consolas" "%FONTS%\consola.ttf"
call :file "consolas bold" "%FONTS%\consolab.ttf"
call :file "tahoma" "%FONTS%\tahoma.ttf"
call :file "tahoma bold" "%FONTS%\tahomabd.ttf"
call :file "lucida" "%FONTS%\lucon.ttf"
call :verb corefonts
call :verb consolas
call :verb tahoma
call :verb lucida
call :verb "fontsmooth=rgb"
echo.

echo [Windows components (winetricks)]
call :verb msxml6
call :verb d3dcompiler_47
call :verb riched20
echo.

echo [.NET (winetricks)]
set DOTNET64=C:\Program Files\dotnet\dotnet.exe
set DOTNET32=C:\Program Files (x86)\dotnet\dotnet.exe
call :file ".NET x64" "%DOTNET64%"
call :file ".NET x86" "%DOTNET32%"
call :verb dotnetdesktop10
"%DOTNET64%" --list-runtimes 2>nul | findstr /c:"Microsoft.WindowsDesktop.App 10." >nul
if errorlevel 1 (echo [KO] run: dotnet --list-runtimes: no WindowsDesktop.App 10 & set ERR=1) else (echo [OK] run: dotnet --list-runtimes: WindowsDesktop.App 10)
echo.

echo [PowerShell (winetricks)]
call :file "pwsh" "C:\Program Files\PowerShell\7\pwsh.exe"
call :file "powershell.exe x64 wrapper" "%SYS64%\WindowsPowerShell\v1.0\powershell.exe"
call :file "powershell.exe x86 wrapper" "%SYS32%\WindowsPowerShell\v1.0\powershell.exe"
call :verb powershell
rem pwsh needs a console under Wine (docker run -t): without it, no output
powershell -NoProfile -Command "Write-Output ('PS=' + $PSVersionTable.PSVersion.Major)" 2>nul | findstr /x /c:"PS=7" >nul
if errorlevel 1 (echo [KO] run: powershell -Command: no PowerShell 7 & set ERR=1) else (echo [OK] run: powershell -Command: PowerShell 7)
echo.

if %ERR%==0 (echo RESULT: everything is installed.) else (echo RESULT: some items are missing!)
exit /b %ERR%

rem ---------------------------------------------------------------------------
rem :file <label> <path>: check that a file exists
:file
rem (path quoted in the message: a ")" in it, as in "(x86)", would close the block)
if exist "%~2" (echo [OK] %~1) else (echo [KO] %~1: "%~2" & set ERR=1)
goto :eof

rem :gecko <label> <folder>: check wine_gecko\xul.dll, for any version
:gecko
set FOUND=0
rem (Wine cmd does not accept a quoted pattern in "for /d")
if exist "%~2" for /d %%G in (%~2\*) do if exist "%%G\wine_gecko\xul.dll" set FOUND=1
if %FOUND%==1 (echo [OK] %~1) else (echo [KO] %~1: %~2\*\wine_gecko\xul.dll & set ERR=1)
goto :eof

rem :verb <verb>: check that the winetricks verb is in winetricks.log
:verb
findstr /x /c:"%~1" "%WTLOG%" >nul 2>&1
if errorlevel 1 (echo [KO] winetricks %~1: not in %WTLOG% & set ERR=1) else (echo [OK] winetricks %~1)
goto :eof
