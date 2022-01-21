import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:yossi/models/contact.dart';
import 'dialer.dart';
import 'firebase_config.dart';
import 'global.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseConfig.platformOptions,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Yossi VOIP Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  var registered = false;
  var hasPushedToCall = false;
  AppLifecycleState? state;
  final _controller = TextEditingController();
  late TextEditingController _callerNameController;
  var _isTyping = false;
  Timer? _timer;
  final Stream<QuerySnapshot> _contactStream =
      FirebaseFirestore.instance.collection('addressBook').snapshots();

  @override
  void initState() {
    super.initState();
    _callerNameController = TextEditingController();
    waitForLogin();
    super.initState();
    waitForCall();
    WidgetsBinding.instance!.addObserver(this);
    _controller.addListener(() {
      cancelTimer();
      startTimer();
      setState(() {
        _isTyping = _controller.text != "";
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _callerNameController.dispose();
    _controller.dispose();
    cancelTimer();
    super.dispose();
  }

  void startTimer() {
    print("timer started");
    _timer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _isTyping = false;
      });
    });
  }

  void cancelTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
    print("didChangeAppLifecycleState");
    if (state == AppLifecycleState.resumed) {
      checkActiveCall();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add))],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(5),
              child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Enter a name here to call another user',
                      prefixIcon: const Icon(
                        Icons.person,
                        size: 28.0,
                      ),
                      suffixIcon: _isTyping
                          ? IconButton(
                              onPressed: _controller.clear,
                              icon: const Icon(Icons.clear),
                            )
                          : IconButton(
                              onPressed: () {
                                beginMakeCall(context, _controller.text);
                              },
                              icon: const Icon(Icons.phone)))),
            ),
            Expanded(
              child: Stack(
                children: [
                  StreamBuilder(
                    stream: _contactStream,
                    builder: (BuildContext context,
                        AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Something went wrong');
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text("Loading");
                      }
                      if (!snapshot.hasData) {
                        return noDataWidget();
                      }
                      return ListView(
                        children: snapshot.data!.docs
                            .map((DocumentSnapshot document) {
                          Map<String, dynamic> data =
                              document.data()! as Map<String, dynamic>;
                          var displayName = data['displayName'] as String;
                          return Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(displayName.substring(0, 1)),
                                ),
                                title: Text(data['displayName']),
                                onTap: () {
                                  beginMakeCall(context, data['displayName']);
                                },
                              ),
                              const Divider()
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                  Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return DialerPage();
                                },
                                fullscreenDialog: true,
                              ));
                        },
                        tooltip: 'Dial Number',
                        child: const Icon(Icons.dialpad),
                      ))
                ],
              ),
            ),
            Container(
              color: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Text(
                      "Other Users Can Call You Using the Name Below",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    TextField(
                      controller: _callerNameController,
                      decoration: InputDecoration(
                          labelText: "My Incoming Dial Name",
                          border: const OutlineInputBorder(),
                          suffix: ElevatedButton(
                              onPressed: () {
                                saveNameToDb();
                              },
                              child: const Text("Change"))),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  registerUser() {
    print("voip- service init");
    // if (TwilioVoice.instance.deviceToken != null) {
    //   print("device token changed");
    // }

    register();

    TwilioVoice.instance.setOnDeviceTokenChanged((token) {
      print("voip-device token changed");
      register();
    });
  }

  register() async {
    if (kDebugMode) {
      print("voip registering with token ");
      print("voip calling accessToken");
    }
    final function = FirebaseFunctions.instance.httpsCallable("accessToken");

    final data = {
      "platform": Platform.isIOS ? "iOS" : "Android",
    };

    final result = await function.call(data);
    if (kDebugMode) {
      print("voip-result");
      print(result.data);
    }
    String? androidToken;
    if (Platform.isAndroid) {
      androidToken = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) {
        print("androidToken is " + androidToken!);
      }
    }
    var token = result.data["jwt_token"];
    TwilioVoice.instance
        .setTokens(accessToken: token, deviceToken: androidToken);
  }

  waitForLogin() {
    final auth = FirebaseAuth.instance;
    auth.authStateChanges().listen((user) async {
      // print("authStateChanges $user");
      if (user == null) {
        print("user is anonymous");
        await auth.signInAnonymously();
      } else if (!registered) {
        registered = true;
        userId = user.uid;
        print("registering user ${user.uid}");
        registerUser();
        addressBookRef.where('uid', isEqualTo: userId).get().then((value) {
          if (value.docs.isNotEmpty) {
            _callerNameController.text = value.docs[0].data().displayName;
          } else {
            var str = getRandomString(5);
            _callerNameController.text = str;
            addressBookRef
                .where('displayName', isEqualTo: str)
                .get()
                .then((exist) {
              if (exist.docs.isEmpty) {
                addressBookRef
                    .doc()
                    .set(Contact(uid: userId, displayName: str));
              } else {
                displayAlert(context, "Name Taken",
                    "The name $str is already taken. Please enter a different name");
              }
            });
          }
          TwilioVoice.instance
              .registerClient(userId, _callerNameController.text);
        });
        FirebaseMessaging.instance.requestPermission();
        // FirebaseMessaging.instance.configure(
        //     onMessage: (Map<String, dynamic> message) {
        //   print("onMessage");
        //   print(message);
        //   return;
        // }, onLaunch: (Map<String, dynamic> message) {
        //   print("onLaunch");
        //   print(message);
        //   return;
        // }, onResume: (Map<String, dynamic> message) {
        //   print("onResume");
        //   print(message);
        //   return;
        // });
      }
    });
  }

  checkActiveCall() async {
    final isOnCall = await TwilioVoice.instance.call.isOnCall();
    print("checkActiveCall $isOnCall");
    if (isOnCall &&
        !hasPushedToCall &&
        TwilioVoice.instance.call.activeCall!.callDirection ==
            CallDirection.incoming) {
      print("user is on call");
      pushToCallScreen(context);
      hasPushedToCall = true;
    }
  }

  void waitForCall() {
    checkActiveCall();
    TwilioVoice.instance.callEventsListener
      ..listen((event) {
        print("voip-onCallStateChanged $event");

        switch (event) {
          case CallEvent.answer:
            //at this point android is still paused
            if (Platform.isIOS && state == null ||
                state == AppLifecycleState.resumed) {
              pushToCallScreen(context);
              hasPushedToCall = true;
            }
            break;
          case CallEvent.ringing:
            final activeCall = TwilioVoice.instance.call.activeCall;
            if (activeCall != null) {
              final customData = activeCall.customParams;
              if (customData != null) {
                print("voip-customData $customData");
              }
            }
            break;
          case CallEvent.connected:
            if (Platform.isAndroid &&
                TwilioVoice.instance.call.activeCall!.callDirection ==
                    CallDirection.incoming) {
              if (state != AppLifecycleState.resumed) {
                TwilioVoice.instance.showBackgroundCallUI();
              } else if (state == null || state == AppLifecycleState.resumed) {
                //pushToCallScreen();
                hasPushedToCall = true;
              }
            }
            break;
          case CallEvent.callEnded:
            hasPushedToCall = false;
            break;
          case CallEvent.returningCall:
            pushToCallScreen(context);
            hasPushedToCall = true;
            break;
          default:
            break;
        }
      });
  }

  void saveNameToDb() {
    var str = _callerNameController.text;
    addressBookRef.where('uid', isEqualTo: userId).get().then((value) {
      if (value.docs.isNotEmpty) {
        var contact = value.docs[0];
        var doc = addressBookRef.doc(contact.id);
        doc.update(<String, dynamic>{"displayName": str});
        displayAlert(context, "Name Changed",
            "Your incoming call name has been changed to $str");
        dismissKeyBoard(context);
      } else {
        addressBookRef.where('displayName', isEqualTo: str).get().then((exist) {
          if (exist.docs.isEmpty) {
            addressBookRef.doc().set(Contact(uid: userId, displayName: str));
            displayAlert(context, "Name Changed",
                "Your incoming call name has been changed to $str");
            dismissKeyBoard(context);
          } else {
            displayAlert(
                context, "Name Taken", "The name $str is already taken");
          }
        });
      }
    });
  }

  void dismissKeyBoard(BuildContext context) {
    FocusScopeNode currentFocus = FocusScope.of(context);

    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  Widget noDataWidget() {
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
