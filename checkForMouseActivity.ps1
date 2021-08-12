param($deviceConfigPath = ".\device_config.json")

Add-Type -Path "${env:MQTT_HOME}\lib\net45\M2Mqtt.Net.dll"

. .\mqttClient.ps1
function CheckForMouseMovement {
    param ($timeout = 50, $iterations = 4)

    Add-Type -AssemblyName System.Windows.Forms
    for ($iteration = 1; $iteration -le $iterations; $iteration++) {
        $p1 = [System.Windows.Forms.Cursor]::Position
        Start-Sleep -Milliseconds $timeout
        $p2 = [System.Windows.Forms.Cursor]::Position
        if ($p1.X -ne $p2.X -or $p1.Y -ne $p2.Y) {
            return $true
        }
    }
    return $false
}

$configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json
$homeassistant_activity_sensor_path = "{0}/{1}/{2}" -f $configuration.homeassistant_auto_discovery_prefix, `
    $configuration.activity_sensor.homeassistant_component, `
    $configuration.activity_sensor.object_name 

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $configuration.homeassistant_host
$mqttClient.user = $configuration.mqtt_login
$mqttClient.password = $configuration.mqtt_password

$state_topic = "$homeassistant_activity_sensor_path/state"

while ($true) {
    if (CheckForMouseMovement -eq $true) {
        $mqttClient.publish($state_topic, 'ON')
    }
}