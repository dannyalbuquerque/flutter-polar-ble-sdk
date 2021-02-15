import Flutter
import UIKit
import RxSwift
import PolarBleSdk
import CoreBluetooth
import streams_channel

public class SwiftPolarBleSdkPlugin: NSObject, FlutterPlugin,PolarBleApiObserver,
                                     PolarBleApiPowerStateObserver,
                                     PolarBleApiDeviceHrObserver,
                                     PolarBleApiDeviceInfoObserver,
                                     PolarBleApiDeviceFeaturesObserver,
                                     PolarBleApiLogger,
                                     PolarBleApiCCCWriteObserver {
    
    
    var api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: Features.allFeatures.rawValue)
    
    //var broadcastDisposable: Disposable?
    //var autoConnectDisposable: Disposable?
    var accDisposables = [String : Disposable?]()
    var ecgDisposables = [String : Disposable?]()
    var ppgDisposables = [String : Disposable?]()
    var searchDisposable: Disposable?
    
    var connectResults = [String : FlutterResult]()
    var disconnectResults = [String : FlutterResult]()
    
    var hrDataSubjects = [String : PublishSubject<PolarHrData>]()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "polar_ble_sdk", binaryMessenger: registrar.messenger())
        let instance = SwiftPolarBleSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.api.observer = instance
        //instance.api.deviceHrObserver = instance
        instance.api.deviceInfoObserver = instance
        instance.api.powerStateObserver = instance
        instance.api.deviceFeaturesObserver = instance
        instance.api.logger = instance
        instance.api.cccWriteObserver = instance
        instance.api.polarFilter(false)
        instance.api.automaticReconnection = false;
        instance.api.deviceHrObserver = instance
        NSLog("\(PolarBleApiDefaultImpl.versionInfo())")
        //        let hrBroadcastEventChannel = FlutterEventChannel(name: Constants.EventNames.hrBroadcast, binaryMessenger: registrar.messenger())
        //        let hrBroadcastStreamHandler = HrBroadcastStreamHandler(hrBroadcastDisposable: instance.broadcastDisposable, api: instance.api)
        //        hrBroadcastEventChannel.setStreamHandler(hrBroadcastStreamHandler)
        let accStreamsChannel = FlutterStreamsChannel(name: Constants.EventNames.acc, binaryMessenger: registrar.messenger())
        accStreamsChannel.setStreamHandlerFactory({ arguments in
            let deviceId = arguments as! String
            instance.accDisposables.updateValue(nil, forKey: deviceId)
            return AccStreamHandler(accDisposable: instance.accDisposables[deviceId] ?? nil, api: instance.api)
        })
        let hrStreamsChannel = FlutterStreamsChannel(name: Constants.EventNames.hr, binaryMessenger: registrar.messenger())
        hrStreamsChannel.setStreamHandlerFactory({ arguments in
            let deviceId = arguments as! String
            instance.hrDataSubjects.updateValue(PublishSubject.init(), forKey: deviceId)
            return HrStreamHandler(hrDataSubject: instance.hrDataSubjects[deviceId]!)
        })
        let ecgStreamsChannel = FlutterStreamsChannel(name: Constants.EventNames.ecg, binaryMessenger: registrar.messenger())
        ecgStreamsChannel.setStreamHandlerFactory({arguments in
                                                    let deviceId = arguments as! String
                                                    instance.ecgDisposables.updateValue(nil, forKey: deviceId)
                                                    return EcgStreamHandler(ecgDisposable: instance.ecgDisposables[deviceId] ?? nil, api: instance.api
                                                    )})
        let ppgStreamsChannel = FlutterStreamsChannel(name: Constants.EventNames.ppg, binaryMessenger: registrar.messenger())
        ppgStreamsChannel.setStreamHandlerFactory({arguments in
            let deviceId = arguments as! String
            instance.ppgDisposables.updateValue(nil, forKey: deviceId)
            return PpgStreamHandler(ppgDisposable: instance.ppgDisposables[deviceId]  ?? nil, api: instance.api)
        })
        let searchEventChannel = FlutterEventChannel(name: Constants.EventNames.search, binaryMessenger: registrar.messenger())
        searchEventChannel.setStreamHandler(SearchStreamHandler(searchDisposable: instance.searchDisposable, api: instance.api))
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method){
        case Constants.MethodNames.connect:
            guard let args = call.arguments else {
                return
            }
            if let myArgs = args as? [String: Any],
               let deviceId = myArgs[Constants.Arguments.deviceId] as? String{
                print("Params received on iOS = \(deviceId)")
                do{
                    try self.api.connectToDevice(deviceId)
                    connectResults[deviceId] = result;
                    //result(nil)
                } catch let err {
                    result(FlutterError(code: call.method,
                                        message: err.localizedDescription,
                                        details: nil))
                }
            } else {
                result(FlutterError(code: "-1", message: "iOS could not extract " +
                                        "flutter arguments in method: (\(call.method)", details: nil))
            }
            break
        //        case Constants.MethodNames.autoconnect:
        //            autoConnectDisposable?.dispose()
        //            autoConnectDisposable = api.startAutoConnectToDevice(-55, service: nil, polarDeviceType: nil)
        //                .subscribe{ e in
        //                    switch e {
        //                    case .completed:
        //                        NSLog("auto connect search complete")
        //                        result(nil)
        //                    case .error(let err):
        //                        NSLog("auto connect failed: \(err)")
        //                        result(FlutterError(code: call.method,
        //                                            message: err.localizedDescription,
        //                                            details: nil))
        //                    @unknown default:
        //                        fatalError()
        //                    }
        //                }
        //            break
        case Constants.MethodNames.disconnect:
            guard let args = call.arguments else {
                return
            }
            if let myArgs = args as? [String: Any],
               let deviceId = myArgs[Constants.Arguments.deviceId] as? String{
                print("Params received on iOS = \(deviceId)")
                do{
                    accDisposables[deviceId]??.dispose();
                    ecgDisposables[deviceId]??.dispose();
                    ppgDisposables[deviceId]??.dispose();
                    try self.api.disconnectFromDevice(deviceId)
                    disconnectResults[deviceId] = result
                    //result(nil)
                } catch let err {
                    result(FlutterError(code: call.method,
                                        message: err.localizedDescription,
                                        details: nil))
                }
            } else {
                result(FlutterError(code: "-1", message: "iOS could not extract " +
                                        "flutter arguments in method: (\(call.method)", details: nil))
            }
            break
        default: result(FlutterMethodNotImplemented)
        }
    }
    
    // PolarBleApiObserver
    public func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        NSLog("DEVICE CONNECTING: \(polarDeviceInfo)")
    }
    
    public func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        NSLog("DEVICE CONNECTED: \(polarDeviceInfo)")
    }
    
    public func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo) {
        NSLog("DISCONNECTED: \(polarDeviceInfo)")
        let deviceId = polarDeviceInfo.deviceId;
        accDisposables[deviceId] = nil
        ecgDisposables[deviceId] = nil
        ppgDisposables[deviceId] = nil
        disconnectResults[deviceId]?(nil)
        disconnectResults[deviceId] = nil
    }
    
    // PolarBleApiDeviceInfoObserver
    public func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        NSLog("battery level updated: \(batteryLevel)")
        connectResults[identifier]?(nil)
        connectResults[identifier] = nil
    }
    
    public func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
        NSLog("dis info: \(uuid.uuidString) value: \(value)")
    }
    
    // PolarBleApiDeviceEcgObserver
    public func ecgFeatureReady(_ identifier: String) {
        NSLog("ECG READY \(identifier)")
    }
    
    // PolarBleApiDeviceAccelerometerObserver
    public func accFeatureReady(_ identifier: String) {
        NSLog("ACC READY")
    }
    
    public func ohrPPGFeatureReady(_ identifier: String) {
        NSLog("OHR PPG ready")
    }
    
    // PolarBleApiPowerStateObserver
    public func blePowerOn() {
        NSLog("BLE ON")
    }
    
    public func blePowerOff() {
        NSLog("BLE OFF")
    }
    
    // PPI
    public func ohrPPIFeatureReady(_ identifier: String) {
        NSLog("PPI Feature ready")
    }
    
    public func ftpFeatureReady(_ identifier: String) {
        NSLog("FTP ready")
    }
    
    public func hrFeatureReady(_ identifier: String) {
        NSLog("HR READY")
    }
    
    
    public func message(_ str: String) {
        NSLog(str)
    }
    
    /// ccc write observer
    public func cccWrite(_ address: UUID, characteristic: CBUUID) {
        NSLog("ccc write: \(address) chr: \(characteristic)")
    }
    
    public func hrValueReceived(_ identifier: String, data: PolarHrData) {
        NSLog("(\(identifier)) HR notification: \(data.hr) rrs: \(data.rrs) rrsMs: \(data.rrsMs) c: \(data.contact) s: \(data.contactSupported)")
        if hrDataSubjects.keys.contains(identifier){
            hrDataSubjects[identifier]?.onNext(data)
        }
    }
}
