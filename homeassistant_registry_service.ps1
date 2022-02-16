param($deviceConfigPath = ".\device_config.json")

Add-Type -Path "${env:MQTT_HOME}\lib\net45\M2Mqtt.Net.dll"

. .\mqttClient.ps1
. .\deviceRegistration.ps1

function MQTTSubscriptionReceiveFunction { 
    . .\deviceRegistration.ps1 
    . .\mqttClient.ps1 
    $payloadMessage = [System.Text.Encoding]::ASCII.GetString($args[1].Message)
    Write-host ("Received: topic: " + $args[1].topic + " payload: " + $payloadMessage)
    if ($args[1].topic -eq "homeassistant/status" -and $payloadMessage.Trim() -eq "online") {
        $configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json
        $mqttClient = [MQTTClient]::new() 
        $mqttClient.mqttHost = $configuration.homeassistant_host
        $mqttClient.user = $configuration.mqtt_login
        $mqttClient.password = $configuration.mqtt_password
        Write-Host "Reregistering Device"
        RegisterDevice $configuration $mqttClient
    }
}

$configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $configuration.homeassistant_host
$mqttClient.user = $configuration.mqtt_login
$mqttClient.password = $configuration.mqtt_password

RegisterDevice $configuration $mqttClient

$mqttClient.registerReceiveFunction($Function:MQTTSubscriptionReceiveFunction)
$mqttClient.subscribe("homeassistant/status")

while ($true) {
    Start-Sleep -Seconds 1
}
