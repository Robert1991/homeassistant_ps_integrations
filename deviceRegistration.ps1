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
    $configurePayload = (ConvertTo-Json $homeassistant_auto_configure_payload -compress)
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
