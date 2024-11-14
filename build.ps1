
# .SYNOPSIS
#   BoxOptimizer build script
# .DESCRIPTION
#   A build script that uses a builder module 🗿
# .LINK
#   https://github.com/alainQtec/BoxOptimizer/blob/main/build.ps1
# .NOTES
#   Author   : Alain Herve
#   Copyright: Copyright © 2024 Alain Herve. All rights reserved.
#   License  : MIT
[cmdletbinding(DefaultParameterSetName = 'task')]
param(
    [parameter(Position = 0, ParameterSetName = 'task')]
    [ValidateScript({
            $task_seq = [string[]]$_; $IsValid = $true
            $Tasks = @('Init', 'Clean', 'Compile', 'Import', 'Test', 'Deploy')
            ForEach ($name in $task_seq) {
                $IsValid = $IsValid -and ($name -in $Tasks)
            }
            if ($IsValid) {
                return $true
            }
            else {
                throw [System.ArgumentException]::new('Task', "ValidSet: $($Tasks -join ', ').")
            }
        }
    )][ValidateNotNullOrEmpty()]
    [string[]]$Task = @('Init', 'Clean', 'Compile', 'Import'),

    [parameter(ParameterSetName = 'help')]
    [Alias('-Help')]
    [switch]$Help
)
# Import the "buider module" and use Build-Module cmdlet to build this module:
Import-Module PsCraft; Build-Module -Task $Task
      