const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp(functions.config().firebase);
const Twilio = require("twilio");
const {AccessToken} = require("twilio").jwt;

const {VoiceGrant} = AccessToken;


// configuration using firebase environment variables
const twilioConfig = functions.config().twilio;
const accountSid = twilioConfig.account_sid;
const authToken = twilioConfig.auth_token;
const moderator = "Da9faUE61nYVXwBqjnEsAhPu8If1";

/**
 * Creates an access token with VoiceGrant using your Twilio credentials.
 *
 * @param {Object} request - POST or GET request that provides the recipient of the call,
 * a phone number or a client
 * @param {Object} response - The Response Object for the http request
 * @returns {string} - The Access Token string and expiry date in milliseconds
 */
exports.accessToken = functions.https.onCall((payload, context) => {
  // Check user authenticated
  if (typeof (context.auth) === "undefined") {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated");
  }
  const userId = context.auth.uid;

  console.log("creating access token for ", userId);
  const apiKey = twilioConfig.api_key;
  const apiSecret = twilioConfig.api_key_secret;
  const outgoingApplicationSid = twilioConfig.app_sid;

  // Used specifically for creating Voice tokens, we need to use separate
  // push credentials for each platform.
  // iOS has different APNs environments, so we need to distinguish between sandbox & production as
  // the one won"t work in the other.

  let pushCredSid;
  switch (payload.platform) {
    case "iOS":
      console.log("creating access token for iOS");
      pushCredSid = payload.production ? twilioConfig.apple_push_credential_release :
         (twilioConfig.apple_push_credential_debug || twilioConfig.apple_push_credential_release);
      break;
    case "Android":
      console.log("creating access token for Android");
      pushCredSid = twilioConfig.android_push_credential;
      break;
    default:
      throw new functions.https.HttpsError("unknown_platform", "No platform specified");
  }

  // generate token valid for 24 hours - minimum is 3min, max is 24 hours, default is 1 hour
  const dateTime = new Date();
  dateTime.setDate(dateTime.getDate()+1);
  // Create an access token which we will sign and return to the client,
  // containing the grant we just created
  const voiceGrant = new VoiceGrant({
    outgoingApplicationSid: outgoingApplicationSid,
    pushCredentialSid: pushCredSid,
  });

  // Create an access token which we will sign and return to the client,
  // containing the grant we just created
  const token = new AccessToken(accountSid, apiKey, apiSecret);
  token.addGrant(voiceGrant);

  // use firebase ID for identity
  token.identity = userId;
  console.log(`Token:${token.toJwt()}`);

  // return json object
  return {
    "jwt_token": token.toJwt(),
    "expiry_date": dateTime.getTime(),
  };
});

exports.callStatus = functions.https.onRequest((req, res) => {
  if (req.method === "POST") {
    handleCallStatus(req.body, res);
  } else {
    res.status(405).end();
  }
  return null;
});

exports.createCallRequest = functions.firestore
    .document("callRequest/{id}")
    .onCreate((snap, context) => {
      const newCallRequest = snap.data();

      // access a particular field as you would any JS property
      const to = newCallRequest.to;
      const from = newCallRequest.from;
      const fromName = newCallRequest.fromName;
      const client = new Twilio(accountSid, authToken);
      const mp3 = "http://com.twilio.music.classical.s3.amazonaws.com/ith_chopin-15-2.mp3";
      const play = `<Play loop="100">${mp3}</Play>`;
      return client.calls
          .create({
            twiml: `<Response><Say>Please wait while we connect you to ${fromName}</Say>${play}</Response>`,
            to: `client:${to}`,
            from: `client:${moderator}`,
            callerId: from,
            statusCallback: "https://us-central1-yossi-47f69.cloudfunctions.net/callStatus",
            statusCallbackEvent: ["initiated", "ringing", "answered", "completed"],
            statusCallbackMethod: "POST",
          })
          .then((c) => {
            const ref = snap.ref;
            return ref.update({callSid: c.sid})
                .then((wt) => console.log(wt))
                .catch((e) => console.log(e));
          })
          .catch((e) => console.log(e));
    });

/**
 * Handles Call Status.
 * @param {Object} data The incoming data.
 * @param {Object} res The response.
 */
function handleCallStatus(data, res) {
  const callSid = data["CallSid"] || data["callSid"];
  const status = data["CallStatus"] || data["Status"] || data["status"];

  if (callSid && status) {
    const callRef = admin
        .firestore().collection("callRequest").where("callSid", "==", callSid);
    if (status === "in-progress") {
      console.log("call is progress. will connect");
      callRef.get().then((calls) => {
        if (!calls.empty) {
          const data = calls.docs[0].data();
          // connect call
          const from = data["from"];
          const twilio = new Twilio(accountSid, authToken);
          twilio.calls(callSid).update({twiml: `<Response><Dial><Client>${from}</Client></Dial></Response>`})
              .then((c) => {
                console.log(c.sid);
                res.status(201).end();
              });
        } else {
          res.status(404).end();
        }
      });
    }

    callRef.get().then((calls) => {
      if (!calls.empty) {
        console.log("found the call");
        calls.forEach((doc) => {
          doc.ref.update({
            status,
            when: new Date().toISOString(),
          }).then((snapshot) => {
            res.status(201).end();
          });
        });
      } else {
        res.status(404).end();
      }
    });
  } else {
    res.status(400).end();
  }
}
