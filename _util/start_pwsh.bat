set PS1_FULLPATH_6=C:\Program Files\PowerShell\6\pwsh.exe
set PS1_FULLPATH_7=C:\Program Files\PowerShell\7\pwsh.exe
set PS1_FULLPATH_NV=C:\Program Files\PowerShell\pwsh.exe
set PWSH=pwsh

if exist "%PS1_FULLPATH_6%" set PWSH=%PS1_FULLPATH_6%
if exist "%PS1_FULLPATH_7%" set PWSH=%PS1_FULLPATH_7%
if exist "%PS1_FULLPATH_NV%" set PWSH=%PS1_FULLPATH_NV%

start "pwsh" /I "%PWSH%" -NoProfile -ExecutionPolicy ByPass -NoLogo
