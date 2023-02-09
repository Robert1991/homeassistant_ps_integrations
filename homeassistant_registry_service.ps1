param($deviceConfigPath = ".\device_config.json")

Add-Type -Path "${env:MQTT_HOME}\lib\net45\M2Mqtt.Net.dll"

. .\mqttClient.ps1
. .\deviceRegistration.ps1

function MQTTSubscriptionReceiveFunction { 
    . .\deviceRegistration.ps1 
    . .\mqttClient.ps1 
    $payloadMessage = [System.Text.Encoding]::UTF8.GetString($args[1].Message)
    Write-host ("Received: " + $args[1].topic + " payload: " + $payloadMessage)
    if ($payloadMessage -eq "online") {
        $configPath = $Event.MessageData
        Write-Host "Detected restart of homeassistant. Renewing device registration with config '$configPath'"
        $configuration = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        $mqttClient = [MQTTClient]::new() 
        $mqttClient.mqttHost = $configuration.homeassistant_host
        $mqttClient.user = $configuration.mqtt_login
        $mqttClient.password = $configuration.mqtt_password
        RegisterDevice $configuration $mqttClient
        Write-Host "Successfully renewed device registration"
    }
}

$configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $configuration.homeassistant_host
$mqttClient.user = $configuration.mqtt_login
$mqttClient.password = $configuration.mqtt_password

RegisterDevice $configuration $mqttClient

$mqttClient.registerReceiveFunction($Function:MQTTSubscriptionReceiveFunction, $deviceConfigPath)
$mqttClient.subscribe("homeassistant/status")

while ($true) {
    Start-Sleep -Seconds 1
}
