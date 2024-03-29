param($deviceConfigPath = ".\device_config.json")

. .\mqttClient.ps1

# for full keylogger example look here https://gist.github.com/dasgoll/7ca1c059dd3b3fbc7277
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

function ReportActivity {
    param (
        [string]$state_topic
    )
    Write-Host "publishing: $state_topic"
    $return = $input.publish($state_topic, 'ON')
    Write-Host "some return: $return"
}

$configuration = Get-Content -Raw -Path $deviceConfigPath | ConvertFrom-Json
$homeassistant_activity_sensor_path = "{0}/{1}/{2}" -f $configuration.homeassistant_auto_discovery_prefix, `
    $configuration.sensor.homeassistant_component, `
    $configuration.sensor.object_name 

$mqttClient = [MQTTClient]::new()
$mqttClient.mqttHost = $configuration.homeassistant_host
$mqttClient.user = $configuration.mqtt_login
$mqttClient.password = $configuration.mqtt_password

$state_topic = "$homeassistant_activity_sensor_path/state"

$activityDetectedInLastIteration = $false
while ($true) {
    $checkForMouseMovementJob = start-job -ScriptBlock ${function:CheckForMouseMovement}
    $checkKeyBoardActivityJob = start-job -ScriptBlock ${function:CheckForKeyboardActivity}
        
    try {
        while ("Running" -eq $checkForMouseMovementJob.State -and "Running" -eq $checkKeyBoardActivityJob.State) {
            Write-Host "Wait"
            Start-Sleep -Milliseconds 100
        }
        
        Start-Sleep -Milliseconds 50
        Write-host "IterationEnd"

        $moveMovedJobObject = $checkForMouseMovementJob | Wait-Job -Timeout 5
        $mouseMoved = $moveMovedJobObject | Receive-Job
        $checkKeyBoardActivityJobObject = $checkKeyBoardActivityJob | Wait-Job -Timeout 5
        $keyStrokeDetected = $checkKeyBoardActivityJobObject | Receive-Job

        if (($mouseMoved -or $keyStrokeDetected) -and -not $activityDetectedInLastIteration) {
            $activityDetectedInLastIteration = $true
            Write-Host "Reporting activity"
            $mqttClient.publishAsync($state_topic, 'ON')
        } else {
            $activityDetectedInLastIteration = $false
        }
    } catch {
        write-host "Error occured: `r`n $_.Exception.Message"
    } finally {
        $checkForMouseMovementJob | Remove-Job -ErrorAction SilentlyContinue
        $checkKeyBoardActivityJob | Remove-Job -ErrorAction SilentlyContinue

        Write-Host "Current Jobs"
        Get-Job -ErrorAction SilentlyContinue
        Remove-Job -State Completed -ErrorAction SilentlyContinue
        Remove-Job -State Failed -ErrorAction SilentlyContinue
    }
}

return 1;