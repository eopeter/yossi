import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseConfig {
  static FirebaseOptions get platformOptions {
    if (kIsWeb) {
      // Web
      return FirebaseOptions(
        appId: dotenv.get('FIREBASE_APPID_WEB'),
        apiKey: dotenv.get('FIREBASE_API_KEY'),
        projectId: dotenv.get('FIREBASE_PROJECTID'),
        messagingSenderId: dotenv.get('FIREBASE_MESSAGE_SENDERID'),
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      // iOS and MacOS
      return FirebaseOptions(
        appId: dotenv.get('FIREBASE_APPID_IOS'),
        apiKey: dotenv.get('FIREBASE_API_KEY'),
        projectId: dotenv.get('FIREBASE_PROJECTID'),
        messagingSenderId: dotenv.get('FIREBASE_MESSAGE_SENDERID'),
        iosBundleId: 'com.yossi.voip',
      );
    } else {
      // Android
      return FirebaseOptions(
        appId: dotenv.get('FIREBASE_APPID_ANDROID'),
        apiKey: dotenv.get('FIREBASE_API_KEY'),
        projectId: dotenv.get('FIREBASE_PROJECTID'),
        messagingSenderId: dotenv.get('FIREBASE_MESSAGE_SENDERID'),
      );
    }
  }
}