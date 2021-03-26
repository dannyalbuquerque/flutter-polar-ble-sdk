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
        guard let args = arguments as? [String: Any] else {
            return nil
        }
        if let deviceId = args[Constants.Arguments.deviceId] as? String, let sampleRate = args[Constants.Arguments.sampleRate] as? Int32  {
            print("Params received on iOS = \(deviceId), \(sampleRate)")
            self.accDisposable?.dispose()
                let customSettings = PolarSensorSetting([PolarSensorSetting.SettingType.range:2, PolarSensorSetting.SettingType.sampleRate: UInt16(sampleRate), PolarSensorSetting.SettingType.resolution: 16])
                NSLog("settings: \(customSettings.settings)")
                self.accDisposable = api.startAccStreaming(deviceId, settings: customSettings).observe(on: MainScheduler.instance)
                    .subscribe{ e in
                        switch e {
                        case .next(let data):
                            for item in data.samples {
                                //NSLog("    x: \(item.x) y: \(item.y) z: \(item.z)")
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
        return nil
    }
    
}

public class HrStreamHandler: NSObject, FlutterStreamHandler {
    
    typealias PolarHrData = (hr: UInt8, rrs: [Int], rrsMs: [Int], contact: Bool, contactSupported: Bool)
    
    var eventSink: FlutterEventSink?
    var hrDataSubject: PublishSubject<PolarHrData>
    var hrDisposable: Disposable?
    
    init(hrDataSubject: PublishSubject<PolarHrData>){
        self.hrDataSubject = hrDataSubject
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        self.hrDisposable?.dispose()
        self.hrDisposable = hrDataSubject.observe(on: MainScheduler.instance)
            .subscribe{ e in
                switch e {
                case .completed:
                    NSLog("completed")
                case .error(let err):
                    NSLog("listening error: \(err)")
                    events(FlutterError(code: "HrStreamHandler.onListen",
                                        message: err.localizedDescription,
                                        details: nil))
                case .next(let data):
                    let hrDict : [String: Any] = [ "hr": data.hr, "rrs":data.rrsMs,"timestamp": (Date.init().timeIntervalSince1970 * 1000.0).rounded()]
                    let hrJsonData = try! JSONSerialization.data(withJSONObject: hrDict, options: [])
                    let hrJsonString = String(data: hrJsonData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                    events(hrJsonString)
                }
            }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        self.hrDisposable?.dispose()
        self.hrDataSubject.dispose()
        return nil
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
        if let deviceId = args as? String{
            print("Params received on iOS = \(deviceId)")
            self.ecgDisposable?.dispose()
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
                               // NSLog("    µV: \(µv)")
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
        return nil
    }
    
}

public class PpgStreamHandler: NSObject, FlutterStreamHandler
 {
    
    var eventSink: FlutterEventSink?
    var ppgDisposable: Disposable?
    var api: PolarBleApi
    
    init(ppgDisposable: Disposable?, api: PolarBleApi){
        self.ppgDisposable = ppgDisposable
        self.api = api
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        guard let args = arguments else {
            return nil
        }
        if let deviceId = args as? String {
            print("Params received on iOS = \(deviceId)")
            self.ppgDisposable?.dispose()
//                let customSettings = PolarSensorSetting([PolarSensorSetting.SettingType.range:2, PolarSensorSetting.SettingType.sampleRate: 25, PolarSensorSetting.SettingType.resolution: 16])
//                NSLog("settings: \(customSettings.settings)")
                self.ppgDisposable = api.requestPpgSettings(deviceId)
                    .asObservable()
                    .flatMap({ (settings) -> Observable<PolarPpgData> in
                        return self.api.startOhrPPGStreaming(deviceId, settings: settings.maxSettings())
                    })
                    .observe(on: MainScheduler.instance)
                    .subscribe{ e in
                        switch e {
                        case .next(let data):
                            var samples = [Int32]()
                            for item in data.samples {
                               // NSLog("    ppg0: \(item.ppg0) ppg1: \(item.ppg1) ppg2: \(item.ppg2), ambient: \(item.ambient)")
                                samples.append(item.ppg0)
                                samples.append(item.ppg1)
                                samples.append(item.ppg2)
                                samples.append(item.ambient)
                            }
                            let ppgDict : [String: Any] = [ "samples":samples,"timestamp": data.timeStamp]
                            let ppgJsonData = try! JSONSerialization.data(withJSONObject: ppgDict, options: [])
                            let ppgJsonString = String(data: ppgJsonData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                            events(ppgJsonString)
                        case .error(let err):
                            NSLog("PPG error: \(err)")
                            events(FlutterError(code: "PpgStreamHandler.onListen",
                                                message: err.localizedDescription,
                                                details: nil))
                        case .completed:
                            break
                        }
                    }
            
        } else {
            events(FlutterError(code: "-1", message: "iOS could not extract " +
                                    "flutter arguments in method: PpgStreamHandler.onListen", details: nil))
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        self.ppgDisposable?.dispose()
        return nil
    }
    
}

public class SearchStreamHandler: NSObject, FlutterStreamHandler
 {
    
    var eventSink: FlutterEventSink?
    var searchDisposable: Disposable?
    var api: PolarBleApi
    
    init(searchDisposable: Disposable?, api: PolarBleApi){
        self.searchDisposable = searchDisposable
        self.api = api
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
            self.searchDisposable?.dispose()
            self.searchDisposable = api.searchForDevice()
                    .observe(on: MainScheduler.instance)
                    .subscribe{ e in
                        switch e {
                        case .next(let deviceInfo):
                            let searchDict : [String: Any] = [ "deviceId":deviceInfo.deviceId,
                                                               "address":deviceInfo.address.uuidString,
                                "rssi":deviceInfo.rssi,
                                "name":deviceInfo.name,
                                "connectable":deviceInfo.connectable,
                            ]
                            let searchJsonData = try! JSONSerialization.data(withJSONObject: searchDict, options: [])
                            let searchJsonString = String(data: searchJsonData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                            events(searchJsonString)
                        case .error(let err):
                            NSLog("Search error: \(err)")
                            events(FlutterError(code: "SearchStreamHandler.onListen",
                                                message: err.localizedDescription,
                                                details: nil))
                        case .completed:
                            break
                        }
                    }
            
    
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        self.searchDisposable?.dispose()
        return nil
    }
    
}

//public class HrBroadcastStreamHandler: NSObject, FlutterStreamHandler {
//
//    var eventSink: FlutterEventSink?
//    var hrBroadcastDisposable: Disposable?
//    var api: PolarBleApi
//
//    init(hrBroadcastDisposable: Disposable?, api: PolarBleApi){
//        self.hrBroadcastDisposable = hrBroadcastDisposable
//        self.api = api
//    }
//
//    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
//        self.eventSink = events
//        self.hrBroadcastDisposable?.dispose()
//        self.hrBroadcastDisposable = nil
//            self.hrBroadcastDisposable = api.startListenForPolarHrBroadcasts(nil)
//                .observe(on: MainScheduler.instance)
//                .subscribe{ e in
//                    switch e {
//                    case .completed:
//                        NSLog("completed")
//                    case .error(let err):
//                        NSLog("listening error: \(err)")
//                        events(FlutterError(code: "HrBroadcastingStreamHandler.onListen",
//                                            message: err.localizedDescription,
//                                            details: nil))
//                        self.hrBroadcastDisposable = nil
//                    case .next(let broadcast):
//                        NSLog("\(broadcast.deviceInfo.name) HR BROADCAST: \(broadcast.hr)")
//                        events(broadcast.hr)
//                    }
//                }
//
//        return nil
//    }
//
//    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
//        self.eventSink = nil
//        self.hrBroadcastDisposable?.dispose()
//        self.hrBroadcastDisposable = nil
//        return nil
//    }
//
//}
