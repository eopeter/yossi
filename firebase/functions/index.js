const functions = require("firebase-functions");
const {AccessToken} = require("twilio").jwt;

const {VoiceGrant} = AccessToken;

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

  // configuration using firebase environment variables
  const twilioConfig = functions.config().twilio;
  const accountSid = twilioConfig.account_sid;
  const apiKey = twilioConfig.api_key;
  const apiSecret = twilioConfig.api_key_secret;
  const outgoingApplicationSid = twilioConfig.app_sid;

  // Used specifically for creating Voice tokens, we need to use separate
  // push credentials for each platform.
  // iOS has different APNs environments, so we need to distinguish between sandbox & production as
  // the one won't work in the other.

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
