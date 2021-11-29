$servicesAutomatic = @(
    "TrkWks",
    "WSearch",
    "MapsBroker", #Delete this line if you use in start menu widgets who use bing maps or whatever
    "Dnscache",
    "SysMain",
    "ndu",
    "CDPSvc",
    "DPS",
    "iphlpsvc", #Delete if you are using IPv6 translation
    "DusmSvc",
    "DiagTrack", #Feedback and Diagnostics
    "MpsSvc", # Windows Defender Firewall
    "WinDefend", # Windows Defender Antivirus Service
    "wscsvc", # Security Center
    "vmms", #Delete this line if you use hyper-v or if not uncomment it
    "Spooler",
    "FontCache",
    "EventLog",
    "Themes",
    "LanmanServer"
)
foreach ($service in $servicesAutomatic) {
    Write-Host "Stoping service ${service}"
    Stop-Service -Name $service -ErrorAction 'silentlycontinue'
    Write-Host "Change the type of startup to Automatic for the service ${service}"
    Set-Service -Name $service -StartupType Automatic -ErrorAction 'silentlycontinue'
    Write-Host "Change the value of the key ${service} in the registry"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\${service}" -Name "Start" -Force -Value 2 -ErrorAction 'silentlycontinue'
}

$servicesManual= @(
    "AJRouter",
    "ALG",
    "AppMgmt",
    "CscService",
    "diagnosticshub.standardcollector.service",
    "dmwappushservice",
    "dmwappushsvc"
    "HomeGroupListener",
    "HomeGroupProvider",
    "IKEEXT",
    "PcaSvc",
    "wcncsvc",
    "WerSvc",
    "WMPNetworkSvc",
    "BthHFSrv",
    "PeerDistSvc",
    "Ifsvc",
    "HvHost",
    "SSDPSRV",
    "upnphost",
    "pla",
    "SharedAccess",
    "TapiSrv",
    "WebClient",
    "WbioSrvc",
    "lfsvc",
    "TabletInputService",
    "WdiServiceHost",
    "PhoneSvc",
    "SmsRouter",
    "stisvc",
    "IpxlatCfgSvc",
    "wlpasvc",
    "MSiSCSI",
    "irmon",
    "NaturalAuthentication",
    "Netlogon",
    "NcdAutoSetup",
    "SEMgrSvc",
    "SessionEnv",
    "TermService",
    "UmRdpService",
    "RpcLocator",
    "RetailDemo",
    "SensorDataService",
    "SensrSvc",
    "SensorService",
    "SNMPTRAP",
    "StorSvc",
    "FrameServer",
    "wisvc",
    "icssvc",
    "WinRM",
    "workfolderssvc",
    "EntAppSvc",
    "WFDSConSvc",
    "WwanSvc",
    "fhsvc",
    "SDRSVC",
    "SecurityHealthService",
    "Sense",
    "WdNisSvc",
    "WdiSystemHost",
    "diagsvc",
    "wlidsvc",
    "BDESVC",
    "BthAvctpSvc",
    "RmSvc",
    "bthserv",
    "WlanSvc",
    "lmhosts",
    "Browser",
    "WpcMonSvc",
    "seclogon",
    "wuauserv",
    "XboxGipSvc",
    "xbgm",
    "XblAuthManager",
    "XblGameSave",
    "XboxNetApiSvc",
    "vmickvpexchange",
    "vmicguestinterface",
    "vmicshutdown",
    "vmicheartbeat",
    "vmcompute",
    "vmicvmsession",
    "vmicrdv",
    "vmictimesync",
    "vmicvss",
    "CertPropSvc",
    "SCardSvr",
    "ScDeviceEnum",
    "SCPolicySvc",
    "Fax",
    "MixedRealityOpenXRSvc",
    "W32Time",
    "spectrum",
    "FontCache3.0.0.0",
    "Wecsvc",
    "TokenBroker",
    "NcbService",
    "InstallService",
    "BITS",
    "IKEEXT"
)

foreach ($service in $servicesManual) {
    Write-Host "Stoping service ${service}"
    Stop-Service -Name $service -ErrorAction 'silentlycontinue'
    Write-Host "Change the type of startup to Manual for the service ${service}"
    Set-Service -Name $service -StartupType Manual -ErrorAction 'silentlycontinue'
    Write-Host "Change the value of the key ${service} in the registry"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\${service}" -Name "Start" -Force -Value 3 -ErrorAction 'silentlycontinue'
}

$servicesDisable = @(
    "tzautoupdate",
    "RemoteRegistry",
    "RemoteAccess",
    "NetTcpPortSharing",
    "shpamsvc",
    "NfsClnt",
    "UevAgentService",
    "AppVClient",
    "ssh-agent"
)
foreach ($service in $servicesDisable) {
    Write-Host "Stoping service ${service}"
    Stop-Service -Name $service -ErrorAction 'silentlycontinue'
    Write-Host "Change the type of startup to Disabled for the service ${service}"
    Set-Service -Name $service -StartupType Disabled -ErrorAction 'silentlycontinue'
    Write-Host "Change the value of the key ${service} in the registry"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\${service}" -Name "Start" -Force -Value 4 -ErrorAction 'silentlycontinue'
}