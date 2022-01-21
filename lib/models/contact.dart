import 'package:flutter/material.dart';

@immutable
class Contact {
  const Contact({
    required this.uid,
    required this.displayName
  });

  Contact.fromJson(Map<String, Object?> json)
      : this(
    displayName: json['displayName']! as String,
    uid: json['uid']! as String,
  );

  final String uid;
  final String displayName;

  Map<String, Object?> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
    };
  }
}