class MQTTClient {
    [string]$mqttHost
    [string]$user
    [string]$password
    [object]$mqttClient

    [void] connect() {
        $this.mqttClient = [uPLibrary.Networking.M2Mqtt.MqttClient]($this.mqttHost)
        $this.mqttClient.Connect([guid]::NewGuid(), $this.user, $this.password)
    }

    [void] publish([string]$topic, [string]$payload) {
        if (!$this.mqttClient.IsConnected) {
            $this.connect()
        }
        $this.mqttClient.Publish($topic, [System.Text.Encoding]::UTF8.GetBytes($payload))
    }

    [object] registerReceiveFunction([object]$receivedFunction) {
        $eventRegistration = Register-ObjectEvent -inputObject $this.mqttClient -EventName "MqttMsgPublishReceived" -Action $receivedFunction
        return $eventRegistration
    }

    [void] subscribe([string]$topic, [object]$receivedFunction) {
        if (!$this.mqttClient.IsConnected) {
            $this.connect()
        }
        $this.mqttClient.Subscribe($topic, 0)
    }
}
