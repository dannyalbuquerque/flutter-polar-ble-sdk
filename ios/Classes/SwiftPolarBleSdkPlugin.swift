import Flutter
import UIKit
import RxSwift
import PolarBleSdk
import CoreBluetooth

public class SwiftPolarBleSdkPlugin: NSObject, FlutterPlugin,PolarBleApiObserver,
                                     PolarBleApiPowerStateObserver,
                                     //PolarBleApiDeviceHrObserver,
                                     PolarBleApiDeviceInfoObserver,
                                     PolarBleApiDeviceFeaturesObserver,
                                     PolarBleApiLogger,
                                     PolarBleApiCCCWriteObserver {
    
    
    var api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: Features.allFeatures.rawValue)
    
    var broadcastDisposable: Disposable?
    var autoConnectDisposable: Disposable?
    var accDisposable: Disposable?
    var ecgDisposable: Disposable?
        
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
        NSLog("\(PolarBleApiDefaultImpl.versionInfo())")
        let hrBroadcastEventChannel = FlutterEventChannel(name: Constants.EventNames.hrBroadcast, binaryMessenger: registrar.messenger())
        let hrBroadcastStreamHandler = HrBroadcastStreamHandler(hrBroadcastDisposable: instance.broadcastDisposable, api: instance.api)
        hrBroadcastEventChannel.setStreamHandler(hrBroadcastStreamHandler)
        let accEventChannel = FlutterEventChannel(name: Constants.EventNames.acc, binaryMessenger: registrar.messenger())
        let accStreamHandler = AccStreamHandler(accDisposable: instance.accDisposable, api: instance.api)
        accEventChannel.setStreamHandler(accStreamHandler)
        let hrStreamHandler = HrStreamHandler()
        let hrEventChannel = FlutterEventChannel(name: Constants.EventNames.hr, binaryMessenger: registrar.messenger())
        hrEventChannel.setStreamHandler(hrStreamHandler)
        instance.api.deviceHrObserver = hrStreamHandler
        let ecgEventChannel = FlutterEventChannel(name: Constants.EventNames.ecg, binaryMessenger: registrar.messenger())
        let ecgStreamHandler = EcgStreamHandler(ecgDisposable: instance.ecgDisposable, api: instance.api)
        ecgEventChannel.setStreamHandler(ecgStreamHandler)
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
                    result(nil)
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
        case Constants.MethodNames.autoconnect:
            autoConnectDisposable?.dispose()
            autoConnectDisposable = api.startAutoConnectToDevice(-55, service: nil, polarDeviceType: nil)
                .subscribe{ e in
                    switch e {
                    case .completed:
                        NSLog("auto connect search complete")
                        result(nil)
                    case .error(let err):
                        NSLog("auto connect failed: \(err)")
                        result(FlutterError(code: call.method,
                                            message: err.localizedDescription,
                                            details: nil))
                    @unknown default:
                        fatalError()
                    }
                }
            break
        case Constants.MethodNames.disconnect:
            guard let args = call.arguments else {
                return
            }
            if let myArgs = args as? [String: Any],
               let deviceId = myArgs[Constants.Arguments.deviceId] as? String{
                print("Params received on iOS = \(deviceId)")
                do{
                    try self.api.disconnectFromDevice(deviceId)
                    result(nil)
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
    }
    
    // PolarBleApiDeviceInfoObserver
    public func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        NSLog("battery level updated: \(batteryLevel)")
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
}
