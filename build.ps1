
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
  [parameter(Mandatory = $false, Position = 0, ParameterSetName = 'task')]
  [ValidateScript({
      $task_seq = [string[]]$_; $IsValid = $true
      $Tasks = @('Clean', 'Compile', 'Test', 'Deploy')
      foreach ($name in $task_seq) {
        $IsValid = $IsValid -and ($name -in $Tasks)
      }
      if ($IsValid) {
        return $true
      } else {
        throw [System.ArgumentException]::new('Task', "ValidSet: $($Tasks -join ', ').")
      }
    }
  )][ValidateNotNullOrEmpty()][Alias('t')]
  [string[]]$Task = 'Test',

  # Module buildRoot
  [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'task')]
  [ValidateScript({
      if (Test-Path -Path $_ -PathType Container -ea Ignore) {
        return $true
      } else {
        throw [System.ArgumentException]::new('Path', "Path: $_ is not a valid directory.")
      }
    })][Alias('p')]
  [string]$Path = (Resolve-Path .).Path,

  [Parameter(Mandatory = $false, ParameterSetName = 'task')]
  [string[]]$RequiredModules = @(),

  [parameter(ParameterSetName = 'task')]
  [Alias('i')]
  [switch]$Import,

  [parameter(ParameterSetName = 'help')]
  [Alias('h', '-help')]
  [switch]$Help
)

begin {
  if ($PSCmdlet.ParameterSetName -eq 'help') { Get-Help $MyInvocation.MyCommand.Source -Full | Out-String | Write-Host -f Green; return }
  $req = Invoke-WebRequest -Method Get -Uri https://raw.githubusercontent.com/alainQtec/PsCraft/refs/heads/main/Public/Build-Module.ps1 -SkipHttpErrorCheck -Verbose:$false
  if ($req.StatusCode -ne 200) { throw "Failed to download Build-Module.ps1" }
  . ([ScriptBlock]::Create("$($req.Content)"))
}
process {
  Build-Module -Task $Task -Path $Path -Import:$Import
}