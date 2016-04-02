path = require "path"
fs = require("fs")
ins = require("util").inspect

conf = require("node-yaml-config").load(path.join(__dirname, (process.env.CONF_PATH or "../../conf/conf.yml")), "utf8")
twitterConf = conf.twitter
Twitter = require("twitter")
_ = require("lodash")

request = require("request")
console.log "Twitter Init"

try do ->

  twitterConf = twitterConf.quickstatsdev
  srConf = conf.sportsRadar

  client = new Twitter twitterConf.auth

  client.stream twitterConf.endpoints.stream, { track: twitterConf.mentionName },  (stream) ->
    console.log "Twitter Stream Open"
    stream.on "data", (tweet, ctx = {}) ->
      [ ctx.tweet, ctx.username, ctx.keys, ctx.replyArray ] = [ tweet, tweet.user.screen_name, tweet.text.split(/\s/g), [] ]
      ctx.replyName = "@#{ctx.username}"
      unless ctx.keys.length < 5
        [ ctx.league, ctx.year, ctx.subject, ctx.resource ] = [ ctx.keys[1].toLowerCase(), ctx.keys[2], ctx.keys[3], ctx.keys[4].toLowerCase() ]
      else ctx.err = new Error "No comprende what you say meng!"
      console.log "[#{ctx.replyName}] #{tweet.text}"
      console.log "Keywords: #{ins ctx.keys}"
      if ctx.keys[0] isnt twitterConf.mentionName then return
      getReply ctx, (ctx) -> replyTweet ctx
    stream.on "error", (err) ->
      console.error "Twitter Stream Error: #{ins err}"

  getRequestUrl = (ctx) ->
    [ endpoint, resource, apiKey ] = [ srConf.endpoints[ctx.league], ctx.resource, srConf.apiKeys[ctx.league] ]
    if resource is "schedule" then return "#{endpoint}/#{ctx.year}/REG/#{resource}#{srConf.resFormat}?api_key=#{apiKey}"

  getReply = (ctx, cb) ->
    if ctx.err then return cb ctx
    console.log "Calling Sportradar API: #{url = getRequestUrl ctx}"
    request.get url
      .on "response", (res) ->
        [ body, ctx.reply ] = [ "", "" ]
        res.on "data", (chunk) -> body += chunk.toString()
        res.on "end", ->
          weeks = JSON.parse(body).weeks
          for week in weeks
            ctx.reply += "#{week.number} "
            for game in week.games
              if game.home.toUpperCase() is ctx.subject.toUpperCase() then ctx.reply += "#{game.away} "
              else if game.away.toUpperCase() is ctx.subject.toUpperCase() then ctx.reply += "at #{game.home} "
              else ctx.reply += "BYE "
          cb ctx
      .on "error", (err) ->
        console.error "Sportradar API Error: #{ins err}"
        [ ctx.err, ctx.reply ] = [ err, "Sorry, we couldn't get that from our provider!" ]
        cb ctx

  replyTweet = (ctx) ->
    if ctx.err and !ctx.reply then setErrReply ctx
    nameLength = ctx.replyName.length
    while ctx.reply?.length > 0
      [ tweetRep, ctx.reply ] = [ ctx.reply.slice(0, (140 - nameLength)), ctx.reply.slice(140 - nameLength) ]
      ctx.replyArray.push tweetRep
    for reply in ctx.replyArray
      console.log "Sending Reply: #{reply}"
      client.post twitterConf.endpoints.tweet, { status: "#{ctx.replyName} #{reply.trim()}" }, (err, tweet, res) ->
        if err then return replyTweet ctx.err = err
        console.log "[#{twitterConf.mentionName}] #{tweet.text}"

  getTimeStamp = -> return "@ #{new Date().getTime()}"
  setErrReply = (ctx) -> return ctx.reply = "#{ctx.replyName} #{ctx.err} #{getTimeStamp()}... Go Gators, tho!"

catch err
  console.error "Error during Twitter Initialization: #{ins err.stack}"

try do ->

  _pc = twitterConf.stuffphilmisses

  client = new Twitter conf.auth

  client.stream twitterConf.endpoints.stream, { track: _pc.mentionName },  (stream) ->
    console.log "#{_pc.screenName} twitter stream open"
    stream.on "data", (tweet) ->
      i = _.random _pc.reply.troll.length
      tweet = _pc.reply.troll[i]
      client.post twitterConf.endpoints.tweet, { status: tweet }, (err, tweet, res) ->
        if err then return console.error "error while trolling phil: #{err}"
        console.log "[#{_pc.mentionName}] #{tweet.text}"
    stream.on "error", (err) ->
      console.error "Twitter Stream Error: #{ins err}"

catch err
  console.error "Error during Twitter Initialization: #{ins err.stack}"
