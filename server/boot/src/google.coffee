## AIzaSyBypKaDE4gFyJ20dsj7krOvuXvHDJVphwQ
#
#
google = require "googleapis"
OAuth2 = google.auth.OAuth2


CLIENT_ID = "339974063286-ctqq68e7h2lmssrpsihh4rf0n9895d2t.apps.googleusercontent.com"
CLIENT_SECRET = "zFDFmsklqA4xcOYqTIrdLlG-"
REDIRECT_URL = "http://www.toekneefof.com/google-test"

oauth2Client = new OAuth2(CLIENT_ID, CLIENT_SECRET, REDIRECT_URL)

url = oauth2Client.generateAuthUrl
  access_type: "offline"
  scope: "https://www.googleapis.com/auth/hangout.telephone"

console.log "Google Init"