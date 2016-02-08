$(document).ready ->
  $('nav li > a').click ->
    $('nav ul > li.active')?.removeClass 'active'
    $(@).parent().addClass 'active'