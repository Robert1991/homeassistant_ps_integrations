param($deviceConfigPath = ".\device_config.json")

Add-Type -Path "${env:MQTT_HOME}\lib\net45\M2Mqtt.Net.dll"

. .\mqttClient.ps1
function WorkstationIsUnlocked {
    try {
        if ((Get-Process logonui -ErrorAction Stop)) {
            return $false
        }
    } catch {
        return $true
    }
}

$configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $configuration.homeassistant_host
$mqttClient.user = $configuration.mqtt_login
$mqttClient.password = $configuration.mqtt_password

$homeassistant_sensor_path = "{0}/{1}/{2}" -f $configuration.homeassistant_auto_discovery_prefix, `
    $configuration.workstation_unlocked_sensor.homeassistant_component, `
    $configuration.workstation_unlocked_sensor.object_name 
$state_topic = "$homeassistant_sensor_path/state"

while ($true) {
    if (WorkstationIsUnlocked -eq $true) {
        write-host "ON"
        $mqttClient.publish($state_topic, 'ON')
    }
    Start-Sleep -s 5
}