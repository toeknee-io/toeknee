loopback = require('loopback')
boot = require('loopback-boot')
app = module.exports = loopback()
http = require "http"
server = require('http').createServer app
async = require "async"
io = require('socket.io')(server)
global.ins = require("util").inspect

chatManager = new (require "#{process.env.FOF_SRC}/lib/chat-manager.js")(io)

# Bootstrap the application, configure models, datasources and middleware.
# Sub-apps like REST API are mounted via boot scripts.
boot app, __dirname

app.start = ->
  # start the web server
  server.listen app.get("port")
  baseUrl = app.get('url').replace(/\/$/, '')
  app.emit 'started'
  console.log 'Web server listening at: %s', baseUrl
  if app.get('loopback-component-explorer')
    explorerPath = app.get('loopback-component-explorer').mountPath
    console.log 'Browse your REST API at %s%s', baseUrl, explorerPath
  return server

# start the server if `$ node server.js`
if require.main is module
  app.start()
