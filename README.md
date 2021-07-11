# Windows10-Optimization

# Summary
 - [Temp Files](#Temp-files)
 - [TaskBar](#TaskBar)

# Temp files

As you know, temporary files are often a lot and some of them take up a lot of space on the disk
I suggest two solutions, you can run the script yourself or you can put a small bash file in the startup folder
### Solution 1
Open a powershell window as administrator in the ' Powershell scripts ' folder and run the following command
```powershell
.\tempFilesCleaner.ps1
```

### Solution 2
Copy the file 'tempFilesCleaner.cmd' in the folder of startup applications, to do this follow the instructions
1) open the 'run' window with the Windows Key + R keyboard shortcut
2) copy and paste this ```%userprofile%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup```
3) copy and paste the file 'tempFilesCleaner.cmd'

At the starting of windows the script will launch automatically 

# TaskBar
### 1 - Remove the News and Interests Widget from Windows 10 Taskbar

To get rid of it from the taskbar entirely, a better solution is to right-click the Weather icon and go to News and interests > Turn off

### 2 - Remove the Meet Now Button on Windows 10

The dead simplest way to get rid of the Meet Now button on the taskbar is to right-click it and select Hide. That’s all it takes. The Meet Now icon will disappear from the notification area of the taskbar.

### 3 - Disable the “Get Even More Out of Windows” Screen

use the keyboard combo Windows Key + I to open Settings > System > Notifications & actions > uncheck the “Suggest ways I can finish setting up my device to get the most out of Windows” button

### 4 - Disable the Windows 10 Welcome Experience

use the keyboard combo Windows Key + I to open Settings > System > Notifications & actions > uncheck the “Show me the Windows welcome experience after updates and occasionally when I sign in to highlight what’s new and suggested” box.
