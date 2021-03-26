package com.example.polar_ble_sdk;

import android.util.Log;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.Disposable;
import polar.com.sdk.api.PolarBleApi;
import polar.com.sdk.api.model.PolarAccelerometerData;
import polar.com.sdk.api.model.PolarSensorSetting;

public class AccStreamHandler implements EventChannel.StreamHandler {
    private static final String TAG = AccStreamHandler.class.getSimpleName();

    private Disposable accDisposable;
    private PolarBleApi api;

    public AccStreamHandler(Disposable accDisposable, PolarBleApi api) {
        this.accDisposable = accDisposable;
        this.api = api;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        if (accDisposable != null) {
            // NOTE dispose will stop streaming if it is "running"
            accDisposable.dispose();
        }
        Map args = (Map) arguments;
        String deviceId = (String) args.get("deviceId");
        int sampleRate = (int) args.get("sampleRate");
        Log.d(TAG, "Params received on iOS = "+deviceId+", "+sampleRate);
        Map<PolarSensorSetting.SettingType, Integer> settings = new HashMap();
        settings.put(PolarSensorSetting.SettingType.RANGE, 2);
        settings.put(PolarSensorSetting.SettingType.SAMPLE_RATE, sampleRate);
        settings.put(PolarSensorSetting.SettingType.RESOLUTION, 16);
        PolarSensorSetting customSettings = new PolarSensorSetting(settings);
        accDisposable = api.startAccStreaming(deviceId, customSettings).observeOn(AndroidSchedulers.mainThread())
                .subscribe(
                        polarAccelerometerData -> {
                            for (PolarAccelerometerData.PolarAccelerometerSample data : polarAccelerometerData.samples) {
                                //Log.d(TAG, "    x: " + data.x + " y: " + data.y + " z: " + data.z);
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
        }
    }
}
