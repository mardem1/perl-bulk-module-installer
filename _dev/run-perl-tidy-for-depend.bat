
rem # run perl tidy on the perl-tidy script

pushd %~dp0

cmd.exe /c perltidy ..\InstallCpanModules_Dependency_Async.pl
echo %ErrorLevel%

del /S /Q ..\InstallCpanModules_Dependency_Async.pl.bak
echo %ErrorLevel%

popd

exit /b 0
