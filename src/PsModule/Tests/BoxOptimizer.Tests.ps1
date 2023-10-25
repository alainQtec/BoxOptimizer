$ModuleName = (Get-Item $PSScriptRoot).Name
$ModulePath = [IO.Path]::Combine($PSScriptRoot, "BuildOutput", $ModuleName) | Get-Item
$moduleVersion = ((Get-ChildItem $ModulePath).Where({ $_.Name -as 'version' -is 'version' }).Name -as 'version[]' | Sort-Object -Descending)[0].ToString()
Get-Module -Name $ModuleName | Remove-Module # Make sure no versions of the module are loaded
Write-Host "[+] Import the module and store the information about the module ..." -ForegroundColor Green
$ModuleInformation = Import-Module -Name "$ModulePath" -PassThru
$ModuleInformation | Format-List
Write-Host "[+] Get all functions present in the Manifest ..." -ForegroundColor Green
$ExportedFunctions = $ModuleInformation.ExportedFunctions.Values.Name
Write-Host "[+] Get all functions present in the Public folder ..." -ForegroundColor Green
$PS1Functions = Get-ChildItem -Path "$ModulePath\$moduleVersion\Public\*.ps1"
Describe "Module tests: $($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')))" {
    Context " Confirm valid Manifest file" {
        It "Should contain RootModule" {
            $ModuleInformation.RootModule | Should -Not -BeNullOrEmpty
        }
        It "Should contain ModuleVersion" {
            $ModuleInformation.Version | Should -Not -BeNullOrEmpty
        }
        It "Should contain GUID" {
            $ModuleInformation.Guid | Should -Not -BeNullOrEmpty
        }
        It "Should contain Author" {
            $ModuleInformation.Author | Should -Not -BeNullOrEmpty
        }
        It "Should contain Description" {
            $ModuleInformation.Description | Should -Not -BeNullOrEmpty
        }
        It "Compare the count of Function Exported and the PS1 files found" {
            $status = $ExportedFunctions.Count -eq $PS1Functions.Count
            $status | Should Be $true
        }
        It "Compare the missing function" {
            If ($ExportedFunctions.count -ne $PS1Functions.count) {
                $Compare = Compare-Object -ReferenceObject $ExportedFunctions -DifferenceObject $PS1Functions.Basename
                $Compare.InputObject -Join ',' | Should BeNullOrEmpty
            }
        }
    }
    Context " Confirm files are valid Powershell syntax" {
        $_scripts = $(Get-Item -Path "$ModulePath/$moduleVersion").GetFiles(
            "*", [System.IO.SearchOption]::AllDirectories
        ).Where({ $_.Extension -in ('.ps1', '.psd1', '.psm1') })
        $testCase = $_scripts | ForEach-Object { @{ file = $_ } }
        It "Script <file> Should have valid Powershell sysntax" -TestCases $testCase {
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
             ($funcNames | Group-Object | Where-Object { $_.Count -gt 1 }).Count | Should -BeLessThan 1
        }
    }
}
Get-Module -Name $ModuleName | Remove-Module