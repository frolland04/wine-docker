@echo off
echo.
echo #############################################################################
echo This is a .BAT file for testing "wine-docker"!
echo This one calls some testing commands.
echo - script: "%~dpnx0"
echo - arguments: "%*"
echo #############################################################################
echo.
rem The following shows the script name
echo "%~dpnx0"
rem The following shows the script arguments
echo "%*"
rem This shows nothing but a blank line
echo.
rem This shows the PATH environment variable
echo %PATH%
echo.
rem This shows the content of C:\
dir C:\
echo.
rem This shows the content of Z:\
dir /W Z:\
echo.