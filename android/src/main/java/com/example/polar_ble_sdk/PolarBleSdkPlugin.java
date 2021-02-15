package com.example.polar_ble_sdk;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import app.loup.streams_channel.StreamsChannel;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.subjects.PublishSubject;
import polar.com.sdk.api.PolarBleApi;
import polar.com.sdk.api.PolarBleApiCallback;
import polar.com.sdk.api.PolarBleApiDefaultImpl;
import polar.com.sdk.api.errors.PolarInvalidArgument;
import polar.com.sdk.api.model.PolarDeviceInfo;
import polar.com.sdk.api.model.PolarHrData;

/** PolarBleSdkPlugin */
public class PolarBleSdkPlugin implements FlutterPlugin, MethodCallHandler {
  private static final String TAG = PolarBleSdkPlugin.class.getSimpleName();
  private static final String API_LOGGER_TAG = "API LOGGER";
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  //private EventChannel hrBroadcastEventChannel;
  private StreamsChannel accStreamsChannel;
  private StreamsChannel hrStreamsChannel;
  private StreamsChannel ecgStreamsChannel;
  private StreamsChannel ppgStreamsChannel;
  private EventChannel searchEventChannel;
  private Map<String, PublishSubject<PolarHrData>> hrDataSubjects = new HashMap();

  private Context context;
  private PolarBleApi api;
  //Disposable broadcastDisposable;
  //Disposable autoConnectDisposable;
  private Map<String, Disposable>  accDisposables = new HashMap();
  private Map<String, Disposable>  ecgDisposables = new HashMap();
  private Map<String, Disposable>  ppgDisposables = new HashMap();
  Disposable searchDisposable;

  private Map<String, Result> connectResults = new HashMap();
  private Map<String, Result> disconnectResults = new HashMap();

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "polar_ble_sdk");
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();
    initialize();
    accStreamsChannel = new StreamsChannel(flutterPluginBinding.getBinaryMessenger(), EventName.acc);
    accStreamsChannel.setStreamHandlerFactory(arguments -> {
      final String deviceId = arguments.toString();
      if(!accDisposables.containsKey(deviceId)){
        accDisposables.put(deviceId, null);
      }
      return new AccStreamHandler(accDisposables.get(deviceId), api);
    });
    hrStreamsChannel = new StreamsChannel(flutterPluginBinding.getBinaryMessenger(), EventName.hr);
    hrStreamsChannel.setStreamHandlerFactory(arguments -> {
      String deviceId = arguments.toString();
      if(!hrDataSubjects.containsKey(deviceId)){
        hrDataSubjects.put(deviceId,PublishSubject.create());
      }
      return new HrStreamHandler(hrDataSubjects.get(deviceId));
    });
    ecgStreamsChannel = new StreamsChannel(flutterPluginBinding.getBinaryMessenger(), EventName.ecg);
    ecgStreamsChannel.setStreamHandlerFactory(arguments -> {
      final String deviceId = arguments.toString();
      if (!ecgDisposables.containsKey(deviceId)) {
        ecgDisposables.put(deviceId, null);
      }
      return new EcgStreamHandler(ecgDisposables.get(deviceId), api);
    });
    ppgStreamsChannel = new StreamsChannel(flutterPluginBinding.getBinaryMessenger(), EventName.ppg);
    ppgStreamsChannel.setStreamHandlerFactory(arguments -> {
      final String deviceId = arguments.toString();
      if (!ppgDisposables.containsKey(deviceId)) {
        ppgDisposables.put(deviceId, null);
      }
      return new PpgStreamHandler(ppgDisposables.get(deviceId), api);
    });
    searchEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.search);
    searchEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        if (searchDisposable != null) {
          searchDisposable.dispose();
          searchDisposable = null;
        }
        searchDisposable = api.searchForDevice().observeOn(AndroidSchedulers.mainThread())
                .subscribe(
                        deviceInfo -> {
                          JSONObject json = new JSONObject();
                          json.put("deviceId", deviceInfo.deviceId);
                          json.put("address", deviceInfo.address);
                          json.put("rssi", deviceInfo.rssi);
                          json.put("name", deviceInfo.name);
                          json.put("connectable", deviceInfo.isConnectable);
                          events.success(json.toString());
                        },
                        throwable -> {
                          Log.e(TAG, "" + throwable.getLocalizedMessage());
                          events.error(TAG, throwable.getLocalizedMessage(), null);
                        },
                        () -> {
                          Log.d(TAG, "Search complete");
                          events.endOfStream();
                        }
                );

      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.search+ " onCancel");
        if (searchDisposable != null) {
          searchDisposable.dispose();
          searchDisposable = null;
        }
      }
    });
//    hrBroadcastEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.hrBroadcast);
//    hrBroadcastEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
//      @Override
//      public void onListen(Object arguments, EventChannel.EventSink events) {
//        Log.d(TAG, EventName.hrBroadcast+ " onListen");
//        if (broadcastDisposable != null)  {
//          broadcastDisposable.dispose();
//          broadcastDisposable = null;
//        }
//        broadcastDisposable = api.startListenForPolarHrBroadcasts(null).subscribe(
//                polarBroadcastData -> {
//                  Log.d(TAG, "HR BROADCAST " +
//                          polarBroadcastData.polarDeviceInfo.deviceId + " HR: " +
//                          polarBroadcastData.hr + " batt: " +
//                          polarBroadcastData.batteryStatus);
//                  events.success(polarBroadcastData.hr);
//                } ,
//                throwable -> {
//                  Log.e(TAG, "" + throwable.getLocalizedMessage());
//                  events.error(TAG, throwable.getLocalizedMessage(), null);
//                },
//                () -> {
//                  Log.d(TAG, "HR broadcast complete");
//                  events.endOfStream();
//                }
//        );
//
//      }
//      @Override
//      public void onCancel(Object arguments) {
//        Log.d(TAG, EventName.hrBroadcast+ " onCancel");
//        if (broadcastDisposable != null)  {
//          broadcastDisposable.dispose();
//          broadcastDisposable = null;
//        }
//      }
//    });
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    Log.d(TAG, "api: " + api.toString());
    if (call.method.equals(MethodName.connect)){
      Log.d(TAG, MethodName.connect);
      String deviceId = call.argument("deviceId");
      try {
        api.connectToDevice(deviceId);
        connectResults.put(deviceId, result);
        //result.success(null);
      } catch (PolarInvalidArgument polarInvalidArgument) {
        polarInvalidArgument.printStackTrace();
        result.error("PolarInvalidArgument", polarInvalidArgument.getMessage(), null);
      } catch (Exception e){
        e.printStackTrace();
        result.error(MethodName.connect, e.getMessage(), e.getStackTrace());
      }
    }else if (call.method.equals(MethodName.disconnect)){
      Log.d(TAG, MethodName.disconnect);
      String deviceId = call.argument("deviceId");
      try {
        if(ecgDisposables.containsKey(deviceId) && ecgDisposables.get(deviceId) != null && !ecgDisposables.get(deviceId).isDisposed()) ecgDisposables.get(deviceId).dispose();
        if(ecgDisposables.containsKey(deviceId) && ecgDisposables.get(deviceId) != null && !ecgDisposables.get(deviceId).isDisposed()) ecgDisposables.get(deviceId).dispose();
        if(ppgDisposables.containsKey(deviceId) && ppgDisposables.get(deviceId) != null && !ppgDisposables.get(deviceId).isDisposed()) ppgDisposables.get(deviceId).dispose();
        api.disconnectFromDevice(deviceId);
        disconnectResults.put(deviceId, result);
        //result.success(null);
      } catch (PolarInvalidArgument polarInvalidArgument) {
        polarInvalidArgument.printStackTrace();
        result.error("PolarInvalidArgument", polarInvalidArgument.getMessage(), null);
      } catch (Exception e){
        e.printStackTrace();
        result.error(MethodName.disconnect, e.getMessage(), e.getStackTrace());
      }
    }
//    else if(call.method.equals(MethodName.autoconnect)){
//      Log.d(TAG, MethodName.autoconnect);
//      if (autoConnectDisposable != null) {
//        autoConnectDisposable.dispose();
//        autoConnectDisposable = null;
//      }
//      autoConnectDisposable = api.autoConnectToDevice(-50, "180D", null).subscribe(
//              () ->         result.success(null),
//              throwable -> Log.e(TAG, "" + throwable.toString())
//      );
//    }
    else {
      Log.d(TAG, "not implemented");
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  private void initialize(){
    Log.d(TAG, "context: " + context.toString());
    api = PolarBleApiDefaultImpl.defaultImplementation(context, PolarBleApi.ALL_FEATURES);
    api.setAutomaticReconnection(false);
    api.setPolarFilter(false);
    api.setApiLogger(s -> Log.d(API_LOGGER_TAG, s));
    Log.d(TAG, "version: " + PolarBleApiDefaultImpl.versionInfo());
    api.setApiCallback(new PolarBleApiCallback() {
      @Override
      public void blePowerStateChanged(boolean powered) {
        Log.d(TAG, "BLE power: " + powered);
      }

      @Override
      public void deviceConnected(@NonNull PolarDeviceInfo polarDeviceInfo) {
        Log.d(TAG, "CONNECTED: " + polarDeviceInfo.deviceId);
      }

      @Override
      public void deviceConnecting(@NonNull PolarDeviceInfo polarDeviceInfo) {
        Log.d(TAG, "CONNECTING: " + polarDeviceInfo.deviceId);
      }

      @Override
      public void deviceDisconnected(@NonNull PolarDeviceInfo polarDeviceInfo) {
        Log.d(TAG, "DISCONNECTED: " + polarDeviceInfo.deviceId);
        String deviceId = polarDeviceInfo.deviceId;
        ecgDisposables.remove(deviceId);
        accDisposables.remove(deviceId);
        ppgDisposables.remove(deviceId);
        if(disconnectResults.containsKey(deviceId)){
          disconnectResults.get(deviceId).success(null);
          disconnectResults.remove(deviceId);
        }
      }

      @Override
      public void ecgFeatureReady(@NonNull String identifier) {
        Log.d(TAG, "ECG READY: " + identifier);
        // ecg streaming can be started now if needed
      }

      @Override
      public void accelerometerFeatureReady(@NonNull String identifier) {
        Log.d(TAG, "ACC READY: " + identifier);
        // acc streaming can be started now if needed
        //accReadySubject.onNext(true);
      }

      @Override
      public void ppgFeatureReady(@NonNull String identifier) {
        Log.d(TAG, "PPG READY: " + identifier);
        // ohr ppg can be started
      }

      @Override
      public void ppiFeatureReady(@NonNull String identifier) {
        Log.d(TAG, "PPI READY: " + identifier);
        // ohr ppi can be started
      }

      @Override
      public void biozFeatureReady(@NonNull String identifier) {
        Log.d(TAG, "BIOZ READY: " + identifier);
        // ohr ppi can be started
      }

      @Override
      public void hrFeatureReady(@NonNull String identifier) {
        Log.d(TAG, "HR READY: " + identifier);
        // hr notifications are about to start
      }

      @Override
      public void disInformationReceived(@NonNull String identifier, @NonNull UUID uuid, @NonNull String value) {
        Log.d(TAG, "uuid: " + uuid + " value: " + value);

      }

      @Override
      public void batteryLevelReceived(@NonNull String identifier, int level) {
        Log.d(TAG, "BATTERY LEVEL: " + level);
        if(connectResults.containsKey(identifier)){
          connectResults.get(identifier).success(null);
          connectResults.remove(identifier);
        }
      }

      @Override
      public void hrNotificationReceived(@NonNull String identifier, @NonNull PolarHrData data) {
        //Log.d(TAG, "HR value: " + data.hr + " rrsMs: " + data.rrsMs + " rr: " + data.rrs + " contact: " + data.contactStatus + "," + data.contactStatusSupported);
        if(hrDataSubjects.containsKey(identifier)){
          hrDataSubjects.get(identifier).onNext(data);
        }
      }

      @Override
      public void polarFtpFeatureReady(@NonNull String s) {
        Log.d(TAG, "FTP ready");
      }
    });
  }
}
