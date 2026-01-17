package com.j.background_sms;

import android.content.Context;
import android.telephony.SmsManager;
import android.telephony.SmsMessage;
import android.app.PendingIntent;
import android.content.Intent;
import java.util.UUID;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class BackgroundSmsPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "background_sms");
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("sendSms")) {
            String phoneNumber = call.argument("phone");
            String message = call.argument("msg");
            int simSlot = call.hasArgument("simSlot") ? (int) call.argument("simSlot") : -1;
            sendSMS(phoneNumber, message, simSlot, result);
        } else if (call.method.equals("isSupportCustomSim")) {
             result.success(true);
        } else {
            result.notImplemented();
        }
    }

    private void sendSMS(String phoneNumber, String message, int simSlot, Result result) {
        try {
            SmsManager smsManager = SmsManager.getDefault();
            // TODO: Add multi-sim support if needed, simplification for now
            
            smsManager.sendTextMessage(phoneNumber, null, message, null, null);
            result.success("Sent");
        } catch (Exception e) {
            result.error("Failed", "Sms Send Failed", e.getMessage());
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
