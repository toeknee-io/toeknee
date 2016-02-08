fs = require "fs"
url = require 'url'
_ =  require 'lodash'
yaml = require "js-yaml"
multer  = require "multer"
storage = multer.diskStorage {
  destination: (req, file, cb) ->
    cb null, "#{process.env.FOF_SRC}/galleries/#{req._galleryId}"
  , filename: (req, file, cb) ->
    cb null, "#{file.originalname}"
}
upload = multer { storage: storage }

SpotifyWebApi = require "spotify-web-api-node"
SPOTIFY_TOKEN_EXPIRE_TIME_MS = 3592000
Promise = require 'promise'

module.exports = (server) ->

  spotifyApi = new SpotifyWebApi {
    clientId : server.get "spotify_cid"
    clientSecret : server.get "spotify_sec"
    redirectUri : server.get "spotify_acb"
  }

  SPOTIFY_UID = server.get "spotify_uid"
  setTokenTimer = true

  getSpotifyToken = () ->
    console.log 'Getting new Spotify Access Token'
    spotifyApi.clientCredentialsGrant()
    .then (data) ->
      token = data.body.access_token
      console.log "Got new Spotify Access Token: #{token}"
      spotifyApi.setAccessToken token
    , (err) ->
      console.log "Something went wrong when retrieving an access token: #{err.message}"
    if setTokenTimer
      setInterval getSpotifyToken, SPOTIFY_TOKEN_EXPIRE_TIME_MS
      setTokenTimer = false

  getSpotifyToken()

  cachedPlaylists = null
  router = server.loopback.Router()

  router.param "galleryId", (req, res, next, id) ->
    console.log "Processing request for gallery: #{id}"
    req._galleryId = id
    next()

  router.get '/uptime', server.loopback.status()
  router.get "/routes", (req, res, next) ->
    routes = yaml.safeLoad(fs.readFileSync("#{process.env.FOF_SRC}/client/js/ng-fof/config/routes.yaml", "utf8"))
    res.json routes

  router.get "/gallery/:galleryId", (req, res) ->
    console.log "Retrieving photos: for gallery [#{req._galleryId}]"
    fs.readdir "#{process.env.FOF_SRC}/galleries/#{req._galleryId}", (err, files) ->
      resStatus = 200
      data = {}
      if err
        console.log "Could not read gallery directory: #{err.message}"
        resStatus = 500
      else
        console.log "Found #{files.length} #{(if files.length is 1 then 'photo' else 'photos')} for gallery #{req._galleryId}"
        console.log(file) for file in files
        data = files
      res.status(resStatus).json(data)

  router.get "/google-test", (req, res) ->
    console.log "Got Google Callback: #{ins req}"

  router.post "/gallery/:galleryId", upload.any(), (req, res, next) ->
    console.log "Saving photo [#{JSON.stringify(req.files)}] for gallery [#{req._galleryId}]"
    res.status(200).json({})

  router.get "/spotify/auth/callback", (req, res, next) ->
    console.log "Got auth response from Spotify: #{ins req}"
    next()

  getPlaylistsTracks = (playlists) ->
    promiseFn = (resolve, reject, newPlaylists = []) ->
      for i, playlist of playlists
        [ playlist.plTracks, playlist.needsPromise ] = [ [], true]
        getNextPlaylistsTracks playlist, {}
          .then (newPlaylist) ->
            newPlaylists.push _.pick newPlaylist, [ 'images', 'name', 'plTracks', 'external_urls', 'uri' ]
            if newPlaylists.length is playlists.length then resolve newPlaylists
          , (err) -> reject err
    return new Promise promiseFn

  filterTrack = (obj) ->
    removeMkt = (currObj) ->
      if _.isObject currObj
        _.forIn currObj, (val, key) ->
          if key is 'available_markets' then delete currObj[key]
          else removeMkt currObj[key]
    removeMkt obj
    return obj

  getNextPlaylistsTracks = (playlist, opts) ->
    promiseFn = (_resolve, _reject) ->
        if playlist.needsPromise then [ playlist.resolve, playlist.reject, playlist.needsPromise ] = [ _resolve, _reject, false ]
        spotifyApi.getPlaylistTracks SPOTIFY_UID, playlist.id, opts
          .then (data) ->
            playlist.plTracks.push(filterTrack val.track) for i, val of data.body.items
            if data.body.next?
              nextQs = url.parse(data.body.next, true).query
              opts = { offset: nextQs.offset, limit: nextQs.limit }
              getNextPlaylistsTracks(playlist, opts).then
            else playlist.resolve playlist
          , (err) -> playlist.reject err
    return new Promise promiseFn

  router.get "/spotify/me/playlists", (req, res) ->
    if cachedPlaylists? then return res.json cachedPlaylists
    spotifyApi.getUserPlaylists SPOTIFY_UID, { 'fields' : 'items' }
      .then (data) ->
        playlists = data.body.items
        getPlaylistsTracks playlists
          .then((newPlaylists) ->
            console.log "Got Playlists: ", newPlaylists
            res.json newPlaylists
            cachedPlaylists = newPlaylists
          , (err) -> console.log "Something went wrong getting Playlist Tracks for User #{SPOTIFY_UID}: #{err.message}")
      , (err) ->
        console.log "Something went wrong getting Playlist for User #{SPOTIFY_UID}: #{err.message}"


  # Setup static routes
  server.use '/', server.loopback.static("#{process.env.FOF_SRC}/client/views")
  server.use '/img', server.loopback.static("#{process.env.FOF_SRC}/client/img")
  server.use '/gallery', server.loopback.static("#{process.env.FOF_SRC}/galleries")
  server.use '/js', server.loopback.static("#{process.env.FOF_SRC}/client/js")
  server.use '/css', server.loopback.static("#{process.env.FOF_SRC}/client/css")

  server.use router

  return