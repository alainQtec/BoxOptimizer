<#
  .SYNOPSIS
    Restores services configuration
  .DESCRIPTION
    Restores services configuration from a backup json or xml
  .EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
  .INPUTS
    Inputs (if any)
  .OUTPUTS
    Output (if any)
  .NOTES
    General notes
  #>
function Restore-Services {
  Begin {
    Push-Location ${PSScriptRoot}
    $script:BackupJson = $(Get-Item $($(Get-ChildItem ServicesDataBackup_*.Json | Select-Object -Property Name , @{l = "CreationTime"; e = { $(Get-Item $_).CreationTime } }) | Sort-Object CreationTime)[0].Name).FullName
    Write-Output "Using BackupJson: $BackupJson"
    Pop-Location
  }
  process {
    $services = Get-Content $BackupJson | ConvertFrom-Json
    foreach ($srvc in $services) {
      Write-Output "Restoring $($srvc.Name) ..."
      # Set-Service -Name $($srvc.Name) -StartupType $srvc.Starttype -Force
      Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($srvc.Name)" -Name "Start" -Force -Value $srvc.Starttype -ErrorAction 'silentlycontinue'
    }
  }
    
  end {
      
  }
}
function Main {
  Restore-Services
}
Main