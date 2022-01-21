import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'call.dart';
import 'models/contact.dart';

late String userId;
final addressBookRef = FirebaseFirestore.instance
    .collection('addressBook')
    .withConverter<Contact>(
        fromFirestore: (snapshots, _) => Contact.fromJson(snapshots.data()!),
        toFirestore: (contact, _) => contact.toJson());

Future<bool?> beginMakeCall(BuildContext context, String number,
    {bool isNumber = false}) async {
  if (!await (TwilioVoice.instance.hasMicAccess())) {
    print("request mic access");
    TwilioVoice.instance.requestMicAccess();
    return false;
  }
  if(isNumber){
    TwilioVoice.instance.call.place(to: number, from: userId);
    pushToCallScreen(context);
    return true;
  }

  addressBookRef.where('displayName', isEqualTo: number).get().then((value) {
    if (value.docs.isNotEmpty) {
      var contact = value.docs[0];
      print("starting call to $value");
      var num = contact.data().uid;
      if(num == userId){
        displayAlert(context, "Self Call", "You cannot call yourself");
        return false;
      }
      TwilioVoice.instance.call.place(to: num, from: userId);
      pushToCallScreen(context);
      return true;
    } else {
      print("no user with name: $number exists");
      return false;
    }
  });
}

void pushToCallScreen(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true, builder: (context) => CallProgressPage()));
}

void displayAlert(BuildContext context, String subject, String body) {
  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: Text(subject),
    content: Text(body),
    actions: [
      TextButton(
        child: const Text("OK"),
        onPressed: () {
          Navigator.of(context).pop(true);
        },
      ),
    ],
  );

  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
