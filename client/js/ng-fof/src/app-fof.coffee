fofApp = angular.module "fofApp", [
  "ngRoute",
  "ngAnimate",
  "ngTouch"
]

fofApp.config [
  "$routeProvider", "$compileProvider",
  ($routeProvider, $compileProvider) ->
    [ yamlRoutes, routeReq ] = [ {}, new XMLHttpRequest ]
    routeReq.open('GET', '/routes', false); routeReq.send null;
    if routeReq.status < 400 then for key, route of JSON.parse(routeReq.responseText).routes
      [ opts, opts.templateUrl ] = [ {}, route.templateUrl ]
      if route.controller? and route.controller isnt "None" then opts.controller = route.controller
      $routeProvider.when route.path, opts
    else window.console.error "Failed to get YAML routes file from Server: #{routeReq.response}"
    $routeProvider.otherwise { redirectTo: '/home' }
    $compileProvider.aHrefSanitizationWhitelist(/^\s*(https?|ftp|mailto|chrome-extension|spotify):/)
]

fofApp.directive "fofNav", ->
  return { restrict: "E", templateUrl: "partials/nav.html" }

fofApp.directive "fofFooter", ->
  return { restrict: "E", templateUrl: "partials/footer.html" }

fofApp.filter 'curYear',['$filter',  ($filter) ->
    return () ->
        return $filter('date')(new Date(), 'yyyy');
]