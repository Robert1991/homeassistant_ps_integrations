class MQTTClient {
    [string]$mqttHost
    [string]$user
    [string]$password

    [void] publish([string]$topic, [string]$payload) {
        $clientCall = "mqtt-cli pub -h {0} -u {1} -pw {2} -t ""{3}"" -m '{4}'" -f $this.mqttHost, $this.user, $this.password, $topic, $payload
        Invoke-Expression $clientCall
    }

    [void] publish([string]$topic, [boolean]$payload) {
        mqtt-cli.exe  pub -t $topic, -m $payload -h $this.mqttHost -u $this.user -pw $this.password
    }
}