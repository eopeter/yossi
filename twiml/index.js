require('dotenv').load();

const http = require('http');
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser')
const methods = require('./src/makecall.js');
const tokenGenerator = methods.tokenGenerator;

var twilio = require('twilio');

// Create Express webapp
const app = express();

// parse application/x-www-form-urlencoded
app.use(bodyParser.urlencoded({ extended: false }))

// Create an http server and run it
const server = http.createServer(app);
const port = process.env.PORT || 3000;
server.listen(port, function() {
  console.log('Express server running on *:' + port);
});
