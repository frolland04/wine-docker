@echo off
echo.
echo #############################################################################
echo This is a .BAT file for testing "wine-docker"!
echo This one calls the command formed by the argument list of the current script.
echo - script: "%~dpnx0"
echo - arguments: "%*"
echo #############################################################################
echo.
%*
