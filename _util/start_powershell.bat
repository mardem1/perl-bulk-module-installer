set PS1_FULLPATH=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
set POWERSHELL=powershell

if exist "%PS1_FULLPATH%" set POWERSHELL=%PS1_FULLPATH%

start "powershell" /I "%POWERSHELL%" -NoProfile -ExecutionPolicy ByPass -NoLogo
