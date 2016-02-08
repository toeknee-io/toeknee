fofApp = angular.module "fofApp"

fofApp.controller "ChatController", [
  "$scope"
  ($scope) ->
    socket = io.connect()
    $scope.messages = []
    $scope.roster = []
    $scope.name = ''
    $scope.text = ''
    socket.on 'connect', ->
      $scope.setName()
      return
    socket.on 'message', (msg) ->
      $scope.messages.push msg
      $scope.$apply()
      return
    socket.on 'roster', (names) ->
      $scope.roster = names
      $scope.$apply()
      return
    $scope.send = ->
      window.console.log 'Sending message:', $scope.text
      socket.emit 'message', { name: $scope.name, msg: $scope.text }
      $scope.text = ''
      return
    $scope.setName = ->
      socket.emit 'identify', $scope.name
      return
]

fofApp.controller "GalleryController", [
  "$scope",
  "$http",
  "$routeParams"
  ($scope, $http, $routeParams) ->
    galleryId = $routeParams.galleryId or ""
    $scope.photos = []
    $("#file-input").fileinput {
      uploadUrl: "gallery/#{galleryId}"
      showPreview: true
    }
    $scope.getPhotos = () ->
      $http.get("gallery/#{galleryId}").then (res) ->
        window.console.log "Files found: #{JSON.stringify res.data}"
        $scope.photos = []
        for file in res.data
          window.console.log "Creating src for file: #{file}"
          $scope.photos.push { src: "gallery/#{$routeParams.galleryId}/#{file}", desc: 'Image 01' }
      , (res) ->
        window.console.log JSON.stringify res
    $scope.getPhotos()
    $('#file-input').on 'fileuploaded', (event, data, previewId, index) ->
      [ form, files, extra, response, reader ] = [ data.form, data.files, data.extra, data.response, data.reader ]
      console.log 'File uploaded triggered'
      $scope.getPhotos()
    window.console.log "Route params: #{JSON.stringify($routeParams)}"
    # initial image index
    $scope._Index = 0
    $scope.isActive = (index) ->
      return $scope._Index is index
    $scope.showPrev = (index) ->
      $scope._Index = if ($scope._Index > 0) then --$scope._Index else $scope.photos.length - 1
      window.console.log "Scope index: #{$scope._Index}"
      return
    $scope.showNext = (index) ->
      $scope._Index = if ($scope._Index < $scope.photos.length - 1) then ++$scope._Index else 0
      window.console.log "Scope index: #{$scope._Index}"
      return
    $scope.showPhoto = (index) ->
      $scope._Index = index
      window.console.log "Scope index: #{$scope._Index}"
      return
]

fofApp.controller "SpotifyController", [
  "$scope", "$http", "$animate", "$interval"
  ($scope, $http, $animate, $interval) ->
    $animate.enabled true
    window.console.log "Angular animations are enabled: #{$animate.enabled()}"
    [ $scope.myPlaylists, $scope.activeIndex,  $scope.swap, $scope.processing ] = [ [], 0, "cover", false ]
    $scope.prevIndex = $scope.activeIndex
    $http.get("/spotify/me/playlists").then (res) ->
      $scope.myPlaylists.push playlist for playlist in res.data
      $scope.activePlaylist = $scope.myPlaylists[$scope.activeIndex]
    $scope.setCarousel = (i) ->
      unless $scope.processing
        $scope.processing = true
        if i > $scope.activeIndex then moveOut = 'move-out-right'; moveIn = 'move-in-left' else moveOut = 'move-out-left'; moveIn = 'move-in-right'
        if i < 0 then i = ($scope.myPlaylists.length - 1)
        else if i >= $scope.myPlaylists.length then i = 0
        $scope.activePlaylist = $scope.myPlaylists[i]
        $("#playlist-cover-#{$scope.activeIndex}").addClass(moveOut)
        $("#playlist-cover-#{$scope.activeIndex}").removeClass 'active'
        $interval ->
          $("#playlist-cover-#{$scope.activeIndex}").removeClass moveOut; $("#playlist-cover-#{i}").addClass(moveIn)
          $interval ->
            $("#playlist-cover-#{i}").removeClass(moveIn)
            [ $scope.prevIndex, $scope.activeIndex, $scope.processing ] = [ $scope.activeIndex, i, false ]
          , 260, 1
        , 250, 1
    $animate.on "addClass", angular.element(document).find("#spotify-playlist-carousel"), (elm, phase) ->
      window.console.log "Class add detected"
    $animate.on "removeClass", angular.element(document).find("#spotify-playlist-carousel"), (elm, phase) ->
      window.console.log "Class removal detected"
]