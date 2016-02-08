[ fs, ins, conf ] = [ require("fs"), require("util").inspect, require('node-yaml-config').load("#{process.env.FOF_SRC}/conf/conf.yml", "utf8") ]
[ twitterConf, srConf ] = [ conf.twitter, conf.sportsRadar ]
[ request, _, Twitter ] = [ require("request"), require("lodash"), require("twitter") ]

console.log "Twitter Init"

try
  client = new Twitter twitterConf.auth

  client.stream twitterConf.endpoints.stream, { track: twitterConf.mentionName },  (stream) ->
    console.log "Twitter Stream Open"
    stream.on "data", (tweet, ctx = {}) ->
      try
        [ ctx.tweet, ctx.username, ctx.keys ] = [ tweet, tweet.user.screen_name, tweet.text.split /\s/g ]
        [ ctx.replyName, ctx.year, ctx.league, ctx.subject, ctx.resource ] = [ "@#{ctx.username}", ctx.keys[1], ctx.keys[2].toLowerCase(), ctx.keys[3], ctx.keys[4].toLowerCase() ]
        console.log "[#{ctx.replyName}] #{tweet.text}"
        console.log "Keywords: #{ins ctx.keys}"
        if ctx.keys[0] isnt twitterConf.mentionName then return
      catch err
        return console.error "Error while building reply options: #{ins err}"
      getReply ctx, (err, reply) ->
        ctx.reply = reply
        replyTweet ctx
    stream.on "error", (err) ->
      console.error "Twitter Stream Error: #{ins err}"

  getRequestUrl = (ctx) ->
    [ endpoint, resource, apiKey ] = [ srConf.endpoints[ctx.league], ctx.resource, srConf.apiKeys[ctx.league] ]
    if resource is "schedule" then return "#{endpoint}/#{ctx.year}/REG/#{resource}#{srConf.resFormat}?api_key=#{apiKey}"

  getReply = (ctx, cb) ->
    console.log "Calling Sportradar API: #{url = getRequestUrl ctx}"
    request.get url
      .on "response", (res) ->
        [ body, reply ] = [ "", "" ]
        res.on "data", (chunk) -> body += chunk.toString()
        res.on "end", (replyArray = []) ->
          weeks = JSON.parse(body).weeks
          for week in weeks
            reply += "#{week.number}. "
            for game in week.games
              if game.home.toUpperCase() is ctx.subject.toUpperCase() then reply += "#{game.away} "
              else if game.away.toUpperCase() is ctx.subject.toUpperCase() then reply += "at #{game.home} "
          while reply.length > 0
            [ tweetRep, reply ] = [ reply.slice(0, (140 - 15)), reply.slice(140 - 15) ]
            replyArray.push tweetRep
          cb null, replyArray
      .on "error", (err) ->
        console.error "Sportradar API Error: #{ins err}"
        ctx.errMsg = "Sorry, we couldn't get that from our provider!"
        errTweet ctx

  replyTweet = (ctx) ->
    for reply in ctx.reply
      console.log "Sending Reply: #{reply}"
      client.post twitterConf.endpoints.tweet, { status: "#{ctx.replyName} #{reply.trim()}" }, (err, tweet, res) ->
        if err
          ctx.errMsg = err[0].message
          errTweet ctx
        console.log "[#{twitterConf.mentionName}] #{tweet.text}"

  errTweet = (ctx) ->
    client.post twitterConf.endpoints.tweet, { status: getErrReply ctx }, (err, tweet, res) ->
      if err then return console.error "Errored while sending error tweet (wtf?!) #{ins err}"
      console.log "[#{twitterConf.mentionName}] #{tweet.text}"

  getTimeStamp = -> return "@ #{new Date().getTime()}"
  getErrReply = (ctx) -> return "#{ctx.replyName} Doh: #{ctx.errMsg} #{getTimeStamp()}... Go Gators, tho!"
catch err
  console.error "Error during Twitter Initialization: #{ins err}"