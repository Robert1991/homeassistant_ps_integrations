
$windowsTasks = @("Homeassistant Registry Service", 
    "Homeassitant Activity Monitor Keyboard",
    "Homeassitant Activity Monitor Mouse",
    "Homeassitant Powerline Connected Sensor",
    "Homeassitant Powerline Workstation Unlocked")

foreach ($windowsTask in $windowsTasks) {
    Write-Host "Restarting $windowsTask"
    Stop-ScheduledTask -TaskName $windowsTask
    Start-ScheduledTask -TaskName $windowsTask
}