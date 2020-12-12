param([switch]$register)

$homeassistant_host = "homeassistant"

$homeassistantAutoDiscoveryPrefix = "homeassistant"
$homeassistantComponent = "binary_sensor"
$homeassistantObjectId = "work_laptop_activity"
$device_class = "motion"
$sensorUniqueId = "f3frQH"
$state_topic = "$homeassistantAutoDiscoveryPrefix/$homeassistantComponent/$homeassistantObjectId/state"
$deviceId = "jt6Qmn"
$signatures = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@
$API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

# for full keylogger example look here https://gist.github.com/dasgoll/7ca1c059dd3b3fbc7277
function CheckForKeyboardActivity {
    param ($API, $iterations = 25, $timeoutInMillis = 50)
    
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

class MQTTClient {
    [string]$mqttHost
    [string]$user
    [string]$password

    [void] publish([string]$topic, [string]$payload) {
        $clientCall = "mqtt-cli pub -h {0} -u {1} -pw {2} -t ""{3}"" -m '{4}'" -f $this.mqttHost,$this.user, $this.password, $topic, $payload
        Invoke-Expression $clientCall
    }

    [void] publish([string]$topic, [boolean]$payload) {
        mqtt-cli pub -t $topic, -m $payload -h $this.mqttHost -u $this.user -pw $this.password
    }
}

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

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $homeassistant_host
$mqttClient.user = "espUser"
$mqttClient.password = "esp123"

if ($register) {
    $device_info = CreateDeviceInfo $deviceId

    $homeassistant_auto_configure_topic = "$homeassistantAutoDiscoveryPrefix/$homeassistantComponent/$homeassistantObjectId/config"
    $homeassistant_auto_configure_payload = [pscustomobject]@{
        unique_id    = $sensorUniqueId
        name         = $homeassistantObjectId
        state_topic  = $state_topic
        device_class = $device_class
        device       = $device_info
        off_delay    = 10
    }
    $configurePayload = (ConvertTo-Json $homeassistant_auto_configure_payload -compress) -replace '"', '""'
    $mqttClient.publish($homeassistant_auto_configure_topic, '\"\"')
    $mqttClient.publish($homeassistant_auto_configure_topic, $configurePayload)
}
else {
    Add-Type -AssemblyName System.Windows.Forms

    while ($true) {
        $p1 = [System.Windows.Forms.Cursor]::Position
        Start-Sleep -Milliseconds 100
        $p2 = [System.Windows.Forms.Cursor]::Position

        $mouseMoved = $true
        if ($p1.X -eq $p2.X -and $p1.Y -eq $p2.Y) {
            $mouseMoved = $false
        }

        if (-not $mouseMoved) {
            $keyStrokeDetected = CheckForKeyboardActivity $API
        }
    
        if ($mouseMoved -or $keyStrokeDetected) {
            $mqttClient.publish($state_topic, 'ON')
            "Activity detected"
            Start-Sleep -seconds 2
        }
    }
}


