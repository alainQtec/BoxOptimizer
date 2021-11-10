#Requires -RunAsAdministrator

$pathName = Get-ChildItem ${env:PROGRAMFILES(X86)}\Microsoft\Edge\Application\ | Select-Object Name -First 1
$versionFolder = $pathName.Name
Set-Location ${env:PROGRAMFILES(X86)}\Microsoft\Edge\Application\${versionFolder}\Installer\
#if script doesn't work copy this line and run it in cmd as administrator in c:\program files(x86)\Microsoft\Edge\Application\<version of edge>\Installer
cmd.exe /c setup --uninstall --force-uninstall --system-level