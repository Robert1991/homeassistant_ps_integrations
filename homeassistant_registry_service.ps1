param($deviceConfigPath = ".\device_config.json")

Add-Type -Path "${env:MQTT_HOME}\lib\net45\M2Mqtt.Net.dll"

. .\mqttClient.ps1

function ReadRelevantSystemInfo {
    return Get-ComputerInfo CsManufacturer, CsDNSHostName, OsVersion, CsModel;
}

function CreateDeviceInfo {
    param ([parameter(Mandatory = $true)]$deviceUniqueId)
    $systemInfo = ReadRelevantSystemInfo;  
    return [pscustomobject]@{
        ids          = @($deviceUniqueId)
        manufacturer = $systemInfo.CsManufacturer
        model        = $systemInfo.CsModel
        name         = $systemInfo.CsDNSHostName
        sw_version   = $systemInfo.OsVersion
    }
}

function RegisterSensor {
    param (
        [String]$autoDiscoveryPrefix,
        [object]$deviceInfo,
        [object]$configuration,
        [object]$mqttClient
    )
    
    $homeassistant_sensor_path = "{0}/{1}/{2}" -f $autoDiscoveryPrefix, `
        $configuration.homeassistant_component, `
        $configuration.object_name 

    $homeassistant_auto_configure_topic = "$homeassistant_sensor_path/config"
    $homeassistant_auto_configure_payload = [pscustomobject]@{
        unique_id    = $configuration.unique_id
        name         = $configuration.object_name
        state_topic  = "$homeassistant_sensor_path/state"
        device_class = $configuration.device_class
        device       = $deviceInfo
        off_delay    = $configuration.off_delay
    }
    $configurePayload = (ConvertTo-Json $homeassistant_auto_configure_payload -compress) -replace '"', '"""'
    Write-Host "Registering $homeassistant_auto_configure_topic"
    $mqttClient.publish($homeassistant_auto_configure_topic, $configurePayload)
}

function RegisterDevice {
    param (
        [object]$configuration,
        [object]$mqttClient
    )
    $deviceInfo = CreateDeviceInfo($configuration.activity_sensor.device_id)
    RegisterSensor -autoDiscoveryPrefix $configuration.homeassistant_auto_discovery_prefix `
        -deviceInfo $deviceInfo `
        -configuration $configuration.activity_sensor `
        -mqttClient $mqttClient
    RegisterSensor -autoDiscoveryPrefix $configuration.homeassistant_auto_discovery_prefix `
        -deviceInfo $deviceInfo `
        -configuration $configuration.powerline_sensor `
        -mqttClient $mqttClient
    RegisterSensor -autoDiscoveryPrefix $configuration.homeassistant_auto_discovery_prefix `
        -deviceInfo $deviceInfo `
        -configuration $configuration.workstation_unlocked_sensor `
        -mqttClient $mqttClient
}

function SubscribeTopicSerivce {
    param ($hostname, $user, $password, $topic)
    $subscribeHS = "mqtt-cli sub -h {0} -u {1} -pw {2} -t ""{3}""" -f $hostname, $user, $password, $topic
    Write-Host $subscribeHS
    Invoke-Expression $subscribeHS
}

$configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $configuration.homeassistant_host
$mqttClient.user = $configuration.mqtt_login
$mqttClient.password = $configuration.mqtt_password

RegisterDevice $configuration $mqttClient

$restartListener = start-job -ScriptBlock ${function:SubscribeTopicSerivce} -ArgumentList $configuration.homeassistant_host, $configuration.mqtt_login, $configuration.mqtt_password, "homeassistant/status"
try {
    while ($true) {
        $status = $restartListener | Receive-Job
        if ($status) {
            Write-Host "Received: $status"
            $status_messages = $status -split "`n"
            $last_status_message = $status_messages[$status_messages.Count - 1]
            if ($last_status_message -eq "online") {
                RegisterDevice $configuration $mqttClient
            }
        } else {
            if ($restartListener.State -ne "Running") {
                $restartListener.Dispose()
                RegisterDevice $configuration $mqttClient
                $restartListener = start-job -ScriptBlock ${function:SubscribeTopicSerivce} -ArgumentList $configuration.homeassistant_host, $configuration.mqtt_login, $configuration.mqtt_password, "homeassistant/status"
            }
        }
        Start-Sleep -Seconds 1
    }
} finally {
    $restartListener.Dispose()
}



    



