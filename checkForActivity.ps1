$homeassistant_host = "homeassistant"

$homeassistantAutoDiscoveryPrefix = "homeassistant"
$homeassistantComponent = "binary_sensor"
$homeassistantObjectId = "work_laptop_activity_1"
$device_class = "motion"
$state_topic = "$homeassistantAutoDiscoveryPrefix/$homeassistantComponent/$homeassistantObjectId/state"

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
        mqtt-cli.exe  pub -t $topic, -m $payload -h $this.mqttHost -u $this.user -pw $this.password
    }

    [void] publish([string]$topic, [boolean]$payload) {
        mqtt-cli.exe  pub -t $topic, -m $payload -h $this.mqttHost -u $this.user -pw $this.password
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

$device_info = CreateDeviceInfo "oADTxd"

$homeassistant_auto_configure_topic = "$homeassistantAutoDiscoveryPrefix/$homeassistantComponent/$homeassistantObjectId/config"
$homeassistant_auto_configure_payload = [pscustomobject]@{
    unique_id    = "A0Qp4N"
    name         = $homeassistantObjectId
    state_topic  = $state_topic
    device_class = $device_class
    device       = $device_info
    off_delay    = 10
}

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $homeassistant_host
$mqttClient.user = "espUser"
$mqttClient.password = "esp123"

$configurePayload = (ConvertTo-Json $homeassistant_auto_configure_payload -compress) -replace '"', '\"'
$mqttClient.publish($homeassistant_auto_configure_topic, '\"\"')
$mqttClient.publish($homeassistant_auto_configure_topic, $configurePayload)

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