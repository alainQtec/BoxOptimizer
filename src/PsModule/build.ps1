<#
.SYNOPSIS
    BoxOptimizer buildScript
.DESCRIPTION
    A custom Psake buildScript for the module BoxOptimizer.
.LINK
    https://github.com/alainQtec/BoxOptimizer/blob/main/build.ps1
.EXAMPLE
    Running ./build.ps1 will only "Init, Compile & Import" the module; That's it, no tests.
    To run tests Use:
    ./build.ps1 -Task Test
    This Will build the module, Import it and run tests using the ./Test-Module.ps1 script.
.EXAMPLE
    ./build.ps1 -Task deploy
    Will build the module, test it and deploy it to PsGallery
#>
[cmdletbinding(DefaultParameterSetName = 'task')]
param(
    [parameter(Position = 0, ParameterSetName = 'task')]
    [ValidateScript({
            $task_seq = [string[]]$_; $IsValid = $true
            $Tasks = @('Init', 'Clean', 'Compile', 'Import', 'Test', 'Deploy')
            foreach ($name in $task_seq) {
                $IsValid = $IsValid -and ($name -in $Tasks)
            }
            if ($IsValid) {
                return $true
            } else {
                throw [System.ArgumentException]::new('Task', "ValidSet: $($Tasks -join ', ').")
            }
        }
    )][ValidateNotNullOrEmpty()]
    [string[]]$Task = @('Init', 'Clean', 'Compile', 'Import'),

    [parameter(ParameterSetName = 'help')]
    [Alias('-Help')]
    [switch]$Help
)

Begin {
    #Requires -RunAsAdministrator
    if ($null -ne ${env:=::}) { Throw 'Please Run this script as Administrator' }
    #region    Variables
    [Environment]::SetEnvironmentVariable('IsAC', $(if (![string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('GITHUB_WORKFLOW'))) { '1' } else { '0' }), [System.EnvironmentVariableTarget]::Process)
    [Environment]::SetEnvironmentVariable('IsCI', $(if (![string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('TF_BUILD'))) { '1' }else { '0' }), [System.EnvironmentVariableTarget]::Process)
    [Environment]::SetEnvironmentVariable('RUN_ID', $(if ([bool][int]$env:IsAC -or $env:CI -eq "true") { [Environment]::GetEnvironmentVariable('GITHUB_RUN_ID') }else { [Guid]::NewGuid().Guid.substring(0, 21).replace('-', [string]::Join('', (0..9 | Get-Random -Count 1))) + '_' }), [System.EnvironmentVariableTarget]::Process);
    $dataFile = [System.IO.FileInfo]::new([IO.Path]::Combine($PSScriptRoot, "$([System.Globalization.CultureInfo]::InstalledUICulture[0].Name)", 'BoxOptimizer.strings.psd1'))
    if (!$dataFile.Exists) { throw [System.IO.FileNotFoundException]::new('Unable to find the LocalizedData file.', 'BoxOptimizer.strings.psd1') }
    $script:localizedData = [scriptblock]::Create("$([IO.File]::ReadAllText($dataFile))").Invoke() # same as "Get-LocalizedData -DefaultUICulture 'en-US'" but the cmdlet is not always installed
    #region    ScriptBlocks
    $script:PSake_ScriptBlock = [scriptblock]::Create({
            # PSake makes variables declared here available in other scriptblocks
            Properties {
                $ProjectName = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')
                $BuildNumber = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildNumber')
                $ProjectRoot = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectPath')
                if (!$ProjectRoot) {
                    if ($pwd.Path -like "*ci*") {
                        Set-Location ..
                    }
                    $ProjectRoot = $pwd.Path
                }
                $outputDir = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildOutput')
                $Timestamp = Get-Date -UFormat "%Y%m%d-%H%M%S"
                $PSVersion = $PSVersionTable.PSVersion.ToString()
                $outputModDir = [IO.path]::Combine([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildOutput'), $ProjectName)
                $tests = "$projectRoot\Tests"
                $lines = ('-' * 70)
                $Verbose = @{}
                $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
                $outputModVerDir = [IO.path]::Combine([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildOutput'), $ProjectName, $BuildNumber)
                $PathSeperator = [IO.Path]::PathSeparator
                $DirSeperator = [IO.Path]::DirectorySeparatorChar
                if ([Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage') -match "!verbose") {
                    $Verbose = @{Verbose = $True }
                }
                $null = @($tests, $Verbose, $TestFile, $outputDir, $outputModDir, $outputModVerDir, $lines, $DirSeperator, $PathSeperator)
                $null = Invoke-Command -NoNewScope -ScriptBlock {
                    $l = [IO.File]::ReadAllLines([IO.Path]::Combine($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildScriptPath')), 'build.ps1'))
                    $t = New-Item $([IO.Path]::GetTempFileName().Replace('.tmp', '.ps1'))
                    Set-Content -Path "$($t.FullName)" -Value $l[$l.IndexOf('    #region    BuildHelper_Functions')..$l.IndexOf('    #endregion BuildHelper_Functions')] -Encoding UTF8 | Out-Null; . $t;
                    Remove-Item -Path $t.FullName
                }
            }
            FormatTaskName ({
                    param($String)
                    "$((Write-Heading "Executing task: {0}" -PassThru) -join "`n")" -f $String
                }
            )
            #Task Default -Depends Init,Test and Compile. Deploy Has to be done Manually
            Task default -depends Test

            Task Init {
                Set-Location $ProjectRoot
                Write-Verbose "Build System Details:"
                Write-Verbose "$((Get-ChildItem Env: | Where-Object {$_.Name -match "^(BUILD_|SYSTEM_|BH)"} | Sort-Object Name | Format-Table Name,Value -AutoSize | Out-String).Trim())"
                Write-Verbose "Module Build version: $BuildNumber"
            } -description 'Initialize build environment'

            Task clean -depends Init {
                $Host.UI.WriteLine()
                Remove-Module $ProjectName -Force -ErrorAction SilentlyContinue
                if (Test-Path -Path $outputDir -PathType Container -ErrorAction SilentlyContinue) {
                    Write-Verbose "Cleaning Previous build Output ..."
                    Get-ChildItem -Path $outputDir -Recurse -Force | Remove-Item -Force -Recurse
                }
                "    Cleaned previous Output directory [$outputDir]"
            } -description 'Cleans module output directory'

            Task Compile -depends Clean {
                Write-Verbose "Create module Output directory"
                New-Item -Path $outputModVerDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                $ModuleManifest = [IO.FileInfo]::New([Environment]::GetEnvironmentVariable($env:RUN_ID + 'PSModuleManifest'))
                Write-Verbose "Add Module files ..."
                try {
                    @(
                        "$([System.Globalization.CultureInfo]::InstalledUICulture[0].Name)"
                        "Private"
                        "Public"
                        "LICENSE"
                        "$($ModuleManifest.Name)"
                        "$ProjectName.psm1"
                    ).ForEach({ Copy-Item -Recurse -Path $([IO.Path]::Combine($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildScriptPath')), $_)) -Destination $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'PSModulePath')) })
                } catch {
                    throw $_
                }
                if (!$ModuleManifest.Exists) { throw [System.IO.FileNotFoundException]::New('Could Not Create Module Manifest!') }
                $functionsToExport = @(); $publicFunctionsPath = [IO.Path]::Combine([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectPath'), "Public")
                if (Test-Path $publicFunctionsPath -PathType Container -ErrorAction SilentlyContinue) {
                    Get-ChildItem -Path $publicFunctionsPath -Filter "*.ps1" -Recurse -File | ForEach-Object {
                        $functionsToExport += $_.BaseName
                    }
                }
                $manifestContent = Get-Content -Path $ModuleManifest -Raw
                $publicFunctionNames = Get-ChildItem -Path $publicFunctionsPath -Filter "*.ps1" | Select-Object -ExpandProperty BaseName

                Write-Verbose -Message "Editing $($ModuleManifest.Name) ..."
                # Using .Replace() is Better than Update-ModuleManifest as this does not destroy the Indentation in the Psd1 file.
                $manifestContent = $manifestContent.Replace(
                    "'<FunctionsToExport>'", $(if ((Test-Path -Path $publicFunctionsPath) -and $publicFunctionNames.count -gt 0) { "'$($publicFunctionNames -join "',`n        '")'" }else { $null })
                ).Replace(
                    "<ModuleVersion>", $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildNumber'))
                ).Replace(
                    "<ReleaseNotes>", $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ReleaseNotes'))
                ).Replace(
                    "<Year>", ([Datetime]::Now.Year)
                )
                $manifestContent | Set-Content -Path $ModuleManifest
                if ((Get-ChildItem $outputModVerDir | Where-Object { $_.Name -eq "$($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))).psd1" }).BaseName -cne $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))) {
                    "    Renaming manifest to correct casing"
                    Rename-Item (Join-Path $outputModVerDir "$($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))).psd1") -NewName "$($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))).psd1" -Force
                }
                $Host.UI.WriteLine()
                "    Created compiled module at [$outputModDir]"
                "    Output version directory contents"
                Get-ChildItem $outputModVerDir | Format-Table -AutoSize
            } -description 'Compiles module from source'

            Task Import -depends Compile {
                $Host.UI.WriteLine()
                '    Testing import of the Compiled module.'
                Test-ModuleManifest -Path $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'PSModuleManifest'))
                Import-Module $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'PSModuleManifest'))
            } -description 'Imports the newly compiled module'

            Task Test -depends Import {
                Write-Heading "Executing Script: ./Test-Module.ps1"
                $test_Script = [IO.FileInfo]::New([IO.Path]::Combine($ProjectRoot, 'Test-Module.ps1'))
                if (!$test_Script.Exists) { throw [System.IO.FileNotFoundException]::New($test_Script.FullName) }
                Import-Module Pester -Verbose:$false -Force -ErrorAction Stop
                $origModulePath = $Env:PSModulePath
                Push-Location $ProjectRoot
                if ($Env:PSModulePath.split($pathSeperator) -notcontains $outputDir ) {
                    $Env:PSModulePath = ($outputDir + $pathSeperator + $origModulePath)
                }
                Remove-Module $ProjectName -ErrorAction SilentlyContinue -Verbose:$false
                Import-Module $outputModDir -Force -Verbose:$false
                $Host.UI.WriteLine();
                $TestResults = & $test_Script
                Write-Host '    Pester invocation complete!' -ForegroundColor Green
                $TestResults | Format-List
                if ($TestResults.FailedCount -gt 0) {
                    Write-Error -Message "One or more Pester tests failed!"
                }
                Pop-Location
                $Env:PSModulePath = $origModulePath
            } -description 'Run Pester tests against compiled module'

            Task Deploy -depends Test -description 'Release new github version and Publish module to PSGallery' {
                if ([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildSystem') -eq 'VSTS' -or ($env:CI -eq "true" -and $env:GITHUB_RUN_ID)) {
                    # Load the module, read the exported functions, update the psd1 FunctionsToExport
                    $commParsed = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage') | Select-String -Pattern '\sv\d+\.\d+\.\d+\s'
                    if ($commParsed) {
                        $commitVer = $commParsed.Matches.Value.Trim().Replace('v', '')
                    }
                    $current_build_version = $CurrentVersion = (Get-Module $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))).Version
                    $Latest_Module_Verion = Get-LatestModuleVersion -Name ([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')) -Source PsGallery
                    "Module Current version on the PSGallery: $Latest_Module_Verion"
                    $galVerSplit = "$Latest_Module_Verion".Split('.')
                    $nextGalVer = [System.Version](($galVerSplit[0..($galVerSplit.Count - 2)] -join '.') + '.' + ([int]$galVerSplit[-1] + 1))
                    # Bump MODULE Version
                    $versionToDeploy = switch ($true) {
                        ($commitVer -and ([System.Version]$commitVer -lt $nextGalVer)) {
                            Write-Host -ForegroundColor Yellow "Version in commit message is $commitVer, which is less than the next Gallery version and would result in an error. Possible duplicate deployment build, skipping module bump and negating deployment"
                            Set-EnvironmentVariable -name ($env:RUN_ID + 'CommitMessage') -Value $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage')).Replace('!deploy', '')
                            $null
                            break
                        }
                        ($commitVer -and ([System.Version]$commitVer -gt $nextGalVer)) {
                            Write-Host -ForegroundColor Green "Module Bumped version: $commitVer [from commit message]"
                            [System.Version]$commitVer
                            break
                        }
                        ($CurrentVersion -ge $nextGalVer) {
                            Write-Host -ForegroundColor Green "Module Bumped version: $CurrentVersion [from manifest]"
                            $CurrentVersion
                            break
                        }
                        ($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage')) -match '!hotfix') {
                            Write-Host -ForegroundColor Green "Module Bumped version: $nextGalVer [commit message match '!hotfix']"
                            $nextGalVer
                            break
                        }
                        ($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage')) -match '!minor') {
                            $minorVers = [System.Version]("{0}.{1}.{2}" -f $nextGalVer.Major, ([int]$nextGalVer.Minor + 1), 0)
                            Write-Host -ForegroundColor Green "Module Bumped version: $minorVers [commit message match '!minor']"
                            $minorVers
                            break
                        }
                        ($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage')) -match '!major') {
                            $majorVers = [System.Version]("{0}.{1}.{2}" -f ([int]$nextGalVer.Major + 1), 0, 0)
                            Write-Host -ForegroundColor Green "Module Bumped version: $majorVers [commit message match '!major']"
                            $majorVers
                            break
                        }
                        Default {
                            Write-Host -ForegroundColor Green "Module Bumped version: $nextGalVer [PSGallery next version]"
                            $nextGalVer
                        }
                    }
                    if (!$versionToDeploy) {
                        Write-Host -ForegroundColor Yellow "No module version matched! Negating deployment to prevent errors"
                        Set-EnvironmentVariable -name ($env:RUN_ID + 'CommitMessage') -Value $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage')).Replace('!deploy', '')
                    }
                    try {
                        [ValidateNotNullOrWhiteSpace()][string]$versionToDeploy = $versionToDeploy.ToString()
                        $manifest = Import-PowerShellDataFile -Path $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'PSModuleManifest'))
                        $latest_Github_release = Invoke-WebRequest "https://api.github.com/repos/alainQtec/BoxOptimizer/releases/latest" | ConvertFrom-Json
                        $latest_Github_release = [PSCustomObject]@{
                            name = $latest_Github_release.name
                            ver  = [version]::new($latest_Github_release.tag_name.substring(1))
                            url  = $latest_Github_release.html_url
                        }
                        $Is_Lower_PsGallery_Version = [version]$current_build_version -le $Latest_Module_Verion
                        $should_Publish_ToPsGallery = ![string]::IsNullOrWhiteSpace($env:NUGETAPIKEY) -and !$Is_Lower_PsGallery_Version
                        $Is_Lower_GitHub_Version = [version]$current_build_version -le $latest_Github_release.ver
                        $should_Publish_GitHubRelease = ![string]::IsNullOrWhiteSpace($env:GitHubPAT) -and ($env:CI -eq "true" -and $env:GITHUB_RUN_ID) -and !$Is_Lower_GitHub_Version
                        if ($should_Publish_ToPsGallery) {
                            $manifestPath = Join-Path $outputModVerDir "$($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))).psd1"
                            if (-not $manifest) {
                                $manifest = Import-PowerShellDataFile -Path $manifestPath
                            }
                            if ($manifest.ModuleVersion.ToString() -eq $versionToDeploy.ToString()) {
                                "    Manifest is already the expected version. Skipping manifest version update"
                            } else {
                                "    Updating module version on manifest to [$versionToDeploy]"
                                Update-Metadata -Path $manifestPath -PropertyName ModuleVersion -Value $versionToDeploy -Verbose
                            }
                            Write-Host "    Publishing version [$versionToDeploy] to PSGallery..." -ForegroundColor Green
                            Publish-Module -Path $outputModVerDir -NuGetApiKey $env:NUGETAPIKEY -Repository PSGallery -Verbose
                            Write-Host "    Published to PsGallery successful!" -ForegroundColor Green
                        } else {
                            if ($Is_Lower_PsGallery_Version) { Write-Warning "SKIPPED Publishing. Module version $Latest_Module_Verion already exists on PsGallery!" }
                            Write-verbose "    SKIPPED Publish of version [$versionToDeploy] to PSGallery"
                        }
                        $commitId = git rev-parse --verify HEAD;
                        if ($should_Publish_GitHubRelease) {
                            $ReleaseNotes = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ReleaseNotes')
                            [ValidateNotNullOrWhiteSpace()][string]$ReleaseNotes = $ReleaseNotes
                            "    Creating Release ZIP..."
                            $ZipTmpPath = [System.IO.Path]::Combine($PSScriptRoot, "$($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))).zip")
                            if ([IO.File]::Exists($ZipTmpPath)) { Remove-Item $ZipTmpPath -Force }
                            Add-Type -Assembly System.IO.Compression.FileSystem
                            [System.IO.Compression.ZipFile]::CreateFromDirectory($outputModDir, $ZipTmpPath)
                            Write-Heading "    Publishing Release v$versionToDeploy @ commit Id [$($commitId)] to GitHub..."
                            $ReleaseNotes += (git log -1 --pretty=%B | Select-Object -Skip 2) -join "`n"
                            $ReleaseNotes = $ReleaseNotes.Replace('<versionToDeploy>', $versionToDeploy)
                            Set-EnvironmentVariable -name ('{0}{1}' -f $env:RUN_ID, 'ReleaseNotes') -Value $ReleaseNotes
                            $gitHubParams = @{
                                VersionNumber    = $versionToDeploy
                                CommitId         = $commitId
                                ReleaseNotes     = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ReleaseNotes')
                                ArtifactPath     = $ZipTmpPath
                                GitHubUsername   = 'alainQtec'
                                GitHubRepository = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')
                                GitHubApiKey     = $env:GitHubPAT
                                Draft            = $false
                            }
                            Publish-GithubRelease @gitHubParams
                            Write-Heading "    Github release created successful!"
                        } else {
                            if ($Is_Lower_GitHub_Version) { Write-Warning "SKIPPED Releasing. Module version $current_build_version already exists on Github!" }
                            Write-verbose "    SKIPPED GitHub Release v$($versionToDeploy) @ commit Id [$($commitId)] to GitHub"
                        }
                    } catch {
                        $_ | Format-List * -Force
                        Write-BuildError $_
                    }
                } else {
                    Write-Host -ForegroundColor Magenta "UNKNOWN Build system"
                }
            }
        }
    )
    $script:PSake_Build = [ScriptBlock]::Create({
            @(
                "Psake"
                "Pester"
                "PSScriptAnalyzer"
            ) | Resolve-Module -UpdateModule -Verbose
            $Host.UI.WriteLine()
            Write-BuildLog "Module Requirements Successfully resolved."
            $null = Set-Content -Path $Psake_BuildFile -Value $PSake_ScriptBlock

            Write-Heading "Invoking psake with task list: [ $($Task -join ', ') ]"
            $psakeParams = @{
                nologo    = $true
                buildFile = $Psake_BuildFile.FullName
                taskList  = $Task
            }
            if ($Task -contains 'TestOnly') {
                Set-Variable -Name ExcludeTag -Scope global -Value @('Module')
            } else {
                Set-Variable -Name ExcludeTag -Scope global -Value $null
            }
            Invoke-psake @psakeParams @verbose
            $Host.UI.WriteLine()
            Remove-Item $Psake_BuildFile -Verbose | Out-Null
            $Host.UI.WriteLine()
        }
    )
    $script:Clean_EnvBuildvariables = [scriptblock]::Create({
            Param (
                [Parameter(Position = 0)]
                [ValidatePattern('\w*')]
                [ValidateNotNullOrEmpty()]
                [string]$build_Id
            )
            if (![string]::IsNullOrWhiteSpace($build_Id)) {
                Write-Heading "CleanUp: Remove Environment Variables"
                $OldEnvNames = [Environment]::GetEnvironmentVariables().Keys | Where-Object { $_ -like "$build_Id*" }
                if ($OldEnvNames.Count -gt 0) {
                    foreach ($Name in $OldEnvNames) {
                        Write-BuildLog "Remove env variable $Name"
                        [Environment]::SetEnvironmentVariable($Name, $null)
                    }
                    [Console]::WriteLine()
                } else {
                    Write-BuildLog "No old Env variables to remove; Move on ...`n"
                }
            } else {
                Write-Warning "Invalid RUN_ID! Skipping ...`n"
            }
            $Host.UI.WriteLine()
        }
    )
    #endregion ScriptBlockss
    $Psake_BuildFile = New-Item $([IO.Path]::GetTempFileName().Replace('.tmp', '.ps1'))
    $verbose = @{}
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        $verbose['Verbose'] = $PSBoundParameters['Verbose']
    }
    #endregion Variables

    #region    BuildHelper_Functions
    function Set-BuildVariables {
        <#
        .SYNOPSIS
            Prepares build env variables
        .DESCRIPTION
            sets unique build env variables, and auto Cleans Last Builds's Env~ variables when on local pc
            good for cleaning leftover variables when last build fails
        #>
        [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
        param(
            [Parameter(Position = 0)]
            [ValidateNotNullOrEmpty()]
            [Alias('RootPath')]
            [string]$Path,

            [Parameter(Position = 1)]
            [ValidatePattern('\w*')]
            [ValidateNotNullOrEmpty()][Alias('Prefix', 'RUN_ID')]
            [String]$VarNamePrefix
        )
        begin {
            class dotEnv {
                [Array]static Read([string]$EnvFile) {
                    $content = Get-Content $EnvFile -ErrorAction Stop
                    $res_Obj = [System.Collections.Generic.List[string[]]]::new()
                    foreach ($line in $content) {
                        if ([string]::IsNullOrWhiteSpace($line)) {
                            Write-Verbose "[GetdotEnv] Skipping empty line"
                            continue
                        }
                        if ($line.StartsWith("#") -or $line.StartsWith("//")) {
                            Write-Verbose "[GetdotEnv] Skipping comment: $line"
                            continue
                        }
                        ($m, $d ) = switch -Wildcard ($line) {
                            "*:=*" { "Prefix", ($line -split ":=", 2); Break }
                            "*=:*" { "Suffix", ($line -split "=:", 2); Break }
                            "*=*" { "Assign", ($line -split "=", 2); Break }
                            Default {
                                throw 'Unable to find Key value pair in line'
                            }
                        }
                        $res_Obj.Add(($d[0].Trim(), $d[1].Trim(), $m));
                    }
                    return $res_Obj
                }
                static [void] Update([string]$EnvFile, [string]$Key, [string]$Value) {
                    [void]($d = [dotenv]::Read($EnvFile) | Select-Object @{l = 'key'; e = { $_[0] } }, @{l = 'value'; e = { $_[1] } }, @{l = 'method'; e = { $_[2] } })
                    $Entry = $d | Where-Object { $_.key -eq $Key }
                    if ([string]::IsNullOrEmpty($Entry)) {
                        throw [System.Exception]::new("key: $Key not found.")
                    }
                    $Entry.value = $Value; $ms = [PSObject]@{ Assign = '='; Prefix = ":="; Suffix = "=:" };
                    Remove-Item $EnvFile -Force; New-Item $EnvFile -ItemType File | Out-Null;
                    foreach ($e in $d) { "{0} {1} {2}" -f $e.key, $ms[$e.method], $e.value | Out-File $EnvFile -Append -Encoding utf8 }
                }

                static [void] Set([string]$EnvFile) {
                    #return if no env file
                    if (!(Test-Path $EnvFile)) {
                        Write-Verbose "[setdotEnv] Could not find .env file"
                        return
                    }

                    #read the local env file
                    $content = [dotEnv]::Read($EnvFile)
                    Write-Verbose "[setdotEnv] Parsed .env file: $EnvFile"
                    foreach ($value in $content) {
                        switch ($value[2]) {
                            "Assign" {
                                [Environment]::SetEnvironmentVariable($value[0], $value[1], "Process") | Out-Null
                            }
                            "Prefix" {
                                $value[1] = "{0};{1}" -f $value[1], [System.Environment]::GetEnvironmentVariable($value[0])
                                [Environment]::SetEnvironmentVariable($value[0], $value[1], "Process") | Out-Null
                            }
                            "Suffix" {
                                $value[1] = "{1};{0}" -f $value[1], [System.Environment]::GetEnvironmentVariable($value[0])
                                [Environment]::SetEnvironmentVariable($value[0], $value[1], "Process") | Out-Null
                            }
                            Default {
                                throw [System.IO.InvalidDataException]::new()
                            }
                        }
                    }
                }
            }
        }

        Process {
            if (![bool][int]$env:IsAC) {
                $LocEnvFile = [IO.FileInfo]::New([IO.Path]::GetFullPath([IO.Path]::Combine($Path, '.env')))
                if (!$LocEnvFile.Exists) {
                    New-Item -Path $LocEnvFile.FullName -ItemType File -ErrorAction Stop
                    Write-BuildLog "Created a new .env file"
                }
                # Set all Default/Preset Env: variables from the .env
                [dotEnv]::Set($LocEnvFile);
                if (![string]::IsNullOrWhiteSpace($env:LAST_BUILD_ID)) {
                    [dotEnv]::Update($LocEnvFile, 'LAST_BUILD_ID', $env:RUN_ID);
                    Get-Item $LocEnvFile -Force | ForEach-Object { $_.Attributes = $_.Attributes -bor "Hidden" }
                    if ($PSCmdlet.ShouldProcess("$Env:ComputerName", "Clean Last Builds's Env~ variables")) {
                        Invoke-Command $Clean_EnvBuildvariables -ArgumentList $env:LAST_BUILD_ID
                    }
                }
            }
            $Version = $script:localizedData.ModuleVersion
            if ($null -eq $Version) { throw [System.ArgumentNullException]::new('version', "Please make sure localizedData.ModuleVersion is not null.") }
            Write-Heading "Set Build Variables for Version: $Version"
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'BuildStart') -Value $(Get-Date -Format o)
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'BuildScriptPath') -Value $Path
            Set-Variable -Name BuildScriptPath -Value ([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildScriptPath')) -Scope Local -Force
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'BuildSystem') -Value $(if ([bool][int]$env:IsCI -or ($Env:BUILD_BUILDURI -like 'vstfs:*')) { "VSTS" }else { [System.Environment]::MachineName })
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'ProjectPath') -Value $(if ([bool][int]$env:IsCI) { $Env:SYSTEM_DEFAULTWORKINGDIRECTORY }else { $BuildScriptPath })
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'BranchName') -Value $(if ([bool][int]$env:IsCI) { $Env:BUILD_SOURCEBRANCHNAME }else { $(Push-Location $BuildScriptPath; (git rev-parse --abbrev-ref HEAD).Trim(); Pop-Location) })
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'CommitMessage') -Value $(if ([bool][int]$env:IsCI) { $Env:BUILD_SOURCEVERSIONMESSAGE }else { $(Push-Location $BuildScriptPath; (git log --format=%B -n 1).Trim(); Pop-Location) })
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'BuildNumber') -Value $(if ([bool][int]$env:IsCI) { $Env:BUILD_BUILDNUMBER } else { $(if ([string]::IsNullOrWhiteSpace($Version)) { Set-Content $VersionFile -Value '1.0.0.1' -Encoding UTF8 -PassThru }else { $Version }) })
            Set-Variable -Name BuildNumber -Value ([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildNumber')) -Scope Local -Force
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'BuildOutput') -Value $([IO.path]::Combine($BuildScriptPath, "BuildOutput"))
            Set-Variable -Name BuildOutput -Value ([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildOutput')) -Scope Local -Force
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'ProjectName') -Value $script:localizedData.ModuleName
            Set-Variable -Name ProjectName -Value ([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')) -Scope Local -Force
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'PSModulePath') -Value $([IO.path]::Combine($BuildOutput, $ProjectName, $BuildNumber))
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'PSModuleManifest') -Value $([IO.path]::Combine($BuildOutput, $ProjectName, $BuildNumber, "$ProjectName.psd1"))
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'ModulePath') -Value $(if (![string]::IsNullOrWhiteSpace($Env:PSModuleManifest)) { [IO.Path]::GetDirectoryName($Env:PSModuleManifest) }else { [IO.Path]::GetDirectoryName($BuildOutput) })
            Set-EnvironmentVariable -Name ('{0}{1}' -f $env:RUN_ID, 'ReleaseNotes') -Value $script:localizedData.ReleaseNotes
        }
    }
    function Get-Elapsed {
        $buildstart = [Environment]::GetEnvironmentVariable($ENV:RUN_ID + 'BuildStart')
        $build_date = if ([string]::IsNullOrWhiteSpace($buildstart)) { Get-Date }else { Get-Date $buildstart }
        $elapse_msg = if ([bool][int]$env:IsCI) {
            "[ + $(((Get-Date) - $build_date).ToString())]"
        } else {
            "[$((Get-Date).ToString("HH:mm:ss")) + $(((Get-Date) - $build_date).ToString())]"
        }
        "$elapse_msg{0}" -f (' ' * (30 - $elapse_msg.Length))
    }
    function Write-TerminatingError {
        <#
        .SYNOPSIS
            Utility to throw an errorrecord
        .DESCRIPTION
            Utility to create ErrorRecords on systems that don't have ThrowError BuiltIn (ie: $PowerShellversion -lt core-6.1.0-windows)
        #>
        [CmdletBinding()]
        [OutputType([System.Management.Automation.ErrorRecord])]
        param (
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.PSCmdlet]
            $CallerPSCmdlet,

            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $ExceptionName,

            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $ExceptionMessage,

            [System.Object]
            $ExceptionObject,

            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $ErrorId,

            [parameter(Mandatory = $true)]
            [ValidateNotNull()]
            [System.Management.Automation.ErrorCategory]
            $ErrorCategory
        )

        $exception = New-Object $ExceptionName $ExceptionMessage;
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $ErrorCategory, $ExceptionObject
        $CallerPSCmdlet.ThrowTerminatingError($errorRecord)
    }
    function New-Directory {
        [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'str')]
        param (
            [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'str')]
            [ValidateNotNullOrEmpty()][string]$Path,
            [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'dir')]
            [ValidateNotNullOrEmpty()][System.IO.DirectoryInfo]$Dir
        )
        $nF = @(); $p = if ($PSCmdlet.ParameterSetName.Equals('str')) { [System.IO.DirectoryInfo]::New($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)) } else { $Dir }
        if ($PSCmdlet.ShouldProcess("Creating Directory '$($p.FullName)' ...", '', '')) {
            while (!$p.Exists) { $nF += $p; $p = $p.Parent }
            [Array]::Reverse($nF); $nF | ForEach-Object { $_.Create() }
        }
    }
    function Get-LocalModule {
        # .SYNOPSIS
        # Gets basic details of an Installed Psmodule
        # .DESCRIPTION
        # Its like using Get-InstalledModule but you can even find unregistered/"manually Installed" modules. (as long as they are in any of $env:PsmodulePath folders)
        # .EXAMPLE
        # Get-LocalModule psake | Select-Object -ExpandProperty Path | Import-Module -Verbose
        [CmdletBinding()]
        [OutputType([LocalPsModule])]
        param (
            # The name of the installed module to search on the machine.
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateNotNullOrEmpty()]
            [string]$Name,

            # The required module version. You don't use this parameter,
            # then this cmdlet will search for the highest version from the specified scope.
            [Parameter(Mandatory = $false, Position = 1)]
            [ValidateNotNullOrEmpty()]
            [version]$version,

            # If you don't use this parameter then, this cmdlet uses LocalMachine as a default scope.
            [Parameter(Mandatory = $false, Position = 2)]
            [ValidateSet('CurrentUser', 'LocalMachine')]
            [string]$Scope
        )
        begin {
            $PsModule = $null
            class LocalPsModule {
                [string]$Name
                [string]$version
                [IO.FileInfo]$Psd1
                [System.String]$Scope
                [IO.DirectoryInfo]$Path
                [bool]$Exists = $false
                [psobject]$Info = $null
                [bool]$IsReadOnly = $false
                [bool]$HasVersiondirs = $false

                LocalPsModule([string]$Name) {
                    $ModuleBase = $null; $AvailModls = Get-Module -ListAvailable -Name $Name -ErrorAction Ignore
                    if ($null -ne $AvailModls) { $ModuleBase = ($AvailModls.ModuleBase -as [string[]])[0] }
                    if ($null -ne $ModuleBase) {
                        $Module = $this::Find($Name, [IO.DirectoryInfo]::New($ModuleBase))
                        $this.IsReadOnly = $Module.IsReadOnly; $this.version = $Module.version;
                        $this.Exists = $Module.Exists; $this.Scope = $Module.Scope
                        $this.Path = $Module.Path
                        $this.Psd1 = $Module.Psd1
                        $this.Name = $Module.Name
                        $this.Info = $Module.Info
                    } else {
                        $this._Init_($Name, 'LocalMachine', $null)
                    }
                }
                LocalPsModule([string]$Name, [string]$scope) {
                    $this._Init_($Name, $scope, $null)
                }
                LocalPsModule([string]$Name, [version]$version) {
                    $this._Init_($Name, $null, $version)
                }
                LocalPsModule([string]$Name, [string]$scope, [version]$version) {
                    $this._Init_($Name, $scope, $version)
                }
                static hidden [PSCustomObject] Find([string]$Name) {
                    [ValidateNotNullOrEmpty()][string]$Name = $Name
                    $ModuleBase = $null; $AvailModls = Get-Module -ListAvailable -Name $Name -ErrorAction Ignore
                    if ($null -ne $AvailModls) { $ModuleBase = ($AvailModls.ModuleBase -as [string[]])[0] }
                    if ($null -ne $ModuleBase) {
                        return [LocalPsModule]::Find($Name, [IO.DirectoryInfo]::New($ModuleBase))
                    } else {
                        return [LocalPsModule]::Find($Name, 'LocalMachine', $null)
                    }
                }
                static hidden [PSCustomObject] Find([string]$Name, [IO.DirectoryInfo]$ModuleBase) {
                    [ValidateNotNullOrEmpty()][IO.DirectoryInfo]$ModuleBase = $ModuleBase
                    $result = [PSCustomObject]@{
                        Name       = [string]::Empty
                        Path       = $null
                        Psd1       = $null
                        Info       = @{}
                        scope      = 'LocalMachine'
                        Exists     = $false
                        Version    = [version]::New()
                        IsReadOnly = $false
                    }
                    $ModulePsd1 = ($ModuleBase.GetFiles().Where({ $_.Name -like "$Name*" -and $_.Extension -eq '.psd1' }))[0]
                    if ($null -eq $ModulePsd1) { return $result }
                    $result.Info = [LocalPsModule]::ReadPowershellDataFile($ModulePsd1.FullName)
                    $result.Name = $ModulePsd1.BaseName
                    $result.Psd1 = $ModulePsd1
                    $result.Path = if ($result.Psd1.Directory.Name -as [version] -is [version]) { $result.Psd1.Directory.Parent } else { $result.Psd1.Directory }
                    $result.Exists = $ModulePsd1.Exists
                    $result.Version = $result.Info.ModuleVersion -as [version]
                    $result.IsReadOnly = $ModulePsd1.IsReadOnly
                    return $result
                }
                static hidden [PSCustomObject] Find([string]$Name, [string]$scope, [version]$version) {
                    $ModuleScope = $scope; if ([string]::IsNullOrWhiteSpace($ModuleScope)) { $ModuleScope = 'LocalMachine' }
                    $Module = $null; $PsModule_Paths = $([LocalPsModule]::Get_Module_Paths($ModuleScope) |
                            ForEach-Object { [IO.DirectoryInfo]::New("$_") } | Where-Object { $_.Exists }
                    ).GetDirectories().Where({ $_.Name -eq $Name });
                    if ($PsModule_Paths.count -gt 0) {
                        $Get_versionDir = [scriptblock]::Create('param([IO.DirectoryInfo[]]$direcrory) return ($direcrory | ForEach-Object { $_.GetDirectories() | Where-Object { $_.Name -as [version] -is [version] } })')
                        $has_versionDir = $Get_versionDir.Invoke($PsModule_Paths).count -gt 0
                        $ModulePsdFiles = $PsModule_Paths | ForEach-Object {
                            if ($has_versionDir) {
                                [string]$MaxVersion = ($Get_versionDir.Invoke([IO.DirectoryInfo]::New("$_")) | Select-Object @{l = 'version'; e = { $_.BaseName -as [version] } } | Measure-Object -Property version -Maximum).Maximum
                                [IO.FileInfo]::New([IO.Path]::Combine("$_", $MaxVersion, $_.BaseName + '.psd1'))
                            } else {
                                [IO.FileInfo]::New([IO.Path]::Combine("$_", $_.BaseName + '.psd1'))
                            }
                        } | Where-Object { $_.Exists }
                        $Get_ModuleVersion = {
                            param ([Parameter(Mandatory)][string]$Psd1Path)
                            $data = [LocalPsModule]::ReadPowershellDataFile($Psd1Path)
                            $_ver = $data.ModuleVersion; if ($null -eq $_ver) { $_ver = [version][IO.FileInfo]::New($Psd1Path).Directory.Name }
                            return $_ver
                        }
                        $Req_ModulePsd1 = if ($null -eq $version) {
                            $ModulePsdFiles | Sort-Object -Property version -Descending | Select-Object -First 1
                        } else {
                            $ModulePsdFiles | Where-Object { $Get_ModuleVersion.Invoke($_.FullName) -eq $version }
                        }
                        $Module = [LocalPsModule]::Find($Req_ModulePsd1.Name, $Req_ModulePsd1.Directory)
                    }
                    return $Module
                }
                static [string[]] Get_Module_Paths() {
                    return [LocalPsModule]::Get_Module_Paths($null)
                }
                static [string[]] Get_Module_Paths([string]$scope) {
                    [string[]]$_Module_Paths = [System.Environment]::GetEnvironmentVariable('PSModulePath').Split([IO.Path]::PathSeparator)
                    if ([string]::IsNullOrWhiteSpace($scope)) { return $_Module_Paths }
                    [ValidateSet('CurrentUser', 'LocalMachine')][string]$scope = $scope
                    if (!(Get-Variable -Name IsWindows -ErrorAction Ignore) -or $(Get-Variable IsWindows -ValueOnly)) {
                        $psv = Get-Variable PSVersionTable -ValueOnly
                        $allUsers_path = Join-Path -Path $env:ProgramFiles -ChildPath $(if ($psv.ContainsKey('PSEdition') -and $psv.PSEdition -eq 'Core') { 'PowerShell' } else { 'WindowsPowerShell' })
                        if ($Scope -eq 'CurrentUser') { $_Module_Paths = $_Module_Paths.Where({ $_ -notlike "*$($allUsers_path | Split-Path)*" -and $_ -notlike "*$env:SystemRoot*" }) }
                    } else {
                        $allUsers_path = Split-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('SHARED_MODULES')) -Parent
                        if ($Scope -eq 'CurrentUser') { $_Module_Paths = $_Module_Paths.Where({ $_ -notlike "*$($allUsers_path | Split-Path)*" -and $_ -notlike "*/var/lib/*" }) }
                    }
                    return $_Module_Paths
                }
                static hidden [PSObject] ReadPowershellDataFile([string]$Psd1Path) {
                    $null = Get-Item -Path $Psd1Path -ErrorAction Stop
                    $data = New-Object PSObject; $text = [IO.File]::ReadAllText("$Psd1Path")
                    $data = [scriptblock]::Create("$text").Invoke()
                    return $data
                }
                hidden _Init_ ([string]$Name, [string]$scope, [version]$version) {
                    [ValidateSet('CurrentUser', 'LocalMachine')][string]$scope = $scope
                    $Module = [LocalPsModule]::Find($Name, $scope, $version); $this.IsReadOnly = $Module.IsReadOnly;
                    $this.version = $Module.version; $this.Exists = $Module.Exists; $this.Scope = $Module.Scope
                    $this.Path = $Module.Path
                    $this.Psd1 = $Module.Psd1
                    $this.Name = $Module.Name
                    $this.Info = $Module.Info
                }
            }
        }
        process {
            $PsModule = switch ($true) {
                $($PSBoundParameters.ContainsKey('version') -and $PSBoundParameters.ContainsKey('Scope')) { New-Object LocalPsModule($Name, $Scope, $version) ; break }
                $($PSBoundParameters.ContainsKey('version') -and !$PSBoundParameters.ContainsKey('Scope')) { New-Object LocalPsModule($Name, 'LocalMachine', $version) ; break }
                $(!$PSBoundParameters.ContainsKey('version') -and $PSBoundParameters.ContainsKey('Scope')) { New-Object LocalPsModule($Name, $Scope, $version) ; break }
                $(!$PSBoundParameters.ContainsKey('version') -and !$PSBoundParameters.ContainsKey('Scope')) { New-Object LocalPsModule($Name) ; break }
                Default { New-Object LocalPsModule($Name) }
            }
        }
        end {
            return $PsModule
        }
    }
    function Get-ModulePath {
        # .DESCRIPTION
        #  Gets the path of installed module; a path you can use with Import-module.
        # .EXAMPLE
        # Get-ModulePath -Name posh-git -version 0.7.3 | Import-module -verbose
        # Will retrieve posh-git version 0.7.3 from $env:psmodulepath and import it.
        [CmdletBinding()][OutputType([string])]
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateNotNullOrEmpty()]
            [string]$Name,

            [Parameter(Mandatory = $false, Position = 1)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({
                    if (!($_ -as 'version' -is [version])) {
                        throw [System.ArgumentException]::New('Please Provide a valid version string')
                    }; $true
                }
            )]
            [string]$version,

            [Parameter(Mandatory = $false, Position = 2)]
            [ValidateSet('CurrentUser', 'LocalMachine')]
            [string]$Scope = 'LocalMachine'
        )
        if ($PSBoundParameters.ContainsKey('version')) {
            return (Get-LocalModule -Name $Name -version ([version]::New($version)) -Scope $Scope).Path
        } else {
            return (Get-LocalModule -Name $Name -Scope $Scope).Path
        }
    }
    function Install-PsGalleryModule {
        #  .SYNOPSIS
        #     Like install-Module but it manually installs the module when the normal way fails.
        #  .DESCRIPTION
        #     Installs a PowerShell module even on systems that don't have a working PowerShellGet.
        #     But Sometimes you just need to apply a quick fix like this one:
        #
        #     Unregister-PSRepository -Name PSGallery
        #     Register-PSRepository -Default
        #     if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        #         Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        #     }
        #
        #     When all that fails, then this function comes in handy.
        [CmdletBinding()]
        [OutputType([IO.FileInfo])]
        param (
            [Parameter(Mandatory = $true)]
            [ValidateScript({ $_ -match '^[a-zA-Z0-9_.-]+$' })]
            [Alias('Name', 'n')]
            [string]$moduleName,

            [Parameter(Mandatory = $false)]
            [ValidateScript({ ($_ -as 'version') -is [version] -or $_ -eq 'latest' })]
            [string]$Version = 'latest',
            [switch]$UpdateOnly,
            [switch]$Passthru
        )
        Begin {
            $Get_Install_Path = [scriptblock]::Create({
                    param([string]$Name, [string]$ReqVersion)
                    $p = [IO.DirectoryInfo][IO.Path]::Combine(
                        $(if (!(Get-Variable -Name IsWindows -ErrorAction Ignore) -or $(Get-Variable IsWindows -ValueOnly)) {
                                $_versionTable = Get-Variable PSVersionTable -ValueOnly
                                $module_folder = if ($_versionTable.ContainsKey('PSEdition') -and $_versionTable.PSEdition -eq 'Core') { 'PowerShell' } else { 'WindowsPowerShell' }
                                Join-Path -Path $([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath $module_folder
                            } else {
                                Split-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('USER_MODULES')) -Parent
                            }
                        ), 'Modules'
                    )
                    if (![string]::IsNullOrWhiteSpace($ReqVersion)) {
                        [IO.Path]::Combine($p.FullName, $Name, $ReqVersion)
                    } else {
                        [IO.Path]::Combine($p.FullName, $Name)
                    }
                }
            )
            [int]$ret = 0; $response = $null; $downloadUrl = ''; $Module_Path = ''
            $InstallModule = [scriptblock]::Create({
                    # There are issues with pester 5.4.1 syntax, so I'll keep using -SkipPublisherCheck.
                    # https://stackoverflow.com/questions/51508982/pester-sample-script-gets-be-is-not-a-valid-should-operator-on-windows-10-wo
                    if ($Version -eq 'latest') {
                        Install-Module -Name $moduleName -SkipPublisherCheck:$($moduleName -eq 'Pester')
                    } else {
                        Install-Module -Name $moduleName -RequiredVersion $Version -SkipPublisherCheck:$($moduleName -eq 'Pester')
                    }
                }
            )
            $UpdateModule = [scriptblock]::Create({
                    try {
                        if ($Version -eq 'latest') {
                            Update-Module -Name $moduleName
                        } else {
                            Update-Module -Name $moduleName -RequiredVersion $Version
                        }
                    } catch {
                        if ($ret -lt 1 -and $_.ErrorRecord.Exception.Message -eq "Module '$moduleName' was not installed by using Install-Module, so it cannot be updated.") {
                            Get-Module $moduleName | Remove-Module -Force; $ret++
                            $UpdateModule.Invoke()
                        }
                    }
                }
            )
        }
        Process {
            # Try Using normal Installation
            try {
                if ($PSCmdlet.MyInvocation.BoundParameters['UpdateOnly']) {
                    $UpdateModule.Invoke()
                } else {
                    $InstallModule.Invoke()
                }
                $Module_Path = (Get-LocalModule -Name $moduleName).Psd1 | Split-Path -ErrorAction Stop
            } catch {
                $VerboseMsg = 'Normal Installation Failed :' + $_.Exception.Message + "`nUsing Manual Instalation ..."
                Write-Verbose $VerboseMsg -Verbose
                # For some reason Install-Module can fail (ex: on Arch). This is a manual workaround when that happens.
                $version_filter = if ($Version -eq 'latest') { 'IsLatestVersion' } else { "Version eq '$Version'" }
                $url = "https://www.powershellgallery.com/api/v2/Packages?`$filter=Id eq '$moduleName' and $version_filter"
                try {
                    $response = Invoke-RestMethod -Uri $url -Method Get -Verbose:$false
                    if ($null -eq $response) {
                        $Error_params = @{
                            ExceptionName    = 'System.InvalidOperationException'
                            ExceptionMessage = "Module '$moduleName' was not found in PSGallery repository."
                            ErrorId          = 'CouldNotFindModule'
                            CallerPSCmdlet   = $PSCmdlet
                            ErrorCategory    = 'InvalidResult'
                        }
                        Write-TerminatingError @Error_params
                    }
                    [ValidateNotNullOrEmpty()][string]$downloadUrl = $response.content.src
                    [ValidateNotNullOrEmpty()][string]$moduleName = $response.properties.Id
                    [ValidateNotNullOrEmpty()][string]$Version = $response.properties.Version
                    $Module_Path = $Get_Install_Path.Invoke($moduleName, $Version)
                } catch {
                    $Error_params = @{
                        ExceptionName    = 'System.InvalidOperationException'
                        ExceptionMessage = "Failed to find PsGallery release for '$moduleName' version '$Version'. Url used: '$url'. $($_.Exception.Message)"
                        ErrorId          = 'RestMethod_Failed'
                        CallerPSCmdlet   = $PSCmdlet
                        ErrorCategory    = 'OperationStopped'
                    }
                    Write-TerminatingError @Error_params
                }
                if (!(Test-Path -Path $Module_Path -PathType Container -ErrorAction Ignore)) { New-Directory -Path $Module_Path }
                $ModuleNupkg = [IO.Path]::Combine($Module_Path, "$moduleName.nupkg")
                Write-Host "Download $moduleName.nupkg ... " -NoNewline -ForegroundColor DarkCyan
                Invoke-WebRequest -Uri $downloadUrl -OutFile $ModuleNupkg -Verbose:$false;
                if ($IsWindows) { Unblock-File -Path $ModuleNupkg }
                Expand-Archive $ModuleNupkg -DestinationPath $Module_Path -Verbose:$false -Force
                $Items_to_CleanUp = [System.Collections.ObjectModel.Collection[System.Object]]::new()
                @('_rels', 'package', '*Content_Types*.xml', "$ModuleNupkg", "$($moduleName.Tolower()).nuspec" ) | ForEach-Object { [void]$Items_to_CleanUp.Add((Get-Item -Path "$Module_Path/$_" -ErrorAction Ignore)) }
                $Items_to_CleanUp = $Items_to_CleanUp | Sort-Object -Unique
                foreach ($Item in $Items_to_CleanUp) {
                    [bool]$Recurse = $Item.Attributes -eq [System.IO.FileAttributes]::Directory
                    Remove-Item -LiteralPath $Item.FullName -Recurse:$Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    function Get-LatestModuleVersion {
        [CmdletBinding()][OutputType([version])]
        param (
            [Parameter(Position = 0, Mandatory = $true)]
            [string]$Name,

            [Parameter(Position = 1, Mandatory = $false)]
            [ValidateSet('LocalMachine', 'PsGallery')]
            [string]$Source = 'PsGallery'
        )

        begin {
            $latest_Version = [version]::New()
        }
        process {
            if ($Source -eq 'LocalMachine') {
                $_Local_Module = Get-LocalModule -Name $Name
                if ($null -ne $_Local_Module) {
                    if ((Test-Path -Path $_Local_Module.Psd1 -PathType Leaf -ErrorAction Ignore)) {
                        $latest_Version = $_Local_Module.Version
                    }
                }
            } else {
                $url = "https://www.powershellgallery.com/packages/$Name/?dummy=$(Get-Random)"; $request = [System.Net.WebRequest]::Create($url)
                # U can also use api: [version]$Version = (Invoke-RestMethod -Uri "https://www.powershellgallery.com/api/v2/Packages?`$filter=Id eq '$PackageName' and IsLatestVersion" -Method Get -Verbose:$false).properties.Version
                $latest_Version = [version]::new(); $request.AllowAutoRedirect = $false
                try {
                    $response = $request.GetResponse()
                    $latest_Version = $response.GetResponseHeader("Location").Split("/")[-1] -as [Version]
                    $response.Close(); $response.Dispose()
                } catch [System.Net.WebException], [System.Net.Http.HttpRequestException], [System.Net.Sockets.SocketException] {
                    $Error_params = @{
                        ExceptionName    = $_.Exception.GetType().FullName
                        ExceptionMessage = "No Internet! " + $_.Exception.Message
                        ErrorId          = 'WebException'
                        CallerPSCmdlet   = $PSCmdlet
                        ErrorCategory    = 'ConnectionError'
                    }
                    Write-TerminatingError @Error_params
                } catch {
                    $Error_params = @{
                        ExceptionName    = $_.Exception.GetType().FullName
                        ExceptionMessage = "PackageName '$PackageName' was Not Found. " + $_.Exception.Message
                        ErrorId          = 'UnexpectedError'
                        CallerPSCmdlet   = $PSCmdlet
                        ErrorCategory    = 'OperationStopped'
                    }
                    Write-TerminatingError @Error_params
                }
            }
        }
        end {
            return $latest_Version
        }
    }
    function Resolve-Module {
        # .DESCRIPTION
        #   Gets latest module version from PSGallery and installs the update if local module is out of date.
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [Alias('Name')]
            [string[]]$Names,
            [switch]$UpdateModule
        )
        process {
            foreach ($moduleName in $Names) {
                Write-Host "`nResolve dependency Module [$moduleName]" -ForegroundColor Magenta
                $Local_ModuleVersion = Get-LatestModuleVersion -Name $moduleName -Source LocalMachine
                $Latest_ModuleVerion = Get-LatestModuleVersion -Name $moduleName -Source PsGallery
                if (!$Latest_ModuleVerion -or $Latest_ModuleVerion -eq ([version]::New())) {
                    $Error_params = @{
                        ExceptionName    = 'System.Data.OperationAbortedException'
                        ExceptionMessage = "Resolve-Module: Get-LatestModuleVersion: Failed to find latest module version for '$moduleName'."
                        ErrorId          = 'CouldNotFindModule'
                        CallerPSCmdlet   = $PSCmdlet
                        ErrorCategory    = 'OperationStoped'
                    }
                    Write-TerminatingError @Error_params
                }
                if (!$Local_ModuleVersion -or $Local_ModuleVersion -eq ([version]::New())) {
                    Write-Verbose -Message "Install $moduleName ..."
                    Install-PsGalleryModule -Name $moduleName
                } elseif ($Local_ModuleVersion -lt $Latest_ModuleVerion -and $UpdateModule.IsPresent) {
                    Write-Verbose -Message "Update $moduleName from version $Local_ModuleVersion to version [$Latest_ModuleVerion] ..." -Verbose
                    Install-PsGalleryModule -Name $moduleName -Version $Latest_ModuleVerion -UpdateOnly
                } else {
                    Write-Verbose -Message "Module $moduleName is already Installed and Up-to-date."
                }
                Write-Verbose -Message "Importing module $moduleName ..."
                Get-ModulePath -Name $moduleName | Import-Module -Verbose:$($PSCmdlet.MyInvocation.BoundParameters['verbose'] -eq $true) -Force:$($PSCmdlet.MyInvocation.BoundParameters['Force'] -eq $true)
            }
        }
    }
    function Write-BuildLog {
        [CmdletBinding()]
        param(
            [parameter(Mandatory, Position = 0, ValueFromRemainingArguments, ValueFromPipeline)]
            [System.Object]$Message,

            [parameter()]
            [Alias('c', 'Command')]
            [Switch]$Cmd,

            [parameter()]
            [Alias('w')]
            [Switch]$Warning,

            [parameter()]
            [Alias('s', 'e')]
            [Switch]$Severe,

            [parameter()]
            [Alias('x', 'nd', 'n')]
            [Switch]$Clean
        )
        Begin {
            if ($PSBoundParameters.ContainsKey('Debug') -and $PSBoundParameters['Debug'] -eq $true) {
                $fg = 'Yellow'
                $lvl = '##[debug]   '
            } elseif ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'] -eq $true) {
                $fg = if ($Host.UI.RawUI.ForegroundColor -eq 'Gray') {
                    'White'
                } else {
                    'Gray'
                }
                $lvl = '##[Verbose] '
            } elseif ($Severe) {
                $fg = 'Red'
                $lvl = '##[Error]   '
            } elseif ($Warning) {
                $fg = 'Yellow'
                $lvl = '##[Warning] '
            } elseif ($Cmd) {
                $fg = 'Magenta'
                $lvl = '##[Command] '
            } else {
                $fg = if ($Host.UI.RawUI.ForegroundColor -eq 'Gray') {
                    'White'
                } else {
                    'Gray'
                }
                $lvl = '##[Info]    '
            }
        }
        Process {
            $fmtMsg = if ($Clean) {
                $Message -split "[\r\n]" | Where-Object { $_ } | ForEach-Object {
                    $lvl + $_
                }
            } else {
                $date = "$(Get-Elapsed) "
                if ($Cmd) {
                    $i = 0
                    $Message -split "[\r\n]" | Where-Object { $_ } | ForEach-Object {
                        $tag = if ($i -eq 0) {
                            'PS > '
                        } else {
                            '  >> '
                        }
                        $lvl + $date + $tag + $_
                        $i++
                    }
                } else {
                    $Message -split "[\r\n]" | Where-Object { $_ } | ForEach-Object {
                        $lvl + $date + $_
                    }
                }
            }
            Write-Host -ForegroundColor $fg $($fmtMsg -join "`n")
        }
    }
    function Write-BuildWarning {
        param(
            [parameter(Mandatory, Position = 0, ValueFromRemainingArguments, ValueFromPipeline)]
            [System.String]$Message
        )
        Process {
            if ([bool][int]$env:IsCI) {
                Write-Host "##vso[task.logissue type=warning; ]$Message"
            } else {
                Write-Warning $Message
            }
        }
    }
    function Write-BuildError {
        param(
            [parameter(Mandatory, Position = 0, ValueFromRemainingArguments, ValueFromPipeline)]
            [System.String]$Message
        )
        Process {
            if ([bool][int]$env:IsCI) {
                Write-Host "##vso[task.logissue type=error; ]$Message"
            }
            Write-Error $Message
        }
    }
    function Set-EnvironmentVariable {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [parameter(Position = 0)]
            [String]$Name,

            [parameter(Position = 1, ValueFromRemainingArguments)]
            [String[]]$Value
        )
        $FullVal = $Value -join " "
        Write-BuildLog "Setting env variable '$Name' to '$fullVal'"
        Set-Item -Path ([IO.Path]::Combine('Env:', $Name)) -Value $FullVal -Force
    }
    function Invoke-CommandWithLog {
        [CmdletBinding()]
        Param (
            [parameter(Mandatory, Position = 0)]
            [ScriptBlock]$ScriptBlock
        )
        Write-BuildLog -Command ($ScriptBlock.ToString() -join "`n"); $ScriptBlock.Invoke()
    }
    function Write-Heading {
        param(
            [parameter(Position = 0)]
            [String]$Title,

            [parameter(Position = 1)]
            [Switch]$Passthru
        )
        $msgList = @(
            ''
            "##[section] $(Get-Elapsed) $Title"
        ) -join "`n"
        if ($Passthru) {
            $msgList
        } else {
            $msgList | Write-Host -ForegroundColor Cyan
        }
    }
    function Write-EnvironmentSummary {
        param(
            [parameter(Position = 0, ValueFromRemainingArguments)]
            [String]$State
        )
        Write-Heading -Title "Build Environment Summary:`n"
        @(
            $(if ($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))) { "Project : $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))" })
            $(if ($State) { "State   : $State" })
            "Engine  : PowerShell $($PSVersionTable.PSVersion.ToString())"
            "Host OS : $(if($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows){"Windows"}elseif($IsLinux){"Linux"}elseif($IsMacOS){"macOS"}else{"[UNKNOWN]"})"
            "PWD     : $PWD"
            ''
        ) | Write-Host
    }
    function FindHashKeyValue {
        [CmdletBinding()]
        param(
            $SearchPath,
            $Ast,
            [string[]]
            $CurrentPath = @()
        )
        # Write-Debug "FindHashKeyValue: $SearchPath -eq $($CurrentPath -Join '.')"
        if ($SearchPath -eq ($CurrentPath -Join '.') -or $SearchPath -eq $CurrentPath[-1]) {
            return $Ast |
                Add-Member NoteProperty HashKeyPath ($CurrentPath -join '.') -PassThru -Force | Add-Member NoteProperty HashKeyName ($CurrentPath[-1]) -PassThru -Force
        }

        if ($Ast.PipelineElements.Expression -is [System.Management.Automation.Language.HashtableAst] ) {
            $KeyValue = $Ast.PipelineElements.Expression
            foreach ($KV in $KeyValue.KeyValuePairs) {
                $result = FindHashKeyValue $SearchPath -Ast $KV.Item2 -CurrentPath ($CurrentPath + $KV.Item1.Value)
                if ($null -ne $result) {
                    $result
                }
            }
        }
    }
    function Get-ModuleManifest {
        <#
        .SYNOPSIS
            Reads a specific value from a PowerShell metdata file (e.g. a module manifest)
        .DESCRIPTION
            By default Get-ModuleManifest gets the ModuleVersion, but it can read any key in the metadata file
        .EXAMPLE
            Get-ModuleManifest .\Configuration.psd1
            Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
        .Example
            Get-ModuleManifest .\Configuration.psd1 ReleaseNotes
            Returns the release notes!
        #>
        [CmdletBinding()]
        param(
            # The path to the module manifest file
            [Parameter(ValueFromPipelineByPropertyName = "True", Position = 0)]
            [Alias("PSPath")]
            [ValidateScript({ if ([IO.Path]::GetExtension($_) -ne ".psd1") { throw "Path must point to a .psd1 file" } $true })]
            [string]$Path,

            # The property (or dotted property path) to be read from the manifest.
            # Get-ModuleManifest searches the Manifest root properties, and also the nested hashtable properties.
            [Parameter(ParameterSetName = "Overwrite", Position = 1)]
            [string]$PropertyName = 'ModuleVersion',

            [switch]$Passthru
        )
        Begin {
            $eap = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            $Tokens = $Null; $ParseErrors = $Null
        }
        Process {
            if (!(Test-Path $Path)) {
                Write-Error -Exception System.Management.Automation.ItemNotFoundException -Message "Can't find file $Path" -ErrorId "PathNotFound,Metadata\Import-Metadata" -Category "ObjectNotFound"
                return
            }
            $Path = Convert-Path $Path
            $AST = [System.Management.Automation.Language.Parser]::ParseFile( $Path, [ref]$Tokens, [ref]$ParseErrors )

            $KeyValue = $Ast.EndBlock.Statements
            $KeyValue = @(FindHashKeyValue $PropertyName $KeyValue)
            if ($KeyValue.Count -eq 0) {
                Write-Error -Exception System.Management.Automation.ItemNotFoundException -Message "Can't find '$PropertyName' in $Path" -ErrorId "PropertyNotFound,Metadata\Get-Metadata" -Category "ObjectNotFound"
                return
            }
            if ($KeyValue.Count -gt 1) {
                $SingleKey = @($KeyValue | Where-Object { $_.HashKeyPath -eq $PropertyName })

                if ($SingleKey.Count -gt 1) {
                    Write-Error -Exception System.Reflection.AmbiguousMatchException -Message ("Found more than one '$PropertyName' in $Path. Please specify a dotted path instead. Matching paths include: '{0}'" -f ($KeyValue.HashKeyPath -join "', '")) -ErrorId "AmbiguousMatch,Metadata\Get-Metadata" -Category "InvalidArgument"
                    return
                } else {
                    $KeyValue = $SingleKey
                }
            }
            $KeyValue = $KeyValue[0]

            if ($Passthru) { $KeyValue } else {
                # # Write-Debug "Start $($KeyValue.Extent.StartLineNumber) : $($KeyValue.Extent.StartColumnNumber) (char $($KeyValue.Extent.StartOffset))"
                # # Write-Debug "End   $($KeyValue.Extent.EndLineNumber) : $($KeyValue.Extent.EndColumnNumber) (char $($KeyValue.Extent.EndOffset))"
                $KeyValue.SafeGetValue()
            }
        }
        End {
            $ErrorActionPreference = $eap
        }
    }
    function Publish-GitHubRelease {
        <#
        .SYNOPSIS
            Publishes a release to GitHub Releases. Borrowed from https://www.herebedragons.io/powershell-create-github-release-with-artifact
        #>
        [CmdletBinding()]
        Param (
            [parameter(Mandatory = $true)]
            [String]$VersionNumber,

            [parameter(Mandatory = $false)]
            [String]$CommitId = 'main',

            [parameter(Mandatory = $true)]
            [String]$ReleaseNotes,

            [parameter(Mandatory = $true)]
            [ValidateScript( { Test-Path $_ })]
            [String]$ArtifactPath,

            [parameter(Mandatory = $true)]
            [String]$GitHubUsername,

            [parameter(Mandatory = $true)]
            [String]$GitHubRepository,

            [parameter(Mandatory = $true)]
            [String]$GitHubApiKey,

            [parameter(Mandatory = $false)]
            [Switch]$PreRelease,

            [parameter(Mandatory = $false)]
            [Switch]$Draft
        )
        $releaseData = @{
            tag_name         = [string]::Format("v{0}", $VersionNumber)
            target_commitish = $CommitId
            name             = [string]::Format("$($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName'))) v{0}", $VersionNumber)
            body             = $ReleaseNotes
            draft            = [bool]$Draft
            prerelease       = [bool]$PreRelease
        }

        $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($gitHubApiKey + ":x-oauth-basic"))

        $releaseParams = @{
            Uri         = "https://api.github.com/repos/$GitHubUsername/$GitHubRepository/releases"
            Method      = 'POST'
            Headers     = @{
                Authorization = $auth
            }
            ContentType = 'application/json'
            Body        = (ConvertTo-Json $releaseData -Compress)
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $result = Invoke-RestMethod @releaseParams
        $uploadUri = $result | Select-Object -ExpandProperty upload_url
        $uploadUri = $uploadUri -creplace '\{\?name,label\}'
        $artifact = Get-Item $ArtifactPath
        $uploadUri = $uploadUri + "?name=$($artifact.Name)"
        $uploadFile = $artifact.FullName

        $uploadParams = @{
            Uri         = $uploadUri
            Method      = 'POST'
            Headers     = @{
                Authorization = $auth
            }
            ContentType = 'application/zip'
            InFile      = $uploadFile
        }
        $result = Invoke-RestMethod @uploadParams
    }
    #endregion BuildHelper_Functions
}
Process {
    if ($Help) {
        Write-Heading "Getting help"
        Write-BuildLog -c '"psake" | Resolve-Module @Mod_Res -Verbose'
        Resolve-Module -Name 'psake' -Verbose:$false
        Get-PSakeScriptTasks -buildFile $Psake_BuildFile.FullName | Sort-Object -Property Name | Format-Table -Property Name, Description, Alias, DependsOn
        exit 0
    }
    Set-BuildVariables -Path $PSScriptRoot -Prefix $env:RUN_ID
    Write-EnvironmentSummary "Build started"
    $security_protocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::SystemDefault
    if ([Net.SecurityProtocolType].GetMember("Tls12").Count -gt 0) { $security_protocol = $security_protocol -bor [Net.SecurityProtocolType]::Tls12 }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]$security_protocol
    $Host.ui.WriteLine()
    Invoke-CommandWithLog { $script:DefaultParameterValues = @{
            '*-Module:Verbose'           = $false
            'Import-Module:ErrorAction'  = 'Stop'
            'Import-Module:Force'        = $true
            'Import-Module:Verbose'      = $false
            'Install-Module:ErrorAction' = 'Stop'
            'Install-Module:Scope'       = 'CurrentUser'
            'Install-Module:Verbose'     = $false
        }
    }
    Write-Heading "Prepare package feeds"
    $Host.ui.WriteLine()
    if ($null -eq (Get-PSRepository -Name PSGallery -ErrorAction Ignore)) {
        Unregister-PSRepository -Name PSGallery -Verbose:$false -ErrorAction Ignore
        Register-PSRepository -Default -InstallationPolicy Trusted
    }
    Write-Heading "Prepare package feeds"
    . $script:PsGallery_Helper_Functions
    if (!(Get-Command dotnet -ErrorAction Ignore) -and ![bool][int]$env:IsAC) {
        Write-Heading "Resolve publish dependency [dotnet sdk]`n" -ForegroundColor Magenta
        Invoke-CommandWithLog {
            [System.Environment]::SetEnvironmentVariable('DOTNET_ROOT', [IO.Path]::Combine($HOME, '.dotnet'))
            # dotnet command version '2.0.0' or newer is required to interact with the NuGet-based repositories.
        };
        if ([System.Environment]::OSVersion.Platform -in ('Win32NT', 'Win32S', 'Win32Windows', 'WinCE')) {
            # Run a separate PowerShell process because the script calls exit, so it will end the current PowerShell session.
            &powershell -NoProfile -ExecutionPolicy unrestricted -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; &([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1'))) -channel LTS"
            $env:PATH = $env:PATH + [IO.Path]::PathSeparator + "$env:DOTNET_ROOT"
            . ([scriptblock]::Create((Invoke-RestMethod -Verbose:$false -Method Get https://api.github.com/gists/8b4ddc0302a9262cf7fc25e919227a2f).files.'Update_Session_Env.ps1'.content))
            Write-Host "`nRefresh SessionEnvironment" -ForegroundColor Magenta
            Update-SessionEnvironment; $Host.ui.WriteLine()
        } else {
            $Host.ui.WriteLine();
            Invoke-WebRequest -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel LTS
            Write-Output 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
            Write-Output 'export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools' >> ~/.bashrc
            Write-Output 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.zshrc
            Write-Output 'export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools' >> ~/.zshrc
        }
    }
    #  dotnet dev-certs https --trust (I commented this out because running this on mac takes for ever!)
    Invoke-CommandWithLog { Get-PackageProvider -Name Nuget -ForceBootstrap -Verbose:$false }
    if (!(Get-PackageProvider -Name Nuget)) {
        Invoke-CommandWithLog { Install-PackageProvider -Name NuGet -Force | Out-Null }
    }
    Resolve-PackageProviders; $Host.ui.WriteLine(); $null = Import-PackageProvider -Name NuGet -Force
    foreach ($Name in @('PackageManagement', 'PowerShellGet')) {
        $Host.UI.WriteLine(); Resolve-Module -Name $Name -UpdateModule -Verbose:$script:DefaultParameterValues['*-Module:Verbose'] -ErrorAction Stop
    }
    $build_sys = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildSystem');
    $lastCommit = git log -1 --pretty=%B
    Write-Heading "Current build system is $build_sys"
    Write-Heading "Finalizing build Prerequisites and Resolving dependencies ..."
    if ($build_sys -eq 'VSTS' -or ($env:CI -eq "true" -and $env:GITHUB_RUN_ID)) {
        if ($Task -contains 'Deploy') {
            $MSG = "Task is 'Deploy' and conditions for deployment are:`n" +
            "    + GitHub API key is not null       : $(![string]::IsNullOrWhiteSpace($env:GitHubPAT))`n" +
            "    + Current branch is main           : $(($env:GITHUB_REF -replace "refs/heads/") -eq 'main')`n" +
            "    + Source is not a pull request     : $($env:GITHUB_EVENT_NAME -ne "pull_request") [$env:GITHUB_EVENT_NAME]`n" +
            "    + Commit message matches '!deploy' : $($lastCommit -match "!deploy") [$lastCommit]`n" +
            "    + Is Current PS version < 5 ?      : $($PSVersionTable.PSVersion.Major -lt 5) [$($PSVersionTable.PSVersion.ToString())]`n" +
            "    + NuGet API key is not null        : $(![string]::IsNullOrWhiteSpace($env:NUGETAPIKEY))`n"
            if ($PSVersionTable.PSVersion.Major -lt 5 -or [string]::IsNullOrWhiteSpace($env:NUGETAPIKEY) -or [string]::IsNullOrWhiteSpace($env:GitHubPAT) ) {
                $MSG = $MSG.Replace('and conditions for deployment are:', 'but conditions are not correct for deployment.')
                $MSG | Write-Host -ForegroundColor Yellow
                if (($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'CommitMessage')) -match '!deploy' -and $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BranchName')) -eq "main") -or $script:ForceDeploy -eq $true) {
                    Write-Warning "Force Deploying detected"
                } else {
                    "Skipping Psake for this job!" | Write-Host -ForegroundColor Yellow
                    exit 0
                }
            } else {
                $MSG | Write-Host -ForegroundColor Green
            }
        }
        Invoke-Command -ScriptBlock $PSake_Build
        if ($Task -contains 'Import' -and $psake.build_success) {
            $Project_Name = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')
            $Project_Path = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildOutput')
            Write-Heading "Importing $Project_Name to local scope"
            Invoke-CommandWithLog { Import-Module $([IO.Path]::Combine($Project_Path, $Project_Name)) -Verbose }
        }
    } else {
        Invoke-Command -ScriptBlock $PSake_Build
        Write-Heading "Create a Local repository"
        $RepoPath = [IO.Path]::Combine([environment]::GetEnvironmentVariable("HOME"), 'LocalPSRepo')
        if (!(Get-Variable -Name IsWindows -ErrorAction Ignore) -or $(Get-Variable IsWindows -ValueOnly)) {
            $RepoPath = [IO.Path]::Combine([environment]::GetEnvironmentVariable("UserProfile"), 'LocalPSRepo')
        }; if (!(Test-Path -Path $RepoPath -PathType Container -ErrorAction Ignore)) { New-Directory -Path $RepoPath | Out-Null }
        Invoke-Command -ScriptBlock ([scriptblock]::Create("Register-PSRepository LocalPSRepo -SourceLocation '$RepoPath' -PublishLocation '$RepoPath' -InstallationPolicy Trusted -Verbose:`$false -ErrorAction Ignore; Register-PackageSource -Name LocalPsRepo -Location '$RepoPath' -Trusted -ProviderName Bootstrap -ErrorAction Ignore"))
        Write-Verbose "Verify that the new repository was created successfully"
        if ($null -eq (Get-PSRepository LocalPSRepo -Verbose:$false -ErrorAction Ignore)) {
            Throw [System.Exception]::New('Failed to create LocalPsRepo', [System.IO.DirectoryNotFoundException]::New($RepoPath))
        }
        $ModuleName = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')
        $ModulePath = [IO.Path]::Combine($([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildOutput')), $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')), $([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildNumber')))
        # Publish To LocalRepo
        $ModulePackage = [IO.Path]::Combine($RepoPath, "${ModuleName}.$([Environment]::GetEnvironmentVariable($env:RUN_ID + 'BuildNumber')).nupkg")
        if ([IO.File]::Exists($ModulePackage)) {
            Remove-Item -Path $ModulePackage -ErrorAction 'SilentlyContinue'
        }
        Write-Heading "Publish to Local PsRepository"
        $RequiredModules = Get-ModuleManifest ([IO.Path]::Combine($ModulePath, "$([Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')).psd1")) RequiredModules -Verbose:$false
        foreach ($Module in $RequiredModules) {
            $md = Get-Module $Module -Verbose:$false; $mdPath = $md.Path | Split-Path
            Write-Verbose "Publish RequiredModule $Module ..."
            Publish-Module -Path $mdPath -Repository LocalPSRepo -Verbose:$false
        }
        Invoke-CommandWithLog { Publish-Module -Path $ModulePath -Repository LocalPSRepo } -Verbose:$false
        # Install Module
        Install-Module $ModuleName -Repository LocalPSRepo
        # Import Module
        if ($Task -contains 'Import' -and $psake.build_success) {
            Write-Heading "Import $ModuleName to local scope"
            Invoke-CommandWithLog { Import-Module $ModuleName }
        }
        Write-Heading "CleanUp: Uninstall the test module, and delete the LocalPSRepo"
        # Remove Module
        if ($Task -notcontains 'Import') {
            Uninstall-Module $ModuleName -ErrorAction Ignore
            # Get-ModulePath $ModuleName | Remove-Item -Recurse -Force -ErrorAction Ignore
        }
        $Local_PSRepo = [IO.DirectoryInfo]::new("$RepoPath")
        if ($Local_PSRepo.Exists) {
            Write-BuildLog "Remove 'local' repository"
            if ($null -ne (Get-PSRepository -Name 'LocalPSRepo' -ErrorAction Ignore)) {
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create("Unregister-PSRepository -Name 'LocalPSRepo' -Verbose -ErrorAction Ignore"))
            }; Remove-Item "$Local_PSRepo" -Force -Recurse -ErrorAction Ignore
        }
    }
}
End {
    Write-EnvironmentSummary "Build finished"
    if (![bool][int]$env:IsAC) {
        Invoke-Command $Clean_EnvBuildvariables -ArgumentList $env:RUN_ID
        [Environment]::SetEnvironmentVariable('RUN_ID', $null)
    }
    exit ([int](!$psake.build_success))
}