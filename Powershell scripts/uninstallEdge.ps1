$pathName = Get-ChildItem ${env:PROGRAMFILES(X86)}\Microsoft\Edge\Application\ | Select-Object Name -First 1
$versionFolder = $pathName.Name
Set-Location ${env:PROGRAMFILES(X86)}\Microsoft\Edge\Application\${versionFolder}\Installer\
cmd.exe /c setup --uninstall --force-uninstall --system-level