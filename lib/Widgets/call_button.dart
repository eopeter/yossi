import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../global.dart';

class CallButton extends StatefulWidget {
  final Map<String, dynamic> data;
  const CallButton(this.data, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CallButtonState();
}

class _CallButtonState extends State<CallButton> {

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('callRequest')
            .where(FieldPath.documentId, isEqualTo: currentCallingId)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ElevatedButton(
              onPressed: () async {
                await createCallRequest(context, widget.data['uid'],
                    widget.data['displayName'], callerDisplayName, (id, error) {
                  if (error == null) {
                    currentCallingId = id!;
                  } else {
                    currentCallingId = "-1";
                    displayAlert(context, "Dial Failed",
                        "An error occurred while creating the dial request");
                  }
                  print("the current call id is: $currentCallingId");
                  if(mounted){
                    Future.delayed(
                        const Duration(seconds: 3),
                            () => setState(() {
                        }));
                  }
                });
              },
              child: const Text("Dial Request"),
            );
          }
          var call = snapshot.data!.docs.first.data()! as Map<String, dynamic>;
          var callStatus = call["status"] as String;
          if (callStatus == "completed" || callStatus == "no-answer" || callStatus == "busy") {
            currentCallingId = "-1";
            if(mounted){
              Future.delayed(
                  const Duration(seconds: 3),
                      () => setState(() {
                  }));
            }
          }
          return ElevatedButton(onPressed: null, child: Text(callStatus.replaceFirst(callStatus[0], callStatus[0].toUpperCase())));
        });
  }
}
