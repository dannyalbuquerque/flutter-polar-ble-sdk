package com.example.polar_ble_sdk;

import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;
import org.reactivestreams.Publisher;

import io.flutter.plugin.common.EventChannel;
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.functions.Function;
import polar.com.sdk.api.PolarBleApi;
import polar.com.sdk.api.model.PolarEcgData;
import polar.com.sdk.api.model.PolarSensorSetting;

public class EcgStreamHandler implements EventChannel.StreamHandler {
    private static final String TAG = EcgStreamHandler.class.getSimpleName();


    private Disposable ecgDisposable;
    private PolarBleApi api;

    public EcgStreamHandler(Disposable ecgDisposable, PolarBleApi api) {
        this.ecgDisposable = ecgDisposable;
        this.api = api;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        if (ecgDisposable != null) {
            ecgDisposable.dispose();
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
                                //Log.d(TAG, "    yV: " + microVolts);
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
        }
    }
}
