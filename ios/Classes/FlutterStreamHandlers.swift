import Foundation
import RxSwift
import PolarBleSdk

public class AccStreamHandler: NSObject, FlutterStreamHandler
 {
    
    var eventSink: FlutterEventSink?
    var accDisposable: Disposable?
    var api: PolarBleApi
    
    init(accDisposable: Disposable?, api: PolarBleApi){
        self.accDisposable = accDisposable
        self.api = api
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        guard let args = arguments else {
            return nil
        }
        if let deviceId = args as? String {
            print("Params received on iOS = \(deviceId)")
            self.accDisposable?.dispose()
            self.accDisposable = nil
                let customSettings = PolarSensorSetting([PolarSensorSetting.SettingType.range:2, PolarSensorSetting.SettingType.sampleRate: 25, PolarSensorSetting.SettingType.resolution: 16])
                NSLog("settings: \(customSettings.settings)")
                self.accDisposable = api.startAccStreaming(deviceId, settings: customSettings).observe(on: MainScheduler.instance)
                    .subscribe{ e in
                        switch e {
                        case .next(let data):
                            for item in data.samples {
                                NSLog("    x: \(item.x) y: \(item.y) z: \(item.z)")
                                let accDict : [String: Any] = [ "x": item.x, "y":item.y,"z":item.z,"timestamp":data.timeStamp]
                                let accJsonData = try! JSONSerialization.data(withJSONObject: accDict, options: [])
                                let accJsonString = String(data: accJsonData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                                events(accJsonString)
                            }
                        case .error(let err):
                            NSLog("ACC error: \(err)")
                            events(FlutterError(code: "AccStreamHandler.onListen",
                                                message: err.localizedDescription,
                                                details: nil))
                            self.accDisposable = nil
                        case .completed:
                            break
                        }
                    }
            
        } else {
            events(FlutterError(code: "-1", message: "iOS could not extract " +
                                    "flutter arguments in method: AccStreamHandler.onListen", details: nil))
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        self.accDisposable?.dispose()
        self.accDisposable = nil
        return nil
    }
    
}

public class HrBroadcastStreamHandler: NSObject, FlutterStreamHandler {
    
    var eventSink: FlutterEventSink?
    var hrBroadcastDisposable: Disposable?
    var api: PolarBleApi
    
    init(hrBroadcastDisposable: Disposable?, api: PolarBleApi){
        self.hrBroadcastDisposable = hrBroadcastDisposable
        self.api = api
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        self.hrBroadcastDisposable?.dispose()
        self.hrBroadcastDisposable = nil
            self.hrBroadcastDisposable = api.startListenForPolarHrBroadcasts(nil)
                .observe(on: MainScheduler.instance)
                .subscribe{ e in
                    switch e {
                    case .completed:
                        NSLog("completed")
                    case .error(let err):
                        NSLog("listening error: \(err)")
                        events(FlutterError(code: "HrBroadcastingStreamHandler.onListen",
                                            message: err.localizedDescription,
                                            details: nil))
                        self.hrBroadcastDisposable = nil
                    case .next(let broadcast):
                        NSLog("\(broadcast.deviceInfo.name) HR BROADCAST: \(broadcast.hr)")
                        events(broadcast.hr)
                    }
                }
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        self.hrBroadcastDisposable?.dispose()
        self.hrBroadcastDisposable = nil
        return nil
    }
    
}

public class HrStreamHandler: NSObject, FlutterStreamHandler, PolarBleApiDeviceHrObserver {
    
    var eventSink: FlutterEventSink?
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    public func hrValueReceived(_ identifier: String, data: PolarHrData) {
        NSLog("(\(identifier)) HR notification: \(data.hr) rrs: \(data.rrs) rrsMs: \(data.rrsMs) c: \(data.contact) s: \(data.contactSupported)")
        if let events = self.eventSink {
            let hrDict : [String: Any] = [ "hr": data.hr, "rrs":data.rrsMs,"timestamp": (Date.init().timeIntervalSince1970 * 1000.0).rounded()]
            let hrJsonData = try! JSONSerialization.data(withJSONObject: hrDict, options: [])
            let hrJsonString = String(data: hrJsonData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
            events(hrJsonString)
        }
    }
}

public class EcgStreamHandler: NSObject, FlutterStreamHandler
 {
    
    var eventSink: FlutterEventSink?
    var ecgDisposable: Disposable?
    var api: PolarBleApi
    
    init(ecgDisposable: Disposable?, api: PolarBleApi){
        self.ecgDisposable = ecgDisposable
        self.api = api
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        guard let args = arguments else {
            return nil
        }
        if let deviceId = args as? String {
            print("Params received on iOS = \(deviceId)")
            self.ecgDisposable?.dispose()
            self.ecgDisposable = nil
//                let customSettings = PolarSensorSetting([PolarSensorSetting.SettingType.range:2, PolarSensorSetting.SettingType.sampleRate: 25, PolarSensorSetting.SettingType.resolution: 16])
//                NSLog("settings: \(customSettings.settings)")
                self.ecgDisposable = api.requestEcgSettings(deviceId)
                    .asObservable()
                    .flatMap({ (settings) -> Observable<PolarEcgData> in
                        return self.api.startEcgStreaming(deviceId, settings: settings.maxSettings())
                    })
                    .observe(on: MainScheduler.instance)
                    .subscribe{ e in
                        switch e {
                        case .next(let data):
                            for µv in data.samples {
                                NSLog("    µV: \(µv)")
                            }
                            let ecgDict : [String: Any] = [ "samples":data.samples,"timestamp": data.timeStamp]
                            let ecgJsonData = try! JSONSerialization.data(withJSONObject: ecgDict, options: [])
                            let ecgJsonString = String(data: ecgJsonData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                            events(ecgJsonString)
                        case .error(let err):
                            NSLog("ECG error: \(err)")
                            events(FlutterError(code: "ECGStreamHandler.onListen",
                                                message: err.localizedDescription,
                                                details: nil))
                            self.ecgDisposable = nil
                        case .completed:
                            break
                        }
                    }
            
        } else {
            events(FlutterError(code: "-1", message: "iOS could not extract " +
                                    "flutter arguments in method: EcgStreamHandler.onListen", details: nil))
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        self.ecgDisposable?.dispose()
        self.ecgDisposable = nil
        return nil
    }
    
}
