import 'package:flutter/material.dart';

@immutable
class CallRequest {
  const CallRequest({
    required this.to,
    required this.displayName,
    required this.status,
    required this.from,
    required this.timeStamp,
    required this.fromName,
  });

  CallRequest.fromJson(Map<String, Object?> json)
      : this(
    displayName: json['displayName']! as String,
    to: json['to']! as String,
    from: json['from']! as String,
    fromName: json['fromName']! as String,
    status: json['status']! as String,
    timeStamp: json['timeStamp']! as DateTime,
  );

  final String to;
  final String displayName;
  final String status;
  final String from;
  final DateTime timeStamp;
  final String fromName;

  Map<String, Object?> toJson() {
    return {
      'to': to,
      'from': from,
      'fromName': fromName,
      'displayName': displayName,
      'status': status,
      'timeStamp': timeStamp,
    };
  }
}