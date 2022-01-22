require('dotenv').load();

const AccessToken = require('twilio').jwt.AccessToken;
const VoiceGrant = AccessToken.VoiceGrant;
const VoiceResponse = require('twilio').twiml.VoiceResponse;

/**
 * Creates an endpoint that can be used in your TwiML App as the Voice Request Url.
 * <br><br>
 * In order to make an outgoing call using Twilio Voice SDK, you need to provide a
 * TwiML App SID in the Access Token. You can run your server, make it publicly
 * accessible and use `/makeCall` endpoint as the Voice Request Url in your TwiML App.
 * <br><br>
 *
 * @param {Object} request - POST or GET request that provides the recipient of the call, a phone number or a client
 * @param {Object} response - The Response Object for the http request
 * @returns {Object} - The Response Object with TwiMl, used to respond to an outgoing call
 */
exports.handler = function(context, event, callback) {
    console.log(event);
    const from = event.From;
    let roomName = `${from}`;

    const twiml = new VoiceResponse();

    // Start with a <Dial> verb
    const dial = twiml.dial();
    // If the caller is the Initiator, then start the conference when they
    // join and end the conference when they leave
    if (from == originalFrom) {
        dial.conference(roomName, {
            startConferenceOnEnter: true,
            endConferenceOnExit: true,
        });
    } else {
        // Otherwise have the caller join as a regular participant
        dial.conference(roomName, {
            startConferenceOnEnter: false,
        });
    }

    callback(null, twiml);
}

const isEmptyOrNull = (s) => {
    return !s || s === '';
}

function isNumber(to) {
  if(to.length == 1) {
    if(!isNaN(to)) {
      console.log("It is a 1 digit long number" + to);
      return true;
    }
  } else if(String(to).charAt(0) == '+') {
    number = to.substring(1);
    if(!isNaN(number)) {
      console.log("It is a number " + to);
      return true;
    };
  } else {
    if(!isNaN(to)) {
      console.log("It is a number " + to);
      return true;
    }
  }
  console.log("not a number");
  return false;
}
