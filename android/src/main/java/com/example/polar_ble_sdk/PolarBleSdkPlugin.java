package com.example.polar_ble_sdk;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONObject;
import org.reactivestreams.Publisher;

import java.sql.Timestamp;
import java.util.Observable;
import java.util.UUID;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.core.Flowable;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.functions.Function;
import io.reactivex.rxjava3.subjects.BehaviorSubject;
import io.reactivex.rxjava3.subjects.Subject;
import polar.com.sdk.api.PolarBleApi;
import polar.com.sdk.api.PolarBleApiCallback;
import polar.com.sdk.api.PolarBleApiDefaultImpl;
import polar.com.sdk.api.errors.PolarInvalidArgument;
import polar.com.sdk.api.model.PolarAccelerometerData;
import polar.com.sdk.api.model.PolarDeviceInfo;
import polar.com.sdk.api.model.PolarEcgData;
import polar.com.sdk.api.model.PolarExerciseEntry;
import polar.com.sdk.api.model.PolarHrData;
import polar.com.sdk.api.model.PolarOhrPPGData;
import polar.com.sdk.api.model.PolarOhrPPIData;
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
  private BehaviorSubject<PolarHrData> hrDataSubject = BehaviorSubject.create();

  private Context context;
  private PolarBleApi api;
  Disposable broadcastDisposable;
  Disposable autoConnectDisposable;
  Disposable accDisposable;
  Disposable ecgDisposable;

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
        if (broadcastDisposable == null) {
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
                    Log.d(TAG, "complete");
                    events.endOfStream();
                  }
          );
        } else {
          broadcastDisposable.dispose();
          broadcastDisposable = null;
          Log.d(TAG, "broadcast disposed");
        }
      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.hrBroadcast+ " onCancel");
        broadcastDisposable.dispose();
        broadcastDisposable = null;
        Log.d(TAG, "broadcast disposed");
      }
    });
    accEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.acc);
    accEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        if (accDisposable == null) {
          String deviceId = arguments.toString();
          accDisposable = api.requestAccSettings(deviceId)
                  .toFlowable()
                  .flatMap((Function<PolarSensorSetting, Publisher<PolarAccelerometerData>>) settings -> {
                    PolarSensorSetting sensorSetting = settings.maxSettings();
                    return api.startAccStreaming(deviceId, sensorSetting);
                  }).observeOn(AndroidSchedulers.mainThread())
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
                            Log.d(TAG, "complete");
                            events.endOfStream();
                          }                  );
        } else {
          // NOTE dispose will stop streaming if it is "running"
          accDisposable.dispose();
          accDisposable = null;
        }
      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.acc+ " onCancel");
        accDisposable.dispose();
        accDisposable = null;
      }
    });
    hrEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.hr);
    hrEventChannel.setStreamHandler(new HrStreamHandler(hrDataSubject));
    ecgEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EventName.ecg);
    ecgEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        if (ecgDisposable == null) {
          String deviceId = arguments.toString();
          ecgDisposable = api.requestEcgSettings(deviceId)
                  .toFlowable()
                  .flatMap((Function<PolarSensorSetting, Publisher<PolarEcgData>>) polarEcgSettings -> {
                    PolarSensorSetting sensorSetting = polarEcgSettings.maxSettings();
                    return api.startEcgStreaming(deviceId, sensorSetting);
                  }).subscribe(
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
                            Log.d(TAG, "complete");
                            events.endOfStream();
                          }
                  );
        } else {
          // NOTE stops streaming if it is "running"
          ecgDisposable.dispose();
          ecgDisposable = null;
        }
      }
      @Override
      public void onCancel(Object arguments) {
        Log.d(TAG, EventName.ecg+ " onCancel");
        ecgDisposable.dispose();
        ecgDisposable = null;
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
        result.success(null);
      } catch (PolarInvalidArgument polarInvalidArgument) {
        polarInvalidArgument.printStackTrace();
        result.error("PolarInvalidArgument", polarInvalidArgument.getMessage(), null);
      }
    }else if (call.method.equals(MethodName.disconnect)){
      Log.d(TAG, MethodName.disconnect);
      String deviceId = call.argument("deviceId");
      try {
        api.disconnectFromDevice(deviceId);
        result.success(null);
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
        ecgDisposable = null;
        accDisposable = null;
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
        Log.d(TAG, "HR value: " + data.hr + " rrsMs: " + data.rrsMs + " rr: " + data.rrs + " contact: " + data.contactStatus + "," + data.contactStatusSupported);
        hrDataSubject.onNext(data);
      }

      @Override
      public void polarFtpFeatureReady(@NonNull String s) {
        Log.d(TAG, "FTP ready");
      }
    });
  }
}
