
rem # run perl tidy on the perl-tidy script

pushd %~dp0

cmd.exe /c perltidy ..\InstallCpanModules.pl
echo %ErrorLevel%

del /S /Q ..\InstallCpanModules.pl.bak
echo %ErrorLevel%

popd

exit /b 0
