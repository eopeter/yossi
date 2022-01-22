import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:yossi/Widgets/call_button.dart';

import '../global.dart';

class ContactList extends StatelessWidget {

  StreamBuilder? callProgress;
  final String callerDisplayName;
  final Stream<QuerySnapshot> _contactStream = FirebaseFirestore.instance
      .collection('addressBook')
      .orderBy('displayName')
      //.where('displayName', isNotEqualTo: 'Moderator')
      .snapshots();

  ContactList(this.callerDisplayName, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _contactStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading");
        }
        if (!snapshot.hasData) {
          return noDataWidget(context);
        }
        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Map<String, dynamic> data =
                document.data()! as Map<String, dynamic>;
            var displayName = data['displayName'] as String;
            TwilioVoice.instance.registerClient(data['uid'], displayName);
            return Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(displayName.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(data['displayName']),
                  trailing: CallButton(data),
                ),
                const Divider()
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget noDataWidget(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.star,
              size: 40,
              color: Colors.grey.withOpacity(0.2),
            ),
            Icon(
              Icons.people,
              size: 120,
              color: Colors.grey.withOpacity(0.5),
            ),
            Icon(
              Icons.access_time,
              size: 40,
              color: Colors.grey.withOpacity(0.2),
            )
          ],
        ),
        Text(
          'List of Users You Can Call. \nClick the button below to dial a number \nor enter a name above to dial by name',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .subtitle1
              ?.copyWith(color: Colors.grey.withOpacity(0.5)),
        )
      ],
    );
  }
}
