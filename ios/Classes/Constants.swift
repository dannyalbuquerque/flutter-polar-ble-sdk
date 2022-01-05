struct Constants {
    struct MethodNames {
        static let connect = "connect"
        static let disconnect = "disconnect"
        static let autoconnect = "autoconnect"
        static let batteryLevel = "batteryLevel"
        static let fwVersion = "fwVersion"
    }
    struct EventNames {
        static let  hrBroadcast = "hrBroadcast"
        static let  acc = "acc"
        static let  hr = "hr"
        static let  ecg = "ecg"
        static let  ppg = "ppg"
        static let  search = "search"
    }
    struct Arguments {
        static let  deviceId = "deviceId"
        static let sampleRate = "sampleRate"
    }
}
