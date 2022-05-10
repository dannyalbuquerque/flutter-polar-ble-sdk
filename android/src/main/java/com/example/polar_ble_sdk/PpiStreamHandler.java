package com.example.polar_ble_sdk;

import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.sql.Timestamp;
import java.util.ArrayList;

import io.flutter.plugin.common.EventChannel;
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.Disposable;
import polar.com.sdk.api.PolarBleApi;
import polar.com.sdk.api.model.PolarOhrPPIData;


public class PpiStreamHandler implements EventChannel.StreamHandler {
    private static final String TAG = PpiStreamHandler.class.getSimpleName();

    private Disposable ppiDisposable;
    private PolarBleApi api;

    public PpiStreamHandler(Disposable ppiDisposable, PolarBleApi api) {
        this.ppiDisposable = ppiDisposable;
        this.api = api;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        if (ppiDisposable != null) {
            ppiDisposable.dispose();
        }
        String deviceId = arguments.toString();
        ppiDisposable = api.startOhrPPIStreaming(deviceId)
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(
                        polarOhrPPIData -> {
                            if(!polarOhrPPIData.samples.isEmpty()){
                                JSONObject json = new JSONObject();
                                json.put("hr", polarOhrPPIData.samples.get(polarOhrPPIData.samples.size() - 1).hr);
                                ArrayList<Integer> rrs = new ArrayList<Integer>();
                                for (PolarOhrPPIData.PolarOhrPPISample sample : polarOhrPPIData.samples)
                                {
                                    rrs.add(sample.ppi);
                                }
                                json.put("rrs", new JSONArray(rrs));
                                json.put("timestamp", new Timestamp(System.currentTimeMillis()).getTime());
                                events.success(json.toString());
                            }

                        },
                        throwable -> {
                            Log.e(TAG, "" + throwable.getLocalizedMessage());
                            events.error(TAG, throwable.getLocalizedMessage(), null);
                        },
                        () -> {
                            Log.d(TAG, "PPG complete");
                            events.endOfStream();
                        });

    }

    @Override
    public void onCancel(Object arguments) {
        Log.d(TAG, EventName.ppi + " onCancel");
        if (ppiDisposable != null) {
            ppiDisposable.dispose();
        }
    }
}
