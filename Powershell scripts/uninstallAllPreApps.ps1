#Requires -RunAsAdministrator

Get-AppxPackage -AllUsers * | Remove-AppxPackage -ErrorAction 'silentlycontinue'