import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dialpad/flutter_dialpad.dart';
import 'package:twilio_voice/twilio_voice.dart';

import 'global.dart';

class DialerPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => DialerPageState();
}

class DialerPageState extends State<DialerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        const SizedBox(height: 150,),
        DialPad(
            enableDtmf: true,
            outputMask: "(000) 000-0000",
            backspaceButtonIconColor: Colors.red,
            buttonColor: Colors.grey,
            makeCall: (number) {
              beginMakeCall(context, number, isNumber: true);
            })
      ],),
    );
  }
}
