package com.example.polar_ble_sdk;

import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;
import org.reactivestreams.Publisher;

import java.util.ArrayList;
import java.util.List;

import io.flutter.plugin.common.EventChannel;
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.functions.Function;
import polar.com.sdk.api.PolarBleApi;
import polar.com.sdk.api.model.PolarOhrPPGData;
import polar.com.sdk.api.model.PolarSensorSetting;

public class PpgStreamHandler implements EventChannel.StreamHandler {
    private static final String TAG = PpgStreamHandler.class.getSimpleName();

    private Disposable ppgDisposable;
    private PolarBleApi api;

    public PpgStreamHandler(Disposable ppgDisposable, PolarBleApi api) {
        this.ppgDisposable = ppgDisposable;
        this.api = api;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        if (ppgDisposable != null) {
            ppgDisposable.dispose();
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
        }
    }
}
