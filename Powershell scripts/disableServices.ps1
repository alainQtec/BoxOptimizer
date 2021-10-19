$servicesDisable = @(
    "AJRouter",
    "ALG",
    "AppMgmt",
    "CscService", # Offline Files
    "diagnosticshub.standardcollector.service",
    "dmwappushservice",
    "HomeGroupListener",
    "HomeGroupProvider",
    "TrkWks",
    "WSearch",
    "IKEEXT",
    "PcaSvc", #Compatibility Mode
    "wcncsvc", # Laptops and other wireless computers need this service for connecting to wireless networks. Desktops that don’t have a wireless card do not need this service.
    "WerSvc",
    "WMPNetworkSvc", #Delete this line if you use OBS-NDI
    "BthHFSrv",
    "PeerDistSvc",
    "MapsBroker", #Delete this line if you use in start menu widgets who use bing maps or whatever
    "Ifsvc",
    "HvHost",
    "Dnscache",
    "SSDPSRV",
    "upnphost",
    "pla",
    "SharedAccess",
    "SysMain",
    "TapiSrv",
    "WebClient",
    "tzautoupdate",
    "RemoteRegistry",
    "RemoteAccess",
    "WbioSrvc",
    "lfsvc", 
    "ndu",
    "NetTcpPortSharing",
    "CDPSvc",
    "TabletInputService", # Delete this line if you are using laptop touch screens and tablets
    "WdiServiceHost",
    "PhoneSvc",
    "SmsRouter",
    "DPS",
    "iphlpsvc", #Delete if you are using IPv6 translation
    "stisvc",
    "DusmSvc",
    "IpxlatCfgSvc",
    "wlpasvc",
    "MSiSCSI",
    "irmon", #File transfer via infrared devices.
    "NaturalAuthentification",
    "Netlogon", #Delete this line if you are using  a domain controller environment.
    "NcdAutoSetup",
    "SEMgrSvc", #Delete this line if you are using NFC but Near Field Communication is a mobile phone technology. Not needed on desktops and tablets.
    "SessionEnv", # Windows RDP
    "TermService", # Windows RDP
    "UmRdpService", # Windows RDP
    "RpcLocator",
    "RetailDemo",
    "SensorDataService",
    "SensrSvc",
    "SensorService",
    "shpamsvc",
    "SNMPTRAP",
    "StorSvc",
    "FrameServer", #Delete if you are using webcam, could be needed to capture webcam frames. at the moment no problems for streaming
    "wisvc", #Delete this line if you want beta testing new versions of Windows via the Insider program.
    "icssvc", #Delete this line if you are using Mobile Network Connection (3G, 4G, LTE, Etc). Keep this line on devices without those options.
    "WinRM",
    "workfolderssvc",
    "EntAppSvc",
    "DiagTrack", #Feedback and Diagnostics
    "NfsClnt",
    "NodAutoSetup",
    "WFDSConSvc",
    "WwanSvc",
    "fhsvc", #delete this line if you are using Windows Backup, Used by Windows Backup.
    "SDRSVC",
    "SecurityHealthService", # Windows Defender Security Center Service
    "Sense", # Windows Defender Advanced Threat Protection Service
    "WdNisSvc", # Windows Defender Antivirus Network Inspection Service
    "MpsSvc", # Windows Defender Firewall
    "WinDefend", # Windows Defender Antivirus Service
    "wscsvc", # Security Center
    "WdiSystemHost",
    "diagsvc",
    "wlidsvc", #Delete if using MS account to log in to computer.
    "BDESVC", #Delete line if you are using storage encryption or if not uncomment it
    #"BthAvctpSvc", #Delete line if you are using Bluetooth Audio Device or Wireless Headphones or if not uncomment it
    #"RmSvc", #Delete line if you are using wifi card and bluetooth or if not uncomment it
    #"bthserv", #Delete line if you are using bluetooth devices or if not uncomment it
    #"WlanSvc", #Delete line if you are using wifi card or if not uncomment it
    #"lmhosts", #Delete line if you are using shared files in your network (NAS and others ...) or if not uncomment it
    #"Browser" #Delete line if you are using Network discovery of systems on local network or if not uncomment it
    "WpcMonSvc", #Delete line if you are using parental controls or if not uncomment it
    #"seclogon", #Need validation | some disable it others not
    #"wuauserv", #WINDOWS UPDATE I personally recommend not to disable this service
    "XboxGipSvc", #Delete this line if using any XBOX console PC to Console functions or if not uncomment it
    "xbgm", #Delete this line if using any XBOX console PC to Console functions or if not uncomment it
    "XblAuthManager", #Delete this line if using any XBOX console PC to Console functions or if not uncomment it
    "XblGameSave",	#Delete this line if using any XBOX console PC to Console functions or if not uncomment it
    "XboxNetApiSvc", #Delete this line if using any XBOX console PC to Console functions or if not uncomment it
    "vmickvpexchange", #Delete this line if you use hyper-v or if not uncomment it
    "vmicguestinterface", #Delete this line if you use hyper-v or if not uncomment it
    "vmicshutdown", #Delete this line if you use hyper-v or if not uncomment it
    "vmicheartbeat", #Delete this line if you use hyper-v or if not uncomment it
    "vmcompute", #Delete this line if you use hyper-v or if not uncomment it
    "vmicvmsession", #Delete this line if you use hyper-v or if not uncomment it
    "vmicrdv", #Delete this line if you use hyper-v or if not uncomment it
    "vmictimesync", #Delete this line if you use hyper-v or if not uncomment it
    "vmms", #Delete this line if you use hyper-v or if not uncomment it
    "vmicvss", #Delete this line if you use hyper-v or if not uncomment it
    "CertPropSvc", #Delete this line if you use Smart Card login or if not uncomment it
    "SCardSvr", #Delete this line if you use Smart Card login or if not uncomment it
    "ScDeviceEnum", #Delete this line if you use Smart Card login or if not uncomment it
    "SCPolicySvc", #Delete this line if you use Smart Card login or if not uncomment it
    #"Spooler" # Need validation | some disable it others not | print spooler
    "Fax"
)
foreach ($service in $servicesDisable) {
    Stop-Service -Name $service
    Set-Service -Name $service -StartupType Disabled
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\${service}" -Name "Start" -Force -Value 4
}

$servicesDemand= @(
    "BITS",
    "IKEEXT"
)

foreach ($service in $servicesDemand) {
    Stop-Service -Name $service
    Set-Service -Name $service -StartupType Disabled
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\${service}" -Name "Start" -Force -Value 3
}