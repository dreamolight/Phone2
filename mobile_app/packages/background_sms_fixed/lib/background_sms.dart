import 'dart:async';
import 'package:flutter/services.dart';

enum SmsStatus { sent, failed }

class BackgroundSms {
  static const MethodChannel _channel = const MethodChannel('background_sms');

  static Future<SmsStatus> sendMessage({required String phoneNumber, required String message, int? simSlot}) async {
    try {
      final String result = await _channel.invokeMethod('sendSms', <String, dynamic>{
        'phone': phoneNumber,
        'msg': message,
        'simSlot': simSlot,
      });
      return result == "Sent" ? SmsStatus.sent : SmsStatus.failed;
    } catch (e) {
      print(e);
      return SmsStatus.failed;
    }
  }

  static Future<bool> get isSupportCustomSim async {
    try {
      final bool result = await _channel.invokeMethod('isSupportCustomSim');
      return result;
    } catch (e) {
      return false;
    }
  }
}
