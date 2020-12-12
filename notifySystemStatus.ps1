$homeassistant_host = "172.22.24.104"

$homassistant_mqtt_login = "espUser"
$homassistant_mqtt_pw = "esp123"

$homassistant_mqtt_pw_1 = "ahch7coGhee5Tai3aengeibiraeloo7iequohfahc2ahvaemaesh9ahShashaiqu"
$sendTimeout = 3
$cpuUsageTopic = "robert_pc/cpu_usage"
$memoryUsageTopic = "robert_pc/memory_usage"
$laptopOnTopic = "robert_pc/on"

function GetCurrentCPUUsage {
    return (Get-Counter '\prozessor(_total)\prozessorzeit (%)').CounterSamples.CookedValue
}

function GetCurrentMemoryUsage {
    $os = Get-Ciminstance Win32_OperatingSystem
    return [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 2)
}

try {
    while ($true) {
        mqtt-cli.exe  pub -t $laptopOnTopic -m  "on" -h $homeassistant_host -u $homassistant_mqtt_login -pw $homassistant_mqtt_pw_1
        $cpuUsage = GetCurrentCPUUsage
        mqtt-cli.exe  pub -t $cpuUsageTopic -m  $cpuUsage -h $homeassistant_host -u $homassistant_mqtt_login -pw $homassistant_mqtt_pw
        $memoryUsage = GetCurrentMemoryUsage
        mqtt-cli.exe  pub -t $memoryUsageTopic -m  $memoryUsage -h $homeassistant_host -u $homassistant_mqtt_login -pw $homassistant_mqtt_pw
        Start-Sleep -Seconds $sendTimeout
        if ([System.Environment]::HasShutdownStarted) {
            mqtt-cli.exe  pub -t $laptopOnTopic -m  "off" -h $homeassistant_host -u $homassistant_mqtt_login -pw $homassistant_mqtt_pw
            Write-Host "Shutdown!"
        }
        Write-Host "Current CPU Usage: $cpuUsage; Current Memory Usage: $memoryUsage"
    }   
}
finally {
    mqtt-cli.exe  pub -t $laptopOnTopic -m  "off" -h $homeassistant_host -u $homassistant_mqtt_login -pw $homassistant_mqtt_pw
}

# $totalRam = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum
# while ($true) {
#     $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#     $cpuTime = (Get-Counter '\prozessor(_total)\prozessorzeit (%)').CounterSamples.CookedValue
#     $availMem = (Get-Counter '\arbeitsspeicher\zugesicherte verwendete bytes (%)').CounterSamples.CookedValue
#     $date + ' > CPU: ' + $cpuTime.ToString("#,0.000") + '%, Avail. Mem.: ' + $availMem.ToString("N0") + 'MB (' + (104857600 * $availMem / $totalRam).ToString("#,0.0") + '%)'
#     Start-Sleep -s 2
# }