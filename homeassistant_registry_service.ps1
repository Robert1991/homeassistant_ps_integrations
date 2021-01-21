param($deviceConfigPath = ".\device_config.json")

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
function RegisterDevice {
    param (
        [object]$configuration,
        [object]$mqttClient
    )
    $device_info = CreateDeviceInfo ($configuration.sensor.device_id)
    $homeassistant_activity_sensor_path = "{0}/{1}/{2}" -f $configuration.homeassistant_auto_discovery_prefix, `
        $configuration.sensor.homeassistant_component, `
        $configuration.sensor.object_name 

    $homeassistant_auto_configure_topic = "$homeassistant_activity_sensor_path/config"
    $homeassistant_auto_configure_payload = [pscustomobject]@{
        unique_id    = $configuration.sensor.unique_id
        name         = $configuration.sensor.object_name
        state_topic  = "$homeassistant_activity_sensor_path/state"
        device_class = $configuration.sensor.device_class
        device       = $device_info
        off_delay    = 10
    }
    $configurePayload = (ConvertTo-Json $homeassistant_auto_configure_payload -compress) -replace '"', '"""'
    Write-Host "Registering $homeassistant_auto_configure_topic"
    $mqttClient = [MQTTClient]::new()
    $mqttClient.mqttHost = $configuration.homeassistant_host
    $mqttClient.user = $configuration.mqtt_login
    $mqttClient.password = $configuration.mqtt_password
    $mqttClient.publish($homeassistant_auto_configure_topic, '\"\"')
    $mqttClient.publish($homeassistant_auto_configure_topic, $configurePayload)
}

$configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json

RegisterDevice $configuration $mqttClient

function SubscribeTopicSerivce {
    param ($hostname, $user, $password, $topic)
    $subscribeHS = "mqtt-cli sub -h {0} -u {1} -pw {2} -t ""{3}""" -f $hostname, $user, $password, $topic
    Write-Host $subscribeHS
    Invoke-Expression $subscribeHS
}

$restartListener = start-job -ScriptBlock ${function:SubscribeTopicSerivce} -ArgumentList $configuration.homeassistant_host,$configuration.mqtt_login,$configuration.mqtt_password,"homeassistant/status"
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
        }
        if ($restartListener.State -ne "Running") {
            $restartListener.Dispose()
            $restartListener = start-job -ScriptBlock ${function:SubscribeTopicSerivce} -ArgumentList $configuration.homeassistant_host,$configuration.mqtt_login,$configuration.mqtt_password,"homeassistant/status"
        }
		Start-Sleep -Seconds 10
    }
}
finally {
    $restartListener.Dispose()
}



    



