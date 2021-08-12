param($deviceConfigPath = ".\device_config.json")

Add-Type -Path "${env:MQTT_HOME}\lib\net45\M2Mqtt.Net.dll"

. .\mqttClient.ps1

function CheckForKeyboardActivity {
    param ($API, $iterations = 4, $timeoutInMillis = 25)
    $signatures = @'
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
    public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@
    $API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

    for ($iteration = 1; $iteration -le $iterations; $iteration++) {
        Start-Sleep -Milliseconds $timeoutInMillis
        for ($ascii = 9; $ascii -le 254; $ascii++) {
            $state = $API::GetAsyncKeyState($ascii)
            if ($state -eq -32767) {
                Write-Host "Key stroke detected"
                return $true;
            }
        }
    }
    return $false;
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
    if (CheckForKeyboardActivity($API) -eq $true) {
        $mqttClient.publish($state_topic, 'ON')
    }
}