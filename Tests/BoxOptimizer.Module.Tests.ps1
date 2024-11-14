
$script:ModuleName = (Get-Item "$PSScriptRoot/..").Name
$script:ModulePath = Resolve-Path "$PSScriptRoot/../BuildOutput/$ModuleName" | Get-Item
$script:moduleVersion = ((Get-ChildItem $ModulePath).Where({ $_.Name -as 'version' -is 'version' }).Name -as 'version[]' | Sort-Object -Descending)[0].ToString()

Write-Host "[+] Testing the latest built module:" -ForegroundColor Green
Write-Host "      ModuleName    $ModuleName"
Write-Host "      ModulePath    $ModulePath"
Write-Host "      Version       $moduleVersion`n"

Get-Module -Name $ModuleName | Remove-Module # Make sure no versions of the module are loaded

Write-Host "[+] Reading module information ..." -ForegroundColor Green
$script:ModuleInformation = Import-Module -Name "$ModulePath" -PassThru
$script:ModuleInformation | Format-List

Write-Host "[+] Get all functions present in the Manifest ..." -ForegroundColor Green
$script:ExportedFunctions = $ModuleInformation.ExportedFunctions.Values.Name
Write-Host "      ExportedFunctions: " -ForegroundColor DarkGray -NoNewline
Write-Host $($ExportedFunctions -join ', ')
$script:PS1Functions = Get-ChildItem -Path "$ModulePath/$moduleVersion/Public/*.ps1"

Describe "Module tests for $($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')))" {
  Context " Confirm valid Manifest file" {
    It "Should contain RootModule" {
      ![string]::IsNullOrWhiteSpace($ModuleInformation.RootModule) | Should -Be $true
    }

    It "Should contain ModuleVersion" {
      ![string]::IsNullOrWhiteSpace($ModuleInformation.Version) | Should -Be $true
    }

    It "Should contain GUID" {
      ![string]::IsNullOrWhiteSpace($ModuleInformation.Guid) | Should -Be $true
    }

    It "Should contain Author" {
      ![string]::IsNullOrWhiteSpace($ModuleInformation.Author) | Should -Be $true
    }

    It "Should contain Description" {
      ![string]::IsNullOrWhiteSpace($ModuleInformation.Description) | Should -Be $true
    }
  }
  Context " Should export all public functions " {
    It "Compare the number of Function Exported and the PS1 files found in the public folder" {
      $status = $ExportedFunctions.Count -eq $PS1Functions.Count
      $status | Should -Be $true
    }

    It "The number of missing functions should be 0 " {
      If ($ExportedFunctions.count -ne $PS1Functions.count) {
        $Compare = Compare-Object -ReferenceObject $ExportedFunctions -DifferenceObject $PS1Functions.Basename
        $($Compare.InputObject -Join '').Trim() | Should -BeNullOrEmpty
      }
    }
  }
  Context " Confirm files are valid Powershell syntax " {
    $_scripts = $(Get-Item -Path "$ModulePath/$moduleVersion").GetFiles(
      "*", [System.IO.SearchOption]::AllDirectories
    ).Where({ $_.Extension -in ('.ps1', '.psd1', '.psm1') })
    $testCase = $_scripts | ForEach-Object { @{ file = $_ } }
    It "ie: each Script/Ps1file should have valid Powershell sysntax" -TestCases $testCase {
      param($file) $contents = Get-Content -Path $file.fullname -ErrorAction Stop
      $errors = $null; [void][System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
      $errors.Count | Should -Be 0
    }
  }
  Context " Confirm there are no duplicate function names in private and public folders" {
    It ' Should have no duplicate functions' {
      $Publc_Dir = Get-Item -Path ([IO.Path]::Combine("$ModulePath/$moduleVersion", 'Public'))
      $Privt_Dir = Get-Item -Path ([IO.Path]::Combine("$ModulePath/$moduleVersion", 'Private'))
      $funcNames = @(); Test-Path -Path ([string[]]($Publc_Dir, $Privt_Dir)) -PathType Container -ErrorAction Stop
      $Publc_Dir.GetFiles("*", [System.IO.SearchOption]::AllDirectories) + $Privt_Dir.GetFiles("*", [System.IO.SearchOption]::AllDirectories) | Where-Object { $_.Extension -eq '.ps1' } | ForEach-Object { $funcNames += $_.BaseName }
      $($funcNames | Group-Object | Where-Object { $_.Count -gt 1 }).Count | Should -BeLessThan 1
    }
  }
}
Remove-Module -Name $ModuleName -Force
