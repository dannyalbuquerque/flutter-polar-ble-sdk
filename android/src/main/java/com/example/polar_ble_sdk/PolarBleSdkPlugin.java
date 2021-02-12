package com.example.polar_ble_sdk;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONObject;
import org.reactivestreams.Publisher;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.core.BackpressureStrategy;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.functions.Function;
import io.reactivex.rxjava3.subjects.BehaviorSubject;
import polar.com.sdk.api.PolarBleApi;
import polar.com.sdk.api.PolarBleApiCallback;
import polar.com.sdk.api.PolarBleApiDefaultImpl;
import polar.com.sdk.api.errors.PolarInvalidArgument;
import polar.com.sdk.api.model.PolarAccelerometerData;
import polar.com.sdk.api.model.PolarDeviceInfo;
import polar.com.sdk.api.model.PolarEcgData;
import polar.com.sdk.api.model.PolarHrData;
import polar.com.sdk.api.model.PolarOhrPPGData;
import polar.com.sdk.api.model.PolarSensorSetting;

/** PolarBleSdkPlugin */
public class PolarBleSdkPlugin implements FlutterPlugin, MethodCallHandler {
  private static final String TAG = PolarBleSdkPlugin.class.getSimpleName();
  private static final String API_LOGGER_TAG = "API LOGGER";
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private EventChannel hrBroadcastEventChannel;
  private EventChannel accEventChannel;
  private EventChannel hrEventChannel;
  private EventChannel ecgEventChannel;
  private EventChannel ppgEventChannel;
  private EventChannel searchEventChannel;
  private BehaviorSubject<PolarHrData> hrDataSubject = BehaviorSubject.create();

  private Context context;
  private PolarBleApi api;
  Disposable broadcastDisposable;
  Disposable autoConnectDisposable;
  Disposable accDisposable;
  Disposable ecgDisposable;
  Disposable ppgDisposable;
  Disposable searchDisposable;

  private Result connectResult;
  private Result disconnectResult;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "polar_ble_sdk");
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();
    initialize();
    hrBroadcastEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.hrBroadcast);
    hrBroadcastEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        Log.d(TAG, EventName.hrBroadcast+ " onListen");
        if (broadcastDisposable != null)  {
        broadcastDisposable.dispose();
        broadcastDisposable = null;
      }
          broadcastDisposable = api.startListenForPolarHrBroadcasts(null).subscribe(
                  polarBroadcastData -> {
                    Log.d(TAG, "HR BROADCAST " +
                            polarBroadcastData.polarDeviceInfo.deviceId + " HR: " +
                            polarBroadcastData.hr + " batt: " +
                            polarBroadcastData.batteryStatus);
                    events.success(polarBroadcastData.hr);
                  } ,
                  throwable -> {
                    Log.e(TAG, "" + throwable.getLocalizedMessage());
                    events.error(TAG, throwable.getLocalizedMessage(), null);
                  },
                  () -> {
                    Log.d(TAG, "HR broadcast complete");
                    events.endOfStream();
                  }
          );

      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.hrBroadcast+ " onCancel");
        if (broadcastDisposable != null)  {
          broadcastDisposable.dispose();
          broadcastDisposable = null;
        }
      }
    });
    accEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.acc);
    accEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        if (accDisposable != null) {
            // NOTE dispose will stop streaming if it is "running"
            accDisposable.dispose();
            accDisposable = null;
          }
          String deviceId = arguments.toString();
        Map<PolarSensorSetting.SettingType, Integer> settings = new HashMap();
        settings.put(PolarSensorSetting.SettingType.RANGE, 2);
        settings.put(PolarSensorSetting.SettingType.SAMPLE_RATE, 25);
        settings.put(PolarSensorSetting.SettingType.RESOLUTION, 16);
        PolarSensorSetting customSettings = new PolarSensorSetting(settings);
        accDisposable = api.startAccStreaming(deviceId, customSettings).observeOn(AndroidSchedulers.mainThread())
                .subscribe(
                        polarAccelerometerData -> {
                          for (PolarAccelerometerData.PolarAccelerometerSample data : polarAccelerometerData.samples) {
                            Log.d(TAG, "    x: " + data.x + " y: " + data.y + " z: " + data.z);
                            JSONObject json = new JSONObject();
                            json.put("x", data.x);
                            json.put("y", data.y);
                            json.put("z", data.z);
                            json.put("timestamp", polarAccelerometerData.timeStamp);
                            events.success(json.toString());
                          }
                        },
                        throwable -> {
                          Log.e(TAG, "" + throwable.getLocalizedMessage());
                          events.error(TAG, throwable.getLocalizedMessage(), null);
                        },
                        () -> {
                          Log.d(TAG, "ACC complete");
                          events.endOfStream();
                        }                  );
        api.startAccStreaming(deviceId, customSettings);

      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.acc+ " onCancel");
        if (accDisposable != null) {
          accDisposable.dispose();
          accDisposable = null;
        }
      }
    });
    hrEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.hr);
    hrEventChannel.setStreamHandler(new HrStreamHandler(hrDataSubject));
    ecgEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.ecg);
    ecgEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        if (ecgDisposable != null) {
          ecgDisposable.dispose();
          ecgDisposable = null;
        }
          String deviceId = arguments.toString();
          ecgDisposable = api.requestEcgSettings(deviceId)
                  .toFlowable()
                  .flatMap((Function<PolarSensorSetting, Publisher<PolarEcgData>>) polarEcgSettings -> {
                    PolarSensorSetting sensorSetting = polarEcgSettings.maxSettings();
                    Log.d(TAG, "ECG settings: " + polarEcgSettings.toString());
                    return api.startEcgStreaming(deviceId, sensorSetting);
                  }).observeOn(AndroidSchedulers.mainThread())
                  .subscribe(
                          polarEcgData -> {
                            for (Integer microVolts : polarEcgData.samples) {
                              Log.d(TAG, "    yV: " + microVolts);
                            }
                            JSONObject json = new JSONObject();
                            json.put("samples", new JSONArray(polarEcgData.samples));
                            json.put("timestamp", polarEcgData.timeStamp);
                            events.success(json.toString());
                          },
                          throwable -> {
                            Log.e(TAG, "" + throwable.getLocalizedMessage());
                            events.error(TAG, throwable.getLocalizedMessage(), null);
                          },
                          () -> {
                            Log.d(TAG, "ECG complete");
                            events.endOfStream();
                          }
                  );

      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.ecg+ " onCancel");
        if (ecgDisposable != null) {
          ecgDisposable.dispose();
          ecgDisposable = null;
        }
      }
    });
    ppgEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.ppg);
    ppgEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        if (ppgDisposable != null) {
          ppgDisposable.dispose();
          ppgDisposable = null;
        }
        String deviceId = arguments.toString();
        ppgDisposable = api.requestPpgSettings(deviceId)
                .toFlowable()
                .flatMap((Function<PolarSensorSetting, Publisher<PolarOhrPPGData>>) polarPpgSettings -> {
                  PolarSensorSetting sensorSetting = polarPpgSettings.maxSettings();
                  Log.d(TAG, "PPG settings: " + polarPpgSettings.toString());
                  return api.startOhrPPGStreaming(deviceId, sensorSetting);
                }).observeOn(AndroidSchedulers.mainThread())
                .subscribe(
                        polarOhrPPGData -> {
                          List<Integer> samples = new ArrayList<Integer>();
                          for (PolarOhrPPGData.PolarOhrPPGSample data : polarOhrPPGData.samples) {
                            Log.d(TAG, "    ppg0: " + data.ppg0 + " ppg1: " + data.ppg1 + " ppg2: " + data.ppg2 + "ambient: " + data.ambient);
                            samples.addAll(data.ppgDataSamples);
                            samples.add(data.ambient);
                          }
                          JSONObject json = new JSONObject();
                          json.put("samples", new JSONArray(samples));
                          json.put("timestamp", polarOhrPPGData.timeStamp);
                          events.success(json.toString());
                        },
                        throwable -> {
                          Log.e(TAG, "" + throwable.getLocalizedMessage());
                          events.error(TAG, throwable.getLocalizedMessage(), null);
                        },
                        () -> {
                          Log.d(TAG, "PPG complete");
                          events.endOfStream();
                        }
                );

      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.ppg+ " onCancel");
        if (ppgDisposable != null) {
          ppgDisposable.dispose();
          ppgDisposable = null;
        }
      }
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
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    Log.d(TAG, "api: " + api.toString());
    if (call.method.equals(MethodName.connect)){
      Log.d(TAG, MethodName.connect);
      String deviceId = call.argument("deviceId");
      try {
        api.connectToDevice(deviceId);
        connectResult = result;
        //result.success(null);
      } catch (PolarInvalidArgument polarInvalidArgument) {
        polarInvalidArgument.printStackTrace();
        result.error("PolarInvalidArgument", polarInvalidArgument.getMessage(), null);
      }
    }else if (call.method.equals(MethodName.disconnect)){
      Log.d(TAG, MethodName.disconnect);
      String deviceId = call.argument("deviceId");
      try {

        if(accDisposable != null && !accDisposable.isDisposed()) accDisposable.dispose();
        if(ecgDisposable != null && !ecgDisposable.isDisposed()) ecgDisposable.dispose();
        if(ppgDisposable != null && !ppgDisposable.isDisposed()) ppgDisposable.dispose();
        api.disconnectFromDevice(deviceId);
        disconnectResult = result;
        //result.success(null);
      } catch (PolarInvalidArgument polarInvalidArgument) {
        polarInvalidArgument.printStackTrace();
        result.error("PolarInvalidArgument", polarInvalidArgument.getMessage(), null);
      }
    }else if(call.method.equals(MethodName.autoconnect)){
      Log.d(TAG, MethodName.autoconnect);
      if (autoConnectDisposable != null) {
        autoConnectDisposable.dispose();
        autoConnectDisposable = null;
      }
      autoConnectDisposable = api.autoConnectToDevice(-50, "180D", null).subscribe(
              () ->         result.success(null),
              throwable -> Log.e(TAG, "" + throwable.toString())
      );
    }
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
        if(disconnectResult != null){
          disconnectResult.success(null);
          disconnectResult = null;
        }
      }

      @Override
      public void deviceDisconnected(@NonNull PolarDeviceInfo polarDeviceInfo) {
        Log.d(TAG, "DISCONNECTED: " + polarDeviceInfo.deviceId);
        ecgDisposable = null;
        accDisposable = null;
        ppgDisposable = null;
        //ppgDisposable = null;
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
        //if(connectResult != null){
        //  connectResult.success(null);
        //  connectResult = null;
        //}
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
      }

      @Override
      public void hrNotificationReceived(@NonNull String identifier, @NonNull PolarHrData data) {
        //Log.d(TAG, "HR value: " + data.hr + " rrsMs: " + data.rrsMs + " rr: " + data.rrs + " contact: " + data.contactStatus + "," + data.contactStatusSupported);
        hrDataSubject.onNext(data);
      }

      @Override
      public void polarFtpFeatureReady(@NonNull String s) {
        Log.d(TAG, "FTP ready");
      }
    });
  }
}
