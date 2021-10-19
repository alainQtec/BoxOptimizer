#Requires -RunAsAdministrator

$directoryPath = "$Env:WinDir\temp", "$Env:WinDir\prefetch", "$ENV:userprofile\AppData\Local\Temp"

for ($i = 0; $i -lt $directoryPath.Count; $i++) {
    Set-Location $directoryPath[$i]
    Remove-Item * -Recurse -Force
}