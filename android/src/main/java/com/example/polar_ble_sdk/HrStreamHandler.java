package com.example.polar_ble_sdk;

import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;
import org.reactivestreams.Publisher;

import java.sql.Timestamp;

import io.flutter.plugin.common.EventChannel;
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.functions.Function;
import io.reactivex.rxjava3.subjects.BehaviorSubject;
import io.reactivex.rxjava3.subjects.PublishSubject;
import polar.com.sdk.api.model.PolarAccelerometerData;
import polar.com.sdk.api.model.PolarHrData;
import polar.com.sdk.api.model.PolarSensorSetting;

public class HrStreamHandler implements EventChannel.StreamHandler {
    private static final String TAG = HrStreamHandler.class.getSimpleName();

    private PublishSubject<PolarHrData> hrDataSubject;
    private Disposable hrDisposable;

    public HrStreamHandler(PublishSubject<PolarHrData> hrDataSubject) {
        this.hrDataSubject = hrDataSubject;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        if (hrDisposable != null)   {
        hrDisposable.dispose();
        hrDisposable = null;
    }
            hrDisposable = hrDataSubject
                    .observeOn(AndroidSchedulers.mainThread())
                    .subscribe(
                            polarHrData -> {
                                    JSONObject json = new JSONObject();
                                    json.put("hr", polarHrData.hr);
                                    json.put("rrs", new JSONArray(polarHrData.rrsMs));
                                    json.put("timestamp", new Timestamp(System.currentTimeMillis()).getTime());
                                    events.success(json.toString());
                            },
                            throwable -> {
                                Log.e(TAG, "" + throwable.getLocalizedMessage());
                                events.error(TAG, throwable.getLocalizedMessage(), null);
                            },
                            () -> {
                                Log.d(TAG, "complete");
                                events.endOfStream();
                            }                  );

    }
    @Override
    public void onCancel(Object arguments) {
        if (hrDisposable != null)   {
            hrDisposable.dispose();
            hrDisposable = null;
        }
    }
}
